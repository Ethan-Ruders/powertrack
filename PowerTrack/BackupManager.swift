//
//  BackupManager.swift
//  PowerTrack
//
//  Created by PowerTrack on 22/11/2026.
//

import Foundation
import SwiftData
#if canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI
import UniformTypeIdentifiers
#endif

// MARK: - DTOs de Sauvegarde Complète Locale

nonisolated struct PowerTrackBackupDTO: Codable, Sendable {
    let schemaVersion: Int
    let exportDate: Date
    let blocs: [BackupBlocDTO]
    let ressentis: [String: RessentiSeanceDTO]
}

nonisolated struct BackupBlocDTO: Codable, Sendable {
    let nom: String
    let dateDebut: Date
    let squat1RM: Double
    let bench1RM: Double
    let deadlift1RM: Double
    let semaines: [BackupSemaineDTO]
}

nonisolated struct BackupSemaineDTO: Codable, Sendable {
    let numero: Int
    let nom: String
    let seances: [BackupSeanceDTO]
}

nonisolated struct BackupSeanceDTO: Codable, Sendable {
    let date: Date
    let titre: String?
    let trackingKey: String?
    let exercices: [BackupExerciceDTO]
}

nonisolated struct BackupExerciceDTO: Codable, Sendable {
    let nom: String
    let categorie: String
    let indications: String?
    let ordre: Int
    let series: [BackupSerieDTO]
}

nonisolated struct BackupSerieDTO: Codable, Sendable {
    let ordre: Int
    let repsCibles: Int
    let rpeCible: Double
    let chargeSaisie: Double?
    let rpeSaisi: Double?
    let estValidee: Bool
}

nonisolated struct BackupRestoreSummary: Sendable {
    let blocsRestored: Int
    let seancesRestored: Int
    let seriesValideesRestored: Int
    let ressentisRestored: Int
}

// MARK: - Gestionnaire Export / Restauration Complète

enum BackupManager {
    static let currentSchemaVersion = 1
    
    /// Construit l'instantané complet de tous les blocs SwiftData (et des ressentis associés).
    static func buildBackupDTO(from modelContext: ModelContext, includeRessentis: Bool = true) throws -> PowerTrackBackupDTO {
        let descriptor = FetchDescriptor<MacroBloc>(sortBy: [SortDescriptor(\.dateDebut, order: .forward)])
        let blocs = try modelContext.fetch(descriptor)
        
        var ressentis: [String: RessentiSeanceDTO] = [:]
        var backupBlocs: [BackupBlocDTO] = []
        
        for bloc in blocs {
            let semainesTries = bloc.semaines.sorted { $0.numero < $1.numero }
            var backupSemaines: [BackupSemaineDTO] = []
            
            for semaine in semainesTries {
                let seancesTries = semaine.seances.sorted { $0.date < $1.date }
                var backupSeances: [BackupSeanceDTO] = []
                
                for seance in seancesTries {
                    let key = seance.trackingKey
                    if includeRessentis,
                       let ressenti = ExportManager.shared.storedRessentiIfPresent(for: seance) {
                        ressentis[key] = ressenti
                    }
                    
                    let exercicesTries = seance.exercices.sorted { $0.ordre < $1.ordre }
                    let backupExercices: [BackupExerciceDTO] = exercicesTries.map { ex in
                        let backupSeries = ex.seriesTriees.enumerated().map { idx, ser in
                            BackupSerieDTO(
                                ordre: idx,
                                repsCibles: ser.repsCibles,
                                rpeCible: ser.rpeCible,
                                chargeSaisie: ser.chargeSaisie,
                                rpeSaisi: ser.rpeSaisi,
                                estValidee: ser.estValidee
                            )
                        }
                        return BackupExerciceDTO(
                            nom: ex.nom,
                            categorie: ex.categorie.rawValue,
                            indications: ex.indications,
                            ordre: ex.ordre,
                            series: backupSeries
                        )
                    }
                    
                    backupSeances.append(
                        BackupSeanceDTO(
                            date: seance.date,
                            titre: seance.titre,
                            trackingKey: key,
                            exercices: backupExercices
                        )
                    )
                }
                
                backupSemaines.append(
                    BackupSemaineDTO(
                        numero: semaine.numero,
                        nom: semaine.nom,
                        seances: backupSeances
                    )
                )
            }
            
            backupBlocs.append(
                BackupBlocDTO(
                    nom: bloc.nom,
                    dateDebut: bloc.dateDebut,
                    squat1RM: bloc.squat1RM,
                    bench1RM: bloc.bench1RM,
                    deadlift1RM: bloc.deadlift1RM,
                    semaines: backupSemaines
                )
            )
        }
        
        return PowerTrackBackupDTO(
            schemaVersion: currentSchemaVersion,
            exportDate: Date(),
            blocs: backupBlocs,
            ressentis: ressentis
        )
    }
    
