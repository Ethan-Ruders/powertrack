//
//  ProgramGenerator.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import Foundation
import SwiftData

// MARK: - Mouvements & Variantes

enum MouvementCompetition: String, CaseIterable, Identifiable, Codable {
    case squat = "Squat"
    case bench = "Bench"
    case deadlift = "Deadlift"
    
    var id: String { rawValue }
    
    var variantesDisponibles: [VarianteMouvement] {
        switch self {
        case .squat:
            return [.pauseSquat, .tempoSquat, .boxSquat]
        case .bench:
            return [.spotoPress, .pause3CT, .larsenPress, .developpeIncline]
        case .deadlift:
            return [.deficitDeadlift, .blockPull, .pauseDeadlift]
        }
    }
}

enum VarianteMouvement: String, CaseIterable, Identifiable, Codable {
    // Squat
    case pauseSquat = "Pause Squat"
    case tempoSquat = "Tempo Squat"
    case boxSquat = "Box Squat"
    // Bench
    case spotoPress = "Spoto Press"
    case pause3CT = "Pause 3CT"
    case larsenPress = "Larsen Press"
    case developpeIncline = "Développé Incliné"
    // Deadlift
    case deficitDeadlift = "Deficit Deadlift"
    case blockPull = "Block Pull"
    case pauseDeadlift = "Pause Deadlift"
    
    var id: String { rawValue }
    
    var parentMouvement: MouvementCompetition {
        switch self {
        case .pauseSquat, .tempoSquat, .boxSquat:
            return .squat
        case .spotoPress, .pause3CT, .larsenPress, .developpeIncline:
            return .bench
        case .deficitDeadlift, .blockPull, .pauseDeadlift:
            return .deadlift
        }
    }
    
    var ratioParDefaut: Double {
        switch self {
        case .pauseSquat: return 0.90
        case .tempoSquat: return 0.88
        case .boxSquat: return 0.92
        case .spotoPress: return 0.91
        case .pause3CT: return 0.88
        case .larsenPress: return 0.90
        case .developpeIncline: return 0.82
        case .deficitDeadlift: return 0.88
        case .blockPull: return 0.95
        case .pauseDeadlift: return 0.89
        }
    }
}

// MARK: - Les 7 Gabarits

enum GabaritProgramme {
    case squatOnly
    case deadliftOnly
    case benchOnly
    case squatBench
    case squatDeadlift
    case benchDeadlift
    case fullSBD
    
    static func determiner(mouvements: Set<MouvementCompetition>) -> GabaritProgramme? {
        let hasS = mouvements.contains(.squat)
        let hasB = mouvements.contains(.bench)
        let hasD = mouvements.contains(.deadlift)
        
        switch (hasS, hasB, hasD) {
        case (true, false, false): return .squatOnly
        case (false, false, true): return .deadliftOnly
        case (false, true, false): return .benchOnly
        case (true, true, false): return .squatBench
        case (true, false, true): return .squatDeadlift
        case (false, true, true): return .benchDeadlift
        case (true, true, true): return .fullSBD
        default: return nil
        }
    }
}

// MARK: - Configuration du Générateur

struct ProgramConfiguration {
    var nomBloc: String
    var mouvements: Set<MouvementCompetition>
    var variantesSelectionnees: [MouvementCompetition: [VarianteMouvement]]
    var ratiosVariantes: [VarianteMouvement: Double]
    var squat1RM: Double
    var bench1RM: Double
    var deadlift1RM: Double
    var dateDebut: Date = Date()
    
    func rmPour(_ mouvement: MouvementCompetition) -> Double {
        switch mouvement {
        case .squat: return squat1RM
        case .bench: return bench1RM
        case .deadlift: return deadlift1RM
        }
    }
    
    func variante(pour mouvement: MouvementCompetition, index: Int = 0) -> VarianteMouvement {
        if let list = variantesSelectionnees[mouvement], !list.isEmpty {
            return list[index % list.count]
        }
        return mouvement.variantesDisponibles[index % mouvement.variantesDisponibles.count]
    }
    
    func ratioPour(_ variante: VarianteMouvement) -> Double {
        return ratiosVariantes[variante] ?? variante.ratioParDefaut
    }
}

