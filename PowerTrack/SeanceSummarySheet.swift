//
//  SeanceSummarySheet.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import SwiftUI
import UIKit

struct TopSetSummaryItem: Identifiable {
    let id = UUID()
    let nomExercice: String
    let charge: Double
    let reps: Int
    let rpeCible: Double
    let rpeReel: Double?
    let e1RM: Double?
}

struct SeanceSummarySheet: View {
    let seance: Seance
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var exportManager = ExportManager.shared
    
    @State private var isShowingExportSheet = false
    @State private var isExportingNow = false
    @State private var exportFeedback: String? = nil
    @State private var exportFeedbackPositive = true
    
    // Calculs de synthèse
    private var seriesValidees: [(exercice: Exercice, serie: Serie)] {
        var res: [(exercice: Exercice, serie: Serie)] = []
        for ex in seance.exercices.sorted(by: { $0.ordre < $1.ordre }) {
            for s in ex.seriesTriees where s.estValidee {
                res.append((exercice: ex, serie: s))
            }
        }
        return res
    }
    
    private var tonnageTotalKg: Double {
        seriesValidees.reduce(0) { total, item in
            let charge = item.serie.chargeSaisie ?? 0
            return total + (charge * Double(item.serie.repsCibles))
        }
    }
    
    private var tonnageTotalTonnes: Double {
        tonnageTotalKg / 1000.0
    }
    
    private var meilleurE1RMSession: (exercice: String, charge: Double)? {
        var top: (exercice: String, charge: Double)? = nil
        for item in seriesValidees {
            if let e1rm = item.serie.calculerE1RM() {
                if top == nil || e1rm > top!.charge {
                    top = (item.exercice.nom, e1rm)
                }
            }
        }
        return top
    }
    
    private var topSetsRealises: [TopSetSummaryItem] {
        var items: [TopSetSummaryItem] = []
        for ex in seance.exercices.sorted(by: { $0.ordre < $1.ordre }) {
            let seriesVal = ex.seriesTriees.filter { $0.estValidee }
            if let heaviest = seriesVal.max(by: { ($0.chargeSaisie ?? 0) < ($1.chargeSaisie ?? 0) }) {
                items.append(TopSetSummaryItem(
                    nomExercice: ex.nom,
                    charge: heaviest.chargeSaisie ?? 0,
                    reps: heaviest.repsCibles,
                    rpeCible: heaviest.rpeCible,
                    rpeReel: heaviest.rpeSaisi,
                    e1RM: heaviest.calculerE1RM()
                ))
            }
        }
        return items
    }
    
    private var statutServeur: (text: String, color: Color) {
        if exportManager.isSeanceExported(seance) {
            return ("Synchronisée", PTTheme.success)
        } else if exportManager.isSeancePendingExport(seance) {
            return ("En file hors-ligne", PTTheme.accent)
        } else {
            return ("Non envoyée", PTTheme.textSecondary)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Hero éditorial
                    VStack(alignment: .leading, spacing: 6) {
                        PTKicker(text: "Séance clôturée · \(dureeEstimeeTexte)", color: PTTheme.success)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "%.2f", tonnageTotalTonnes))
                                .font(.system(size: 42, weight: .bold).monospacedDigit())
                                .foregroundColor(PTTheme.textPrimary)
                            Text("t soulevées")
                                .font(.title3.weight(.medium))
                                .foregroundColor(PTTheme.textSecondary)
                        }
                        
