//
//  models.swift
//  PowerTrack
//
//  Created by ethan ruders on 11/07/2026.
//

import Foundation
import SwiftData
import Combine

// MARK: - Énumérations & Classification SBD

nonisolated enum CategorieExercice: String, Codable, Sendable {
    case competition
    case polyarticulaire
    case isolation
}

nonisolated enum TypeEchauffementExercice: Equatable, Sendable {
    case sbdOuVariante
    case polyarticulaireAccessoire
    case aucun
}

nonisolated enum MouvementParent: String, CaseIterable, Identifiable, Codable, Sendable {
    case squat
    case bench
    case deadlift
    case autre
    
    var id: String { rawValue }
    
    var nomAffichage: String {
        switch self {
        case .squat: return "Squat"
        case .bench: return "Bench"
        case .deadlift: return "Deadlift"
        case .autre: return "Autre"
        }
    }
    
    /// Détermine le mouvement de compétition parent depuis le nom d'exercice.
    static func detecter(nomExercice: String) -> MouvementParent {
        let lower = nomExercice.lowercased()
        if lower.contains("bench")
            || lower.contains("développé couché")
            || lower.contains("developpe couche")
            || lower.contains("spoto")
            || lower.contains("larsen")
            || lower.contains("3ct") {
            return .bench
        }
        if lower.contains("squat") {
            return .squat
        }
        if lower.contains("deadlift")
            || lower.contains("soulevé de terre")
            || lower.contains("souleve de terre")
            || lower.contains("deficit")
            || lower.contains("déficit")
            || lower.contains("block pull") {
            return .deadlift
        }
        return .autre
    }
    
    /// Indique s'il s'agit d'un mouvement SBD de compétition pur (hors variantes / accessoires).
    static func estMouvementCompetition(nomExercice: String, categorie: CategorieExercice) -> Bool {
        guard detecter(nomExercice: nomExercice) != .autre else { return false }
        let lower = nomExercice.lowercased()
        let motsClesVariante = [
            "pause", "tempo", "box", "spoto", "larsen", "3ct",
            "deficit", "déficit", "block pull", "pin", "board",
            "close grip", "prise serrée", "prise serree",
            "incliné", "incline", "bulgare", "hack", "goblet",
            "front", "rdl", "roumain", "stiff"
        ]
        return categorie == .competition && !motsClesVariante.contains(where: { lower.contains($0) })
    }
}

// MARK: - Scores de Force Athlétique (DOTS & IPF GL)

nonisolated enum PowerliftingScoring {
    /// Calcule le score DOTS officiel masculin (identique à `analyze_powertrack.py`).
    static func dotsMale(totalKg: Double, bodyweightKg: Double) -> Double? {
        guard totalKg > 0, bodyweightKg > 0 else { return nil }
        let bw = bodyweightKg
        let denom = -307.75076
            + 24.0900756 * bw
            - 0.1918759221 * pow(bw, 2)
            + 0.0007391293 * pow(bw, 3)
            - 0.000001093 * pow(bw, 4)
        guard denom > 0 else { return nil }
        return ((totalKg * 500.0) / denom * 100.0).rounded() / 100.0
    }
    
    /// Calcule le score DOTS officiel féminin.
    static func dotsFemale(totalKg: Double, bodyweightKg: Double) -> Double? {
        guard totalKg > 0, bodyweightKg > 0 else { return nil }
        let bw = bodyweightKg
        let denom = -57.96288
            + 13.6175032 * bw
            - 0.1126655495 * pow(bw, 2)
            + 0.0005158568 * pow(bw, 3)
            - 0.0000010706 * pow(bw, 4)
        guard denom > 0 else { return nil }
        return ((totalKg * 500.0) / denom * 100.0).rounded() / 100.0
    }
    
    /// Calcule le score IPF Goodlift officiel masculin Classic (3-lift raw).
    static func ipfGLMaleClassic(totalKg: Double, bodyweightKg: Double) -> Double? {
        guard totalKg > 0, bodyweightKg > 0 else { return nil }
        let denom = 1199.72839 - 1025.18162 * exp(-0.00921 * bodyweightKg)
        guard denom > 0 else { return nil }
        return ((totalKg * 100.0) / denom * 100.0).rounded() / 100.0
    }
    
    /// Calcule le score IPF Goodlift officiel féminin Classic (3-lift raw).
    static func ipfGLFemaleClassic(totalKg: Double, bodyweightKg: Double) -> Double? {
        guard totalKg > 0, bodyweightKg > 0 else { return nil }
        let denom = 610.32796 - 1045.59282 * exp(-0.03048 * bodyweightKg)
        guard denom > 0 else { return nil }
        return ((totalKg * 100.0) / denom * 100.0).rounded() / 100.0
    }
}