// MARK: - Moteur de Génération

enum ProgramGenerator {
    
    @discardableResult
    static func genererEtSauvegarder(
        config: ProgramConfiguration,
        into modelContext: ModelContext
    ) throws -> MacroBloc {
        guard let gabarit = GabaritProgramme.determiner(mouvements: config.mouvements) else {
            throw NSError(domain: "ProgramGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Veuillez sélectionner au moins un mouvement."])
        }
        
        let macroBloc = MacroBloc(
            nom: config.nomBloc.isEmpty ? "Bloc Force" : config.nomBloc,
            dateDebut: config.dateDebut,
            squat1RM: config.squat1RM,
            bench1RM: config.bench1RM,
            deadlift1RM: config.deadlift1RM
        )
        
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: config.dateDebut)
        
        for numSemaine in 1...4 {
            let nomSemaine: String
            switch numSemaine {
            case 1: nomSemaine = "Semaine 1 - Hypertrophie (RPE 6)"
            case 2: nomSemaine = "Semaine 2 - Accumulation (RPE 7)"
            case 3: nomSemaine = "Semaine 3 - Peaking (RPE 8)"
            case 4: nomSemaine = "Semaine 4 - Test PR (RPE 9-10)"
            default: nomSemaine = "Semaine \(numSemaine)"
            }
            
            let semaine = Semaine(numero: numSemaine, nom: nomSemaine)
            semaine.macroBloc = macroBloc
            
            let seancesSemaine = genererSeancesPourGabarit(
                gabarit: gabarit,
                numSemaine: numSemaine,
                config: config,
                baseDate: baseDate,
                semaine: semaine
            )
            
            semaine.seances = seancesSemaine
            macroBloc.semaines.append(semaine)
        }
        
        modelContext.insert(macroBloc)
        try modelContext.save()
        return macroBloc
    }
    
    // MARK: - Routing des 7 Gabarits
    
    private static func genererSeancesPourGabarit(
        gabarit: GabaritProgramme,
        numSemaine: Int,
        config: ProgramConfiguration,
        baseDate: Date,
        semaine: Semaine
    ) -> [Seance] {
        var seances: [Seance] = []
        let calendar = Calendar.current
        let weekOffset = (numSemaine - 1) * 7
        
        func datePourJour(_ offsetJour: Int) -> Date {
            calendar.date(byAdding: .day, value: weekOffset + offsetJour, to: baseDate) ?? baseDate
        }
        
        switch gabarit {
        // Cas 1 : Squat Only (2 séances/semaine)
        case .squatOnly:
            let s1 = Seance(date: datePourJour(0), titre: "Squat Compétition & Jambes")
            s1.semaine = semaine
            s1.exercices.append(creerExerciceComp(mouv: .squat, config: config, numSemaine: numSemaine, ordre: 0, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Fentes Haltères", cat: .polyarticulaire, series: 3, reps: 10, ordre: 1, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 12, ordre: 2, seance: s1))
            seances.append(s1)
            
            let s2 = Seance(date: datePourJour(3), titre: "Variante Squat & Chaîne Postérieure")
            s2.semaine = semaine
            let vSquat = config.variante(pour: .squat, index: 0)
            s2.exercices.append(creerExerciceVariante(variante: vSquat, config: config, numSemaine: numSemaine, ordre: 0, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 4, reps: 12, ordre: 1, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Extensions Lombaires", cat: .isolation, series: 3, reps: 15, ordre: 2, seance: s2))
            seances.append(s2)
            
        // Cas 2 : Deadlift Only (2 séances/semaine)
        case .deadliftOnly:
            let s1 = Seance(date: datePourJour(0), titre: "Deadlift Compétition & Dos")
            s1.semaine = semaine
            s1.exercices.append(creerExerciceComp(mouv: .deadlift, config: config, numSemaine: numSemaine, ordre: 0, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Tractions", cat: .polyarticulaire, series: 4, reps: 8, ordre: 1, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Tirage Poitrine", cat: .polyarticulaire, series: 3, reps: 10, ordre: 2, seance: s1))
            seances.append(s1)
            
            let s2 = Seance(date: datePourJour(3), titre: "Variante Deadlift & Ischios/Lombaires")
            s2.semaine = semaine
            let vDL = config.variante(pour: .deadlift, index: 0)
            s2.exercices.append(creerExerciceVariante(variante: vDL, config: config, numSemaine: numSemaine, ordre: 0, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Good Morning", cat: .polyarticulaire, series: 3, reps: 10, ordre: 1, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Nordic Hamstring Curl", cat: .isolation, series: 3, reps: 8, ordre: 2, seance: s2))
            seances.append(s2)
            
        // Cas 3 : Bench Only (3 séances/semaine)
        case .benchOnly:
            let s1 = Seance(date: datePourJour(0), titre: "Bench Compétition & Dos")
            s1.semaine = semaine
            s1.exercices.append(creerExerciceComp(mouv: .bench, config: config, numSemaine: numSemaine, ordre: 0, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Rowing Buste Penché", cat: .polyarticulaire, series: 4, reps: 8, ordre: 1, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Écartés Haltères", cat: .isolation, series: 3, reps: 12, ordre: 2, seance: s1))
            seances.append(s1)
            
            let s2 = Seance(date: datePourJour(2), titre: "Variante Bench 1 & Épaules")
            s2.semaine = semaine
            let vB1 = config.variante(pour: .bench, index: 0)
            s2.exercices.append(creerExerciceVariante(variante: vB1, config: config, numSemaine: numSemaine, ordre: 0, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Développé Militaire Haltères", cat: .polyarticulaire, series: 3, reps: 8, ordre: 1, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Élévations Latérales", cat: .isolation, series: 4, reps: 15, ordre: 2, seance: s2))
            seances.append(s2)
            
            let s3 = Seance(date: datePourJour(4), titre: "Variante Bench 2 & Bras")
            s3.semaine = semaine
            let vB2 = config.variante(pour: .bench, index: 1)
            s3.exercices.append(creerExerciceVariante(variante: vB2, config: config, numSemaine: numSemaine, ordre: 0, seance: s3))
            s3.exercices.append(creerAccessoire(nom: "Barre au Front (Triceps)", cat: .isolation, series: 3, reps: 10, ordre: 1, seance: s3))
            s3.exercices.append(creerAccessoire(nom: "Curl Biceps Barre", cat: .isolation, series: 3, reps: 12, ordre: 2, seance: s3))
            seances.append(s3)
            
        // Cas 4 : Squat + Bench (4 séances/semaine)
        case .squatBench:
            let s1 = Seance(date: datePourJour(0), titre: "Squat Compétition & Variante Bench 1")
            s1.semaine = semaine
            s1.exercices.append(creerExerciceComp(mouv: .squat, config: config, numSemaine: numSemaine, ordre: 0, seance: s1))
            let vB1 = config.variante(pour: .bench, index: 0)
            s1.exercices.append(creerExerciceVariante(variante: vB1, config: config, numSemaine: numSemaine, ordre: 1, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 10, ordre: 2, seance: s1))
            seances.append(s1)
            
            let s2 = Seance(date: datePourJour(1), titre: "Bench Compétition & Haut du Corps")
            s2.semaine = semaine
            s2.exercices.append(creerExerciceComp(mouv: .bench, config: config, numSemaine: numSemaine, ordre: 0, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Rowing Buste Penché", cat: .polyarticulaire, series: 4, reps: 8, ordre: 1, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, ordre: 2, seance: s2))
            seances.append(s2)
            
            let s3 = Seance(date: datePourJour(3), titre: "Variante Squat & Bas du Corps")
            s3.semaine = semaine
            let vS = config.variante(pour: .squat, index: 0)
            s3.exercices.append(creerExerciceVariante(variante: vS, config: config, numSemaine: numSemaine, ordre: 0, seance: s3))
            s3.exercices.append(creerAccessoire(nom: "Fentes Haltères", cat: .polyarticulaire, series: 3, reps: 10, ordre: 1, seance: s3))
            s3.exercices.append(creerAccessoire(nom: "Leg Extension", cat: .isolation, series: 3, reps: 12, ordre: 2, seance: s3))
            seances.append(s3)
            
            let s4 = Seance(date: datePourJour(5), titre: "Variante Bench 2 & Bras/Épaules")
            s4.semaine = semaine
            let vB2 = config.variante(pour: .bench, index: 1)
            s4.exercices.append(creerExerciceVariante(variante: vB2, config: config, numSemaine: numSemaine, ordre: 0, seance: s4))
            s4.exercices.append(creerAccessoire(nom: "Développé Militaire", cat: .polyarticulaire, series: 3, reps: 8, ordre: 1, seance: s4))
            s4.exercices.append(creerAccessoire(nom: "Extensions Triceps Poulie", cat: .isolation, series: 3, reps: 12, ordre: 2, seance: s4))
            seances.append(s4)
            
        // Cas 5 : Squat + Deadlift (3 séances/semaine)
        case .squatDeadlift:
            let s1 = Seance(date: datePourJour(0), titre: "Squat Compétition & Cuisses")
            s1.semaine = semaine
            s1.exercices.append(creerExerciceComp(mouv: .squat, config: config, numSemaine: numSemaine, ordre: 0, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 10, ordre: 1, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 4, reps: 12, ordre: 2, seance: s1))
            seances.append(s1)
            
            let s2 = Seance(date: datePourJour(2), titre: "Deadlift Compétition & Dos")
            s2.semaine = semaine
            s2.exercices.append(creerExerciceComp(mouv: .deadlift, config: config, numSemaine: numSemaine, ordre: 0, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Tractions", cat: .polyarticulaire, series: 4, reps: 8, ordre: 1, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Rowing Machine", cat: .polyarticulaire, series: 3, reps: 10, ordre: 2, seance: s2))
            seances.append(s2)
            
            let s3 = Seance(date: datePourJour(4), titre: "Variantes Squat & Deadlift")
            s3.semaine = semaine
            let vS = config.variante(pour: .squat, index: 0)
            let vD = config.variante(pour: .deadlift, index: 0)
            s3.exercices.append(creerExerciceVariante(variante: vS, config: config, numSemaine: numSemaine, ordre: 0, seance: s3))
            s3.exercices.append(creerExerciceVariante(variante: vD, config: config, numSemaine: numSemaine, ordre: 1, seance: s3))
            s3.exercices.append(creerAccessoire(nom: "Gainage / Core", cat: .isolation, series: 3, reps: 45, ordre: 2, seance: s3))
            seances.append(s3)
            
        // Cas 6 : Bench + Deadlift (3 séances/semaine)
        case .benchDeadlift:
            let s1 = Seance(date: datePourJour(0), titre: "Bench Compétition & Dos/Épaules")
            s1.semaine = semaine
            s1.exercices.append(creerExerciceComp(mouv: .bench, config: config, numSemaine: numSemaine, ordre: 0, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Rowing Barre", cat: .polyarticulaire, series: 4, reps: 8, ordre: 1, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Élévations Latérales", cat: .isolation, series: 3, reps: 15, ordre: 2, seance: s1))
            seances.append(s1)
            
            let s2 = Seance(date: datePourJour(2), titre: "Deadlift Compétition & Variante Bench 1")
            s2.semaine = semaine
            s2.exercices.append(creerExerciceComp(mouv: .deadlift, config: config, numSemaine: numSemaine, ordre: 0, seance: s2))
            let vB1 = config.variante(pour: .bench, index: 0)
            s2.exercices.append(creerExerciceVariante(variante: vB1, config: config, numSemaine: numSemaine, ordre: 1, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, ordre: 2, seance: s2))
            seances.append(s2)
            
            let s3 = Seance(date: datePourJour(4), titre: "Variante Deadlift & Variante Bench 2")
            s3.semaine = semaine
            let vD = config.variante(pour: .deadlift, index: 0)
            let vB2 = config.variante(pour: .bench, index: 1)
            s3.exercices.append(creerExerciceVariante(variante: vD, config: config, numSemaine: numSemaine, ordre: 0, seance: s3))
            s3.exercices.append(creerExerciceVariante(variante: vB2, config: config, numSemaine: numSemaine, ordre: 1, seance: s3))
            s3.exercices.append(creerAccessoire(nom: "Triceps Poulie", cat: .isolation, series: 3, reps: 12, ordre: 2, seance: s3))
            seances.append(s3)
            
        // Cas 7 : Full SBD (4 séances/semaine)
        case .fullSBD:
            let s1 = Seance(date: datePourJour(0), titre: "Squat Compétition & Variante Bench 1")
            s1.semaine = semaine
            s1.exercices.append(creerExerciceComp(mouv: .squat, config: config, numSemaine: numSemaine, ordre: 0, seance: s1))
            let vB1 = config.variante(pour: .bench, index: 0)
            s1.exercices.append(creerExerciceVariante(variante: vB1, config: config, numSemaine: numSemaine, ordre: 1, seance: s1))
            s1.exercices.append(creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 10, ordre: 2, seance: s1))
            seances.append(s1)
            
            let s2 = Seance(date: datePourJour(1), titre: "Bench Compétition & Épaules/Triceps")
            s2.semaine = semaine
            s2.exercices.append(creerExerciceComp(mouv: .bench, config: config, numSemaine: numSemaine, ordre: 0, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Développé Militaire Haltères", cat: .polyarticulaire, series: 3, reps: 8, ordre: 1, seance: s2))
            s2.exercices.append(creerAccessoire(nom: "Extensions Triceps Poulie", cat: .isolation, series: 3, reps: 12, ordre: 2, seance: s2))
            seances.append(s2)
            
            let s3 = Seance(date: datePourJour(3), titre: "Deadlift Compétition & Dos")
            s3.semaine = semaine
            s3.exercices.append(creerExerciceComp(mouv: .deadlift, config: config, numSemaine: numSemaine, ordre: 0, seance: s3))
            s3.exercices.append(creerAccessoire(nom: "Rowing Buste Penché", cat: .polyarticulaire, series: 4, reps: 8, ordre: 1, seance: s3))
            s3.exercices.append(creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, ordre: 2, seance: s3))
            seances.append(s3)
            
            let s4 = Seance(date: datePourJour(5), titre: "Variante Squat & Variante Bench 2")
            s4.semaine = semaine
            let vS = config.variante(pour: .squat, index: 0)
            let vB2 = config.variante(pour: .bench, index: 1)
            s4.exercices.append(creerExerciceVariante(variante: vS, config: config, numSemaine: numSemaine, ordre: 0, seance: s4))
            s4.exercices.append(creerExerciceVariante(variante: vB2, config: config, numSemaine: numSemaine, ordre: 1, seance: s4))
            s4.exercices.append(creerAccessoire(nom: "Curl Biceps", cat: .isolation, series: 3, reps: 12, ordre: 2, seance: s4))
            seances.append(s4)
        }
        
        return seances
    }
    
    // MARK: - Moteur de Séries & Charges
    
    private static func creerExerciceComp(
        mouv: MouvementCompetition,
        config: ProgramConfiguration,
        numSemaine: Int,
        ordre: Int,
        seance: Seance
    ) -> Exercice {
        let ex = Exercice(nom: "\(mouv.rawValue) Compétition", categorie: .competition, indications: nil, ordre: ordre)
        ex.seance = seance
        let rm = config.rmPour(mouv)
        
        switch numSemaine {
        case 1:
            // Top Set 1x5 @ RPE 6 + Back-offs 4x6 @ -10% Top Set
            let chargeTop = round(calculerCharge(rm: rm, reps: 5, rpe: 6.0) / 2.5) * 2.5
            let serieTop = Serie(repsCibles: 5, rpeCible: 6.0, chargeSaisie: chargeTop)
            serieTop.exercice = ex
            ex.series.append(serieTop)
            
            let chargeBackoff = round((chargeTop * 0.90) / 2.5) * 2.5
            for _ in 0..<4 {
                let serieBack = Serie(repsCibles: 6, rpeCible: 6.0, chargeSaisie: chargeBackoff)
                serieBack.exercice = ex
                ex.series.append(serieBack)
            }
            
        case 2:
            // Top Set 1x4 @ RPE 7 + Back-offs 3x5 @ -10% Top Set
            let chargeTop = round(calculerCharge(rm: rm, reps: 4, rpe: 7.0) / 2.5) * 2.5
            let serieTop = Serie(repsCibles: 4, rpeCible: 7.0, chargeSaisie: chargeTop)
            serieTop.exercice = ex
            ex.series.append(serieTop)
            
            let chargeBackoff = round((chargeTop * 0.90) / 2.5) * 2.5
            for _ in 0..<3 {
                let serieBack = Serie(repsCibles: 5, rpeCible: 7.0, chargeSaisie: chargeBackoff)
                serieBack.exercice = ex
                ex.series.append(serieBack)
            }
            
        case 3:
            // Top Set 1x2 @ RPE 8 + Back-offs 3x3 @ -10% Top Set
            let chargeTop = round(calculerCharge(rm: rm, reps: 2, rpe: 8.0) / 2.5) * 2.5
            let serieTop = Serie(repsCibles: 2, rpeCible: 8.0, chargeSaisie: chargeTop)
            serieTop.exercice = ex
            ex.series.append(serieTop)
            
            let chargeBackoff = round((chargeTop * 0.90) / 2.5) * 2.5
            for _ in 0..<3 {
                let serieBack = Serie(repsCibles: 3, rpeCible: 8.0, chargeSaisie: chargeBackoff)
                serieBack.exercice = ex
                ex.series.append(serieBack)
            }
            
        case 4:
            // 1x1 @ RPE 9 (Ouvreur) puis 1x1 @ RPE 10 (Max) + aucun back-off
            let chargeOuvreur = round(calculerCharge(rm: rm, reps: 1, rpe: 9.0) / 2.5) * 2.5
            let chargeMax = round(calculerCharge(rm: rm, reps: 1, rpe: 10.0) / 2.5) * 2.5
            
            let serie1 = Serie(repsCibles: 1, rpeCible: 9.0, chargeSaisie: chargeOuvreur)
            serie1.exercice = ex
            let serie2 = Serie(repsCibles: 1, rpeCible: 10.0, chargeSaisie: chargeMax)
            serie2.exercice = ex
            ex.series.append(contentsOf: [serie1, serie2])
            
        default: break
        }
        
        return ex
    }
    
    private static func creerExerciceVariante(
        variante: VarianteMouvement,
        config: ProgramConfiguration,
        numSemaine: Int,
        ordre: Int,
        seance: Seance
    ) -> Exercice {
        let ex = Exercice(nom: variante.rawValue, categorie: .polyarticulaire, indications: nil, ordre: ordre)
        ex.seance = seance
        let rmParent = config.rmPour(variante.parentMouvement)
        let ratio = config.ratioPour(variante)
        
        let nbSeries: Int
        let reps: Int
        let rpe: Double
        
        switch numSemaine {
        case 1:
            nbSeries = 4; reps = 8; rpe = 6.0
        case 2:
            nbSeries = 4; reps = 6; rpe = 7.0
        case 3:
            nbSeries = 3; reps = 4; rpe = 8.0
        case 4:
            // Deload actif (2x3 @ RPE 6)
            nbSeries = 2; reps = 3; rpe = 6.0
        default:
            nbSeries = 3; reps = 5; rpe = 7.0
        }
        
        let charge = round(calculerCharge(rm: rmParent, reps: reps, rpe: rpe, ratioVariante: ratio) / 2.5) * 2.5
        for _ in 0..<nbSeries {
            let serie = Serie(repsCibles: reps, rpeCible: rpe, chargeSaisie: charge)
            serie.exercice = ex
            ex.series.append(serie)
        }
        return ex
    }
    
    private static func creerAccessoire(
        nom: String,
        cat: CategorieExercice,
        series: Int,
        reps: Int,
        ordre: Int,
        seance: Seance
    ) -> Exercice {
        let ex = Exercice(nom: nom, categorie: cat, indications: nil, ordre: ordre)
        ex.seance = seance
        for _ in 0..<series {
            let serie = Serie(repsCibles: reps, rpeCible: 7.0, chargeSaisie: nil)
            serie.exercice = ex
            ex.series.append(serie)
        }
        return ex
    }
}
