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
    @Query(sort: \MacroBloc.dateDebut, order: .reverse) private var blocs: [MacroBloc]
    
    @State private var mouvementSelectionne: MouvementCompetition = .bench
    @State private var selectedBlocID: PersistentIdentifier? = nil
    
    private var selectedBloc: MacroBloc? {
        guard let selectedBlocID else { return nil }
        return blocs.first(where: { $0.persistentModelID == selectedBlocID })
    }
    
    private var scopedBlocs: [MacroBloc] {
        if let selectedBloc {
            return [selectedBloc]
        }
        return blocs
    }
    
    private var weeklyBloc: MacroBloc? {
        selectedBloc ?? blocs.first
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if blocs.count > 1 {
                        blocFilterStrip
                    }
                    
                    totalAndRecordsSection
                    e1rmEvolutionSection
                    tonnageHebdoSection
                    rpeMoyenHebdoSection
                }
                .padding(.vertical, 16)
            }
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle("Performance")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Filtre Multi-Bloc
    
    private var blocFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                blocFilterPill(title: "Tous les blocs", isSelected: selectedBloc == nil) {
                    selectedBlocID = nil
                }
                
                ForEach(blocs) { bloc in
                    let isSelected = selectedBloc?.persistentModelID == bloc.persistentModelID
                    blocFilterPill(title: bloc.nom, isSelected: isSelected) {
                        selectedBlocID = bloc.persistentModelID
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func blocFilterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? PTTheme.bg : PTTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? PTTheme.textPrimary : PTTheme.surface)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : PTTheme.hairline, lineWidth: 0.5)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Hero Total Estimé & Records SBD
    
    private var totalAndRecordsSection: some View {
        let squatBest = meilleurE1RMPourMouvement(.squat)
        let benchBest = meilleurE1RMPourMouvement(.bench)
        let deadliftBest = meilleurE1RMPourMouvement(.deadlift)
        let total = squatBest + benchBest + deadliftBest
        
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PTKicker(text: "Total SBD Estimé · e1RM", color: PTTheme.accent)
                    Spacer()
                    PTKicker(text: selectedBloc?.nom ?? "Global")
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(total > 0 ? PTFormat.weight(total) : "—")
                        .font(.system(size: 40, weight: .bold).monospacedDigit())
                        .foregroundColor(total > 0 ? PTTheme.textPrimary : PTTheme.textTertiary)
                    
                    if total > 0 {
                        Text("kg")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(PTTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            if total > 0 {
                proportionalSBDBar(squat: squatBest, bench: benchBest, deadlift: deadliftBest, total: total)
                    .padding(.horizontal, 16)
            }
            
            VStack(spacing: 0) {
                PTHairline()
                HStack(spacing: 0) {
                    recordColumn(mouvement: .squat, value: squatBest, total: total, dotColor: PTTheme.textPrimary)
                    verticalHairline
                    recordColumn(mouvement: .bench, value: benchBest, total: total, dotColor: PTTheme.accent)
                    verticalHairline
                    recordColumn(mouvement: .deadlift, value: deadliftBest, total: total, dotColor: PTTheme.textSecondary)
                }
                PTHairline()
            }
        }
    }
    
    private func proportionalSBDBar(squat: Double, bench: Double, deadlift: Double, total: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let sqW = max(0, w * (squat / total))
            let bnW = max(0, w * (bench / total))
            let dlW = max(0, w * (deadlift / total))
            
            HStack(spacing: 2) {
                if sqW > 0 {
                    Rectangle()
                        .fill(PTTheme.textPrimary)
                        .frame(width: sqW)
                }
                if bnW > 0 {
                    Rectangle()
                        .fill(PTTheme.accent)
                        .frame(width: bnW)
                }
                if dlW > 0 {
                    Rectangle()
                        .fill(PTTheme.textSecondary)
                        .frame(width: dlW)
                }
            }
        }
        .frame(height: 3)
        .background(PTTheme.hairline)
    }
    
    private func recordColumn(mouvement: MouvementCompetition, value: Double, total: Double, dotColor: Color) -> some View {
        let share = total > 0 && value > 0 ? Int(round((value / total) * 100.0)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
                PTKicker(text: mouvement.rawValue)
            }
            
            Text(value > 0 ? "\(PTFormat.weight(value)) kg" : "—")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(value > 0 ? PTTheme.textPrimary : PTTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Text(share > 0 ? "\(share)% du total" : "Aucune donnée")
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(PTTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var verticalHairline: some View {
        Rectangle()
            .fill(PTTheme.hairline)
            .frame(width: 0.5)
    }
    
    // MARK: - Section A : Progression e1RM
    
    private var e1rmEvolutionSection: some View {
        let points = pointsE1RMPourMouvement(mouvementSelectionne)
        let minVal = points.map(\.e1rm).min() ?? 0
        let maxVal = points.map(\.e1rm).max() ?? 100
        let domainMin = max(0, minVal - 10)
        let domainMax = max(domainMin + 10, maxVal + 10)
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                PTKicker(text: "Progression e1RM")
                Spacer()
                if let latest = points.last {
                    Text("Dernier · \(PTFormat.weight(latest.e1rm)) kg")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundColor(PTTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            
            HStack(spacing: 8) {
                ForEach(MouvementCompetition.allCases) { m in
                    let isSelected = mouvementSelectionne == m
                    Button {
                        mouvementSelectionne = m
                    } label: {
                        Text(m.rawValue)
                            .font(.caption.weight(isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? PTTheme.bg : PTTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? PTTheme.textPrimary : PTTheme.surface)
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : PTTheme.hairline, lineWidth: 0.5)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                if points.isEmpty {
                    Text("Aucune série validée pour \(mouvementSelectionne.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(PTTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 170)
                        .padding(.horizontal, 16)
                } else {
                    Chart {
                        ForEach(points) { point in
                            AreaMark(
                                x: .value("Date", point.date, unit: .day),
                                yStart: .value("Base", domainMin),
                                yEnd: .value("e1RM (kg)", point.e1rm)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [PTTheme.accent.opacity(0.24), PTTheme.accent.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("e1RM (kg)", point.e1rm)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(PTTheme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            PointMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("e1RM (kg)", point.e1rm)
                            )
                            .foregroundStyle(PTTheme.accent)
                            .symbolSize(30)
                            .annotation(position: .top) {
                                Text(PTFormat.weight(point.e1rm))
                                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                    .foregroundColor(PTTheme.textSecondary)
                            }
                        }
                    }
                    .chartYScale(domain: domainMin...domainMax)
                    .chartYAxis {
                        AxisMarks(position: .leading) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(PTTheme.hairline)
                            AxisValueLabel {
                                if let v = val.as(Double.self) {
                                    Text("\(Int(v))")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundColor(PTTheme.textTertiary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(format: .dateTime.day().month())
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(PTTheme.textTertiary)
                        }
                    }
                    .frame(height: 190)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                
                PTHairline()
            }
        }
    }
    
    // MARK: - Section B : Tonnage Hebdomadaire
    
    private var tonnageHebdoSection: some View {
        let tonnageData = donneesTonnageHebdo()
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                PTKicker(text: "Tonnage Hebdomadaire")
                Spacer()
                if let bloc = weeklyBloc {
                    PTKicker(text: bloc.nom, color: PTTheme.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                if tonnageData.isEmpty {
                    Text("Aucune donnée de tonnage disponible.")
                        .font(.subheadline)
                        .foregroundColor(PTTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding(.horizontal, 16)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Chart {
                            ForEach(tonnageData) { point in
                                BarMark(
                                    x: .value("Semaine", "S\(point.semaineNumero)"),
                                    y: .value("Tonnage (kg)", point.tonnageKg)
                                )
                                .foregroundStyle(by: .value("Catégorie", point.categorie))
                                .cornerRadius(3)
                            }
                        }
                        .chartForegroundStyleScale([
                            "Compétition": PTTheme.accent,
                            "Variante": PTTheme.textSecondary,
                            "Accessoire": PTTheme.surfaceElevated
                        ])
                        .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
                        .chartYAxis {
                            AxisMarks(position: .leading) { val in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(PTTheme.hairline)
                                AxisValueLabel {
                                    if let v = val.as(Double.self) {
                                        Text(String(format: "%.1f t", v / 1000.0))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundColor(PTTheme.textTertiary)
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(PTTheme.textTertiary)
                            }
                        }
                        .frame(height: 180)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                
                PTHairline()
            }
        }
    }
    
    // MARK: - Section C : RPE Moyen Hebdomadaire
    
    private var rpeMoyenHebdoSection: some View {
        let pointsRPE = rpeMoyenParSemaine()
        return Group {
            if !pointsRPE.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        PTKicker(text: "RPE Moyen par Semaine")
                        Spacer()
                        if let bloc = weeklyBloc {
                            PTKicker(text: bloc.nom, color: PTTheme.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        PTHairline()
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(Array(pointsRPE.enumerated()), id: \.element.semaine) { idx, item in
                                    VStack(spacing: 4) {
                                        PTKicker(text: String(format: "S%02d", item.semaine))
                                        
                                        Text(item.rpeMoyen > 0 ? String(format: "%.1f", item.rpeMoyen) : "—")
                                            .font(.title3.weight(.bold).monospacedDigit())
                                            .foregroundColor(item.rpeMoyen > 0 ? (item.rpeMoyen >= 9.0 ? PTTheme.accent : PTTheme.textPrimary) : PTTheme.textTertiary)
                                            .lineLimit(1)
                                    }
                                    .frame(minWidth: 74, maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 10)
                                    
                                    if idx < pointsRPE.count - 1 {
                                        verticalHairline
                                    }
                                }
                            }
                            .containerRelativeFrame(.horizontal) { width, _ in
                                max(width, CGFloat(pointsRPE.count) * 74)
                            }
                        }
                        
                        PTHairline()
                    }
                }
            }
        }
    }
    
    // MARK: - Logique d'Extraction & Calculs SwiftData
    
    private func pointsE1RMPourMouvement(_ mouvement: MouvementCompetition) -> [E1RMPoint] {
        var pointsParDate: [Date: E1RMPoint] = [:]
        let calendar = Calendar.current
        
        for bloc in scopedBlocs {
            for semaine in bloc.semaines {
                for seance in semaine.seances {
                    let jour = calendar.startOfDay(for: seance.date)
                    for ex in seance.exercices where correspondAuMouvement(nom: ex.nom, mouv: mouvement) {
                        for serie in ex.series where serie.estValidee {
                            guard let charge = serie.chargeSaisie, charge > 0,
                                  let e1rm = serie.calculerE1RM() else { continue }
                            let reps = serie.repsCibles
                            let rpe = serie.rpeSaisi ?? serie.rpeCible
                            
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
        pointsE1RMPourMouvement(mouvement).map(\.e1rm).max() ?? 0
    }
    
    private func correspondAuMouvement(nom: String, mouv: MouvementCompetition) -> Bool {
        let lower = nom.lowercased()
        switch mouv {
        case .squat:
            return lower.contains("squat")
        case .bench:
            return lower.contains("bench") || lower.contains("développé couché") || lower.contains("spoto") || lower.contains("larsen") || lower.contains("3ct")
        case .deadlift:
            return lower.contains("deadlift") || lower.contains("soulevé de terre") || lower.contains("block pull")
        }
    }
    
    private func donneesTonnageHebdo() -> [TonnageHebdoPoint] {
        var data: [TonnageHebdoPoint] = []
        guard let bloc = weeklyBloc else { return [] }
        
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
        guard let bloc = weeklyBloc else { return [] }
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