// MARK: - Modèles

@Model
final class MacroBloc {
    var nom: String
    var dateDebut: Date
    var squat1RM: Double
    var bench1RM: Double
    var deadlift1RM: Double
    
    @Relationship(deleteRule: .cascade, inverse: \Semaine.macroBloc)
    var semaines: [Semaine] = []
    
    init(nom: String, dateDebut: Date = Date(), squat1RM: Double = 0.0, bench1RM: Double = 0.0, deadlift1RM: Double = 0.0) {
        self.nom = nom
        self.dateDebut = dateDebut
        self.squat1RM = squat1RM
        self.bench1RM = bench1RM
        self.deadlift1RM = deadlift1RM
    }
    
    /// Nombre total de séries programmées sur tout le bloc.
    var totalSeriesCount: Int {
        semaines.reduce(0) { $0 + $1.totalSeriesCount }
    }
    
    /// Nombre total de séries validées sur tout le bloc.
    var validatedSeriesCount: Int {
        semaines.reduce(0) { $0 + $1.validatedSeriesCount }
    }
    
    /// Ratio de complétion global du bloc (0.0 à 1.0).
    var progressionRatio: Double {
        let total = totalSeriesCount
        guard total > 0 else { return 0.0 }
        return Double(validatedSeriesCount) / Double(total)
    }
    
    /// Numéro de la première semaine inachevée (ou de la dernière semaine si tout est validé).
    var activeSemaineNumero: Int? {
        let tries = semaines.sorted { $0.numero < $1.numero }
        if let firstIncomplete = tries.first(where: { $0.validatedSeriesCount < $0.totalSeriesCount }) {
            return firstIncomplete.numero
        }
        return tries.last?.numero
    }
}

@Model
final class Semaine {
    var numero: Int
    var nom: String
    var macroBloc: MacroBloc?
    
    @Relationship(deleteRule: .cascade, inverse: \Seance.semaine)
    var seances: [Seance] = []
    
    init(numero: Int, nom: String) {
        self.numero = numero
        self.nom = nom
    }
    
    /// Nombre total de séries programmées dans la semaine.
    var totalSeriesCount: Int {
        seances.reduce(0) { $0 + $1.totalSeriesCount }
    }
    
    /// Nombre total de séries validées dans la semaine.
    var validatedSeriesCount: Int {
        seances.reduce(0) { $0 + $1.validatedSeriesCount }
    }
    
    /// Nombre de séances entièrement terminées dans la semaine.
    var completedSeancesCount: Int {
        seances.filter { $0.totalSeriesCount > 0 && $0.validatedSeriesCount == $0.totalSeriesCount }.count
    }
    
    /// Ratio de complétion de la semaine (0.0 à 1.0).
    var progressionRatio: Double {
        let total = totalSeriesCount
        guard total > 0 else { return 0.0 }
        return Double(validatedSeriesCount) / Double(total)
    }
}

@Model
final class Seance {
    var date: Date
    var titre: String?
    var semaine: Semaine?
    
    @Relationship(deleteRule: .cascade, inverse: \Exercice.seance)
    var exercices: [Exercice] = []
    
    init(date: Date, titre: String? = nil) {
        self.date = date
        self.titre = titre
    }
    
    /// Clé stable permettant d'identifier la séance dans le suivi d'état local
    var trackingKey: String {
        let semNum = semaine?.numero ?? 0
        let blocNom = semaine?.macroBloc?.nom ?? "bloc"
        let timestamp = Int(date.timeIntervalSince1970)
        return "\(blocNom)_S\(semNum)_\(titre ?? "seance")_\(timestamp)"
    }
    
    /// Nombre total de séries programmées dans la séance
    var totalSeriesCount: Int {
        exercices.reduce(0) { $0 + $1.series.count }
    }
    
    /// Nombre de séries validées dans la séance
    var validatedSeriesCount: Int {
        exercices.reduce(0) { total, ex in
            total + ex.series.filter(\.estValidee).count
        }
    }
    
    /// Ratio de complétion entre 0.0 et 1.0
    var progressionRatio: Double {
        let total = totalSeriesCount
        guard total > 0 else { return 0.0 }
        return Double(validatedSeriesCount) / Double(total)
    }
}

@Model
final class Exercice {
    var nom: String
    var categorie: CategorieExercice
    var indications: String?
    var ordre: Int
    var seance: Seance?
    
