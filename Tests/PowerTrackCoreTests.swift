//
//  PowerTrackCoreTests.swift
//  PowerTrack Core Unit Tests
//

import Foundation
import SwiftData
import Combine

private var testsPassed = 0

private func check(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        fputs("❌ FAIL [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]: \(message)\n", stderr)
        exit(1)
    }
    testsPassed += 1
}

private func checkApprox(_ actual: Double?, _ expected: Double, tolerance: Double = 0.01, _ message: String, file: String = #file, line: Int = #line) {
    guard let actual else {
        fputs("❌ FAIL [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]: \(message) (actual was nil, expected \(expected))\n", stderr)
        exit(1)
    }
    if abs(actual - expected) > tolerance {
        fputs("❌ FAIL [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]: \(message) (actual \(actual) != expected \(expected))\n", stderr)
        exit(1)
    }
    testsPassed += 1
}

@main
struct PowerTrackCoreTestRunner {
    static func main() throws {
        print("Running PowerTrack Core Unit Tests...")
        
        testRPEAndChargeEngine()
        testE1RMCalculations()
        testSerieOrderingAndLegacyFallback()
        testUnifiedMovementClassification()
        testDOTSAndIPFGLScoring()
        testWarmupRungsGeneration()
        try testAllProgramGeneratorTemplates()
        try testMultiVariantProgramGeneration()
        try testProgramJSONImporter()
        try testExportManagerDTOAndRessenti()
        try testBackupExportAndRestoreRoundTrip()
        try testRankSystemAndFFForceTags()
        try testExplicitSessionStartAndClose()
        
        print("✅ All \(testsPassed) assertions passed cleanly!")
    }
    
    // MARK: - 1. Moteur RPE & Charges
    
    static func testRPEAndChargeEngine() {
        checkApprox(pourcentagePour(reps: 1, rpe: 10.0), 1.00, "1 rep @ RPE 10 == 100%")
        checkApprox(pourcentagePour(reps: 5, rpe: 8.0), 0.81, "5 reps @ RPE 8 == 81%")
        checkApprox(pourcentagePour(reps: 10, rpe: 1.0), 0.515, "10 reps @ RPE 1 == 51.5%")
        checkApprox(pourcentagePour(reps: 12, rpe: -5.0), 0.40, "Plancher RPE à 40%")
        checkApprox(calculerCharge(rm: 200.0, reps: 1, rpe: 10.0), 200.0, "200 kg 1x1@10")
        checkApprox(calculerCharge(rm: 180.0, reps: 5, rpe: 8.0, ratioVariante: 0.90), 130.0, "Arrondi 2.5 kg sur variante")
    }
    
    // MARK: - 2. Calcul e1RM
    
    static func testE1RMCalculations() {
        let singleMax = Serie(repsCibles: 1, rpeCible: 10.0, chargeSaisie: 182.5, rpeSaisi: 10.0, estValidee: true)
        checkApprox(singleMax.calculerE1RM(), 182.5, "1RM exact à 182.5 kg")
        
        let topSet = Serie(repsCibles: 5, rpeCible: 8.0, chargeSaisie: 140.0, rpeSaisi: 8.0, estValidee: true)
        checkApprox(topSet.calculerE1RM(), 172.5, "140x5@8 -> 172.5 kg e1RM")
        
        let invalidCharge = Serie(repsCibles: 5, rpeCible: 8.0, chargeSaisie: 0.0)
        check(invalidCharge.calculerE1RM() == nil, "Charge <= 0 donne nil")
        
        let invalidRPE = Serie(repsCibles: 5, rpeCible: 11.0, chargeSaisie: 100.0)
        check(invalidRPE.calculerE1RM() == nil, "RPE > 10 donne nil")
    }
    
    // MARK: - 3. Ordre Déterministe des Séries & Fallback Historique
    
    static func testSerieOrderingAndLegacyFallback() {
        let ex = Exercice(nom: "Squat Compétition", categorie: .competition, ordre: 0)
        let s2 = Serie(repsCibles: 5, rpeCible: 6.5, chargeSaisie: 130.0, ordre: 2)
        let s0 = Serie(repsCibles: 3, rpeCible: 8.0, chargeSaisie: 155.0, ordre: 0)
        let s1 = Serie(repsCibles: 5, rpeCible: 7.0, chargeSaisie: 135.0, ordre: 1)
        ex.series = [s2, s0, s1]
        
        let sorted = ex.seriesTriees
        check(sorted.map(\.ordre) == [0, 1, 2], "seriesTriees suit strictement Serie.ordre")
        checkApprox(ex.chargeCibleTopSet, 155.0, "Top set référence utilise bien ordre 0")
        
        // Legacy sans ordre (tous ordre == 0)
        let exLegacy = Exercice(nom: "Bench Compétition", categorie: .competition, ordre: 0)
        let b1 = Serie(repsCibles: 5, rpeCible: 7.0, chargeSaisie: 100.0, ordre: 0)
        let top = Serie(repsCibles: 3, rpeCible: 8.5, chargeSaisie: 115.0, ordre: 0)
        exLegacy.series = [b1, top]
        checkApprox(exLegacy.seriesTriees.first?.chargeSaisie, 115.0, "Repli historique place RPE/charge la plus haute en 1er")
    }
    
