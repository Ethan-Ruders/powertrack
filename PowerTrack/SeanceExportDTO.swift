//
//  SeanceExportDTO.swift
//  PowerTrack
//
//  Created by ethan ruders on 13/08/2026.
//

import Foundation
import Combine

// MARK: - Structures DTO (Data Transfer Objects) pour le JSON v2

/// Charge utile complète d'une séance exportée vers le serveur Linux (n8n -> PostgreSQL).
struct SeanceExportDTO: Codable, Sendable {
    let schemaVersion: Int
    let seanceId: String
    let exportDate: String
    let dateSeance: String
    let blocNom: String?
    let blocDateDebut: String?
    let bloc1RM: BlocReference1RMDTO?
    let semaineNumero: Int?
    let semaineNom: String
    let seanceTitre: String?
    let heureDebut: String?
    let dureeMinutes: Int?
    let seriesValideesCount: Int
    let seriesProgrammeesCount: Int
    let tauxCompletion: Double
    let tonnageTotalKg: Double
    let ressenti: RessentiSeanceDTO?
    let exercices: [ExerciceExportDTO]
}

struct BlocReference1RMDTO: Codable, Sendable {
    let squat: Double
    let bench: Double
    let deadlift: Double
}

/// Check-in subjectif et signaux de récupération saisis par l'athlète.
struct RessentiSeanceDTO: Codable, Equatable, Sendable {
    var poidsCorpsKg: Double?
    var sommeilHeures: Double?
    var niveauEnergie: Int?
    var fatigueLombaire: Int?
    var stress: Int?
    var hydratationLitres: Double?
    var douleurSignalee: String?
    var notesSeance: String?
    
    var isEmpty: Bool {
        let douleurVide = douleurSignalee?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        let notesVides = notesSeance?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        return poidsCorpsKg == nil
            && sommeilHeures == nil
            && niveauEnergie == nil
            && fatigueLombaire == nil
            && stress == nil
            && hydratationLitres == nil
            && douleurVide
            && notesVides
    }
    
    func normalized() -> RessentiSeanceDTO? {
        let cleaned = RessentiSeanceDTO(
            poidsCorpsKg: poidsCorpsKg,
            sommeilHeures: sommeilHeures,
            niveauEnergie: niveauEnergie,
            fatigueLombaire: fatigueLombaire,
            stress: stress,
            hydratationLitres: hydratationLitres,
            douleurSignalee: douleurSignalee?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            notesSeance: notesSeance?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        return cleaned.isEmpty ? nil : cleaned
    }
}

struct ExerciceExportDTO: Codable, Sendable {
    let ordre: Int
    let nom: String
    let categorie: String
    let mouvementParent: String
    let indications: String?
    let tonnageKg: Double
    let meilleurE1RM: Double?
    let series: [SerieExportDTO]
}

struct SerieExportDTO: Codable, Sendable {
    let numero: Int
    let repsCibles: Int
    let rpeCible: Double
    let charge: Double?
    let rpe: Double?
    let deltaRPE: Double?
    let e1RM: Double?
    let estValidee: Bool
}

// MARK: - File d'attente hors-ligne & Résultats

struct ExportQueueItem: Codable, Identifiable, Sendable {
    let id: UUID
    let seanceId: String
    let titre: String
    let createdAt: Date
    let payloadData: Data
    var lastError: String?
}

enum ExportOutcome: Sendable {
    case sent(statusCode: Int, jsonString: String)
    case queuedOffline(reason: String, jsonString: String)
    case missingConfiguration(jsonString: String)
}

// MARK: - Manager d'Export & Configuration Serveur

final class ExportManager: ObservableObject {
    static let shared = ExportManager()
    
    private enum Keys {
        static let webhookURL = "pt_n8n_webhook_url"
        static let authHeaderName = "pt_n8n_auth_header_name"
        static let authHeaderValue = "pt_n8n_auth_header_value"
        static let pendingQueue = "pt_export_pending_queue"
        static let ressentiPrefix = "pt_ressenti_"
        static let lastBodyweightKg = "pt_last_bodyweight_kg"
    }
    
