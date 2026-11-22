//
//  ProgramJSONImporter.swift
//  PowerTrack
//
//  Created by PowerTrack on 17/11/2026.
//

import Foundation
import SwiftData

// MARK: - DTOs d'Import de Programme JSON (Coach & Prédéfini)

struct CoachProgramImportDTO: Decodable {
    let schemaVersion: Int?
    let blocName: String?
    let dateDebut: String?
    let squat1RM: Double?
    let bench1RM: Double?
    let deadlift1RM: Double?
    let weeks: [ProgrammeSemaineDTO]
}

struct ProgrammeSemaineDTO: Decodable {
    let weekNumber: Int
    let phase: String
    let sessions: [ProgrammeSeanceDTO]
}

struct ProgrammeSeanceDTO: Decodable {
    let day: Int
    let dayOffset: Int?
    let title: String
    let exercises: [ProgrammeExerciceDTO]
}

struct ProgrammeSerieDTO: Decodable {
    let reps: Int
    let weight: Double?
    let rpe: Double
}

struct ProgrammeExerciceDTO: Decodable {
    let name: String
    let sets: Int?
    let reps: Int?
    let weight: Double?
    let rpe: Double?
    let categorie: String
    let indications: String?
    let series: [ProgrammeSerieDTO]?
    
    /// Résout la liste de séries cibles (format détaillé `series` ou format uniforme `sets`/`reps`/`weight`/`rpe`).
    func resolvedSeries() -> [ProgrammeSerieDTO] {
        if let explicitSeries = series, !explicitSeries.isEmpty {
            return explicitSeries
        }
        let count = max(1, sets ?? 1)
        let targetReps = max(1, reps ?? 5)
        let targetRPE = rpe ?? 7.5
        return (0..<count).map { _ in
            ProgrammeSerieDTO(reps: targetReps, weight: weight, rpe: targetRPE)
        }
    }
}

// MARK: - Prévisualisation & Import SwiftData

struct ProgramImportPreview {
    let blocName: String
    let dateDebut: Date
    let squat1RM: Double
    let bench1RM: Double
    let deadlift1RM: Double
    let weeks: [ProgrammeSemaineDTO]
    
    var weekCount: Int { weeks.count }
    var sessionCount: Int { weeks.reduce(0) { $0 + $1.sessions.count } }
    var totalSets: Int {
        weeks.reduce(0) { totalW, w in
            totalW + w.sessions.reduce(0) { totalS, s in
                totalS + s.exercises.reduce(0) { $0 + $1.resolvedSeries().count }
            }
        }
    }
}

enum ProgramJSONImporter {
    