    @Relationship(deleteRule: .cascade, inverse: \Serie.exercice)
    var series: [Serie] = []
    
    init(nom: String, categorie: CategorieExercice, indications: String? = nil, ordre: Int) {
        self.nom = nom
        self.categorie = categorie
        self.indications = indications
        self.ordre = ordre
    }
    
    // MARK: - Logique de Filtrage, Ordre & Éligibilité à l'Échauffement
    
    /// Séries triées de manière déterministe selon `Serie.ordre` (avec repli sur le schéma Top Set -> Back-offs pour les données historiques).
    var seriesTriees: [Serie] {
        guard series.count > 1 else { return series }
        if series.allSatisfy({ $0.ordre == 0 }) {
            return series.sorted { a, b in
                if a.rpeCible != b.rpeCible { return a.rpeCible > b.rpeCible }
                let ca = a.chargeSaisie ?? 0.0
                let cb = b.chargeSaisie ?? 0.0
                if ca != cb { return ca > cb }
                return a.repsCibles < b.repsCibles
            }
        }
        return series.sorted { $0.ordre < $1.ordre }
    }
    
    /// Première série de travail (Top Set) servant de référence pour l'échauffement
    var topSetReference: Serie? {
        seriesTriees.first
    }
    
    /// Charge cible de la première série de travail (Top Set)
    var chargeCibleTopSet: Double? {
        let sorted = seriesTriees
        if let charge = sorted.first?.chargeSaisie, charge > 0 {
            return charge
        }
        return sorted.compactMap(\.chargeSaisie).first { $0 > 0 }
    }
    
    /// Répétitions cibles de la première série de travail (Top Set)
    var repsCiblesTopSet: Int {
        seriesTriees.first?.repsCibles ?? 5
    }
    
    /// RPE cible de la première série de travail (Top Set)
    var rpeCibleTopSet: Double {
        seriesTriees.first?.rpeCible ?? 8.0
    }
    
    /// Mouvement SBD parent unifié (`squat`, `bench`, `deadlift`, `autre`).
    var mouvementParent: MouvementParent {
        MouvementParent.detecter(nomExercice: nom)
    }
    
    /// Indique s'il s'agit d'un mouvement SBD de compétition pur (hors variantes / accessoires).
    var estMouvementCompetitionPur: Bool {
        MouvementParent.estMouvementCompetition(nomExercice: nom, categorie: categorie)
    }
    
    /// Clé stable pour comparer les PR et rappeler la séance précédente sans mélanger Compétition et Variantes.
    var cleComparaisonPR: String {
        if estMouvementCompetitionPur {
            return "comp_\(mouvementParent.rawValue)"
        }
        return "var_\(nom.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
    }
    
    /// Détermine le type d'échauffement adapté selon le nom et la catégorie de l'exercice
    var typeEchauffement: TypeEchauffementExercice {
        let lower = nom.lowercased()
        
        // Cas C — Exercices d'Isolation : aucun échauffement
        let motsClesIsolation = [
            "curl", "triceps", "face pull", "leg extension", "leg curl",
            "oiseau", "reverse pec deck", "élévation", "elevation", "mollet", "extension"
        ]
        if categorie == .isolation || motsClesIsolation.contains(where: { lower.contains($0) }) {
            return .aucun
        }
        
        // Cas A — Mouvements SBD & Variantes : montée en gamme complète (5 paliers avec barre à vide)
        let motsClesSBD = [
            "squat", "bench", "développé couché", "developpe couche", "deadlift",
            "soulevé de terre", "souleve de terre", "spoto", "3ct", "larsen",
            "pause", "tempo", "deficit", "déficit", "block pull"
        ]
        if categorie == .competition || motsClesSBD.contains(where: { lower.contains($0) }) {
            return .sbdOuVariante
        }
        
        // Cas B — Mouvements Polyarticulaires Accessoires (Rowing, OHP, Dips, Tractions, Presse)
        // Uniquement si une charge de travail > 20 kg est définie (exclut poids du corps / sans charge)
        if let charge = chargeCibleTopSet, charge > 20.0 {
            return .polyarticulaireAccessoire
        }
        
        return .aucun
    }
    
    /// Indique si l'exercice nécessite l'affichage du bouton d'échauffement
    /// Retourne `false` pour l'isolation et les mouvements au poids du corps / sans charge cible
    var necessiteEchauffement: Bool {
        typeEchauffement != .aucun
    }
    
    /// Indique s'il s'agit d'un mouvement SBD ou d'une variante directe
    var estSBDOuVariante: Bool {
        typeEchauffement == .sbdOuVariante
    }
}

