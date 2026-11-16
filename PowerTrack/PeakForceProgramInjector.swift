//
//  PeakForceProgramInjector.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import Foundation
import SwiftData

// MARK: - DTOs de Décodage du Programme JSON

struct ProgrammeSemaineDTO: Decodable {
    let weekNumber: Int
    let phase: String
    let sessions: [ProgrammeSeanceDTO]
}

struct ProgrammeSeanceDTO: Decodable {
    let day: Int
    let title: String
    let exercises: [ProgrammeExerciceDTO]
}

struct ProgrammeExerciceDTO: Decodable {
    let name: String
    let sets: Int
    let reps: Int
    let weight: Double?
    let rpe: Double
    let categorie: String
}

// MARK: - Injecteur SwiftData

enum PeakForceProgramInjector {
    static let nomBlocParDefaut = "Peak Force & PR (Semaines 5 à 8)"
    
    public static let programmeJSON = """
[
  {
    "weekNumber": 5,
    "phase": "Intensification (Lourd)",
    "sessions": [
      {
        "day": 1,
        "title": "Bench Force & Dos",
        "exercises": [
          { "name": "Bench Compétition", "sets": 4, "reps": 3, "weight": 110.0, "rpe": 8.0, "categorie": "competition" },
          { "name": "Rowing Buste Appuyé", "sets": 4, "reps": 8, "weight": null, "rpe": 7.5, "categorie": "polyarticulaire" },
          { "name": "Face Pull", "sets": 3, "reps": 15, "weight": null, "rpe": 7.0, "categorie": "isolation" },
          { "name": "Curl Biceps", "sets": 3, "reps": 12, "weight": null, "rpe": 7.0, "categorie": "isolation" }
        ]
      },
      {
        "day": 2,
        "title": "Stabilité Lourd",
        "exercises": [
          { "name": "Spoto Press", "sets": 4, "reps": 3, "weight": 102.5, "rpe": 8.0, "categorie": "competition" },
          { "name": "Développé Militaire Haltères (Debout)", "sets": 4, "reps": 8, "weight": null, "rpe": 7.5, "categorie": "polyarticulaire" },
          { "name": "Reverse Pec Deck", "sets": 4, "reps": 12, "weight": null, "rpe": 7.0, "categorie": "isolation" },
          { "name": "Extensions Triceps Poulie", "sets": 3, "reps": 12, "weight": null, "rpe": 7.5, "categorie": "isolation" }
        ]
      },
      {
        "day": 3,
        "title": "Puissance",
        "exercises": [
          { "name": "Bench 3CT", "sets": 4, "reps": 2, "weight": 100.0, "rpe": 8.0, "categorie": "competition" },
          { "name": "Tractions", "sets": 4, "reps": 8, "weight": null, "rpe": 7.5, "categorie": "polyarticulaire" },
          { "name": "Dips Lestés", "sets": 3, "reps": 10, "weight": null, "rpe": 7.5, "categorie": "polyarticulaire" },
          { "name": "Curl Marteau", "sets": 4, "reps": 12, "weight": null, "rpe": 7.0, "categorie": "isolation" }
        ]
      }
    ]
  },
  {
    "weekNumber": 6,
    "phase": "Fin de bloc Force",
    "sessions": [
      {
        "day": 1,
        "title": "Bench Force (Top Set)",
        "exercises": [
          { "name": "Bench Compétition (Top Set)", "sets": 1, "reps": 2, "weight": 115.0, "rpe": 8.5, "categorie": "competition" },
          { "name": "Bench Compétition (Back-offs)", "sets": 3, "reps": 3, "weight": 107.5, "rpe": 8.0, "categorie": "competition" },
          { "name": "Rowing Buste Appuyé", "sets": 4, "reps": 8, "weight": null, "rpe": 7.5, "categorie": "polyarticulaire" },
          { "name": "Face Pull", "sets": 3, "reps": 15, "weight": null, "rpe": 7.0, "categorie": "isolation" },
          { "name": "Curl Biceps", "sets": 3, "reps": 12, "weight": null, "rpe": 7.0, "categorie": "isolation" }
        ]
      },
      {
        "day": 2,
        "title": "Stabilité",
        "exercises": [
          { "name": "Spoto Press", "sets": 3, "reps": 3, "weight": 105.0, "rpe": 8.5, "categorie": "competition" },
          { "name": "Développé Militaire Haltères (Debout)", "sets": 3, "reps": 8, "weight": null, "rpe": 7.5, "categorie": "polyarticulaire" },
          { "name": "Reverse Pec Deck", "sets": 3, "reps": 12, "weight": null, "rpe": 7.0, "categorie": "isolation" },
          { "name": "Extensions Triceps Poulie", "sets": 3, "reps": 12, "weight": null, "rpe": 7.5, "categorie": "isolation" }
        ]
      },
      {
        "day": 3,
        "title": "Puissance",
        "exercises": [
          { "name": "Bench 3CT", "sets": 3, "reps": 2, "weight": 102.5, "rpe": 8.5, "categorie": "competition" },
          { "name": "Tractions", "sets": 3, "reps": 8, "weight": null, "rpe": 7.5, "categorie": "polyarticulaire" },
          { "name": "Dips Lestés", "sets": 3, "reps": 8, "weight": null, "rpe": 8.0, "categorie": "polyarticulaire" },
          { "name": "Curl Marteau", "sets": 3, "reps": 12, "weight": null, "rpe": 7.0, "categorie": "isolation" }
        ]
      }
    ]
  },
  {
    "weekNumber": 7,
    "phase": "Peak Nerveux",
    "sessions": [
      {
        "day": 1,
        "title": "Bench Peak",
        "exercises": [
          { "name": "Bench Compétition (Single)", "sets": 1, "reps": 1, "weight": 122.5, "rpe": 8.5, "categorie": "competition" },
          { "name": "Bench Compétition (Back-offs)", "sets": 3, "reps": 2, "weight": 105.0, "rpe": 7.5, "categorie": "competition" },
          { "name": "Rowing Buste Appuyé", "sets": 3, "reps": 8, "weight": null, "rpe": 7.0, "categorie": "polyarticulaire" },
          { "name": "Face Pull", "sets": 2, "reps": 15, "weight": null, "rpe": 6.5, "categorie": "isolation" }
        ]
      },
      {
        "day": 2,
        "title": "Stabilité Légère",
        "exercises": [
          { "name": "Spoto Press", "sets": 3, "reps": 2, "weight": 100.0, "rpe": 7.0, "categorie": "competition" },
          { "name": "Développé Militaire Haltères", "sets": 3, "reps": 8, "weight": null, "rpe": 6.5, "categorie": "polyarticulaire" }
        ]
      },
      {
        "day": 3,
        "title": "Activation",
        "exercises": [
          { "name": "Bench 3CT", "sets": 3, "reps": 2, "weight": 95.0, "rpe": 6.5, "categorie": "competition" },
          { "name": "Tractions", "sets": 3, "reps": 8, "weight": null, "rpe": 6.0, "categorie": "polyarticulaire" }
        ]
      }
    ]
  },
  {
    "weekNumber": 8,
    "phase": "Deload & PR",
    "sessions": [
      {
        "day": 1,
        "title": "Deload Actif",
        "exercises": [
          { "name": "Bench Compétition", "sets": 3, "reps": 3, "weight": 85.0, "rpe": 5.0, "categorie": "competition" },
          { "name": "Face Pull", "sets": 2, "reps": 15, "weight": null, "rpe": 5.0, "categorie": "isolation" }
        ]
      },
      {
        "day": 2,
        "title": "Activation Pré-Test",
        "exercises": [
          { "name": "Bench Compétition", "sets": 1, "reps": 1, "weight": 100.0, "rpe": 5.5, "categorie": "competition" }
        ]
      },
      {
        "day": 3,
        "title": "TEST PR (Jour J)",
        "exercises": [
          { "name": "Bench Compétition (Ouvreur)", "sets": 1, "reps": 1, "weight": 120.0, "rpe": 7.5, "categorie": "competition" },
          { "name": "Bench Compétition (Validation)", "sets": 1, "reps": 1, "weight": 130.0, "rpe": 8.5, "categorie": "competition" },
          { "name": "Bench Compétition (Nouveau PR)", "sets": 1, "reps": 1, "weight": 135.0, "rpe": 10.0, "categorie": "competition" }
        ]
      }
    ]
  }
]
"""

