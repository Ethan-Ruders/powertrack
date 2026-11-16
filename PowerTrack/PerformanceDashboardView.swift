//
//  PerformanceDashboardView.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Modèles d'Analyse

struct E1RMPoint: Identifiable {
    let id = UUID()
    let date: Date
    let e1rm: Double
    let charge: Double
    let reps: Int
    let rpe: Double
    let nomExercice: String
}

struct TonnageHebdoPoint: Identifiable {
    let id = UUID()
    let semaineNom: String
    let semaineNumero: Int
    let categorie: String
    let tonnageKg: Double
    let rpeMoyen: Double
}

struct PerformanceDashboardView: View {
    @Query private var blocs: [MacroBloc]
    
    @State private var mouvementSelectionne: MouvementCompetition = .bench
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    topRecordsSection
                    e1rmEvolutionSection
                    tonnageHebdoSection
                    rpeMoyenHebdoSection
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Performance")
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Cartes Records du Moment
    
    private var topRecordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Records Estimés (e1RM)")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                recordCard(mouvement: .squat)
                recordCard(mouvement: .bench)
                recordCard(mouvement: .deadlift)
            }
        }
    }
    
    private func recordCard(mouvement: MouvementCompetition) -> some View {
        let maxE1rm = meilleurE1RMPourMouvement(mouvement)
        return VStack(alignment: .leading, spacing: 6) {
            Text(mouvement.rawValue)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Text(maxE1rm > 0 ? "\(Int(maxE1rm)) kg" : "-")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(maxE1rm > 0 ? .white : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Section A : Graphique e1RM
    
    private var e1rmEvolutionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progression e1RM")
                .font(.headline)
                .foregroundColor(.white)
            
            Picker("Mouvement", selection: $mouvementSelectionne) {
                ForEach(MouvementCompetition.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            
            let points = pointsE1RMPourMouvement(mouvementSelectionne)
            
            if points.isEmpty {
                VStack(spacing: 6) {
                    Text("Aucune série validée pour \(mouvementSelectionne.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(Color(white: 0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("e1RM (kg)", point.e1rm)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        
                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("e1RM (kg)", point.e1rm)
                        )
                        .foregroundStyle(Color.orange)
                        .symbolSize(40)
                        .annotation(position: .top) {
                            Text("\(Int(point.e1rm))")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text("\(Int(v)) kg")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.day().month())
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(height: 190)
                .padding(16)
                .background(Color(white: 0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
    
    // MARK: - Section B : Tonnage Hebdomadaire
    
    private var tonnageHebdoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tonnage Hebdomadaire")
                .font(.headline)
                .foregroundColor(.white)
            
            let tonnageData = donneesTonnageHebdo()
            
            if tonnageData.isEmpty {
                Text("Aucune donnée de tonnage disponible.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .background(Color(white: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Chart {
                    ForEach(tonnageData) { point in
                        BarMark(
                            x: .value("Semaine", "S\(point.semaineNumero)"),
                            y: .value("Tonnage (kg)", point.tonnageKg)
                        )
                        .foregroundStyle(by: .value("Catégorie", point.categorie))
                        .cornerRadius(4)
                    }
                }
                .chartForegroundStyleScale([
                    "Compétition": Color.orange,
                    "Variante": Color(white: 0.45),
                    "Accessoire": Color(white: 0.28)
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(String(format: "%.1f t", v / 1000.0))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .padding(16)
                .background(Color(white: 0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
    
    // MARK: - Section C : RPE Moyen Hebdomadaire
    
    private var rpeMoyenHebdoSection: some View {
        let pointsRPE = rpeMoyenParSemaine()
        return Group {
            if !pointsRPE.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RPE Moyen par Semaine")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 10) {
                        ForEach(pointsRPE, id: \.semaine) { item in
                            VStack(spacing: 4) {
                                Text("S\(item.semaine)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Text(item.rpeMoyen > 0 ? String(format: "%.1f", item.rpeMoyen) : "-")
                                    .font(.headline.weight(.bold).monospacedDigit())
                                    .foregroundColor(item.rpeMoyen > 0 ? .white : .secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(white: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(16)
                    .background(Color(white: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - Logique d'Extraction & Calculs SwiftData
    
    private func pointsE1RMPourMouvement(_ mouvement: MouvementCompetition) -> [E1RMPoint] {
        var pointsParDate: [Date: E1RMPoint] = [:]
        let calendar = Calendar.current
        
        for bloc in blocs {
            for semaine in bloc.semaines {
                for seance in semaine.seances {
                    let jour = calendar.startOfDay(for: seance.date)
                    for ex in seance.exercices where correspondAuMouvement(nom: ex.nom, mouv: mouvement) {
                        for serie in ex.series where serie.estValidee {
                            guard let charge = serie.chargeSaisie, charge > 0 else { continue }
                            let reps = serie.repsCibles
                            let rpe = serie.rpeSaisi ?? serie.rpeCible
                            
                            let repsALechecTheorique = Double(reps) + max(0, 10.0 - rpe)
                            let e1rmBrut = charge * (1.0 + repsALechecTheorique / 30.0)
                            let e1rm = round(e1rmBrut / 2.5) * 2.5
                            
                            if let existant = pointsParDate[jour] {
                                if e1rm > existant.e1rm {
                                    pointsParDate[jour] = E1RMPoint(
                                        date: seance.date,
                                        e1rm: e1rm,
                                        charge: charge,
                                        reps: reps,
                                        rpe: rpe,
                                        nomExercice: ex.nom
                                    )
                                }
                            } else {
                                pointsParDate[jour] = E1RMPoint(
                                    date: seance.date,
                                    e1rm: e1rm,
                                    charge: charge,
                                    reps: reps,
                                    rpe: rpe,
                                    nomExercice: ex.nom
                                )
                            }
                        }
                    }
                }
            }
        }
        
        return pointsParDate.values.sorted { $0.date < $1.date }
    }
    
    private func meilleurE1RMPourMouvement(_ mouvement: MouvementCompetition) -> Double {
        let points = pointsE1RMPourMouvement(mouvement)
        return points.map(\.e1rm).max() ?? 0
    }
    
    private func correspondAuMouvement(nom: String, mouv: MouvementCompetition) -> Bool {
        let lower = nom.lowercased()
        switch mouv {
        case .squat:
            return lower.contains("squat")
        case .bench:
            return lower.contains("bench") || lower.contains("développé couché") || lower.contains("spoto") || lower.contains("larsen")
        case .deadlift:
            return lower.contains("deadlift") || lower.contains("soulevé de terre") || lower.contains("block pull")
        }
    }
    
    private func donneesTonnageHebdo() -> [TonnageHebdoPoint] {
        var data: [TonnageHebdoPoint] = []
        guard let bloc = blocs.first else { return [] }
        
        for semaine in bloc.semaines.sorted(by: { $0.numero < $1.numero }) {
            var tonnagesParCat: [String: Double] = [
                "Compétition": 0,
                "Variante": 0,
                "Accessoire": 0
            ]
            var rpeCumul = 0.0
            var countSeries = 0
            
            for seance in semaine.seances {
                for ex in seance.exercices {
                    let catNom: String
                    switch ex.categorie {
                    case .competition: catNom = "Compétition"
                    case .polyarticulaire: catNom = "Variante"
                    case .isolation: catNom = "Accessoire"
                    }
                    
                    for serie in ex.series where serie.estValidee {
                        let charge = serie.chargeSaisie ?? 0
                        tonnagesParCat[catNom, default: 0] += (charge * Double(serie.repsCibles))
                        if let rpe = serie.rpeSaisi {
                            rpeCumul += rpe
                            countSeries += 1
                        }
                    }
                }
            }
            
            let rpeMoyen = countSeries > 0 ? (rpeCumul / Double(countSeries)) : 0.0
            
            for (cat, val) in tonnagesParCat where val > 0 {
                data.append(TonnageHebdoPoint(
                    semaineNom: "S\(semaine.numero)",
                    semaineNumero: semaine.numero,
                    categorie: cat,
                    tonnageKg: val,
                    rpeMoyen: rpeMoyen
                ))
            }
        }
        
        return data
    }
    
    private func rpeMoyenParSemaine() -> [(semaine: Int, rpeMoyen: Double)] {
        guard let bloc = blocs.first else { return [] }
        var res: [(semaine: Int, rpeMoyen: Double)] = []
        
        for sem in bloc.semaines.sorted(by: { $0.numero < $1.numero }) {
            var totalRPE = 0.0
            var count = 0
            for seance in sem.seances {
                for ex in seance.exercices {
                    for serie in ex.series where serie.estValidee {
                        if let rpe = serie.rpeSaisi {
                            totalRPE += rpe
                            count += 1
                        }
                    }
                }
            }
            res.append((semaine: sem.numero, rpeMoyen: count > 0 ? (totalRPE / Double(count)) : 0.0))
        }
        return res
    }
}