@Model
final class Serie {
    var repsCibles: Int
    var rpeCible: Double
    var chargeSaisie: Double?
    var rpeSaisi: Double?
    var estValidee: Bool
    var ordre: Int = 0
    var exercice: Exercice?
    
    init(repsCibles: Int, rpeCible: Double, chargeSaisie: Double? = nil, rpeSaisi: Double? = nil, estValidee: Bool = false, ordre: Int = 0) {
        self.repsCibles = repsCibles
        self.rpeCible = rpeCible
        self.chargeSaisie = chargeSaisie
        self.rpeSaisi = rpeSaisi
        self.estValidee = estValidee
        self.ordre = ordre
    }
    
    /// Calcule le 1RM estimé basé sur la formule d'Epley et le RPE
    func calculerE1RM(charge: Double? = nil, reps: Int? = nil, rpe: Double? = nil) -> Double? {
        let chargeEffective = charge ?? self.chargeSaisie ?? 0.0
        let repsEffectives = reps ?? self.repsCibles
        let rpeEffectif = rpe ?? self.rpeSaisi ?? self.rpeCible
        
        // Vérification de base pour éviter les calculs absurdes
        guard chargeEffective > 0, repsEffectives > 0, rpeEffectif > 0, rpeEffectif <= 10 else { return nil }
        
        // Calcul du nombre de répétitions théoriques à l'échec absolu
        let repsALechecTheorique = Double(repsEffectives) + (10.0 - rpeEffectif)
        
        // Si c'est un vrai 1RM (1 rep @ RPE 10), la charge est le max.
        if repsALechecTheorique <= 1.0 {
            return round(chargeEffective / 2.5) * 2.5
        }
        
        // Formule d'Epley : 1RM = Charge * (1 + Reps / 30)
        let e1rmBrut = chargeEffective * (1.0 + repsALechecTheorique / 30.0)
        
        // Arrondi à 2.5 kg près (incréments standards en compétition de Force Athlétique)
        return round(e1rmBrut / 2.5) * 2.5
    }
}

// MARK: - Suivi d'État "Séance en cours" & Chronomètre de Séance

final class SeanceProgressTracker: ObservableObject {
    static let shared = SeanceProgressTracker()
    
    @Published private(set) var lastUpdateToken = UUID()
    
    private let defaults = UserDefaults.standard
    private let activeDatePrefix = "pt_seance_active_date_"
    private let startTimePrefix = "pt_seance_start_time_"
    private let endTimePrefix = "pt_seance_end_time_"
    private let closedPrefix = "pt_seance_closed_"
    private let explicitlyStartedPrefix = "pt_seance_started_"
    
    private init() {}
    
    /// Démarre explicitement la séance avant la validation de la première série.
    func startSeance(_ seance: Seance) {
        let key = seance.trackingKey
        let now = Date()
        defaults.set(now, forKey: activeDatePrefix + key)
        defaults.set(false, forKey: closedPrefix + key)
        defaults.set(true, forKey: explicitlyStartedPrefix + key)
        if defaults.object(forKey: startTimePrefix + key) == nil {
            defaults.set(now, forKey: startTimePrefix + key)
        }
        defaults.removeObject(forKey: endTimePrefix + key)
        lastUpdateToken = UUID()
    }
    
    /// Enregistre qu'une série de cette séance a été validée aujourd'hui
    func recordSetValidation(for seance: Seance) {
        let key = seance.trackingKey
        defaults.set(Date(), forKey: activeDatePrefix + key)
        defaults.set(false, forKey: closedPrefix + key)
        if defaults.object(forKey: startTimePrefix + key) == nil {
            defaults.set(Date(), forKey: startTimePrefix + key)
        }
        defaults.removeObject(forKey: endTimePrefix + key)
        lastUpdateToken = UUID()
    }
    
    /// Met à jour le suivi local lorsqu'une série est dévalidée (réinitialise si aucune série n'est plus validée, sauf si démarrée manuellement).
    func recordSetUnvalidation(for seance: Seance) {
        let key = seance.trackingKey
        let startedManually = defaults.bool(forKey: explicitlyStartedPrefix + key)
        if seance.validatedSeriesCount == 0 && !startedManually {
            defaults.removeObject(forKey: activeDatePrefix + key)
            defaults.removeObject(forKey: startTimePrefix + key)
            defaults.removeObject(forKey: endTimePrefix + key)
            defaults.removeObject(forKey: closedPrefix + key)
        }
        lastUpdateToken = UUID()
    }
    
