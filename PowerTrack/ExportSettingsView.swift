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
                VStack(spacing: 20) {
                    webhookCard
                    authCard
                    testAndStatusSection
                    offlineQueueCard
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Serveur Linux & Export")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Cartes
    
    private var webhookCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Webhook n8n (Serveur Linux)", systemImage: "server.rack")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Les séances validées et vos ressentis sont envoyés en JSON (v2) vers cette URL.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("https://n8n.exemple.fr/webhook/powertrack", text: $exportManager.webhookURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(12)
                .background(Color(white: 0.17))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var authCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Authentification (optionnel)", systemImage: "lock.shield")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Si ton webhook n8n vérifie un en-tête HTTP (Header Auth).")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("Nom du header (ex: X-API-Key)", text: $exportManager.authHeaderName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(12)
                .background(Color(white: 0.17))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            SecureField("Token / Clé secrète", text: $exportManager.authHeaderValue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(12)
                .background(Color(white: 0.17))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var testAndStatusSection: some View {
        VStack(spacing: 10) {
            Button(action: lancerTestConnexion) {
                HStack(spacing: 8) {
                    if isTesting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "bolt.horizontal.circle.fill")
                    }
                    Text(isTesting ? "Test en cours..." : "Tester la connexion (ping)")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(exportManager.hasValidWebhookURL ? Color.orange : Color(white: 0.25))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!exportManager.hasValidWebhookURL || isTesting)
            
            if let message = statusMessage {
                HStack(spacing: 8) {
                    Image(systemName: statusIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(statusIsSuccess ? .green : .orange)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(12)
                .background(Color(white: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
    
    private var offlineQueueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("File d'attente hors-ligne", systemImage: "tray.full.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(exportManager.pendingQueue.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(exportManager.pendingQueue.isEmpty ? .secondary : .black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(exportManager.pendingQueue.isEmpty ? Color(white: 0.20) : Color.orange)
                    .clipShape(Capsule())
            }
            
            if exportManager.pendingQueue.isEmpty {
                Text("Aucune séance en attente d'envoi.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(exportManager.pendingQueue) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.titre)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                        
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let err = item.lastError {
                            Text(err)
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(white: 0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                HStack(spacing: 10) {
                    Button(action: renvoyerFile) {
                        HStack(spacing: 6) {
                            if isFlushing {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Renvoyer tout")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isFlushing || !exportManager.hasValidWebhookURL)
                    
                    Button(role: .destructive) {
                        exportManager.clearPendingQueue()
                    } label: {
                        Text("Vider")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
