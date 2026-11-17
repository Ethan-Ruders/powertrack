//
//  SeanceExportSheet.swift
//  PowerTrack
//
//  Created by PowerTrack on 17/11/2026.
//

import SwiftUI
import UIKit

/// Modale rapide post-séance permettant de saisir les ressentis et d'exporter le JSON v2 vers n8n ou le presse-papier.
struct SeanceExportSheet: View {
    let seance: Seance
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var exportManager = ExportManager.shared
    
    @State private var ressenti: RessentiSeanceDTO = RessentiSeanceDTO()
    @State private var douleurDetail = ""
    @State private var notesText = ""
    @State private var isExporting = false
    @State private var isShowingSettings = false
    @State private var feedbackMessage: String? = nil
    @State private var feedbackIsPositive = true
    @State private var copiedJSON = false
    
    private let douleursRapides = [
        "Aucune",
        "Zone opérée",
        "Lombaires",
        "Avant-bras/Coudes",
        "Épaules",
        "Poignet"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ressentisCard
                    douleurEtNotesCard
                    actionsCard
                    
                    if let msg = feedbackMessage {
                        HStack(spacing: 8) {
                            Image(systemName: feedbackIsPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(feedbackIsPositive ? .green : .orange)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(white: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Ressentis & Export")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        sauvegarderRessenti()
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                ExportSettingsView()
            }
            .onAppear(perform: chargerRessenti)
            .onDisappear(perform: sauvegarderRessenti)
        }
    }
    
    // MARK: - Sections UI
    
    private var ressentisCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Check-in Récupération (optionnel)")
                .font(.headline)
                .foregroundColor(.white)
            
            // Poids du corps
            HStack {
                Text("Poids du corps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    TextField("74.5", value: $ressenti.poidsCorpsKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(.white)
                        .frame(width: 64)
                    Text("kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(white: 0.17))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // Sommeil & Hydratation
            stepperRow(
                label: "Sommeil",
                valueText: ressenti.sommeilHeures.map { String(format: "%.1f h", $0) } ?? "-",
                onMinus: {
                    let current = ressenti.sommeilHeures ?? 7.5
                    ressenti.sommeilHeures = max(0, (current - 0.5).roundedToHalf)
                },
                onPlus: {
                    let current = ressenti.sommeilHeures ?? 7.0
                    ressenti.sommeilHeures = min(14, (current + 0.5).roundedToHalf)
                }
            )
            
            stepperRow(
                label: "Hydratation",
                valueText: ressenti.hydratationLitres.map { String(format: "%.2f L", $0) } ?? "-",
                onMinus: {
                    let current = ressenti.hydratationLitres ?? 2.0
                    ressenti.hydratationLitres = max(0, ((current - 0.25) * 4).rounded() / 4)
                },
                onPlus: {
                    let current = ressenti.hydratationLitres ?? 1.75
                    ressenti.hydratationLitres = min(6, ((current + 0.25) * 4).rounded() / 4)
                }
            )
            
            Divider().background(Color.white.opacity(0.08))
            
            ratingPickerRow(titre: "Énergie (1 = vidé, 5 = top)", selection: $ressenti.niveauEnergie)
            ratingPickerRow(titre: "Fatigue lombaire (1 = frais, 5 = saturé)", selection: $ressenti.fatigueLombaire)
            ratingPickerRow(titre: "Stress / DS (1 = zen, 5 = élevé)", selection: $ressenti.stress)
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var douleurEtNotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Douleurs & Observations Techniques")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(douleursRapides, id: \.self) { label in
                        let isSelected = douleurDetail == label
                        Button {
                            HapticAndSoundManager.shared.triggerSelection()
                            douleurDetail = isSelected ? "" : label
                        } label: {
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(isSelected ? .black : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.orange : Color(white: 0.18))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            TextField("Autre douleur ou précision (ex: léger tiraillement coude gauche)", text: $douleurDetail)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(10)
                .background(Color(white: 0.17))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            TextField("Notes séance (ex: depth limite, bench asymétrique, barre frotte)", text: $notesText, axis: .vertical)
                .lineLimit(2...4)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(10)
                .background(Color(white: 0.17))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var actionsCard: some View {
        VStack(spacing: 10) {
            Button(action: envoyerVersServeur) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(isExporting ? "Envoi en cours..." : "Envoyer vers Serveur Linux (n8n)")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
            
            HStack(spacing: 10) {
                Button(action: copierJSON) {
                    HStack(spacing: 6) {
                        Image(systemName: copiedJSON ? "checkmark" : "doc.on.doc")
                        Text(copiedJSON ? "JSON copié" : "Copier JSON")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                ShareLink(
                    item: jsonCourant(),
                    preview: SharePreview("PowerTrack - \(seance.titre ?? "Séance").json")
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Partager")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - Sous-vues
    
    private func stepperRow(label: String, valueText: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 8) {
                Button(action: {
                    HapticAndSoundManager.shared.triggerSelection()
                    onMinus()
                }) {
                    Image(systemName: "minus")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(width: 30, height: 28)
                        .background(Color(white: 0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Text(valueText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white)
                    .frame(minWidth: 56, alignment: .center)
                
                Button(action: {
                    HapticAndSoundManager.shared.triggerSelection()
                    onPlus()
                }) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(width: 30, height: 28)
                        .background(Color(white: 0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func ratingPickerRow(titre: String, selection: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titre)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    let isSelected = selection.wrappedValue == value
                    Button {
                        HapticAndSoundManager.shared.triggerSelection()
                        selection.wrappedValue = isSelected ? nil : value
                    } label: {
                        Text("\(value)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundColor(isSelected ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.orange : Color(white: 0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Logique
    
    private func chargerRessenti() {
        let saved = exportManager.loadRessenti(for: seance)
        ressenti = saved
        douleurDetail = saved.douleurSignalee ?? ""
        notesText = saved.notesSeance ?? ""
    }
    
    private func construireRessentiCourant() -> RessentiSeanceDTO {
        var copy = ressenti
        copy.douleurSignalee = douleurDetail
        copy.notesSeance = notesText
        return copy
    }
    
    private func sauvegarderRessenti() {
        exportManager.saveRessenti(construireRessentiCourant(), for: seance)
    }
    
    private func jsonCourant() -> String {
        let current = construireRessentiCourant()
        exportManager.saveRessenti(current, for: seance)
        return exportManager.genererJSONString(for: seance, ressenti: current)
    }
    
    private func copierJSON() {
        UIPasteboard.general.string = jsonCourant()
        HapticAndSoundManager.shared.triggerSetValidated()
        copiedJSON = true
        feedbackIsPositive = true
        feedbackMessage = "JSON v2 complet copié dans le presse-papier."
    }
    
    private func envoyerVersServeur() {
        let current = construireRessentiCourant()
        exportManager.saveRessenti(current, for: seance)
        isExporting = true
        feedbackMessage = nil
        
        Task {
            let outcome = await exportManager.exporterSeance(seance: seance, ressenti: current)
            isExporting = false
            switch outcome {
            case .sent(let statusCode, _):
                HapticAndSoundManager.shared.triggerPRValidated()
                feedbackIsPositive = true
                feedbackMessage = "Séance et ressentis envoyés vers n8n (HTTP \(statusCode))."
            case .queuedOffline(let reason, _):
                feedbackIsPositive = false
                feedbackMessage = "Serveur injoignable : séance mise en file d'attente hors-ligne (\(reason))."
            case .missingConfiguration:
                feedbackIsPositive = false
                feedbackMessage = "URL webhook n8n non configurée. Appuie sur l'icône engrenage en haut à droite."
                isShowingSettings = true
            }
        }
    }
}

private extension Double {
    var roundedToHalf: Double {
        (self * 2.0).rounded() / 2.0
    }
}
