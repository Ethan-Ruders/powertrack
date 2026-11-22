//
//  PowerTrackCoreTests.swift
//  PowerTrack Core Unit Tests
//

import Foundation
import SwiftData

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
        try testProgramJSONImporter()
        try testExportManagerDTOAndRessenti()
        try testBackupExportAndRestoreRoundTrip()
        
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
}
