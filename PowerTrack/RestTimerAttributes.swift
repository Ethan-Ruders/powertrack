//
//  RestTimerAttributes.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import Foundation
import ActivityKit

public struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
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
    }
    
    // Données statiques de l'activité
    public var nomSeance: String
    
    public init(nomSeance: String = "Séance PowerTrack") {
        self.nomSeance = nomSeance
    }
}