    /// Mappe le JSON fourni vers la hiérarchie MacroBloc -> Semaine -> Seance -> Exercice -> Serie
    /// et l'enregistre dans le ModelContext SwiftData.
    @discardableResult
    static func injecterBlocPeakForce(
        into modelContext: ModelContext,
        jsonString: String = programmeJSON,
        nomBloc: String = nomBlocParDefaut,
        dateDebut: Date = Date()
    ) throws -> MacroBloc {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(
                domain: "PeakForceProgramInjector",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Impossible d'encoder le JSON en données UTF-8"]
            )
        }
        
        let decoder = JSONDecoder()
        let semainesDTO = try decoder.decode([ProgrammeSemaineDTO].self, from: data)
        
        let nouveauBloc = MacroBloc(
            nom: nomBloc,
            dateDebut: dateDebut,
            squat1RM: 0.0,
            bench1RM: 135.0,
            deadlift1RM: 0.0
        )
        
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: dateDebut)
        
        for semaineDTO in semainesDTO {
            let nomSemaine = "Semaine \(semaineDTO.weekNumber) - \(semaineDTO.phase)"
            let semaine = Semaine(numero: semaineDTO.weekNumber, nom: nomSemaine)
            semaine.macroBloc = nouveauBloc
            
            // Calcul de l'écart en semaines (semaines 5 à 8 -> indices 0 à 3)
            let weekOffset = max(0, semaineDTO.weekNumber - 5)
            
            for sessionDTO in semaineDTO.sessions {
                // Répartition des séances : Jour 1 (+0 j), Jour 2 (+2 j), Jour 3 (+4 j)
                let dayOffset = max(0, (sessionDTO.day - 1) * 2)
                let sessionDate = calendar.date(
                    byAdding: .day,
                    value: (weekOffset * 7) + dayOffset,
                    to: baseDate
                ) ?? baseDate
                
                let seance = Seance(date: sessionDate, titre: sessionDTO.title)
                seance.semaine = semaine
                
                for (exerciseIndex, exerciseDTO) in sessionDTO.exercises.enumerated() {
                    let categorie = CategorieExercice(rawValue: exerciseDTO.categorie) ?? .polyarticulaire
                    let exercice = Exercice(
                        nom: exerciseDTO.name,
                        categorie: categorie,
                        indications: nil,
                        ordre: exerciseIndex
                    )
                    exercice.seance = seance
                    
                    for _ in 0..<exerciseDTO.sets {
                        let serie = Serie(
                            repsCibles: exerciseDTO.reps,
                            rpeCible: exerciseDTO.rpe,
                            chargeSaisie: exerciseDTO.weight,
                            rpeSaisi: nil,
                            estValidee: false
                        )
                        serie.exercice = exercice
                        exercice.series.append(serie)
                    }
                    
                    seance.exercices.append(exercice)
                }
                
                semaine.seances.append(seance)
            }
            
            nouveauBloc.semaines.append(semaine)
        }
        
        modelContext.insert(nouveauBloc)
        try modelContext.save()
        
        return nouveauBloc
    }
}
