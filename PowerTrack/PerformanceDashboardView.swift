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
    @ObservedObject private var exportManager = ExportManager.shared
    @ObservedObject private var progressTracker = SeanceProgressTracker.shared
    
    @State private var mouvementSelectionne: MouvementCompetition = .bench
    @State private var selectedBlocID: PersistentIdentifier? = nil
    @State private var competitionUniquement: Bool = true
    
    // Sélection interactive sur les graphiques
    @State private var selectedE1RMDate: Date? = nil
    @State private var selectedTonnageWeek: String? = nil
    
    // Saisie rapide poids de corps pour calcul DOTS / IPF GL
    @State private var isEditingBodyweight: Bool = false
    @State private var bodyweightDraft: String = ""
    
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
    
    private var seanceEnCours: Seance? {
        _ = progressTracker.lastUpdateToken
        return progressTracker.findActiveSeance(in: blocs)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if blocs.count > 1 {
                        blocFilterStrip
                    }
                    
                    scopeFilterStrip
                    totalAndRecordsSection
                    e1rmEvolutionSection
                    tonnageHebdoSection
                    rpeMoyenHebdoSection
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle("Performance")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .safeAreaInset(edge: .bottom) {
                PTBottomOverlayStack(activeSeance: seanceEnCours)
            }
            .onChange(of: mouvementSelectionne) { _, _ in
                selectedE1RMDate = nil
            }
            .onChange(of: selectedBlocID) { _, _ in
                selectedE1RMDate = nil
                selectedTonnageWeek = nil
            }
            .onChange(of: competitionUniquement) { _, _ in
                selectedE1RMDate = nil
            }
        }
    }
    
    // MARK: - Filtres Multi-Bloc & Compétition/Variantes
    
    private var blocFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(title: "Tous les blocs", isSelected: selectedBloc == nil) {
                    selectedBlocID = nil
                }
                
                ForEach(blocs) { bloc in
                    let isSelected = selectedBloc?.persistentModelID == bloc.persistentModelID
                    filterPill(title: bloc.nom, isSelected: isSelected) {
                        selectedBlocID = bloc.persistentModelID
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var scopeFilterStrip: some View {
        HStack(spacing: 8) {
            filterPill(title: "Compétition", isSelected: competitionUniquement) {
                competitionUniquement = true
            }
            filterPill(title: "Toutes variantes", isSelected: !competitionUniquement) {
                competitionUniquement = false
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private func filterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
    
    // MARK: - Hero Total Estimé, DOTS / IPF GL & Records SBD
    
    private var totalAndRecordsSection: some View {
        let squatBest = meilleurE1RMPourMouvement(.squat)
        let benchBest = meilleurE1RMPourMouvement(.bench)
        let deadliftBest = meilleurE1RMPourMouvement(.deadlift)
        let total = squatBest + benchBest + deadliftBest
        
        let bw = exportManager.lastBodyweightKg
        let dots = bw.flatMap { PowerliftingScoring.dotsMale(totalKg: total, bodyweightKg: $0) }
        let ipfGL = bw.flatMap { PowerliftingScoring.ipfGLMaleClassic(totalKg: total, bodyweightKg: $0) }
        
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PTKicker(text: competitionUniquement ? "Total SBD Estimé · Compétition" : "Total SBD Estimé · Avec variantes", color: PTTheme.accent)
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
                    
                    Spacer()
                    
                    bodyweightControl
                }
                
                if isEditingBodyweight {
                    HStack(spacing: 8) {
                        TextField("Poids de corps (kg)", text: $bodyweightDraft)
                            .keyboardType(.decimalPad)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundColor(PTTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(PTTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(PTTheme.hairline, lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        Button("OK") {
                            let normalized = bodyweightDraft.replacingOccurrences(of: ",", with: ".")
                            if let parsed = Double(normalized), parsed > 0 {
                                exportManager.lastBodyweightKg = parsed
                            }
                            isEditingBodyweight = false
                        }
                        .font(.caption.weight(.bold))
                        .foregroundColor(PTTheme.bg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PTTheme.textPrimary)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
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
                
                if let dots, let ipfGL, let bw, bw > 0 {
                    PTHairline()
                    HStack(spacing: 0) {
                        scoreColumn(kicker: "DOTS", value: String(format: "%.2f", dots))
                        verticalHairline
                        scoreColumn(kicker: "IPF GL", value: String(format: "%.2f", ipfGL))
                        verticalHairline
                        scoreColumn(kicker: "Poids de corps", value: "\(PTFormat.weight(bw)) kg")
                    }
                }
                PTHairline()
            }
        }
    }
    
    private var bodyweightControl: some View {
        Button {
            if let existing = exportManager.lastBodyweightKg, existing > 0 {
                bodyweightDraft = PTFormat.weight(existing)
            } else {
                bodyweightDraft = ""
            }
            withAnimation(.snappy(duration: 0.2)) {
                isEditingBodyweight.toggle()
            }
        } label: {
            Text(exportManager.lastBodyweightKg.map { "PDC · \(PTFormat.weight($0)) kg" } ?? "Définir PDC")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundColor(PTTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PTTheme.surface)
                .overlay(
                    Capsule()
                        .stroke(PTTheme.hairline, lineWidth: 0.5)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func scoreColumn(kicker: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            PTKicker(text: kicker)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundColor(PTTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
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
    
    // MARK: - Section A : Progression e1RM Interactive
    
    private var e1rmEvolutionSection: some View {
        let points = pointsE1RMPourMouvement(mouvementSelectionne)
        let selectedPoint = selectedE1RMPoint(in: points)
        let minVal = points.map(\.e1rm).min() ?? 0
        let maxVal = points.map(\.e1rm).max() ?? 100
        let domainMin = max(0, minVal - 10)
        let domainMax = max(domainMin + 10, maxVal + 10)
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                PTKicker(text: "Progression e1RM")
                Spacer()
                if let pt = selectedPoint {
                    Text("\(PTFormat.weight(pt.charge)) kg × \(pt.reps) @ \(PTFormat.rpe(pt.rpe)) · e1RM \(PTFormat.weight(pt.e1rm)) kg")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(PTTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else if let latest = points.last {
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
                    VStack(alignment: .leading, spacing: 6) {
                        if let pt = selectedPoint {
                            Text("\(pt.nomExercice) · \(pt.date.formatted(.dateTime.day().month(.abbreviated)))")
                                .font(.caption2)
                                .foregroundColor(PTTheme.textSecondary)
                        }
                        
                        Chart {
                            if let pt = selectedPoint {
                                RuleMark(x: .value("Sélection", pt.date))
                                    .foregroundStyle(PTTheme.hairlineStrong)
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            }
                            
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
                                
                                let isHighlighted = selectedPoint?.id == point.id
                                PointMark(
                                    x: .value("Date", point.date, unit: .day),
                                    y: .value("e1RM (kg)", point.e1rm)
                                )
                                .foregroundStyle(isHighlighted ? PTTheme.textPrimary : PTTheme.accent)
                                .symbolSize(isHighlighted ? 60 : 30)
                                .annotation(position: .top) {
                                    Text(PTFormat.weight(point.e1rm))
                                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                        .foregroundColor(isHighlighted ? PTTheme.textPrimary : PTTheme.textSecondary)
                                }
                            }
                        }
                        .chartXSelection(value: $selectedE1RMDate)
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                
                PTHairline()
            }
        }
    }
    
    // MARK: - Section B : Tonnage Hebdomadaire Interactif
    
    private var tonnageHebdoSection: some View {
        let tonnageData = donneesTonnageHebdo()
        let weekSummary = selectedTonnageSummary(in: tonnageData)
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                PTKicker(text: "Tonnage Hebdomadaire")
                Spacer()
                if let summary = weekSummary {
                    Text(summary)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(PTTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else if let bloc = weeklyBloc {
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
                            if let week = selectedTonnageWeek {
                                RuleMark(x: .value("Semaine", week))
                                    .foregroundStyle(PTTheme.hairlineStrong)
                            }
                            
                            ForEach(tonnageData) { point in
                                BarMark(
                                    x: .value("Semaine", "S\(point.semaineNumero)"),
                                    y: .value("Tonnage (kg)", point.tonnageKg)
                                )
                                .foregroundStyle(by: .value("Catégorie", point.categorie))
                                .cornerRadius(3)
                            }
                        }
                        .chartXSelection(value: $selectedTonnageWeek)
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
    
    private func selectedE1RMPoint(in points: [E1RMPoint]) -> E1RMPoint? {
        guard let date = selectedE1RMDate else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    private func selectedTonnageSummary(in data: [TonnageHebdoPoint]) -> String? {
        guard let week = selectedTonnageWeek else { return nil }
        let matching = data.filter { "S\($0.semaineNumero)" == week }
        guard !matching.isEmpty else { return nil }
        let totalKg = matching.reduce(0.0) { $0 + $1.tonnageKg }
        let comp = matching.filter { $0.categorie == "Compétition" }.reduce(0.0) { $0 + $1.tonnageKg }
        let vari = matching.filter { $0.categorie == "Variante" }.reduce(0.0) { $0 + $1.tonnageKg }
        let acc = matching.filter { $0.categorie == "Accessoire" }.reduce(0.0) { $0 + $1.tonnageKg }
        return String(format: "%@ · %.2f t (C %.1f · V %.1f · A %.1f)", week, totalKg / 1000.0, comp / 1000.0, vari / 1000.0, acc / 1000.0)
    }
    
    private func parentTarget(for mouvement: MouvementCompetition) -> MouvementParent {
        switch mouvement {
        case .squat: return .squat
        case .bench: return .bench
        case .deadlift: return .deadlift
        }
    }
    
    private func pointsE1RMPourMouvement(_ mouvement: MouvementCompetition) -> [E1RMPoint] {
        var pointsParDate: [Date: E1RMPoint] = [:]
        let calendar = Calendar.current
        let cibleParent = parentTarget(for: mouvement)
        
        for bloc in scopedBlocs {
            for semaine in bloc.semaines {
                for seance in semaine.seances {
                    let jour = calendar.startOfDay(for: seance.date)
                    for ex in seance.exercices where ex.mouvementParent == cibleParent {
                        if competitionUniquement && !ex.estMouvementCompetitionPur {
                            continue
                        }
                        for serie in ex.seriesTriees where serie.estValidee {
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
                    
                    for serie in ex.seriesTriees where serie.estValidee {
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
                    for serie in ex.seriesTriees where serie.estValidee {
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
