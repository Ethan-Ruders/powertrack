//
//  ExportSettingsView.swift
//  PowerTrack
//
//  Created by PowerTrack on 17/11/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Écran de configuration du webhook n8n (Serveur Linux), file hors-ligne et sauvegarde complète locale.
struct ExportSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var exportManager = ExportManager.shared
    @AppStorage("pt_appearance_mode") private var appearanceModeRaw: String = PTAppearanceMode.system.rawValue
    
    @State private var isTesting = false
    @State private var isFlushing = false
    @State private var statusMessage: String? = nil
    @State private var statusIsSuccess = false
    
    // Sauvegarde / Restauration locale complète (.json)
    @State private var backupDocument = PowerTrackJSONDocument()
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var pendingBackupToRestore: PowerTrackBackupDTO? = nil
    @State private var showingRestoreConfirm = false
    @State private var backupFeedbackMessage: String? = nil
    @State private var backupFeedbackIsSuccess = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    appearanceSection
                    webhookSection
                    authSection
                    testAndStatusSection
                    offlineQueueSection
                    localBackupSection
                }
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle("Réglages & Export")
            .navigationBarTitleDisplayMode(.inline)
            .ptAppearance()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(PTTheme.textSecondary)
                }
            }
            .fileExporter(
                isPresented: $isExportingBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: nomFichierSauvegarde()
            ) { result in
                switch result {
                case .success:
                    HapticAndSoundManager.shared.triggerSetValidated()
                    backupFeedbackIsSuccess = true
                    backupFeedbackMessage = "Sauvegarde complète exportée avec succès."
                case .failure(let error):
                    backupFeedbackIsSuccess = false
                    backupFeedbackMessage = "Échec export sauvegarde : \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $isImportingBackup,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                chargerSauvegardePourRestauration(result)
            }
            .confirmationDialog(
                "Restaurer la sauvegarde ?",
                isPresented: $showingRestoreConfirm,
                titleVisibility: .visible
            ) {
                Button("Ajouter aux blocs existants") {
                    executerRestauration(replaceExisting: false)
                }
                Button("Remplacer tous les blocs existants", role: .destructive) {
                    executerRestauration(replaceExisting: true)
                }
                Button("Annuler", role: .cancel) {
                    pendingBackupToRestore = nil
                }
            } message: {
                if let dto = pendingBackupToRestore {
                    let totalSeances = dto.blocs.reduce(0) { t, b in
                        t + b.semaines.reduce(0) { $0 + $1.seances.count }
                    }
                    Text("\(dto.blocs.count) bloc(s) · \(totalSeances) séance(s) · \(dto.ressentis.count) ressenti(s). Choisis si tu veux fusionner ou remplacer tes données locales.")
                }
            }
        }
    }
    
    // MARK: - Sections Éditoriales
    
    private var appearanceSection: some View {
        let selectedMode = PTAppearanceMode(rawValue: appearanceModeRaw) ?? .system
        
        return VStack(alignment: .leading, spacing: 10) {
            PTKicker(text: "Apparence")
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Suit automatiquement le mode jour / nuit de l'iPhone par défaut.")
                        .font(.caption)
                        .foregroundColor(PTTheme.textSecondary)
                    
                    HStack(spacing: 8) {
                        ForEach(PTAppearanceMode.allCases) { mode in
                            let isSelected = (mode == selectedMode)
                            Button {
                                HapticAndSoundManager.shared.triggerSelection()
                                appearanceModeRaw = mode.rawValue
                            } label: {
                                Text(mode.label)
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? PTTheme.bg : PTTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                PTHairline()
            }
        }
    }
    
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
            PTKicker(text: "Authentification (Trousseau iOS)")
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("En-tête HTTP vérifié par ton webhook n8n. La clé secrète est chiffrée dans le Trousseau iOS.")
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
                statusBanner(message: message, isSuccess: statusIsSuccess)
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
                    Text("Aucune séance en attente. La file se vide automatiquement dès le retour réseau.")
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
    
    private var localBackupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PTKicker(text: "Sauvegarde complète locale (SideStore)")
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exporte tous tes blocs, séries validées et ressentis dans un fichier .json avant une réinstallation.")
                        .font(.caption)
                        .foregroundColor(PTTheme.textSecondary)
                    
                    HStack(spacing: 10) {
                        Button(action: preparerExportSauvegarde) {
                            HStack(spacing: 6) {
                                Image(systemName: "externaldrive.badge.plus")
                                Text("Exporter (.json)")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PTPrimaryPillButtonStyle())
                        
                        Button {
                            isImportingBackup = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc")
                                Text("Restaurer")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PTSecondaryPillButtonStyle())
                    }
                    
                    if let backupMsg = backupFeedbackMessage {
                        statusBanner(message: backupMsg, isSuccess: backupFeedbackIsSuccess)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                PTHairline()
            }
        }
    }
    
    private func statusBanner(message: String, isSuccess: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSuccess ? PTTheme.success : PTTheme.accent)
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
    
    // MARK: - Actions Réseau & Sauvegarde
    
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
    
    private func preparerExportSauvegarde() {
        do {
            let data = try BackupManager.exportBackupJSON(from: modelContext)
            backupDocument = PowerTrackJSONDocument(data: data)
            isExportingBackup = true
        } catch {
            backupFeedbackIsSuccess = false
            backupFeedbackMessage = "Impossible de générer la sauvegarde : \(error.localizedDescription)"
        }
    }
    
    private func chargerSauvegardePourRestauration(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                let parsed = try BackupManager.parseBackup(from: data)
                pendingBackupToRestore = parsed
                showingRestoreConfirm = true
            } catch {
                backupFeedbackIsSuccess = false
                backupFeedbackMessage = "Fichier de sauvegarde invalide : \(error.localizedDescription)"
            }
        case .failure(let error):
            backupFeedbackIsSuccess = false
            backupFeedbackMessage = error.localizedDescription
        }
    }
    
    private func executerRestauration(replaceExisting: Bool) {
        guard let backup = pendingBackupToRestore else { return }
        pendingBackupToRestore = nil
        do {
            let summary = try BackupManager.restoreBackup(backup, into: modelContext, replaceExisting: replaceExisting)
            HapticAndSoundManager.shared.triggerPRValidated()
            backupFeedbackIsSuccess = true
            backupFeedbackMessage = "Restauré : \(summary.blocsRestored) bloc(s), \(summary.seancesRestored) séance(s), \(summary.seriesValideesRestored) série(s) validée(s)."
        } catch {
            backupFeedbackIsSuccess = false
            backupFeedbackMessage = "Erreur restauration : \(error.localizedDescription)"
        }
    }
    
    private func nomFichierSauvegarde() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "powertrack-backup-\(formatter.string(from: Date()))"
    }
}