    /// Encode la sauvegarde complète au format JSON formaté (ISO8601).
    static func exportBackupJSON(from modelContext: ModelContext, includeRessentis: Bool = true) throws -> Data {
        let dto = try buildBackupDTO(from: modelContext, includeRessentis: includeRessentis)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(dto)
    }
    
    /// Décode et valide une sauvegarde complète JSON.
    static func parseBackup(from data: Data) throws -> PowerTrackBackupDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(PowerTrackBackupDTO.self, from: data)
        guard dto.schemaVersion == currentSchemaVersion else {
            throw NSError(
                domain: "BackupManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Version de sauvegarde non supportée (v\(dto.schemaVersion))."]
            )
        }
        return dto
    }
    
    /// Restaure une sauvegarde dans SwiftData (en ajoutant ou en remplaçant les blocs existants).
    @discardableResult
    static func restoreBackup(
        _ backup: PowerTrackBackupDTO,
        into modelContext: ModelContext,
        replaceExisting: Bool
    ) throws -> BackupRestoreSummary {
        if replaceExisting {
            let existing = try modelContext.fetch(FetchDescriptor<MacroBloc>())
            for bloc in existing {
                modelContext.delete(bloc)
            }
        }
        
        var seancesCount = 0
        var seriesValideesCount = 0
        var ressentisCount = 0
        
        for blocDTO in backup.blocs {
            let bloc = MacroBloc(
                nom: blocDTO.nom,
                dateDebut: blocDTO.dateDebut,
                squat1RM: blocDTO.squat1RM,
                bench1RM: blocDTO.bench1RM,
                deadlift1RM: blocDTO.deadlift1RM
            )
            
            for semDTO in blocDTO.semaines.sorted(by: { $0.numero < $1.numero }) {
                let semaine = Semaine(numero: semDTO.numero, nom: semDTO.nom)
                semaine.macroBloc = bloc
                
                for seaDTO in semDTO.seances {
                    let seance = Seance(date: seaDTO.date, titre: seaDTO.titre)
                    seance.semaine = semaine
                    seancesCount += 1
                    
                    for exDTO in seaDTO.exercices.sorted(by: { $0.ordre < $1.ordre }) {
                        let cat = CategorieExercice(rawValue: exDTO.categorie.lowercased()) ?? .polyarticulaire
                        let ex = Exercice(
                            nom: exDTO.nom,
                            categorie: cat,
                            indications: exDTO.indications,
                            ordre: exDTO.ordre
                        )
                        ex.seance = seance
                        
                        for (idx, serDTO) in exDTO.series.sorted(by: { $0.ordre < $1.ordre }).enumerated() {
                            let serie = Serie(
                                repsCibles: serDTO.repsCibles,
                                rpeCible: serDTO.rpeCible,
                                chargeSaisie: serDTO.chargeSaisie,
                                rpeSaisi: serDTO.rpeSaisi,
                                estValidee: serDTO.estValidee,
                                ordre: serDTO.ordre > 0 || idx == 0 ? serDTO.ordre : idx
                            )
                            serie.exercice = ex
                            ex.series.append(serie)
                            if serDTO.estValidee {
                                seriesValideesCount += 1
                            }
                        }
                        
                        seance.exercices.append(ex)
                    }
                    
                    if let savedKey = seaDTO.trackingKey,
                       let ressenti = backup.ressentis[savedKey],
                       !ressenti.isEmpty {
                        ExportManager.shared.saveRessenti(ressenti, for: seance)
                        ressentisCount += 1
                    }
                    
                    semaine.seances.append(seance)
                }
                
                bloc.semaines.append(semaine)
            }
            
            modelContext.insert(bloc)
        }
        
        try modelContext.save()
        
        return BackupRestoreSummary(
            blocsRestored: backup.blocs.count,
            seancesRestored: seancesCount,
            seriesValideesRestored: seriesValideesCount,
            ressentisRestored: ressentisCount
        )
    }
}

#if canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
nonisolated struct PowerTrackJSONDocument: FileDocument, Sendable {
    static let readableContentTypes: [UTType] = [.json]
    
    var data: Data
    
    init(data: Data = Data()) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let content = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = content
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