    /// Analyse un JSON de programme (format objet complet Coach v2 ou tableau `[ProgrammeSemaineDTO]` historique).
    static func parse(
        jsonString: String,
        defaultBlocName: String = "Bloc Importé",
        defaultDateDebut: Date = Date(),
        defaultSquat1RM: Double = 0.0,
        defaultBench1RM: Double = 0.0,
        defaultDeadlift1RM: Double = 0.0
    ) throws -> ProgramImportPreview {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8), !data.isEmpty else {
            throw NSError(
                domain: "ProgramJSONImporter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Le contenu JSON est vide ou invalide."]
            )
        }
        
        let decoder = JSONDecoder()
        
        if let fullDTO = try? decoder.decode(CoachProgramImportDTO.self, from: data) {
            guard !fullDTO.weeks.isEmpty else {
                throw NSError(
                    domain: "ProgramJSONImporter",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Le programme JSON ne contient aucune semaine."]
                )
            }
            let parsedDate = parseDate(fullDTO.dateDebut) ?? defaultDateDebut
            return ProgramImportPreview(
                blocName: fullDTO.blocName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil ?? defaultBlocName,
                dateDebut: parsedDate,
                squat1RM: fullDTO.squat1RM ?? defaultSquat1RM,
                bench1RM: fullDTO.bench1RM ?? defaultBench1RM,
                deadlift1RM: fullDTO.deadlift1RM ?? defaultDeadlift1RM,
                weeks: fullDTO.weeks
            )
        }
        
        let weeks = try decoder.decode([ProgrammeSemaineDTO].self, from: data)
        guard !weeks.isEmpty else {
            throw NSError(
                domain: "ProgramJSONImporter",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Le tableau de semaines JSON est vide."]
            )
        }
        
        return ProgramImportPreview(
            blocName: defaultBlocName,
            dateDebut: defaultDateDebut,
            squat1RM: defaultSquat1RM,
            bench1RM: defaultBench1RM,
            deadlift1RM: defaultDeadlift1RM,
            weeks: weeks
        )
    }
    
    /// Insère un `ProgramImportPreview` dans SwiftData et retourne le `MacroBloc` créé.
    @discardableResult
    static func injecter(
        preview: ProgramImportPreview,
        into modelContext: ModelContext,
        overrideBlocName: String? = nil,
        overrideDateDebut: Date? = nil
    ) throws -> MacroBloc {
        let finalName = overrideBlocName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil ?? preview.blocName
        let finalDate = overrideDateDebut ?? preview.dateDebut
        
        let nouveauBloc = MacroBloc(
            nom: finalName,
            dateDebut: finalDate,
            squat1RM: preview.squat1RM,
            bench1RM: preview.bench1RM,
            deadlift1RM: preview.deadlift1RM
        )
        
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: finalDate)
        let sortedWeeks = preview.weeks.sorted { $0.weekNumber < $1.weekNumber }
        let minWeekNumber = sortedWeeks.first?.weekNumber ?? 1
        
        for semaineDTO in sortedWeeks {
            let nomSemaine = "Semaine \(semaineDTO.weekNumber) - \(semaineDTO.phase)"
            let semaine = Semaine(numero: semaineDTO.weekNumber, nom: nomSemaine)
            semaine.macroBloc = nouveauBloc
            
            let weekOffset = max(0, semaineDTO.weekNumber - minWeekNumber)
            let canSpaceByTwoDays = semaineDTO.sessions.allSatisfy { (($0.day - 1) * 2) <= 6 }
            
            for sessionDTO in semaineDTO.sessions {
                let dayOffset: Int
                if let explicitOffset = sessionDTO.dayOffset {
                    dayOffset = max(0, min(6, explicitOffset))
                } else if canSpaceByTwoDays {
                    dayOffset = max(0, (sessionDTO.day - 1) * 2)
                } else {
                    dayOffset = max(0, min(6, sessionDTO.day - 1))
                }
                
                let sessionDate = calendar.date(
                    byAdding: .day,
                    value: (weekOffset * 7) + dayOffset,
                    to: baseDate
                ) ?? baseDate
                
                let seance = Seance(date: sessionDate, titre: sessionDTO.title)
                seance.semaine = semaine
                
                for (exerciseIndex, exerciseDTO) in sessionDTO.exercises.enumerated() {
                    let categorie = CategorieExercice(rawValue: exerciseDTO.categorie.lowercased()) ?? .polyarticulaire
                    let exercice = Exercice(
                        nom: exerciseDTO.name,
                        categorie: categorie,
                        indications: exerciseDTO.indications?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil,
                        ordre: exerciseIndex
                    )
                    exercice.seance = seance
                    
                    for (serieIndex, serieDTO) in exerciseDTO.resolvedSeries().enumerated() {
                        let serie = Serie(
                            repsCibles: serieDTO.reps,
                            rpeCible: serieDTO.rpe,
                            chargeSaisie: serieDTO.weight,
                            rpeSaisi: nil,
                            estValidee: false,
                            ordre: serieIndex
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
    
    /// Raccourci direct : parse un JSON et l'injecte dans SwiftData.
    @discardableResult
    static func injecterDepuisJSON(
        _ jsonString: String,
        into modelContext: ModelContext,
        defaultBlocName: String = "Bloc Coach",
        defaultDateDebut: Date = Date(),
        defaultSquat1RM: Double = 0.0,
        defaultBench1RM: Double = 0.0,
        defaultDeadlift1RM: Double = 0.0
    ) throws -> MacroBloc {
        let preview = try parse(
            jsonString: jsonString,
            defaultBlocName: defaultBlocName,
            defaultDateDebut: defaultDateDebut,
            defaultSquat1RM: defaultSquat1RM,
            defaultBench1RM: defaultBench1RM,
            defaultDeadlift1RM: defaultDeadlift1RM
        )
        return try injecter(preview: preview, into: modelContext)
    }
    
    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: raw) {
            return date
        }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        return dayFormatter.date(from: raw)
    }
}

private extension String {
    var nonEmptyOrNil: String? {
        isEmpty ? nil : self
    }
}
