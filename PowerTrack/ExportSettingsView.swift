//
//  ExportSettingsView.swift
//  PowerTrack
//
//  Created by PowerTrack on 17/11/2026.
//

import SwiftUI

/// Écran de configuration du webhook n8n (Serveur Linux) et gestion de la file d'export hors-ligne.
struct ExportSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var exportManager = ExportManager.shared
    
    @State private var isTesting = false
    @State private var isFlushing = false
    @State private var statusMessage: String? = nil
    @State private var statusIsSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    webhookSection
                    authSection
                    testAndStatusSection
                    offlineQueueSection
                }
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle("Serveur Linux & Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(PTTheme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Sections Éditoriales
    
    private var webhookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PTKicker(text: "Webhook n8n (Serveur Linux)")
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Les séances validées et vos ressentis sont envoyés en JSON (v2) vers cette URL.")
                        .font(.caption)
                        .foregroundColor(PTTheme.textSecondary)
                    
                    TextField("https://n8n.exemple.fr/webhook/powertrack", text: $exportManager.webhookURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline)
                        .foregroundColor(PTTheme.textPrimary)
                        .padding(12)
                        .background(PTTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PTTheme.hairline, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                PTHairline()
            }
        }
    }
    
    private var authSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PTKicker(text: "Authentification (optionnel)")
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Si ton webhook n8n vérifie un en-tête HTTP (Header Auth).")
                        .font(.caption)
                        .foregroundColor(PTTheme.textSecondary)
                    
                    TextField("Nom du header (ex: X-API-Key)", text: $exportManager.authHeaderName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline)
                        .foregroundColor(PTTheme.textPrimary)
                        .padding(12)
                        .background(PTTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PTTheme.hairline, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    SecureField("Token / Clé secrète", text: $exportManager.authHeaderValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline)
                        .foregroundColor(PTTheme.textPrimary)
                        .padding(12)
                        .background(PTTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PTTheme.hairline, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                PTHairline()
            }
        }
    }
    
    private var testAndStatusSection: some View {
        VStack(spacing: 12) {
            Button(action: lancerTestConnexion) {
                HStack(spacing: 8) {
                    if isTesting {
                        ProgressView()
                            .tint(PTTheme.bg)
                    } else {
                        Image(systemName: "bolt.horizontal.circle.fill")
                    }
                    Text(isTesting ? "Test en cours..." : "Tester la connexion (ping)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PTPrimaryPillButtonStyle(isDisabled: !exportManager.hasValidWebhookURL || isTesting))
            .disabled(!exportManager.hasValidWebhookURL || isTesting)
            
            if let message = statusMessage {
                HStack(spacing: 10) {
                    Image(systemName: statusIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(statusIsSuccess ? PTTheme.success : PTTheme.accent)
                    Text(message)
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
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var offlineQueueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PTKicker(text: "File d'attente hors-ligne")
                Spacer()
                Text("\(exportManager.pendingQueue.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(exportManager.pendingQueue.isEmpty ? PTTheme.textSecondary : PTTheme.bg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(exportManager.pendingQueue.isEmpty ? PTTheme.surfaceElevated : PTTheme.accent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                if exportManager.pendingQueue.isEmpty {
                    Text("Aucune séance en attente d'envoi.")
                        .font(.caption)
                        .foregroundColor(PTTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                } else {
                    ForEach(exportManager.pendingQueue) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.titre)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(PTTheme.textPrimary)
                            
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(PTTheme.textTertiary)
                            
                            if let err = item.lastError {
                                Text(err)
                                    .font(.caption2)
                                    .foregroundColor(PTTheme.accent)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        PTHairline(leadingInset: 16)
                    }
                    
                    HStack(spacing: 10) {
                        Button(action: renvoyerFile) {
                            HStack(spacing: 6) {
                                if isFlushing {
                                    ProgressView().tint(PTTheme.bg)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Renvoyer tout")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PTPrimaryPillButtonStyle(isDisabled: isFlushing || !exportManager.hasValidWebhookURL))
                        .disabled(isFlushing || !exportManager.hasValidWebhookURL)
                        
                        Button(role: .destructive) {
                            exportManager.clearPendingQueue()
                        } label: {
                            Text("Vider")
                                .foregroundColor(PTTheme.danger)
                        }
                        .buttonStyle(PTSecondaryPillButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                
                PTHairline()
            }
        }
    }
    
    // MARK: - Actions
    
    private func lancerTestConnexion() {
        isTesting = true
        statusMessage = nil
        Task {
            let result = await exportManager.testerConnexion()
            isTesting = false
            switch result {
            case .success(let code):
                HapticAndSoundManager.shared.triggerSetValidated()
                statusIsSuccess = true
                statusMessage = "Connexion OK (HTTP \(code))."
            case .failure(let error):
                statusIsSuccess = false
                statusMessage = "Échec : \(error.localizedDescription)"
            }
        }
    }
    
    private func renvoyerFile() {
        isFlushing = true
        statusMessage = nil
        Task {
            let res = await exportManager.flushPendingQueue()
            isFlushing = false
            if res.remaining == 0 {
                HapticAndSoundManager.shared.triggerSetValidated()
                statusIsSuccess = true
                statusMessage = "\(res.sent) séance(s) envoyée(s) avec succès."
            } else {
                statusIsSuccess = false
                statusMessage = "\(res.sent) envoyée(s), \(res.remaining) restante(s) : \(res.lastError ?? "erreur réseau")"
            }
        }
    }
}
