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
            return [.benchTempo, .spotoPress, .pause3CT, .larsenPress]
        case .deadlift:
            return [.pauseDeadlift, .blockPull, .deficitDeadlift]
        }
    }
    
    var indicationComp: String {
        switch self {
        case .squat:
            return "Low-bar prise élargie, poignets neutres, depth sous parallèle"
        case .bench:
            return "Centrage strict sur banc, omoplates fixes, pause 1ct nette"
        case .deadlift:
            return "Slack pull patient, contact léger jambes sans freiner"
        }
    }
}

enum VarianteMouvement: String, CaseIterable, Identifiable, Codable {
    // Squat
    case pauseSquat = "Pause Squat"
    case tempoSquat = "Tempo Squat"
    case boxSquat = "Box Squat"
    // Bench
    case benchTempo = "Bench Tempo"
    case spotoPress = "Spoto Press"
    case pause3CT = "Pause 3CT"
    case larsenPress = "Larsen Press"
    // Deadlift
    case pauseDeadlift = "Pause Deadlift"
    case blockPull = "Block Pull"
    case deficitDeadlift = "Deficit Deadlift"
    
    var id: String { rawValue }
    
    var parentMouvement: MouvementCompetition {
        switch self {
        case .pauseSquat, .tempoSquat, .boxSquat:
            return .squat
        case .benchTempo, .spotoPress, .pause3CT, .larsenPress:
            return .bench
        case .pauseDeadlift, .blockPull, .deficitDeadlift:
            return .deadlift
        }
    }
    
    var ratioParDefaut: Double {
        switch self {
        case .pauseSquat: return 0.90
        case .tempoSquat: return 0.88
        case .boxSquat: return 0.92
        case .benchTempo: return 0.89
        case .spotoPress: return 0.91
        case .pause3CT: return 0.88
        case .larsenPress: return 0.90
        case .pauseDeadlift: return 0.89
        case .blockPull: return 0.95
        case .deficitDeadlift: return 0.88
        }
    }
    
    var indicationParDefaut: String {
        switch self {
        case .pauseSquat: return "Pause 2s en bas sous la parallèle, gainage strict"
        case .tempoSquat: return "Descente contrôlée 3s + pause 1s, depth validée"
        case .boxSquat: return "Box sous la parallèle, sans relâcher en bas"
        case .benchTempo: return "Descente 3s contrôlée + pause 1ct, symétrie stricte"
        case .spotoPress: return "Arrêt 2–3 cm au-dessus poitrine, omoplates ancrées"
        case .pause3CT: return "Pause nette 3s poitrine sans perdre la tension"
        case .larsenPress: return "Jambes tendues sans leg drive, stabilité haut du corps"
        case .pauseDeadlift: return "Pause 2s sous le genou, trajectoire verticale légère"
        case .blockPull: return "Sur bloc parquet, posture propre et passage genoux"
        case .deficitDeadlift: return "Déficit modéré, hanches fixes et dos neutre"
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
    var inclureSemaineTestPR: Bool = false
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
    
    private struct ProgressionComp {
        let repsTop: Int
        let rpeTop: Double
        let setsBackoff: Int
        let repsBackoff: Int
        let rpeBackoff: Double
        let ratioBackoff: Double
    }
    
    private struct ProgressionVariante {
        let sets: Int
        let reps: Int
        let rpe: Double
    }
    
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
            case 1: nomSemaine = "Semaine 1 - Volume & Technique (RPE 6.5)"
            case 2: nomSemaine = "Semaine 2 - Accumulation (RPE 7.5)"
            case 3: nomSemaine = "Semaine 3 - Intensification (RPE 8)"
            case 4: nomSemaine = "Semaine 4 - Pic Contrôlé (RPE 8.5)"
            default: nomSemaine = "Semaine \(numSemaine)"
            }
            
            let semaine = Semaine(numero: numSemaine, nom: nomSemaine)
            semaine.macroBloc = macroBloc
            
            semaine.seances = genererSeancesPourGabarit(
                gabarit: gabarit,
                numSemaine: numSemaine,
                config: config,
                baseDate: baseDate,
                semaine: semaine
            )
            macroBloc.semaines.append(semaine)
        }
        
        if config.inclureSemaineTestPR {
            let semainePR = Semaine(numero: 5, nom: "Semaine 5 - Taper & Test PR")
            semainePR.macroBloc = macroBloc
            semainePR.seances = genererSemaineTestPR(
                config: config,
                baseDate: baseDate,
                semaine: semainePR
            )
            macroBloc.semaines.append(semainePR)
        }
        