    // MARK: - 4. Classification Unifiée SBD vs Variantes
    
    static func testUnifiedMovementClassification() {
        let sqComp = Exercice(nom: "Squat Compétition", categorie: .competition, ordre: 0)
        check(sqComp.mouvementParent == .squat, "Squat comp parent")
        check(sqComp.estMouvementCompetitionPur == true, "Squat comp pur")
        check(sqComp.cleComparaisonPR == "comp_squat", "Clé PR squat comp")
        
        let pauseSq = Exercice(nom: "Pause Squat", categorie: .polyarticulaire, ordre: 1)
        check(pauseSq.mouvementParent == .squat, "Pause Squat parent squat")
        check(pauseSq.estMouvementCompetitionPur == false, "Pause Squat n'est pas comp pur")
        check(pauseSq.cleComparaisonPR == "var_pause squat", "Clé PR distincte pour variante")
        
        let spoto = Exercice(nom: "Spoto Press", categorie: .competition, ordre: 2)
        check(spoto.mouvementParent == .bench, "Spoto parent bench")
        check(spoto.estMouvementCompetitionPur == false, "Spoto même tagué .competition reste une variante")
        
        let dlTest = Exercice(nom: "Deadlift Compétition (Test PR)", categorie: .competition, ordre: 3)
        check(dlTest.mouvementParent == .deadlift, "DL test PR parent deadlift")
        check(dlTest.estMouvementCompetitionPur == true, "DL test PR est comp pur")
        
        let deficitDL = Exercice(nom: "Deficit Deadlift", categorie: .polyarticulaire, ordre: 4)
        check(deficitDL.mouvementParent == .deadlift, "Deficit DL parent deadlift")
        check(deficitDL.estMouvementCompetitionPur == false, "Deficit DL variante")
        
        let row = Exercice(nom: "Rowing Buste Appuyé", categorie: .polyarticulaire, ordre: 5)
        check(row.mouvementParent == .autre, "Rowing parent autre")
        check(row.estMouvementCompetitionPur == false, "Rowing pas comp")
    }
    
    // MARK: - 5. Scores DOTS & IPF GL
    
    static func testDOTSAndIPFGLScoring() {
        // Références alignées sur analyze_powertrack.py (total 520 kg @ 74.5 kg)
        let dots = PowerliftingScoring.dotsMale(totalKg: 520.0, bodyweightKg: 74.5)
        let ipf = PowerliftingScoring.ipfGLMaleClassic(totalKg: 520.0, bodyweightKg: 74.5)
        checkApprox(dots, 374.66, tolerance: 0.01, "DOTS officiel 520 kg @ 74.5 kg")
        checkApprox(ipf, 76.08, tolerance: 0.01, "IPF GL Classic officiel 520 kg @ 74.5 kg")
        check(PowerliftingScoring.dotsMale(totalKg: 0, bodyweightKg: 74.5) == nil, "DOTS nil si total nul")
        check(PowerliftingScoring.ipfGLMaleClassic(totalKg: 520, bodyweightKg: 0) == nil, "IPF GL nil si pdc nul")
    }
    
    // MARK: - 6. Génération Paliers Échauffement
    
    static func testWarmupRungsGeneration() {
        // Cas C : Isolation -> 0 palier
        let curl = Exercice(nom: "Curl Marteau", categorie: .isolation, ordre: 0)
        curl.series = [Serie(repsCibles: 12, rpeCible: 7.0, chargeSaisie: 16.0)]
        check(genererPaliersEchauffement(pour: curl).isEmpty, "Cas C isolation : aucun palier")
        
        // Cas B : Polyarticulaire > 20 kg -> 2 paliers (50% et 75%)
        let legPress = Exercice(nom: "Presse à Cuisses", categorie: .polyarticulaire, ordre: 1)
        legPress.series = [Serie(repsCibles: 10, rpeCible: 7.0, chargeSaisie: 120.0)]
        let rungsB = genererPaliersEchauffement(pour: legPress)
        check(rungsB.count == 2, "Cas B accessoire >20kg génère 2 paliers")
        checkApprox(rungsB[0].chargeKg, 60.0, "Cas B palier 1 à 50%")
        checkApprox(rungsB[1].chargeKg, 90.0, "Cas B palier 2 à 75%")
        
        // Cas A : SBD -> barre à vide + paliers croissants < cible
        let squat = Exercice(nom: "Squat Compétition", categorie: .competition, ordre: 0)
        squat.series = [Serie(repsCibles: 5, rpeCible: 8.0, chargeSaisie: 160.0)]
        let rungsA = genererPaliersEchauffement(pour: squat)
        check(rungsA.count == 5, "Cas A SBD 160kg génère 5 paliers")
        checkApprox(rungsA.first?.chargeKg, 20.0, "Cas A commence barre à vide 20 kg")
        check(rungsA.allSatisfy { $0.chargeKg < 160.0 }, "Tous les paliers strictement < charge de travail")
    }
    
    // MARK: - 7. Les 7 Gabarits ProgramGenerator + Semaine 5 PR
    