                        Text("\(seance.titre ?? seance.date.formatted(date: .abbreviated, time: .omitted)) · \(Int(tonnageTotalKg)) kg au total")
                            .font(.subheadline)
                            .foregroundColor(PTTheme.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    
                    PTHairline()
                    
                    // Lignes KPI épurées
                    metricRow(
                        label: "Meilleur e1RM",
                        value: meilleurE1RMSession.map { "\(PTFormat.weight($0.charge)) kg" } ?? "-",
                        detail: meilleurE1RMSession?.exercice,
                        valueColor: PTTheme.accent
                    )
                    PTHairline(leadingInset: 20)
                    
                    metricRow(
                        label: "Séries validées",
                        value: "\(seriesValidees.count) / \(seance.totalSeriesCount)",
                        detail: "\(Int(round(seance.progressionRatio * 100.0)))%",
                        valueColor: PTTheme.textPrimary
                    )
                    PTHairline(leadingInset: 20)
                    
                    metricRow(
                        label: "Durée",
                        value: dureeEstimeeTexte,
                        detail: dureeReelleMinutes != nil ? "Temps réel" : "Estimée",
                        valueColor: PTTheme.textPrimary
                    )
                    PTHairline(leadingInset: 20)
                    
                    metricRow(
                        label: "Serveur n8n",
                        value: statutServeur.text,
                        detail: exportManager.hasValidWebhookURL ? "Webhook configuré" : "Aucun webhook configuré",
                        valueColor: statutServeur.color
                    )
                    PTHairline()
                    
                    // Top Sets & Intensité
                    if !topSetsRealises.isEmpty {
                        PTKicker(text: "Top Sets & Intensité")
                            .padding(.horizontal, 20)
                            .padding(.top, 22)
                            .padding(.bottom, 10)
                        
                        PTHairline()
                        
                        ForEach(Array(topSetsRealises.enumerated()), id: \.element.id) { index, top in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(top.nomExercice)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(PTTheme.textPrimary)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 6) {
                                        Text("\(PTFormat.weight(top.charge)) kg × \(top.reps)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundColor(PTTheme.textSecondary)
                                        
                                        if let e1rm = top.e1RM {
                                            Text("· e1RM \(PTFormat.weight(e1rm)) kg")
                                                .font(.caption.monospacedDigit())
                                                .foregroundColor(PTTheme.accent)
                                        }
                                    }
                                }
                                
                                Spacer(minLength: 6)
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let reel = top.rpeReel {
                                        Text("@\(PTFormat.rpe(reel))")
                                            .font(.subheadline.weight(.bold).monospacedDigit())
                                            .foregroundColor(couleurPourRPE(reel: reel, cible: top.rpeCible))
                                    } else {
                                        Text("-")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundColor(PTTheme.textSecondary)
                                    }
                                    
                                    Text("cible @\(PTFormat.rpe(top.rpeCible))")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundColor(PTTheme.textTertiary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 13)
                            
                            if index < topSetsRealises.count - 1 {
                                PTHairline(leadingInset: 20)
                            } else {
                                PTHairline()
                            }
                        }
                    }
                    
                    if let feedback = exportFeedback {
                        HStack(spacing: 8) {
                            Image(systemName: exportFeedbackPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(exportFeedbackPositive ? PTTheme.success : PTTheme.accent)
                            Text(feedback)
                                .font(.caption)
                                .foregroundColor(PTTheme.textPrimary)
                            Spacer()
                        }
                        .padding(12)
                        .background(PTTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PTTheme.hairline, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    }
                    
                    // Actions finales
                    VStack(spacing: 10) {
                        if exportManager.hasValidWebhookURL && !exportManager.isSeanceExported(seance) {
                            Button(action: envoyerDirectementVersN8n) {
                                HStack(spacing: 8) {
                                    if isExportingNow {
                                        ProgressView().tint(PTTheme.textPrimary)
                                    } else {
                                        Image(systemName: "arrow.up.circle")
                                    }
                                    Text(isExportingNow ? "Envoi vers n8n..." : "Envoyer directement vers n8n")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PTSecondaryPillButtonStyle())
                            .disabled(isExportingNow)
                        }
                        
                        Button(action: {
                            HapticAndSoundManager.shared.triggerLightImpact()
                            isShowingExportSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane")
                                Text("Ressentis & Export (n8n)")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PTSecondaryPillButtonStyle())
                        
                        Button(action: {
                            let impact = UINotificationFeedbackGenerator()
                            impact.notificationOccurred(.success)
                            dismiss()
                        }) {
                            Text("Valider et fermer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PTPrimaryPillButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 28)
                }
            }
            .ptAppBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(PTTheme.textSecondary)
                }
            }
            .sheet(isPresented: $isShowingExportSheet) {
                SeanceExportSheet(seance: seance)
            }
            .ptAppearance()
        }
    }
    
    // MARK: - Helpers UI & Actions
    
    private func envoyerDirectementVersN8n() {
        isExportingNow = true
        exportFeedback = nil
        Task {
            let outcome = await exportManager.exporterSeance(seance: seance)
            isExportingNow = false
            switch outcome {
            case .sent(let statusCode, _):
                HapticAndSoundManager.shared.triggerSetValidated()
                exportFeedbackPositive = true
                exportFeedback = "Séance synchronisée avec n8n (HTTP \(statusCode))."
            case .queuedOffline(let reason, _):
                exportFeedbackPositive = false
                exportFeedback = "Serveur indisponible : ajoutée à la file hors-ligne (\(reason))."
            case .missingConfiguration:
                exportFeedbackPositive = false
                isShowingExportSheet = true
            }
        }
    }
    
    private func metricRow(label: String, value: String, detail: String?, valueColor: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(PTTheme.textSecondary)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(PTTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    private var dureeReelleMinutes: Int? {
        SeanceProgressTracker.shared.sessionDurationMinutes(for: seance)
    }
    
    private var dureeEstimeeTexte: String {
        let minutes = dureeReelleMinutes ?? max(45, seriesValidees.count * 4)
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }
    
    private func couleurPourRPE(reel: Double, cible: Double) -> Color {
        let diff = reel - cible
        if diff <= 0.0 {
            return PTTheme.success
        } else if diff <= 0.5 {
            return PTTheme.accent
        } else {
            return PTTheme.danger
        }
    }
}