    /// Initialise ou récupère l'heure de début de la séance pour le compteur de durée
    func ensureSessionStartDate(for seance: Seance) -> Date {
        let key = seance.trackingKey
        if let existing = defaults.object(forKey: startTimePrefix + key) as? Date {
            return existing
        }
        let now = Date()
        defaults.set(now, forKey: startTimePrefix + key)
        return now
    }
    
    /// Retourne l'heure de début enregistrée pour la séance, si disponible
    func sessionStartDate(for seance: Seance) -> Date? {
        defaults.object(forKey: startTimePrefix + seance.trackingKey) as? Date
    }
    
    /// Retourne l'heure de clôture enregistrée pour la séance, si disponible
    func sessionEndDate(for seance: Seance) -> Date? {
        defaults.object(forKey: endTimePrefix + seance.trackingKey) as? Date
    }
    
    /// Calcule la durée réelle écoulée en minutes depuis le début de la séance
    func sessionDurationMinutes(for seance: Seance) -> Int? {
        guard let start = sessionStartDate(for: seance) else { return nil }
        let end = sessionEndDate(for: seance) ?? Date()
        return max(1, Int(round(end.timeIntervalSince(start) / 60.0)))
    }
    
    /// Marque la séance comme clôturée (lorsque l'utilisateur clique sur "Terminer la séance")
    func markSeanceClosed(_ seance: Seance) {
        let key = seance.trackingKey
        defaults.set(true, forKey: closedPrefix + key)
        defaults.set(false, forKey: explicitlyStartedPrefix + key)
        defaults.set(Date(), forKey: endTimePrefix + key)
        lastUpdateToken = UUID()
    }
    
    /// Efface les clés locales de suivi pour une séance (utile pour réinitialisation / tests).
    func resetTracking(for seance: Seance) {
        let key = seance.trackingKey
        defaults.removeObject(forKey: activeDatePrefix + key)
        defaults.removeObject(forKey: startTimePrefix + key)
        defaults.removeObject(forKey: endTimePrefix + key)
        defaults.removeObject(forKey: closedPrefix + key)
        defaults.removeObject(forKey: explicitlyStartedPrefix + key)
        lastUpdateToken = UUID()
    }
    
    /// Indique si la séance est en cours aujourd'hui (démarrée explicitement ou au moins 1 série validée, et non clôturée)
    func isSeanceInProgressToday(_ seance: Seance) -> Bool {
        let key = seance.trackingKey
        if defaults.bool(forKey: closedPrefix + key) {
            return false
        }
        
        let calendar = Calendar.current
        if defaults.bool(forKey: explicitlyStartedPrefix + key) {
            if let activeDate = defaults.object(forKey: activeDatePrefix + key) as? Date {
                return calendar.isDateInToday(activeDate)
            }
            return true
        }
        
        let validated = seance.validatedSeriesCount
        guard validated > 0 else { return false }
        
        if let activeDate = defaults.object(forKey: activeDatePrefix + key) as? Date {
            return calendar.isDateInToday(activeDate)
        }
        
        if calendar.isDateInToday(seance.date) {
            return true
        }
        
        return validated < seance.totalSeriesCount
    }
    
    /// Recherche la séance actuellement en cours parmi une liste de blocs
    func findActiveSeance(in blocs: [MacroBloc]) -> Seance? {
        var candidates: [(seance: Seance, activeDate: Date)] = []
        for bloc in blocs {
            for semaine in bloc.semaines {
                for seance in semaine.seances where isSeanceInProgressToday(seance) {
                    let activeDate = (defaults.object(forKey: activeDatePrefix + seance.trackingKey) as? Date) ?? seance.date
                    candidates.append((seance, activeDate))
                }
            }
        }
        return candidates.sorted { $0.activeDate > $1.activeDate }.first?.seance
    }
}

// MARK: - Moteur de Calcul RPE & Charges

func pourcentagePour(reps: Int, rpe: Double) -> Double {
    let baseRPE10: [Int: Double] = [
        1: 1.00, 2: 0.96, 3: 0.92, 4: 0.89, 5: 0.86,
        6: 0.84, 7: 0.81, 8: 0.79, 9: 0.76, 10: 0.74
    ]
    
    let pctBase = baseRPE10[reps] ?? 0.70
    let ajustementRPE = (10.0 - rpe) * 0.025
    
    return max(0.40, pctBase - ajustementRPE)
}

func calculerCharge(rm: Double, reps: Int, rpe: Double, ratioVariante: Double = 1.0) -> Double {
    let pct = pourcentagePour(reps: reps, rpe: rpe)
    let chargeBrute = rm * ratioVariante * pct
    return round(chargeBrute / 2.5) * 2.5
}