    private let defaults = UserDefaults.standard
    
    @Published var webhookURL: String {
        didSet { defaults.set(webhookURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.webhookURL) }
    }
    
    @Published var authHeaderName: String {
        didSet { defaults.set(authHeaderName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.authHeaderName) }
    }
    
    @Published var authHeaderValue: String {
        didSet { defaults.set(authHeaderValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.authHeaderValue) }
    }
    
    @Published private(set) var pendingQueue: [ExportQueueItem] = []
    
    private init() {
        self.webhookURL = defaults.string(forKey: Keys.webhookURL) ?? ""
        self.authHeaderName = defaults.string(forKey: Keys.authHeaderName) ?? "X-API-Key"
        self.authHeaderValue = defaults.string(forKey: Keys.authHeaderValue) ?? ""
        self.pendingQueue = Self.loadQueue(from: defaults)
    }
    
    var hasValidWebhookURL: Bool {
        guard let url = resolvedWebhookURL() else { return false }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }
    
    // MARK: - Persistance locale des ressentis
    
    func loadRessenti(for seance: Seance) -> RessentiSeanceDTO {
        let key = Keys.ressentiPrefix + seance.trackingKey
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(RessentiSeanceDTO.self, from: data) {
            return decoded
        }
        let lastWeight = defaults.object(forKey: Keys.lastBodyweightKg) as? Double
        return RessentiSeanceDTO(poidsCorpsKg: lastWeight)
    }
    
    func saveRessenti(_ ressenti: RessentiSeanceDTO, for seance: Seance) {
        let key = Keys.ressentiPrefix + seance.trackingKey
        if let encoded = try? JSONEncoder().encode(ressenti) {
            defaults.set(encoded, forKey: key)
        }
        if let bw = ressenti.poidsCorpsKg, bw > 0 {
            defaults.set(bw, forKey: Keys.lastBodyweightKg)
        }
    }
    
    // MARK: - Construction du Payload JSON v2
    