        modelContext.insert(macroBloc)
        try modelContext.save()
        return macroBloc
    }
    
    // MARK: - Routing des 7 Gabarits (Semaines 1 à 4)
    
    private static func genererSeancesPourGabarit(
        gabarit: GabaritProgramme,
        numSemaine: Int,
        config: ProgramConfiguration,
        baseDate: Date,
        semaine: Semaine
    ) -> [Seance] {
        var seances: [Seance] = []
        let weekOffset = (numSemaine - 1) * 7
        
        switch gabarit {
        // Cas 1 : Squat Only (4 séances/semaine : 3 Squat Force + Hypertrophie complète)
        case .squatOnly:
            let s1 = nouvelleSeance(offsetJours: weekOffset + 0, baseDate: baseDate, titre: "Squat Compétition & Bas", semaine: semaine)
            s1.exercices = [
                creerExerciceComp(mouv: .squat, config: config, numSemaine: numSemaine, ordre: 0, seance: s1),
                creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.0, indications: "Amplitude contrôlée sans décoller le sacrum", numSemaine: numSemaine, ordre: 1, seance: s1),
                creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Contrôle excentrique ischios", numSemaine: numSemaine, ordre: 2, seance: s1),
                creerAccessoire(nom: "Gainage / Core", cat: .isolation, series: 3, reps: 45, rpe: 7.0, indications: "Anti-extension lombaire (secondes)", numSemaine: numSemaine, ordre: 3, seance: s1)
            ]
            seances.append(s1)
            
            let s2 = nouvelleSeance(offsetJours: weekOffset + 1, baseDate: baseDate, titre: "Hypertrophie Haut du Corps", semaine: semaine)
            s2.exercices = [
                creerAccessoire(nom: "Développé Incliné Haltères", cat: .polyarticulaire, series: 4, reps: 10, rpe: 7.5, indications: "Hypertrophie haut de pecs, zéro surextension", numSemaine: numSemaine, ordre: 0, seance: s2),
                creerAccessoire(nom: "Rowing Buste Appuyé", cat: .polyarticulaire, series: 4, reps: 10, rpe: 7.5, indications: "Zéro fatigue lombaire, contrôle omoplates", numSemaine: numSemaine, ordre: 1, seance: s2),
                creerAccessoire(nom: "Développé Militaire Haltères", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.0, indications: "Contrôle épaules sans cambrure excessive", numSemaine: numSemaine, ordre: 2, seance: s2),
                creerAccessoire(nom: "Tirage Vertical", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Dorsaux et ceinture scapulaire", numSemaine: numSemaine, ordre: 3, seance: s2)
            ]
            seances.append(s2)
            
            let s3 = nouvelleSeance(offsetJours: weekOffset + 3, baseDate: baseDate, titre: "Variante Squat & Unilatéral", semaine: semaine)
            let vSquat = config.variante(pour: .squat)
            s3.exercices = [
                creerExerciceVariante(variante: vSquat, config: config, numSemaine: numSemaine, ordre: 0, seance: s3),
                creerAccessoire(nom: "Fentes Bulgares Haltères", cat: .polyarticulaire, series: 3, reps: 8, rpe: 7.0, indications: "Par jambe, stabilité bassin", numSemaine: numSemaine, ordre: 1, seance: s3),
                creerAccessoire(nom: "Leg Extension", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Isolation quadriceps", numSemaine: numSemaine, ordre: 2, seance: s3),
                creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Contrôle excentrique", numSemaine: numSemaine, ordre: 3, seance: s3)
            ]
            seances.append(s3)
            
            let s4 = nouvelleSeance(offsetJours: weekOffset + 5, baseDate: baseDate, titre: "Squat Technique & Haut du Corps", semaine: semaine)
            s4.exercices = [
                creerExerciceCompTechnique(mouv: .squat, rpeOffset: -0.5, indications: "Technique & depth sous parallèle, barre fluide", config: config, numSemaine: numSemaine, ordre: 0, seance: s4),
                creerAccessoire(nom: "Rowing Machine Prise Neutre", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Renfort haut du dos pour le rack low-bar", numSemaine: numSemaine, ordre: 1, seance: s4),
                creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, rpe: 7.0, indications: "Mobilité/stabilité épaules", numSemaine: numSemaine, ordre: 2, seance: s4),
                creerAccessoire(nom: "Curl Marteau", cat: .isolation, series: 3, reps: 12, rpe: 7.0, indications: "Prise neutre anti-tendinite avant-bras/poignet", numSemaine: numSemaine, ordre: 3, seance: s4)
            ]
            seances.append(s4)
            
        // Cas 2 : Deadlift Only (4 séances/semaine : 2 Deadlift Force + Hypertrophie complète)
        case .deadliftOnly:
            let s1 = nouvelleSeance(offsetJours: weekOffset + 0, baseDate: baseDate, titre: "Deadlift Compétition & Dos/Ischios", semaine: semaine)
            s1.exercices = [
                creerExerciceComp(mouv: .deadlift, config: config, numSemaine: numSemaine, ordre: 0, seance: s1),
                creerAccessoire(nom: "Rowing Buste Appuyé", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Zéro fatigue lombaire, contrôle omoplates", numSemaine: numSemaine, ordre: 1, seance: s1),
                creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Contrôle excentrique ischios", numSemaine: numSemaine, ordre: 2, seance: s1),
                creerAccessoire(nom: "Gainage / Core", cat: .isolation, series: 3, reps: 45, rpe: 7.0, indications: "Anti-extension lombaire (secondes)", numSemaine: numSemaine, ordre: 3, seance: s1)
            ]
            seances.append(s1)
            
            let s2 = nouvelleSeance(offsetJours: weekOffset + 1, baseDate: baseDate, titre: "Hypertrophie Haut du Corps", semaine: semaine)
            s2.exercices = [
                creerAccessoire(nom: "Développé Incliné Haltères", cat: .polyarticulaire, series: 4, reps: 10, rpe: 7.5, indications: "Hypertrophie haut de pecs, zéro surextension", numSemaine: numSemaine, ordre: 0, seance: s2),
                creerAccessoire(nom: "Tirage Vertical", cat: .polyarticulaire, series: 4, reps: 10, rpe: 7.5, indications: "Dorsaux engagés sans élan", numSemaine: numSemaine, ordre: 1, seance: s2),
                creerAccessoire(nom: "Développé Militaire Haltères", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.0, indications: "Amplitude contrôlée", numSemaine: numSemaine, ordre: 2, seance: s2),
                creerAccessoire(nom: "Extensions Triceps Poulie", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Corde/prise neutre", numSemaine: numSemaine, ordre: 3, seance: s2)
            ]
            seances.append(s2)
            
            let s3 = nouvelleSeance(offsetJours: weekOffset + 3, baseDate: baseDate, titre: "Variante Deadlift & Unilatéral", semaine: semaine)
            let vDL = config.variante(pour: .deadlift)
            s3.exercices = [
                creerExerciceVariante(variante: vDL, config: config, numSemaine: numSemaine, ordre: 0, seance: s3),
                creerAccessoire(nom: "Fentes Bulgares Haltères", cat: .polyarticulaire, series: 3, reps: 8, rpe: 7.0, indications: "Par jambe, zéro compression axiale", numSemaine: numSemaine, ordre: 1, seance: s3),
                creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Contrôle ischios", numSemaine: numSemaine, ordre: 2, seance: s3),
                creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, rpe: 7.0, indications: "Stabilité scapulaire", numSemaine: numSemaine, ordre: 3, seance: s3)
            ]
            seances.append(s3)
            
            let s4 = nouvelleSeance(offsetJours: weekOffset + 5, baseDate: baseDate, titre: "Hypertrophie Quads & Haut du Corps", semaine: semaine)
            s4.exercices = [
                creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 4, reps: 10, rpe: 7.0, indications: "Force de poussée au sol sans stress lombaire", numSemaine: numSemaine, ordre: 0, seance: s4),
                creerAccessoire(nom: "Pec Deck", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Hypertrophie pectoraux sans surextension", numSemaine: numSemaine, ordre: 1, seance: s4),
                creerAccessoire(nom: "Rowing Machine Prise Neutre", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Épaisseur dos sans fatigue lombaire", numSemaine: numSemaine, ordre: 2, seance: s4),
                creerAccessoire(nom: "Curl Marteau", cat: .isolation, series: 3, reps: 12, rpe: 7.0, indications: "Prise neutre avant-bras/poignet", numSemaine: numSemaine, ordre: 3, seance: s4)
            ]
            seances.append(s4)
            
        // Cas 3 : Bench Only (4 séances/semaine, 100% Haut du Corps, 4 Benchs : 3 Comp + 1 Variante)
        case .benchOnly:
            let s1 = nouvelleSeance(offsetJours: weekOffset + 0, baseDate: baseDate, titre: "Bench Compétition (Principal) & Dos", semaine: semaine)
            s1.exercices = [
                creerExerciceComp(mouv: .bench, config: config, numSemaine: numSemaine, ordre: 0, seance: s1),
                creerAccessoire(nom: "Rowing Buste Appuyé", cat: .polyarticulaire, series: 4, reps: 10, rpe: 7.5, indications: "Fixation scapulaire sans stress lombaire", numSemaine: numSemaine, ordre: 1, seance: s1),
                creerAccessoire(nom: "Reverse Pec Deck", cat: .isolation, series: 3, reps: 12, rpe: 7.0, indications: "Contrôle arrière d'épaule", numSemaine: numSemaine, ordre: 2, seance: s1),
                creerAccessoire(nom: "Extensions Triceps Poulie", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Corde/prise neutre pour protéger le poignet", numSemaine: numSemaine, ordre: 3, seance: s1)
            ]
            seances.append(s1)
            
            let s2 = nouvelleSeance(offsetJours: weekOffset + 1, baseDate: baseDate, titre: "Bench Technique (Léger) & Épaules", semaine: semaine)
            s2.exercices = [
                creerExerciceCompTechnique(mouv: .bench, rpeOffset: -0.5, indications: "Vitesse & symétrie sur banc : pause 1ct légère sans fatigue", config: config, numSemaine: numSemaine, ordre: 0, seance: s2),
                creerAccessoire(nom: "Tirage Vertical", cat: .polyarticulaire, series: 4, reps: 10, rpe: 7.5, indications: "Prise contrôlée, omoplates abaissées", numSemaine: numSemaine, ordre: 1, seance: s2),
                creerAccessoire(nom: "Élévations Latérales", cat: .isolation, series: 4, reps: 15, rpe: 7.0, indications: "Contrôle strict sans tricher", numSemaine: numSemaine, ordre: 2, seance: s2),
                creerAccessoire(nom: "Curl Marteau", cat: .isolation, series: 3, reps: 12, rpe: 7.0, indications: "Prise neutre anti-tendinite avant-bras", numSemaine: numSemaine, ordre: 3, seance: s2)
            ]
            seances.append(s2)
            
            let s3 = nouvelleSeance(offsetJours: weekOffset + 3, baseDate: baseDate, titre: "Variante Bench & Hypertrophie Poussée", semaine: semaine)
            let vB = config.variante(pour: .bench)
            s3.exercices = [
                creerExerciceVariante(variante: vB, config: config, numSemaine: numSemaine, ordre: 0, seance: s3),
                creerAccessoire(nom: "Développé Incliné Haltères", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Hypertrophie haut de pecs, zéro surextension épaule", numSemaine: numSemaine, ordre: 1, seance: s3),
                creerAccessoire(nom: "Rowing Machine Prise Neutre", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Stabilité dos sans tension lombaire", numSemaine: numSemaine, ordre: 2, seance: s3),
                creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, rpe: 7.0, indications: "Coiffe des rotateurs & omoplates", numSemaine: numSemaine, ordre: 3, seance: s3)
            ]
            seances.append(s3)
            
            let s4 = nouvelleSeance(offsetJours: weekOffset + 5, baseDate: baseDate, titre: "Bench Technique (Secondaire) & Bras", semaine: semaine)
            s4.exercices = [
                creerExerciceCompTechnique(mouv: .bench, rpeOffset: 0.0, indications: "Technique & symétrie : pause 1ct nette sur chaque rep", config: config, numSemaine: numSemaine, ordre: 0, seance: s4),
                creerAccessoire(nom: "Tirage Horizontal Poulie", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Contrôle scapulaire", numSemaine: numSemaine, ordre: 1, seance: s4),
                creerAccessoire(nom: "Extensions Triceps Poulie", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Verrouillage triceps", numSemaine: numSemaine, ordre: 2, seance: s4),
                creerAccessoire(nom: "Curl Marteau", cat: .isolation, series: 3, reps: 12, rpe: 7.0, indications: "Équilibre bras & protection coude", numSemaine: numSemaine, ordre: 3, seance: s4)
            ]
            seances.append(s4)
            
        // Cas 4 : Squat + Bench (4 séances/semaine : Squat+Var Bench J1 -> Bench J2 -> Var Squat+Var Bench J3 -> Squat+Bench J4)
        case .squatBench:
            let s1 = nouvelleSeance(offsetJours: weekOffset + 0, baseDate: baseDate, titre: "Squat Compétition & Variante Bench", semaine: semaine)
            let vB1 = config.variante(pour: .bench, index: 0)
            s1.exercices = [
                creerExerciceComp(mouv: .squat, config: config, numSemaine: numSemaine, ordre: 0, seance: s1),
                creerExerciceVariante(variante: vB1, config: config, numSemaine: numSemaine, ordre: 1, seance: s1),
                creerAccessoire(nom: "Rowing Buste Appuyé", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Zéro fatigue lombaire", numSemaine: numSemaine, ordre: 2, seance: s1),
                creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.0, indications: "Volume quadriceps sans charge axiale", numSemaine: numSemaine, ordre: 3, seance: s1)
            ]
            seances.append(s1)
            
            let s2 = nouvelleSeance(offsetJours: weekOffset + 1, baseDate: baseDate, titre: "Bench Compétition & Hypertrophie Haut", semaine: semaine)
            s2.exercices = [
                creerExerciceComp(mouv: .bench, config: config, numSemaine: numSemaine, ordre: 0, seance: s2),
                creerAccessoire(nom: "Développé Incliné Haltères", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Hypertrophie contrôlée, coudes à 45°", numSemaine: numSemaine, ordre: 1, seance: s2),
                creerAccessoire(nom: "Tirage Vertical", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Équilibre poussée/tirage", numSemaine: numSemaine, ordre: 2, seance: s2),
                creerAccessoire(nom: "Extensions Triceps Poulie", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Corde/prise neutre", numSemaine: numSemaine, ordre: 3, seance: s2)
            ]
            seances.append(s2)
            
            let s3 = nouvelleSeance(offsetJours: weekOffset + 3, baseDate: baseDate, titre: "Variante Squat & Variante Bench", semaine: semaine)
            let vS = config.variante(pour: .squat)
            let vB2 = config.variante(pour: .bench, index: 1)
            s3.exercices = [
                creerExerciceVariante(variante: vS, config: config, numSemaine: numSemaine, ordre: 0, seance: s3),
                creerExerciceVariante(variante: vB2, config: config, numSemaine: numSemaine, ordre: 1, seance: s3),
                creerAccessoire(nom: "Fentes Bulgares Haltères", cat: .polyarticulaire, series: 3, reps: 8, rpe: 7.0, indications: "Par jambe, stabilité bassin", numSemaine: numSemaine, ordre: 2, seance: s3),
                creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, rpe: 7.0, indications: "Coiffe des rotateurs & omoplates", numSemaine: numSemaine, ordre: 3, seance: s3)
            ]
            seances.append(s3)
            
            let s4 = nouvelleSeance(offsetJours: weekOffset + 5, baseDate: baseDate, titre: "Squat & Bench Technique", semaine: semaine)
            s4.exercices = [
                creerExerciceCompTechnique(mouv: .squat, rpeOffset: -0.5, indications: "Technique & depth sous parallèle, barre fluide", config: config, numSemaine: numSemaine, ordre: 0, seance: s4),
                creerExerciceCompTechnique(mouv: .bench, rpeOffset: 0.0, indications: "Technique & symétrie : pause 1ct nette", config: config, numSemaine: numSemaine, ordre: 1, seance: s4),
                creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Ischios sans charge lombaire", numSemaine: numSemaine, ordre: 2, seance: s4),
                creerAccessoire(nom: "Curl Marteau", cat: .isolation, series: 3, reps: 12, rpe: 7.0, indications: "Prise neutre avant-bras/poignet", numSemaine: numSemaine, ordre: 3, seance: s4)
            ]
            seances.append(s4)
            
        // Cas 5 : Squat + Deadlift (3 séances/semaine)
        case .squatDeadlift:
            let s1 = nouvelleSeance(offsetJours: weekOffset + 0, baseDate: baseDate, titre: "Deadlift Compétition & Dos", semaine: semaine)
            s1.exercices = [
                creerExerciceComp(mouv: .deadlift, config: config, numSemaine: numSemaine, ordre: 0, seance: s1),
                creerAccessoire(nom: "Rowing Buste Appuyé", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Zéro fatigue lombaire", numSemaine: numSemaine, ordre: 1, seance: s1),
                creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Contrôle ischios", numSemaine: numSemaine, ordre: 2, seance: s1),
                creerAccessoire(nom: "Gainage / Core", cat: .isolation, series: 3, reps: 45, rpe: 7.0, indications: "Anti-extension lombaire (secondes)", numSemaine: numSemaine, ordre: 3, seance: s1)
            ]
            seances.append(s1)
            
            let s2 = nouvelleSeance(offsetJours: weekOffset + 2, baseDate: baseDate, titre: "Squat Compétition & Quadriceps", semaine: semaine)
            s2.exercices = [
                creerExerciceComp(mouv: .squat, config: config, numSemaine: numSemaine, ordre: 0, seance: s2),
                creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.0, indications: "Hypertrophie quads sans charge axiale", numSemaine: numSemaine, ordre: 1, seance: s2),
                creerAccessoire(nom: "Tirage Vertical", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Contrôle haut du dos", numSemaine: numSemaine, ordre: 2, seance: s2),
                creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, rpe: 7.0, indications: "Mobilité épaules pour le low-bar", numSemaine: numSemaine, ordre: 3, seance: s2)
            ]
            seances.append(s2)
            
            let s3 = nouvelleSeance(offsetJours: weekOffset + 4, baseDate: baseDate, titre: "Variantes Squat & Deadlift", semaine: semaine)
            let vS = config.variante(pour: .squat)
            let vD = config.variante(pour: .deadlift)
            s3.exercices = [
                creerExerciceVariante(variante: vS, config: config, numSemaine: numSemaine, ordre: 0, seance: s3),
                creerExerciceVariante(variante: vD, config: config, numSemaine: numSemaine, ordre: 1, seance: s3),
                creerAccessoire(nom: "Fentes Bulgares Haltères", cat: .polyarticulaire, series: 3, reps: 8, rpe: 7.0, indications: "Par jambe", numSemaine: numSemaine, ordre: 2, seance: s3)
            ]
            seances.append(s3)
            
        // Cas 6 : Bench + Deadlift (4 séances/semaine : Bench à chaque séance en alternant Comp/Variante, DL 1 jour sur 2)
        case .benchDeadlift:
            let s1 = nouvelleSeance(offsetJours: weekOffset + 0, baseDate: baseDate, titre: "Deadlift Compétition & Bench Technique", semaine: semaine)
            s1.exercices = [
                creerExerciceComp(mouv: .deadlift, config: config, numSemaine: numSemaine, ordre: 0, seance: s1),
                creerExerciceCompTechnique(mouv: .bench, rpeOffset: 0.0, indications: "Technique & symétrie : pause 1ct nette", config: config, numSemaine: numSemaine, ordre: 1, seance: s1),
                creerAccessoire(nom: "Rowing Buste Appuyé", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Zéro stress lombaire", numSemaine: numSemaine, ordre: 2, seance: s1),
                creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Chaîne postérieure isolée", numSemaine: numSemaine, ordre: 3, seance: s1)
            ]
            seances.append(s1)
            
            let s2 = nouvelleSeance(offsetJours: weekOffset + 1, baseDate: baseDate, titre: "Variante Bench & Hypertrophie Haut", semaine: semaine)
            let vB1 = config.variante(pour: .bench, index: 0)
            s2.exercices = [
                creerExerciceVariante(variante: vB1, config: config, numSemaine: numSemaine, ordre: 0, seance: s2),
                creerAccessoire(nom: "Développé Incliné Haltères", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Hypertrophie haut de pecs, zéro surextension", numSemaine: numSemaine, ordre: 1, seance: s2),
                creerAccessoire(nom: "Tirage Vertical", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Contrôle scapulaire", numSemaine: numSemaine, ordre: 2, seance: s2),
                creerAccessoire(nom: "Extensions Triceps Poulie", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Corde/prise neutre", numSemaine: numSemaine, ordre: 3, seance: s2)
            ]
            seances.append(s2)
            
            let s3 = nouvelleSeance(offsetJours: weekOffset + 3, baseDate: baseDate, titre: "Bench Compétition & Variante Deadlift", semaine: semaine)
            let vD = config.variante(pour: .deadlift)
            s3.exercices = [
                creerExerciceComp(mouv: .bench, config: config, numSemaine: numSemaine, ordre: 0, seance: s3),
                creerExerciceVariante(variante: vD, config: config, numSemaine: numSemaine, ordre: 1, seance: s3),
                creerAccessoire(nom: "Fentes Bulgares Haltères", cat: .polyarticulaire, series: 3, reps: 8, rpe: 7.0, indications: "Par jambe, zéro compression axiale", numSemaine: numSemaine, ordre: 2, seance: s3),
                creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, rpe: 7.0, indications: "Épaules & omoplates", numSemaine: numSemaine, ordre: 3, seance: s3)
            ]
            seances.append(s3)
            
            let s4 = nouvelleSeance(offsetJours: weekOffset + 5, baseDate: baseDate, titre: "Variante Bench & Hypertrophie", semaine: semaine)
            let vB2 = config.variante(pour: .bench, index: 1)
            s4.exercices = [
                creerExerciceVariante(variante: vB2, config: config, numSemaine: numSemaine, ordre: 0, seance: s4),
                creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.0, indications: "Hypertrophie quads sans fatigue lombaire", numSemaine: numSemaine, ordre: 1, seance: s4),
                creerAccessoire(nom: "Rowing Machine Prise Neutre", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Dos épaisseur sans fatigue bas du dos", numSemaine: numSemaine, ordre: 2, seance: s4),
                creerAccessoire(nom: "Curl Marteau", cat: .isolation, series: 3, reps: 12, rpe: 7.0, indications: "Prise neutre avant-bras/poignet", numSemaine: numSemaine, ordre: 3, seance: s4)
            ]
            seances.append(s4)
            
        // Cas 7 : Full SBD (4 séances/semaine : J1 DL / J2 Bench / J3 Squat + Var Bench / J4 SBD)
        case .fullSBD:
            // J1 (Lundi) : Deadlift Compétition & Chaîne Postérieure / Dos
            let s1 = nouvelleSeance(offsetJours: weekOffset + 0, baseDate: baseDate, titre: "Deadlift Compétition & Dos/Jambes", semaine: semaine)
            s1.exercices = [
                creerExerciceComp(mouv: .deadlift, config: config, numSemaine: numSemaine, ordre: 0, seance: s1),
                creerAccessoire(nom: "Rowing Buste Appuyé", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Zéro fatigue lombaire, fixe les omoplates", numSemaine: numSemaine, ordre: 1, seance: s1),
                creerAccessoire(nom: "Fentes Bulgares Haltères", cat: .polyarticulaire, series: 3, reps: 8, rpe: 7.0, indications: "Par jambe, stabilité hanches sans compression axiale", numSemaine: numSemaine, ordre: 2, seance: s1),
                creerAccessoire(nom: "Leg Curl", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Contrôle excentrique ischios", numSemaine: numSemaine, ordre: 3, seance: s1)
            ]
            seances.append(s1)
            
            // J2 (Mardi) : Bench Compétition & Hypertrophie Haut du Corps (0 fatigue lombaire)
            let s2 = nouvelleSeance(offsetJours: weekOffset + 1, baseDate: baseDate, titre: "Bench Compétition & Hypertrophie Haut", semaine: semaine)
            s2.exercices = [
                creerExerciceComp(mouv: .bench, config: config, numSemaine: numSemaine, ordre: 0, seance: s2),
                creerAccessoire(nom: "Développé Incliné Haltères", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Hypertrophie haut de pecs, zéro surextension épaule", numSemaine: numSemaine, ordre: 1, seance: s2),
                creerAccessoire(nom: "Tirage Vertical", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.5, indications: "Dorsaux et stabilité scapulaire", numSemaine: numSemaine, ordre: 2, seance: s2),
                creerAccessoire(nom: "Extensions Triceps Poulie", cat: .isolation, series: 3, reps: 12, rpe: 7.5, indications: "Corde/prise neutre pour protéger le poignet", numSemaine: numSemaine, ordre: 3, seance: s2)
            ]
            seances.append(s2)
            
            // J3 (Jeudi - 72h après DL) : Squat Compétition & Variante Bench
            let s3 = nouvelleSeance(offsetJours: weekOffset + 3, baseDate: baseDate, titre: "Squat Compétition & Variante Bench", semaine: semaine)
            let vB = config.variante(pour: .bench)
            s3.exercices = [
                creerExerciceComp(mouv: .squat, config: config, numSemaine: numSemaine, ordre: 0, seance: s3),
                creerExerciceVariante(variante: vB, config: config, numSemaine: numSemaine, ordre: 1, seance: s3),
                creerAccessoire(nom: "Presse à Cuisses", cat: .polyarticulaire, series: 3, reps: 10, rpe: 7.0, indications: "Volume quadriceps sans charge lombaire", numSemaine: numSemaine, ordre: 2, seance: s3),
                creerAccessoire(nom: "Face Pull", cat: .isolation, series: 3, reps: 15, rpe: 7.0, indications: "Coiffe des rotateurs & omoplates", numSemaine: numSemaine, ordre: 3, seance: s3)
            ]
            seances.append(s3)
            
            // J4 (Samedi - suivi du dimanche off) : SBD (Variante Squat + Bench Comp Technique + Variante DL)
            let s4 = nouvelleSeance(offsetJours: weekOffset + 5, baseDate: baseDate, titre: "SBD Technique & Prévention", semaine: semaine)
            let vS = config.variante(pour: .squat)
            let vD = config.variante(pour: .deadlift)
            s4.exercices = [
                creerExerciceVariante(variante: vS, config: config, numSemaine: numSemaine, ordre: 0, seance: s4),
                creerExerciceCompTechnique(mouv: .bench, rpeOffset: 0.0, indications: "Technique & symétrie : pause 1ct nette sur chaque rep, zéro rebond", config: config, numSemaine: numSemaine, ordre: 1, seance: s4),
                creerExerciceVariante(variante: vD, config: config, numSemaine: numSemaine, ordre: 2, seance: s4),
                creerAccessoire(nom: "Curl Marteau", cat: .isolation, series: 3, reps: 12, rpe: 7.0, indications: "Prise neutre anti-tendinite avant-bras/poignet", numSemaine: numSemaine, ordre: 3, seance: s4)
            ]
            seances.append(s4)
        }
        
        return seances
    }
    
    // MARK: - Semaine 5 Optionnelle : Taper + Test PR en 1 Journée
    
    private static func genererSemaineTestPR(
        config: ProgramConfiguration,
        baseDate: Date,
        semaine: Semaine
    ) -> [Seance] {
        let weekOffset = 4 * 7
        let mouvementsOrdonnes: [MouvementCompetition] = [.squat, .bench, .deadlift].filter {
            config.mouvements.contains($0)
        }
        
        // Séance 1 (Lundi) : Taper Technique (~65%)
        let s1 = nouvelleSeance(offsetJours: weekOffset + 0, baseDate: baseDate, titre: "Taper Technique (Léger)", semaine: semaine)
        for (idx, mouv) in mouvementsOrdonnes.enumerated() {
            let rm = config.rmPour(mouv)
            let charge = arrondirChargeSiValide(rm * 0.65)
            let ex = Exercice(
                nom: "\(mouv.rawValue) Compétition",
                categorie: .competition,
                indications: "Taper ~65% : barre rapide, technique parfaite, zéro fatigue",
                ordre: idx
            )
            ex.seance = s1
            for serieIdx in 0..<2 {
                let s = Serie(repsCibles: 3, rpeCible: 5.0, chargeSaisie: charge, ordre: serieIdx)
                s.exercice = ex
                ex.series.append(s)
            }
            s1.exercices.append(ex)
        }
        if config.mouvements.contains(.bench) {
            s1.exercices.append(
                creerAccessoire(
                    nom: "Face Pull",
                    cat: .isolation,
                    series: 2,
                    reps: 12,
                    rpe: 5.5,
                    indications: "Mobilité/activation épaules uniquement",
                    numSemaine: 4,
                    ordre: mouvementsOrdonnes.count,
                    seance: s1
                )
            )
        }
        
        // Séance 2 (Mercredi) : Activation Nerveuse (~75%)
        let s2 = nouvelleSeance(offsetJours: weekOffset + 2, baseDate: baseDate, titre: "Activation Nerveuse Pré-PR", semaine: semaine)
        for (idx, mouv) in mouvementsOrdonnes.enumerated() {
            let rm = config.rmPour(mouv)
            let charge = arrondirChargeSiValide(rm * 0.75)
            let ex = Exercice(
                nom: "\(mouv.rawValue) Compétition",
                categorie: .competition,
                indications: "Singles explosifs à ~75%, pause nette au bench, depth nette au squat",
                ordre: idx
            )
            ex.seance = s2
            for serieIdx in 0..<2 {
                let s = Serie(repsCibles: 1, rpeCible: 5.5, chargeSaisie: charge, ordre: serieIdx)
                s.exercice = ex
                ex.series.append(s)
            }
            s2.exercices.append(ex)
        }
        
        // Séance 3 (Samedi) : JOUR J — Test PR en 1 Journée (Ordre Compétition S -> B -> D)
        let s3 = nouvelleSeance(offsetJours: weekOffset + 5, baseDate: baseDate, titre: "TEST PR — Simulation Plateau", semaine: semaine)
        for (idx, mouv) in mouvementsOrdonnes.enumerated() {
            let rm = config.rmPour(mouv)
            let ouvreur = arrondirChargeSiValide(rm * 0.90)
            let deuxieme = arrondirChargeSiValide(rm * 0.96)
            let prTarget: Double? = rm > 0 ? max(arrondirCharge(rm * 1.025), rm + 2.5) : nil
            
            let ex = Exercice(
                nom: "\(mouv.rawValue) Compétition (Test PR)",
                categorie: .competition,
                indications: "Ouvreur (90%) → 2e barre (96%) → PR ! Standard compétition strict.",
                ordre: idx
            )
            ex.seance = s3
            
            let tentatives: [(rpe: Double, charge: Double?)] = [
                (8.0, ouvreur),
                (9.0, deuxieme),
                (10.0, prTarget)
            ]
            for (serieIdx, t) in tentatives.enumerated() {
                let s = Serie(repsCibles: 1, rpeCible: t.rpe, chargeSaisie: t.charge, ordre: serieIdx)
                s.exercice = ex
                ex.series.append(s)
            }
            s3.exercices.append(ex)
        }
        
        return [s1, s2, s3]
    }
    
    // MARK: - Moteur de Séries & Charges (Semaines 1 à 4)
    
    private static func nouvelleSeance(offsetJours: Int, baseDate: Date, titre: String, semaine: Semaine) -> Seance {
        let date = Calendar.current.date(byAdding: .day, value: offsetJours, to: baseDate) ?? baseDate
        let seance = Seance(date: date, titre: titre)
        seance.semaine = semaine
        return seance
    }
    
    private static func creerExerciceComp(
        mouv: MouvementCompetition,
        config: ProgramConfiguration,
        numSemaine: Int,
        ordre: Int,
        seance: Seance
    ) -> Exercice {
        let ex = Exercice(
            nom: "\(mouv.rawValue) Compétition",
            categorie: .competition,
            indications: mouv.indicationComp,
            ordre: ordre
        )
        ex.seance = seance
        let rm = config.rmPour(mouv)
        let isDeadlift = (mouv == .deadlift)
        
        let plan: ProgressionComp
        switch numSemaine {
        case 1:
            plan = ProgressionComp(repsTop: 5, rpeTop: 6.5, setsBackoff: isDeadlift ? 2 : 3, repsBackoff: 5, rpeBackoff: 6.0, ratioBackoff: 0.90)
        case 2:
            plan = ProgressionComp(repsTop: 4, rpeTop: 7.5, setsBackoff: isDeadlift ? 2 : 3, repsBackoff: 4, rpeBackoff: 7.0, ratioBackoff: 0.90)
        case 3:
            plan = ProgressionComp(repsTop: 3, rpeTop: 8.0, setsBackoff: isDeadlift ? 2 : 3, repsBackoff: 3, rpeBackoff: 7.5, ratioBackoff: 0.90)
        default:
            // S4 : Pic Contrôlé 1x2 @ RPE 8.5 + back-offs allégés (0 back-off lourd au Deadlift)
            plan = ProgressionComp(repsTop: 2, rpeTop: 8.5, setsBackoff: isDeadlift ? 0 : 2, repsBackoff: 2, rpeBackoff: 7.0, ratioBackoff: 0.875)
        }
        
        let chargeTop = rm > 0 ? arrondirCharge(calculerCharge(rm: rm, reps: plan.repsTop, rpe: plan.rpeTop)) : nil
        let serieTop = Serie(repsCibles: plan.repsTop, rpeCible: plan.rpeTop, chargeSaisie: chargeTop, ordre: 0)
        serieTop.exercice = ex
        ex.series.append(serieTop)
        
        if plan.setsBackoff > 0 {
            let chargeBackoff = chargeTop.map { arrondirCharge($0 * plan.ratioBackoff) }
            for backoffIdx in 1...plan.setsBackoff {
                let serieBack = Serie(repsCibles: plan.repsBackoff, rpeCible: plan.rpeBackoff, chargeSaisie: chargeBackoff, ordre: backoffIdx)
                serieBack.exercice = ex
                ex.series.append(serieBack)
            }
        }
        
        return ex
    }
    
    /// Mouvement de compétition secondaire/technique (travail technique sans Top Set RPE 8.5).
    private static func creerExerciceCompTechnique(
        mouv: MouvementCompetition,
        rpeOffset: Double,
        indications: String,
        config: ProgramConfiguration,
        numSemaine: Int,
        ordre: Int,
        seance: Seance
    ) -> Exercice {
        let ex = Exercice(
            nom: "\(mouv.rawValue) Compétition",
            categorie: .competition,
            indications: indications,
            ordre: ordre
        )
        ex.seance = seance
        let rm = config.rmPour(mouv)
        
        let planBase: ProgressionVariante
        switch numSemaine {
        case 1: planBase = ProgressionVariante(sets: 3, reps: 5, rpe: 6.5)
        case 2: planBase = ProgressionVariante(sets: 3, reps: 4, rpe: 7.0)
        case 3: planBase = ProgressionVariante(sets: 3, reps: 3, rpe: 7.5)
        default: planBase = ProgressionVariante(sets: 2, reps: 3, rpe: 6.0)
        }
        
        let rpeCible = max(5.5, min(8.5, planBase.rpe + rpeOffset))
        let charge = rm > 0 ? arrondirCharge(calculerCharge(rm: rm, reps: planBase.reps, rpe: rpeCible)) : nil
        for serieIdx in 0..<planBase.sets {
            let serie = Serie(repsCibles: planBase.reps, rpeCible: rpeCible, chargeSaisie: charge, ordre: serieIdx)
            serie.exercice = ex
            ex.series.append(serie)
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
        let ex = Exercice(
            nom: variante.rawValue,
            categorie: .polyarticulaire,
            indications: variante.indicationParDefaut,
            ordre: ordre
        )
        ex.seance = seance
        let rmParent = config.rmPour(variante.parentMouvement)
        let ratio = config.ratioPour(variante)
        let isDeadlift = (variante.parentMouvement == .deadlift)
        
        let plan: ProgressionVariante
        switch numSemaine {
        case 1:
            plan = isDeadlift
                ? ProgressionVariante(sets: 3, reps: 4, rpe: 6.0)
                : ProgressionVariante(sets: 3, reps: 6, rpe: 6.5)
        case 2:
            plan = isDeadlift
                ? ProgressionVariante(sets: 3, reps: 4, rpe: 6.5)
                : ProgressionVariante(sets: 3, reps: 5, rpe: 7.0)
        case 3:
            plan = isDeadlift
                ? ProgressionVariante(sets: 2, reps: 3, rpe: 7.0)
                : ProgressionVariante(sets: 3, reps: 4, rpe: 7.5)
        default:
            // S4 : Décharge active sur les variantes pour dissiper la fatigue
            plan = isDeadlift
                ? ProgressionVariante(sets: 2, reps: 2, rpe: 6.0)
                : ProgressionVariante(sets: 2, reps: 3, rpe: 6.0)
        }
        
        let charge = rmParent > 0 ? arrondirCharge(calculerCharge(rm: rmParent, reps: plan.reps, rpe: plan.rpe, ratioVariante: ratio)) : nil
        for serieIdx in 0..<plan.sets {
            let serie = Serie(repsCibles: plan.reps, rpeCible: plan.rpe, chargeSaisie: charge, ordre: serieIdx)
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
        rpe: Double,
        indications: String?,
        numSemaine: Int,
        ordre: Int,
        seance: Seance
    ) -> Exercice {
        let ex = Exercice(nom: nom, categorie: cat, indications: indications, ordre: ordre)
        ex.seance = seance
        // En S4 (Pic Contrôlé), allègement d'une série et -0.5 RPE sur les accessoires
        let nbSeries = (numSemaine >= 4) ? max(2, series - 1) : series
        let rpeCible = (numSemaine >= 4) ? max(6.0, rpe - 0.5) : rpe
        for serieIdx in 0..<nbSeries {
            let serie = Serie(repsCibles: reps, rpeCible: rpeCible, chargeSaisie: nil, ordre: serieIdx)
            serie.exercice = ex
            ex.series.append(serie)
        }
        return ex
    }
    
    private static func arrondirCharge(_ value: Double) -> Double {
        round(value / 2.5) * 2.5
    }
    
    private static func arrondirChargeSiValide(_ value: Double) -> Double? {
        guard value > 0 else { return nil }
        return arrondirCharge(value)
    }
}
