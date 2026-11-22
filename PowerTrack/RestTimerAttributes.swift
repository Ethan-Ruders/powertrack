//
//  RestTimerAttributes.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import Foundation
import ActivityKit

nonisolated public struct RestTimerAttributes: ActivityAttributes, Sendable {
    nonisolated public struct ContentState: Codable, Hashable, Sendable {
        public var nomExercice: String
        public var numeroSerie: Int
        public var dateDebutRepos: Date
        public var dateFinRepos: Date
        public var dureeTotale: TimeInterval
        
        public init(
            nomExercice: String,
            numeroSerie: Int,
            dateDebutRepos: Date,
            dateFinRepos: Date,
            dureeTotale: TimeInterval
        ) {
            self.nomExercice = nomExercice
            self.numeroSerie = numeroSerie
            self.dateDebutRepos = dateDebutRepos
            self.dateFinRepos = dateFinRepos
            self.dureeTotale = dureeTotale
        }
        
        /// Plage sécurisée évitant un intervalle invalide (`dateDebut > dateFin`) dans SwiftUI `timerInterval`.
        public var timerRange: ClosedRange<Date> {
            dateDebutRepos...max(dateDebutRepos, dateFinRepos)
        }
    }
    
    // Données statiques de l'activité
    public var nomSeance: String
    
    public init(nomSeance: String = "Séance PowerTrack") {
        self.nomSeance = nomSeance
    }
}
