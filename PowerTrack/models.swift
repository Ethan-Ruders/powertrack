//
//  models.swift
//  PowerTrack
//
//  Created by ethan ruders on 11/07/2026.
//

import Foundation
import SwiftData
import Combine

// MARK: - Énumérations

enum CategorieExercice: String, Codable {
    case competition
    case polyarticulaire
    case isolation
}

enum TypeEchauffementExercice {
    case sbdOuVariante
    case polyarticulaireAccessoire
    case aucun
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
    
    // MARK: - Logique de Filtrage & Éligibilité à l'Échauffement
    
    /// Première série de travail (Top Set) servant de référence pour l'échauffement
    var topSetReference: Serie? {
        series.first
    }
    
    /// Charge cible de la première série de travail (Top Set)
    var chargeCibleTopSet: Double? {
        if let charge = series.first?.chargeSaisie, charge > 0 {
            return charge
        }
        return series.compactMap(\.chargeSaisie).first { $0 > 0 }
    }
    
    /// Répétitions cibles de la première série de travail (Top Set)
    var repsCiblesTopSet: Int {
        series.first?.repsCibles ?? 5
    }
    
    /// RPE cible de la première série de travail (Top Set)
    var rpeCibleTopSet: Double {
        series.first?.rpeCible ?? 8.0
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
            "pause", "tempo", "deficit", "déficit", "block pull", "incliné", "incline"
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
    var exercice: Exercice?
    
    init(repsCibles: Int, rpeCible: Double, chargeSaisie: Double? = nil, rpeSaisi: Double? = nil, estValidee: Bool = false) {
        self.repsCibles = repsCibles
        self.rpeCible = rpeCible
        self.chargeSaisie = chargeSaisie
        self.rpeSaisi = rpeSaisi
        self.estValidee = estValidee
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
    private let closedPrefix = "pt_seance_closed_"
    
    private init() {}
    
    /// Enregistre qu'une série de cette séance a été validée aujourd'hui
    func recordSetValidation(for seance: Seance) {
        let key = seance.trackingKey
        defaults.set(Date(), forKey: activeDatePrefix + key)
        defaults.set(false, forKey: closedPrefix + key)
        if defaults.object(forKey: startTimePrefix + key) == nil {
            defaults.set(Date(), forKey: startTimePrefix + key)
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
    
    /// Marque la séance comme clôturée (lorsque l'utilisateur clique sur "Terminer la séance")
    func markSeanceClosed(_ seance: Seance) {
        let key = seance.trackingKey
        defaults.set(true, forKey: closedPrefix + key)
        lastUpdateToken = UUID()
    }
    
    /// Indique si la séance est en cours aujourd'hui (au moins 1 série validée et non clôturée)
    func isSeanceInProgressToday(_ seance: Seance) -> Bool {
        let validated = seance.validatedSeriesCount
        guard validated > 0 else { return false }
        
        let key = seance.trackingKey
        if defaults.bool(forKey: closedPrefix + key) {
            return false
        }
        
        let calendar = Calendar.current
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