    func buildDTO(seance: Seance, ressenti: RessentiSeanceDTO? = nil) -> SeanceExportDTO {
        let isoFormatter = ISO8601DateFormatter()
        let now = Date()
        
        let exercicesTries = seance.exercices.sorted { $0.ordre < $1.ordre }
        var exercicesExport: [ExerciceExportDTO] = []
        var tonnageTotalSeance: Double = 0
        
        for exercice in exercicesTries {
            var seriesExport: [SerieExportDTO] = []
            var tonnageExercice: Double = 0
            var meilleurE1RMExercice: Double? = nil
            
            for (index, serie) in exercice.series.enumerated() {
                let charge = serie.chargeSaisie
                let rpeReel = serie.rpeSaisi
                let e1rm = serie.estValidee ? serie.calculerE1RM() : nil
                
                let deltaRPE: Double?
                if serie.estValidee, let rpe = rpeReel {
                    deltaRPE = ((rpe - serie.rpeCible) * 10.0).rounded() / 10.0
                } else {
                    deltaRPE = nil
                }
                
                if serie.estValidee, let c = charge, c > 0 {
                    tonnageExercice += c * Double(serie.repsCibles)
                }
                if let valE1rm = e1rm {
                    meilleurE1RMExercice = max(meilleurE1RMExercice ?? 0, valE1rm)
                }
                
                seriesExport.append(
                    SerieExportDTO(
                        numero: index + 1,
                        repsCibles: serie.repsCibles,
                        rpeCible: serie.rpeCible,
                        charge: charge,
                        rpe: rpeReel,
                        deltaRPE: deltaRPE,
                        e1RM: e1rm,
                        estValidee: serie.estValidee
                    )
                )
            }
            
            tonnageTotalSeance += tonnageExercice
            
            exercicesExport.append(
                ExerciceExportDTO(
                    ordre: exercice.ordre,
                    nom: exercice.nom,
                    categorie: exercice.categorie.rawValue,
                    mouvementParent: Self.mouvementParent(pour: exercice.nom),
                    indications: exercice.indications,
                    tonnageKg: (tonnageExercice * 10.0).rounded() / 10.0,
                    meilleurE1RM: meilleurE1RMExercice,
                    series: seriesExport
                )
            )
        }
        
        let bloc = seance.semaine?.macroBloc
        let bloc1RM: BlocReference1RMDTO? = bloc.map {
            BlocReference1RMDTO(squat: $0.squat1RM, bench: $0.bench1RM, deadlift: $0.deadlift1RM)
        }
        
        let startDate = SeanceProgressTracker.shared.sessionStartDate(for: seance)
        let dureeMinutes = SeanceProgressTracker.shared.sessionDurationMinutes(for: seance)
        let ressentiEffectif = (ressenti ?? loadRessenti(for: seance)).normalized()
        
        return SeanceExportDTO(
            schemaVersion: 2,
            seanceId: seance.trackingKey,
            exportDate: isoFormatter.string(from: now),
            dateSeance: isoFormatter.string(from: seance.date),
            blocNom: bloc?.nom,
            blocDateDebut: bloc.map { isoFormatter.string(from: $0.dateDebut) },
            bloc1RM: bloc1RM,
            semaineNumero: seance.semaine?.numero,
            semaineNom: seance.semaine?.nom ?? "Semaine inconnue",
            seanceTitre: seance.titre,
            heureDebut: startDate.map { isoFormatter.string(from: $0) },
            dureeMinutes: dureeMinutes,
            seriesValideesCount: seance.validatedSeriesCount,
            seriesProgrammeesCount: seance.totalSeriesCount,
            tauxCompletion: (seance.progressionRatio * 1000.0).rounded() / 1000.0,
            tonnageTotalKg: (tonnageTotalSeance * 10.0).rounded() / 10.0,
            ressenti: ressentiEffectif,
            exercices: exercicesExport
        )
    }
    
    func buildPayloadData(for seance: Seance, ressenti: RessentiSeanceDTO? = nil) throws -> Data {
        let dto = buildDTO(seance: seance, ressenti: ressenti)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(dto)
    }
    
    func genererJSONString(for seance: Seance, ressenti: RessentiSeanceDTO? = nil) -> String {
        do {
            let data = try buildPayloadData(for: seance, ressenti: ressenti)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"\(error.localizedDescription)\"}"
        }
    }
    
    // MARK: - Envoi Réseau & File Hors-Ligne
    
    /// Encode et envoie la séance vers le webhook n8n configuré, ou la place en file hors-ligne en cas d'échec réseau.
    @discardableResult
    func exporterSeance(seance: Seance, webhookURL customURL: String? = nil, ressenti: RessentiSeanceDTO? = nil) async -> ExportOutcome {
        if let ressenti {
            saveRessenti(ressenti, for: seance)
        }
        
        let payloadData: Data
        do {
            payloadData = try buildPayloadData(for: seance, ressenti: ressenti)
        } catch {
            return .queuedOffline(reason: "Encodage JSON impossible : \(error.localizedDescription)", jsonString: "{}")
        }
        
        let jsonString = String(data: payloadData, encoding: .utf8) ?? "{}"
        let targetURLString = (customURL ?? webhookURL).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = Self.validatedURL(from: targetURLString) else {
            return .missingConfiguration(jsonString: jsonString)
        }
        
        do {
            let statusCode = try await postJSONData(payloadData, to: url)
            removeFromQueue(seanceId: seance.trackingKey)
            return .sent(statusCode: statusCode, jsonString: jsonString)
        } catch {
            let titre = seance.titre ?? seance.date.formatted(date: .abbreviated, time: .omitted)
            enqueueOffline(
                ExportQueueItem(
                    id: UUID(),
                    seanceId: seance.trackingKey,
                    titre: titre,
                    createdAt: Date(),
                    payloadData: payloadData,
                    lastError: error.localizedDescription
                )
            )
            return .queuedOffline(reason: error.localizedDescription, jsonString: jsonString)
        }
    }
    