    static func testAllProgramGeneratorTemplates() throws {
        let configContainer = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MacroBloc.self, configurations: configContainer)
        let context = ModelContext(container)
        
        let cases: [(Set<MouvementCompetition>, Int, Bool)] = [
            ([.squat], 16, false),
            ([.deadlift], 16, false),
            ([.bench], 16, false),
            ([.squat, .bench], 16, false),
            ([.squat, .deadlift], 12, false),
            ([.bench, .deadlift], 16, false),
            ([.squat, .bench, .deadlift], 19, true) // 16 + 3 séances S5 PR
        ]
        
        for (mouvs, expectedSessions, withPR) in cases {
            let cfg = ProgramConfiguration(
                nomBloc: "Test \(mouvs.count)",
                mouvements: mouvs,
                variantesSelectionnees: [:],
                ratiosVariantes: [:],
                squat1RM: 170,
                bench1RM: 130,
                deadlift1RM: 200,
                inclureSemaineTestPR: withPR,
                dateDebut: Date()
            )
            let bloc = try ProgramGenerator.genererEtSauvegarder(config: cfg, into: context)
            let sessionCount = bloc.semaines.reduce(0) { $0 + $1.seances.count }
            check(sessionCount == expectedSessions, "Gabarit \(mouvs) attend \(expectedSessions) séances, obtenu \(sessionCount)")
            
            for sem in bloc.semaines {
                for sea in sem.seances {
                    for ex in sea.exercices {
                        let ordres = ex.seriesTriees.map(\.ordre)
                        check(ordres == Array(0..<ex.series.count), "Séries doivent avoir un ordre contigu 0..<\(ex.series.count)")
                    }
                }
            }
        }
    }
    
    static func testMultiVariantProgramGeneration() throws {
        let configContainer = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MacroBloc.self, configurations: configContainer)
        let context = ModelContext(container)
        
        func generer(
            mouvements: Set<MouvementCompetition>,
            variantes: [MouvementCompetition: [VarianteMouvement]]
        ) throws -> [Semaine] {
            let cfg = ProgramConfiguration(
                nomBloc: "Test Multi Variantes",
                mouvements: mouvements,
                variantesSelectionnees: variantes,
                ratiosVariantes: [:],
                squat1RM: 170,
                bench1RM: 130,
                deadlift1RM: 200,
                inclureSemaineTestPR: false,
                dateDebut: Date(timeIntervalSince1970: 1_795_000_000)
            )
            let bloc = try ProgramGenerator.genererEtSauvegarder(config: cfg, into: context)
            return bloc.semaines.sorted { $0.numero < $1.numero }
        }
        
        func seancesTriees(_ semaine: Semaine) -> [Seance] {
            semaine.seances.sorted { $0.date < $1.date }
        }
        
        func exercicesTries(_ seance: Seance) -> [Exercice] {
            seance.exercices.sorted { $0.ordre < $1.ordre }
        }
        
        func occurrences(dans semaines: [Semaine], pour parent: MouvementParent) -> [String: Int] {
            var counts: [String: Int] = [:]
            for sem in semaines {
                for sea in sem.seances {
                    for ex in sea.exercices where ex.mouvementParent == parent && !ex.estMouvementCompetitionPur {
                        counts[ex.nom, default: 0] += 1
                    }
                }
            }
            return counts
        }
        
        // Garde de déduplication
        let dupCfg = ProgramConfiguration(
            nomBloc: "Dedup",
            mouvements: [.bench],
            variantesSelectionnees: [.bench: [.spotoPress, .spotoPress]],
            ratiosVariantes: [:],
            squat1RM: 0,
            bench1RM: 130,
            deadlift1RM: 0
        )
        check(dupCfg.nombreVariantesSelectionnees(pour: .bench) == 1, "Déduplication variante répétée -> count == 1")
        check(dupCfg.variantesOrdonnees(pour: .bench) == [.spotoPress], "Déduplication garde Spoto Press unique")
        
        // 1. Bench Only - 1 variante (comportement inchangé)
        do {
            let sems = try generer(mouvements: [.bench], variantes: [.bench: [.spotoPress]])
            check(sems.count == 4, "Bench Only 1 var : 4 semaines")
            for sem in sems {
                let s = seancesTriees(sem)
                check(exercicesTries(s[0])[0].nom == "Bench Compétition", "Bench Only 1 var S1 Comp")
                check(exercicesTries(s[1])[0].nom == "Bench Compétition", "Bench Only 1 var S2 Comp Tech")
                check(exercicesTries(s[2])[0].nom == "Spoto Press", "Bench Only 1 var S3 Spoto")
                check(exercicesTries(s[3])[0].nom == "Bench Compétition", "Bench Only 1 var S4 Comp Tech")
                check(s[3].titre == "Bench Technique (Secondaire) & Bras", "Bench Only 1 var titre S4 conservé")
            }
        }
        
        // 2. Bench Only - 2 variantes
        do {
            let sems = try generer(mouvements: [.bench], variantes: [.bench: [.spotoPress, .larsenPress]])
            for sem in sems {
                let s = seancesTriees(sem)
                check(exercicesTries(s[0])[0].nom == "Bench Compétition", "Bench Only 2 var S1 Comp")
                check(exercicesTries(s[1])[0].nom == "Bench Compétition", "Bench Only 2 var S2 Comp Tech")
                check(exercicesTries(s[2])[0].nom == "Spoto Press", "Bench Only 2 var S3 = 1re variante")
                check(exercicesTries(s[3])[0].nom == "Larsen Press", "Bench Only 2 var S4 = 2e variante")
                check(s[3].titre == "Variante Bench & Bras", "Bench Only 2 var titre S4 mis à jour")
            }
        }
        
        // 3. Bench Only - 3 variantes (ordre non-standard + vérification RPE léger S2)
        do {
            let sems = try generer(mouvements: [.bench], variantes: [.bench: [.larsenPress, .pause3CT, .spotoPress]])
            for sem in sems {
                let s = seancesTriees(sem)
                check(exercicesTries(s[0])[0].nom == "Bench Compétition", "Bench Only 3 var S1 Comp")
                check(exercicesTries(s[1])[0].nom == "Larsen Press", "Bench Only 3 var S2 = Larsen Press")
                check(s[1].titre == "Variante Bench (Léger) & Épaules", "Bench Only 3 var S2 titre mis à jour")
                check(exercicesTries(s[2])[0].nom == "Pause 3CT", "Bench Only 3 var S3 = Pause 3CT")
                check(exercicesTries(s[3])[0].nom == "Spoto Press", "Bench Only 3 var S4 = Spoto Press")
                check(s[3].titre == "Variante Bench & Bras", "Bench Only 3 var S4 titre mis à jour")
            }
            let s1Sem1 = seancesTriees(sems[0])
            checkApprox(exercicesTries(s1Sem1[1])[0].seriesTriees.first?.rpeCible, 6.0, "Bench Only 3 var W1 S2 RPE léger == 6.0")
            checkApprox(exercicesTries(s1Sem1[2])[0].seriesTriees.first?.rpeCible, 6.5, "Bench Only 3 var W1 S3 RPE standard == 6.5")
        }
        
        // 4. Bench Only - 4 variantes (rotation continue sur 12 slots -> 3x chacune, jamais de doublon hebdo)
        do {
            let ordered: [VarianteMouvement] = [.benchTempo, .spotoPress, .pause3CT, .larsenPress]
            let sems = try generer(mouvements: [.bench], variantes: [.bench: ordered])
            let attenduesParSemaine: [[String]] = [
                ["Bench Tempo", "Spoto Press", "Pause 3CT"],
                ["Larsen Press", "Bench Tempo", "Spoto Press"],
                ["Pause 3CT", "Larsen Press", "Bench Tempo"],
                ["Spoto Press", "Pause 3CT", "Larsen Press"]
            ]
            for (idx, sem) in sems.enumerated() {
                let s = seancesTriees(sem)
                check(exercicesTries(s[0])[0].nom == "Bench Compétition", "Bench Only 4 var S1 reste Compétition")
                let trio = [exercicesTries(s[1])[0].nom, exercicesTries(s[2])[0].nom, exercicesTries(s[3])[0].nom]
                check(trio == attenduesParSemaine[idx], "Bench Only 4 var S\(idx + 1) rotation exacte")
                check(Set(trio).count == 3, "Bench Only 4 var jamais 2x la même variante dans S\(idx + 1)")
            }
            let counts = occurrences(dans: sems, pour: .bench)
            for v in ordered {
                check(counts[v.rawValue] == 3, "Bench Only 4 var : \(v.rawValue) apparaît exactement 3 fois (obtenu \(counts[v.rawValue] ?? 0))")
            }
        }
        
        // 5. Squat Only - 2 et 3 variantes
        do {
            let sems2 = try generer(mouvements: [.squat], variantes: [.squat: [.tempoSquat, .boxSquat]])
            for sem in sems2 {
                let s = seancesTriees(sem)
                check(exercicesTries(s[2])[0].nom == "Tempo Squat", "Squat Only 2 var S3 = Tempo Squat")
                check(exercicesTries(s[3])[0].nom == "Box Squat", "Squat Only 2 var S4 = Box Squat")
                check(s[3].titre == "Variante Squat & Haut du Corps", "Squat Only 2 var titre S4")
            }
            checkApprox(exercicesTries(seancesTriees(sems2[0])[3])[0].seriesTriees.first?.rpeCible, 6.0, "Squat Only 2 var W1 S4 RPE allégé == 6.0")
            
            let sq3: [VarianteMouvement] = [.pauseSquat, .tempoSquat, .boxSquat]
            let sems3 = try generer(mouvements: [.squat], variantes: [.squat: sq3])
            for sem in sems3 {
                let s = seancesTriees(sem)
                check(exercicesTries(s[2])[0].nom != exercicesTries(s[3])[0].nom, "Squat Only 3 var S3 != S4")
            }
            let counts = occurrences(dans: sems3, pour: .squat)
            for v in sq3 {
                check((counts[v.rawValue] ?? 0) >= 2, "Squat Only 3 var : \(v.rawValue) présent au moins 2x")
            }
        }
        
        // 6. Deadlift Only - 3 variantes (rotation hebdo S1..S4)
        do {
            let dl3: [VarianteMouvement] = [.pauseDeadlift, .blockPull, .deficitDeadlift]
            let sems = try generer(mouvements: [.deadlift], variantes: [.deadlift: dl3])
            let nomsS3 = sems.map { exercicesTries(seancesTriees($0)[2])[0].nom }
            check(nomsS3 == ["Pause Deadlift", "Block Pull", "Deficit Deadlift", "Pause Deadlift"], "Deadlift Only 3 var rotation hebdo")
        }
        
        // 7. Squat + Bench - 3 Squat + 4 Bench
        do {
            let sq3: [VarianteMouvement] = [.pauseSquat, .tempoSquat, .boxSquat]
            let bn4: [VarianteMouvement] = [.benchTempo, .spotoPress, .pause3CT, .larsenPress]
            let sems = try generer(mouvements: [.squat, .bench], variantes: [.squat: sq3, .bench: bn4])
            check(seancesTriees(sems[0])[3].titre == "Variantes Squat & Bench", "Squat+Bench titre S4 quand les deux ont multi-variantes")
            let sqCounts = occurrences(dans: sems, pour: .squat)
            let bnCounts = occurrences(dans: sems, pour: .bench)
            for v in sq3 {
                check((sqCounts[v.rawValue] ?? 0) >= 2, "Squat+Bench : \(v.rawValue) présent")
            }
            for v in bn4 {
                check(bnCounts[v.rawValue] == 3, "Squat+Bench : \(v.rawValue) 3x sur 4 semaines")
            }
        }
        
        // 8. Squat + Deadlift - 2 Squat + 3 Deadlift
        do {
            let sq2: [VarianteMouvement] = [.pauseSquat, .boxSquat]
            let dl3: [VarianteMouvement] = [.pauseDeadlift, .blockPull, .deficitDeadlift]
            let sems = try generer(mouvements: [.squat, .deadlift], variantes: [.squat: sq2, .deadlift: dl3])
            let sqCounts = occurrences(dans: sems, pour: .squat)
            let dlCounts = occurrences(dans: sems, pour: .deadlift)
            for v in sq2 {
                check(sqCounts[v.rawValue] == 2, "Squat+DL : \(v.rawValue) 2x")
            }
            for v in dl3 {
                check((dlCounts[v.rawValue] ?? 0) >= 1, "Squat+DL : \(v.rawValue) présent")
            }
        }
        
        // 9. Bench + Deadlift - 4 Bench + 2 Deadlift
        do {
            let bn4: [VarianteMouvement] = [.benchTempo, .spotoPress, .pause3CT, .larsenPress]
            let dl2: [VarianteMouvement] = [.pauseDeadlift, .deficitDeadlift]
            let sems = try generer(mouvements: [.bench, .deadlift], variantes: [.bench: bn4, .deadlift: dl2])
            check(seancesTriees(sems[0])[0].titre == "Deadlift Compétition & Variante Bench", "Bench+DL S1 titre mis à jour pour >=3 variantes")
            let bnCounts = occurrences(dans: sems, pour: .bench)
            let dlCounts = occurrences(dans: sems, pour: .deadlift)
            for v in bn4 {
                check(bnCounts[v.rawValue] == 3, "Bench+DL : \(v.rawValue) exactement 3x")
            }
            for v in dl2 {
                check(dlCounts[v.rawValue] == 2, "Bench+DL : \(v.rawValue) exactement 2x")
            }
        }
        
        // 10. Full SBD - 2 Squat + 4 Bench + 3 Deadlift
        do {
            let sq2: [VarianteMouvement] = [.pauseSquat, .tempoSquat]
            let bn4: [VarianteMouvement] = [.benchTempo, .spotoPress, .pause3CT, .larsenPress]
            let dl3: [VarianteMouvement] = [.pauseDeadlift, .blockPull, .deficitDeadlift]
            let sems = try generer(
                mouvements: [.squat, .bench, .deadlift],
                variantes: [.squat: sq2, .bench: bn4, .deadlift: dl3]
            )
            let sqCounts = occurrences(dans: sems, pour: .squat)
            let bnCounts = occurrences(dans: sems, pour: .bench)
            let dlCounts = occurrences(dans: sems, pour: .deadlift)
            for v in sq2 {
                check(sqCounts[v.rawValue] == 2, "Full SBD : \(v.rawValue) 2x")
            }
            for v in bn4 {
                check(bnCounts[v.rawValue] == 2, "Full SBD : \(v.rawValue) 2x")
            }
            for v in dl3 {
                check((dlCounts[v.rawValue] ?? 0) >= 1, "Full SBD : \(v.rawValue) présent")
            }
        }
    }
    
    // MARK: - 8. ProgramJSONImporter (v2 + tableau historique)
    
    static func testProgramJSONImporter() throws {
        let configContainer = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MacroBloc.self, configurations: configContainer)
        let context = ModelContext(container)
        
        let v2JSON = """
        {
          "schemaVersion": 2,
          "blocName": "Bloc Coach Test",
          "dateDebut": "2026-11-23",
          "squat1RM": 180,
          "bench1RM": 135,
          "deadlift1RM": 210,
          "weeks": [
            {
              "weekNumber": 1,
              "phase": "Volume",
              "sessions": [
                {
                  "day": 1,
                  "dayOffset": 0,
                  "title": "Squat & Accessoires",
                  "exercises": [
                    {
                      "name": "Squat Compétition",
                      "categorie": "competition",
                      "indications": "Pause nette",
                      "series": [
                        { "reps": 4, "weight": 150, "rpe": 8.0 },
                        { "reps": 4, "weight": 135, "rpe": 7.0 }
                      ]
                    },
                    {
                      "name": "Leg Curl",
                      "sets": 3,
                      "reps": 12,
                      "weight": 45,
                      "rpe": 7.5,
                      "categorie": "isolation"
                    }
                  ]
                }
              ]
            }
          ]
        }
        """
        
        let preview = try ProgramJSONImporter.parse(jsonString: v2JSON)
        check(preview.blocName == "Bloc Coach Test", "Import nom bloc v2")
        check(preview.totalSets == 5, "Total séries v2 == 5")
        
        let bloc = try ProgramJSONImporter.injecter(preview: preview, into: context)
        check(bloc.semaines.count == 1, "1 semaine injectée")
        let sq = bloc.semaines[0].seances[0].exercices.sorted { $0.ordre < $1.ordre }[0]
        check(sq.seriesTriees.map(\.ordre) == [0, 1], "Ordre séries importées v2")
        checkApprox(sq.seriesTriees[0].chargeSaisie, 150.0, "Top set v2 charge")
        
        let legacyJSON = """
        [
          {
            "weekNumber": 1,
            "phase": "Base",
            "sessions": [
              {
                "day": 1,
                "title": "Bench",
                "exercises": [
                  { "name": "Bench Compétition", "sets": 2, "reps": 5, "weight": 100, "rpe": 7.0, "categorie": "competition" }
                ]
              }
            ]
          }
        ]
        """
        let legacyPreview = try ProgramJSONImporter.parse(jsonString: legacyJSON)
        check(legacyPreview.totalSets == 2, "Import format tableau historique")
    }
    
    // MARK: - 9. ExportManager DTO & Ressenti
    
    static func testExportManagerDTOAndRessenti() throws {
        let emptyRessenti = RessentiSeanceDTO(douleurSignalee: "   ", notesSeance: "\n ")
        check(emptyRessenti.normalized() == nil, "Ressenti espaces vides normalisé à nil")
        
        let bloc = MacroBloc(nom: "Bloc Export", squat1RM: 175, bench1RM: 130, deadlift1RM: 205)
        let sem = Semaine(numero: 1, nom: "Semaine 1")
        sem.macroBloc = bloc
        let seance = Seance(date: Date(), titre: "Jour 1")
        seance.semaine = sem
        
        let ex = Exercice(nom: "Spoto Press", categorie: .competition, ordre: 0)
        ex.seance = seance
        let s0 = Serie(repsCibles: 4, rpeCible: 7.5, chargeSaisie: 110.0, rpeSaisi: 8.5, estValidee: true, ordre: 0)
        let s1 = Serie(repsCibles: 4, rpeCible: 7.5, chargeSaisie: 110.0, rpeSaisi: 7.5, estValidee: false, ordre: 1)
        s0.exercice = ex
        s1.exercice = ex
        ex.series = [s1, s0] // Volontairement inversé pour tester le tri ExportDTO
        seance.exercices = [ex]
        
        let dto = ExportManager.shared.buildDTO(
            seance: seance,
            ressenti: RessentiSeanceDTO(poidsCorpsKg: 74.2, sommeilHeures: 8.0, notesSeance: " Fluide ")
        )
        check(dto.schemaVersion == 2, "Schema v2")
        checkApprox(dto.tonnageTotalKg, 440.0, "Seules les séries validées comptent dans le tonnage")
        check(dto.exercices[0].mouvementParent == "bench", "Spoto Press -> bench")
        checkApprox(dto.exercices[0].series[0].deltaRPE, 1.0, "Première série (ordre 0) exportée en premier avec deltaRPE = +1.0")
        check(dto.exercices[0].series[0].estValidee == true, "Série 1 exportée validée")
        check(dto.ressenti?.notesSeance == "Fluide", "Notes ressenti trimées")
        
        // Régression boucle infinie UI : sauvegarder deux fois le même poids de corps ne doit pas réémettre objectWillChange
        let identicalRessenti = RessentiSeanceDTO(poidsCorpsKg: 74.2, sommeilHeures: 8.0)
        ExportManager.shared.saveRessenti(identicalRessenti, for: seance)
        var emittedCount = 0
        let cancellable = ExportManager.shared.objectWillChange.sink { _ in
            emittedCount += 1
        }
        ExportManager.shared.saveRessenti(identicalRessenti, for: seance)
        cancellable.cancel()
        check(emittedCount == 0, "saveRessenti identique n'émet pas objectWillChange (pas de boucle de rendu)")
    }
    
    // MARK: - 10. BackupManager Export & Restauration Complète
    
    static func testBackupExportAndRestoreRoundTrip() throws {
        let config1 = ModelConfiguration(isStoredInMemoryOnly: true)
        let container1 = try ModelContainer(for: MacroBloc.self, configurations: config1)
        let ctx1 = ModelContext(container1)
        
        let cfg = ProgramConfiguration(
            nomBloc: "Bloc Backup Test",
            mouvements: [.squat, .bench],
            variantesSelectionnees: [:],
            ratiosVariantes: [:],
            squat1RM: 185,
            bench1RM: 140,
            deadlift1RM: 0,
            inclureSemaineTestPR: false,
            dateDebut: Date(timeIntervalSince1970: 1_795_000_000)
        )
        let bloc = try ProgramGenerator.genererEtSauvegarder(config: cfg, into: ctx1)
        let premiereSeance = bloc.semaines.sorted { $0.numero < $1.numero }[0].seances.sorted { $0.date < $1.date }[0]
        let firstEx = premiereSeance.exercices.sorted { $0.ordre < $1.ordre }[0]
        let topSet = firstEx.seriesTriees[0]
        topSet.chargeSaisie = 147.5
        topSet.rpeSaisi = 7.5
        topSet.estValidee = true
        try ctx1.save()
        
        ExportManager.shared.saveRessenti(
            RessentiSeanceDTO(poidsCorpsKg: 75.0, sommeilHeures: 8.5, douleurSignalee: "Aucune"),
            for: premiereSeance
        )
        
        let jsonData = try BackupManager.exportBackupJSON(from: ctx1)
        let parsed = try BackupManager.parseBackup(from: jsonData)
        check(parsed.blocs.count == 1, "Backup contient 1 bloc")
        check(!parsed.ressentis.isEmpty, "Backup contient les ressentis")
        
        // Restauration dans un second contexte propre avec un ancien bloc à remplacer
        let config2 = ModelConfiguration(isStoredInMemoryOnly: true)
        let container2 = try ModelContainer(for: MacroBloc.self, configurations: config2)
        let ctx2 = ModelContext(container2)
        ctx2.insert(MacroBloc(nom: "Ancien Bloc"))
        try ctx2.save()
        
        let summary = try BackupManager.restoreBackup(parsed, into: ctx2, replaceExisting: true)
        check(summary.blocsRestored == 1, "1 bloc restauré")
        check(summary.seancesRestored == 16, "16 séances restaurées")
        check(summary.seriesValideesRestored == 1, "1 série validée restaurée")
        check(summary.ressentisRestored == 1, "1 ressenti restauré")
        
        let restoredBlocs = try ctx2.fetch(FetchDescriptor<MacroBloc>())
        check(restoredBlocs.count == 1 && restoredBlocs[0].nom == "Bloc Backup Test", "Remplacement complet effectué")
        let restoredSeance = restoredBlocs[0].semaines.sorted { $0.numero < $1.numero }[0].seances.sorted { $0.date < $1.date }[0]
        let restoredTop = restoredSeance.exercices.sorted { $0.ordre < $1.ordre }[0].seriesTriees[0]
        check(restoredTop.estValidee == true, "État validé restauré")
        checkApprox(restoredTop.chargeSaisie, 147.5, "Charge restaurée")
        checkApprox(restoredTop.rpeSaisi, 7.5, "RPE saisi restauré")
        checkApprox(ExportManager.shared.loadRessenti(for: restoredSeance).poidsCorpsKg, 75.0, "Ressenti associé restauré")
    }
    
    // MARK: - 11. Système de Rangs 7×3, INVICTUS & FFForce
    
    static func testRankSystemAndFFForceTags() throws {
        check(RankGrade.allCases.count == 7, "7 grades au total")
        check(RankTier.allTiers.count == 21, "21 paliers (7×3)")
        for i in 1..<RankTier.allTiers.count {
            check(RankTier.allTiers[i].minDots > RankTier.allTiers[i - 1].minDots, "Seuils DOTS strictement croissants")
        }
        
        check(RankGrade.iron.ffforceTag == "Débutant", "Fer FFF tag")
        check(RankGrade.bronze.ffforceTag == "Club", "Bronze FFF tag")
        check(RankGrade.silver.ffforceTag == "FFF · Dép.", "Argent FFF tag")
        check(RankGrade.gold.ffforceTag == "FFF · Régional", "Or FFF tag")
        check(RankGrade.platinum.ffforceTag == "FFF · National", "Platine FFF tag")
        check(RankGrade.diamond.ffforceTag == "FFF · Élite", "Diamant FFF tag")
        check(RankGrade.invictus.ffforceTag == "FFF · Intl.", "INVICTUS FFF tag")
        check(RankGrade.invictus.displayName == "INVICTUS", "Dernier rang nommé INVICTUS")
        
        // Résolution DOTS sur le profil de l'athlète @ 74.5 kg
        let dots485 = PowerliftingScoring.dotsMale(totalKg: 485, bodyweightKg: 74.5)!
        check(RankCalculator.tier(forDOTS: dots485).displayName == "Argent III", "485 kg @ 74.5 -> Argent III")
        
        let dots490 = PowerliftingScoring.dotsMale(totalKg: 490, bodyweightKg: 74.5)!
        check(RankCalculator.tier(forDOTS: dots490).displayName == "Or I", "490 kg @ 74.5 -> Or I")
        
        let dots585 = PowerliftingScoring.dotsMale(totalKg: 585, bodyweightKg: 74.5)!
        check(RankCalculator.tier(forDOTS: dots585).displayName == "Platine I", "585 kg @ 74.5 -> Platine I")
        
        let dots670 = PowerliftingScoring.dotsMale(totalKg: 670, bodyweightKg: 74.5)!
        check(RankCalculator.tier(forDOTS: dots670).displayName == "Diamant I", "670 kg @ 74.5 -> Diamant I")
        
        let dots755 = PowerliftingScoring.dotsMale(totalKg: 755, bodyweightKg: 74.5)!
        check(RankCalculator.tier(forDOTS: dots755).displayName == "INVICTUS I", "755 kg @ 74.5 -> INVICTUS I")
        
        let benchRank = RankCalculator.liftRank(e1rmKg: 130, bodyweightKg: 74.5, movement: .bench)
        check(benchRank?.grade == .gold && benchRank?.tier == 2, "Bench 130 kg @ 74.5 -> Or II")
        
        // Test promotion silencieuse via RankStateManager
        let suiteName = "pt_rank_test_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        defer { testDefaults.removePersistentDomain(forName: suiteName) }
        let mgr = RankStateManager(defaults: testDefaults)
        
        let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MacroBloc.self, configurations: cfg)
        let ctx = ModelContext(container)
        
        let bloc = MacroBloc(nom: "Test Rank")
        let sem = Semaine(numero: 1, nom: "S1"); sem.macroBloc = bloc
        let seance = Seance(date: Date(), titre: "J1"); seance.semaine = sem
        let exSq = Exercice(nom: "Squat Compétition", categorie: .competition, ordre: 0); exSq.seance = seance
        let exBn = Exercice(nom: "Bench Compétition", categorie: .competition, ordre: 1); exBn.seance = seance
        let exDl = Exercice(nom: "Deadlift Compétition", categorie: .competition, ordre: 2); exDl.seance = seance
        let sSq = Serie(repsCibles: 1, rpeCible: 10, chargeSaisie: 165, rpeSaisi: 10, estValidee: true); sSq.exercice = exSq
        let sBn = Serie(repsCibles: 1, rpeCible: 10, chargeSaisie: 130, rpeSaisi: 10, estValidee: true); sBn.exercice = exBn
        let sDl = Serie(repsCibles: 1, rpeCible: 10, chargeSaisie: 190, rpeSaisi: 10, estValidee: true); sDl.exercice = exDl
        ctx.insert(bloc)
        
        let initialSnap = RankCalculator.snapshot(from: [bloc], bodyweightKg: 74.5)
        mgr.syncBaselineIfNeeded(from: initialSnap)
        check(mgr.activePromotion == nil, "Sync initiale ne déclenche pas de popup")
        
        sBn.chargeSaisie = 135
        mgr.evaluateAfterSetValidation(blocs: [bloc], bodyweightKg: 74.5, validatedMovement: .bench)
        check(mgr.activePromotion?.newTier.displayName == "Or I", "Franchissement 490 kg déclenche Or I")
        check(mgr.activePromotion?.isDivisionPromotion == true, "Argent III -> Or I est une promotion de grade")
    }
    
    // MARK: - 12. Démarrage & Clôture Explicite de Séance
    
    static func testExplicitSessionStartAndClose() throws {
        let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MacroBloc.self, configurations: cfg)
        let ctx = ModelContext(container)
        
        let bloc = MacroBloc(nom: "Bloc Session Test")
        let sem = Semaine(numero: 1, nom: "S1"); sem.macroBloc = bloc
        let seance = Seance(date: Date(), titre: "Jour Start Explicit")
        seance.semaine = sem
        let ex = Exercice(nom: "Bench Compétition", categorie: .competition, ordre: 0); ex.seance = seance
        let s1 = Serie(repsCibles: 4, rpeCible: 8.0, chargeSaisie: 100.0, estValidee: false, ordre: 0); s1.exercice = ex
        ctx.insert(bloc)
        
        let tracker = SeanceProgressTracker.shared
        tracker.resetTracking(for: seance)
        defer { tracker.resetTracking(for: seance) }
        
        check(tracker.sessionStartDate(for: seance) == nil, "Avant démarrage: aucune date de début")
        check(tracker.isSeanceInProgressToday(seance) == false, "Avant démarrage: pas en cours")
        
        tracker.startSeance(seance)
        check(tracker.sessionStartDate(for: seance) != nil, "startSeance initialise la date de début")
        check(tracker.isSeanceInProgressToday(seance) == true, "startSeance active la séance même à 0 série validée")
        check(tracker.findActiveSeance(in: [bloc])?.trackingKey == seance.trackingKey, "findActiveSeance retourne la séance démarrée")
        
        tracker.recordSetUnvalidation(for: seance)
        check(tracker.sessionStartDate(for: seance) != nil, "Dévalidation à 0 série conserve le chrono d'une séance démarrée manuellement")
        
        tracker.markSeanceClosed(seance)
        check(tracker.sessionEndDate(for: seance) != nil, "markSeanceClosed enregistre l'heure de fin")
        check(tracker.sessionDurationMinutes(for: seance) != nil, "Durée calculée après clôture")
        check(tracker.isSeanceInProgressToday(seance) == false, "Séance clôturée n'est plus en cours")
    }
}
