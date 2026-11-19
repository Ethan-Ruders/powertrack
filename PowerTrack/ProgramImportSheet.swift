//
//  ProgramImportSheet.swift
//  PowerTrack
//
//  Created by PowerTrack on 17/11/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

/// Modale permettant de coller ou d'importer un fichier JSON de programme généré par le Coach.
struct ProgramImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var jsonInput = ""
    @State private var blocNameOverride = ""
    @State private var preview: ProgramImportPreview? = nil
    @State private var errorMessage: String? = nil
    @State private var isPickingFile = false
    
    var onImported: ((MacroBloc) -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    sourceActionsSection
                    jsonEditorSection
                    
                    if let error = errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(PTTheme.danger)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(PTTheme.textPrimary)
                            Spacer()
                        }
                        .padding(12)
                        .background(PTTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PTTheme.danger.opacity(0.4), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.horizontal, 16)
                    }
                    
                    if let parsed = preview {
                        previewSection(parsed)
                    }
                }
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle("Importer un Bloc JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(PTTheme.textSecondary)
                }
            }
            .fileImporter(
                isPresented: $isPickingFile,
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                chargerFichierJSON(result)
            }
        }
    }
    
    // MARK: - Sections UI
    
    private var sourceActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PTKicker(text: "Source du programme")
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("Colle le programme JSON généré par ton coach ou importe un fichier .json.")
                        .font(.caption)
                        .foregroundColor(PTTheme.textSecondary)
                    
                    HStack(spacing: 10) {
                        Button(action: collerPressePapier) {
                            Label("Coller", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PTPrimaryPillButtonStyle())
                        
                        Button {
                            isPickingFile = true
                        } label: {
                            Label("Fichier .json", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PTSecondaryPillButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                PTHairline()
            }
        }
    }
    
    private var jsonEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PTKicker(text: "Contenu JSON")
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                TextEditor(text: $jsonInput)
                    .scrollContentBackground(.hidden)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(PTTheme.textPrimary)
                    .frame(minHeight: 160, maxHeight: 240)
                    .padding(10)
                    .background(PTTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PTTheme.hairline, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .onChange(of: jsonInput) { _, _ in
                        analyserJSON()
                    }
                
                PTHairline()
            }
        }
    }
    
    private func previewSection(_ parsed: ProgramImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(PTTheme.success)
                    .frame(width: 6, height: 6)
                PTKicker(text: "Aperçu prêt à injecter", color: PTTheme.success)
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PTHairline()
                
                TextField("Nom du bloc", text: $blocNameOverride)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(PTTheme.textPrimary)
                    .padding(11)
                    .background(PTTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PTTheme.hairline, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                
                PTHairline()
                
                HStack(spacing: 0) {
                    statColumn(label: "Semaines", value: "\(parsed.weekCount)")
                    verticalHairline
                    statColumn(label: "Séances", value: "\(parsed.sessionCount)")
                    verticalHairline
                    statColumn(label: "Séries", value: "\(parsed.totalSets)")
                }
                
                if parsed.squat1RM > 0 || parsed.bench1RM > 0 || parsed.deadlift1RM > 0 {
                    PTHairline()
                    Text("1RM réf · S \(Int(parsed.squat1RM)) kg · B \(Int(parsed.bench1RM)) kg · D \(Int(parsed.deadlift1RM)) kg")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(PTTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                }
                
                PTHairline()
            }
            
            Button {
                injecter(parsed)
            } label: {
                Text("Injecter dans PowerTrack")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PTPrimaryPillButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }
    
    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            PTKicker(text: label)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(PTTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var verticalHairline: some View {
        Rectangle()
            .fill(PTTheme.hairline)
            .frame(width: 0.5)
    }
    
    // MARK: - Actions
    
    private func collerPressePapier() {
        if let text = UIPasteboard.general.string {
            jsonInput = text
            analyserJSON()
        }
    }
    
    private func chargerFichierJSON(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
            }
            do {
                jsonInput = try String(contentsOf: url, encoding: .utf8)
                analyserJSON()
            } catch {
                errorMessage = "Impossible de lire le fichier : \(error.localizedDescription)"
                preview = nil
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func analyserJSON() {
        let trimmed = jsonInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            preview = nil
            errorMessage = nil
            return
        }
        do {
            let parsed = try ProgramJSONImporter.parse(jsonString: trimmed)
            preview = parsed
            blocNameOverride = parsed.blocName
            errorMessage = nil
        } catch {
            preview = nil
            errorMessage = "JSON invalide : \(error.localizedDescription)"
        }
    }
    
    private func injecter(_ parsed: ProgramImportPreview) {
        do {
            let bloc = try ProgramJSONImporter.injecter(
                preview: parsed,
                into: modelContext,
                overrideBlocName: blocNameOverride
            )
            HapticAndSoundManager.shared.triggerPRValidated()
            onImported?(bloc)
            dismiss()
        } catch {
            errorMessage = "Erreur SwiftData : \(error.localizedDescription)"
        }
    }
}