    /// Tente de renvoyer toutes les séances en attente dans la file hors-ligne.
    func flushPendingQueue() async -> (sent: Int, remaining: Int, lastError: String?) {
        guard let url = resolvedWebhookURL() else {
            return (0, pendingQueue.count, "URL webhook non configurée")
        }
        
        var remainingItems: [ExportQueueItem] = []
        var sentCount = 0
        var lastError: String? = nil
        
        for var item in pendingQueue {
            do {
                _ = try await postJSONData(item.payloadData, to: url)
                sentCount += 1
            } catch {
                item.lastError = error.localizedDescription
                lastError = error.localizedDescription
                remainingItems.append(item)
            }
        }
        
        pendingQueue = remainingItems
        saveQueue()
        return (sentCount, remainingItems.count, lastError)
    }
    
    func clearPendingQueue() {
        pendingQueue = []
        saveQueue()
    }
    
    /// Envoie un ping de test léger au webhook n8n configuré.
    func testerConnexion() async -> Result<Int, Error> {
        guard let url = resolvedWebhookURL() else {
            return .failure(NSError(domain: "ExportManager", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "URL webhook invalide ou vide."
            ]))
        }
        
        let pingPayload: [String: String] = [
            "type": "powertrack_ping",
            "schemaVersion": "2",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: pingPayload, options: [.sortedKeys])
            let status = try await postJSONData(data, to: url)
            return .success(status)
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Helpers Privés
    
    private func resolvedWebhookURL() -> URL? {
        Self.validatedURL(from: webhookURL)
    }
    
    private static func validatedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }
        return url
    }
    
    private func postJSONData(_ data: Data, to url: URL) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let headerName = authHeaderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let headerValue = authHeaderValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !headerName.isEmpty && !headerValue.isEmpty {
            request.setValue(headerValue, forHTTPHeaderField: headerName)
        }
        
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ExportManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Réponse serveur non HTTP."
            ])
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ExportManager", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Le serveur a répondu HTTP \(httpResponse.statusCode)."
            ])
        }
        return httpResponse.statusCode
    }
    
    private func enqueueOffline(_ item: ExportQueueItem) {
        if let idx = pendingQueue.firstIndex(where: { $0.seanceId == item.seanceId }) {
            pendingQueue[idx] = item
        } else {
            pendingQueue.append(item)
        }
        saveQueue()
    }
    
    private func removeFromQueue(seanceId: String) {
        pendingQueue.removeAll { $0.seanceId == seanceId }
        saveQueue()
    }
    
    private func saveQueue() {
        if let encoded = try? JSONEncoder().encode(pendingQueue) {
            defaults.set(encoded, forKey: Keys.pendingQueue)
        }
    }
    
    private static func loadQueue(from defaults: UserDefaults) -> [ExportQueueItem] {
        guard let data = defaults.data(forKey: Keys.pendingQueue),
              let decoded = try? JSONDecoder().decode([ExportQueueItem].self, from: data) else {
            return []
        }
        return decoded
    }
    
    static func mouvementParent(pour nom: String) -> String {
        let lower = nom.lowercased()
        if lower.contains("bench") || lower.contains("développé couché") || lower.contains("developpe couche")
            || lower.contains("spoto") || lower.contains("larsen") || lower.contains("3ct") {
            return "bench"
        }
        if lower.contains("squat") {
            return "squat"
        }
        if lower.contains("deadlift") || lower.contains("soulevé de terre") || lower.contains("souleve de terre")
            || lower.contains("deficit") || lower.contains("déficit") || lower.contains("block pull") {
            return "deadlift"
        }
        return "autre"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
