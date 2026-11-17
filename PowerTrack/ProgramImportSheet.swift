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
                VStack(spacing: 18) {
                    sourceActionsCard
                    jsonEditorCard
                    
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(white: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    
                    if let parsed = preview {
                        previewCard(parsed)
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Importer un Bloc JSON")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
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
    
    // MARK: - Cartes UI
    
    private var sourceActionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Colle le programme JSON généré par ton coach ou importe un fichier `.json`.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                Button(action: collerPressePapier) {
                    Label("Coller", systemImage: "doc.on.clipboard")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button {
                    isPickingFile = true
                } label: {
                    Label("Fichier .json", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var jsonEditorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contenu JSON")
                .font(.headline)
                .foregroundColor(.white)
            
            TextEditor(text: $jsonInput)
                .scrollContentBackground(.hidden)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .frame(minHeight: 160, maxHeight: 240)
                .padding(8)
                .background(Color(white: 0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: jsonInput) { _, _ in
                    analyserJSON()
                }
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func previewCard(_ parsed: ProgramImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Aperçu prêt à injecter", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            TextField("Nom du bloc", text: $blocNameOverride)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(10)
                .background(Color(white: 0.17))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            HStack(spacing: 12) {
                statPill(label: "Semaines", value: "\(parsed.weekCount)")
                statPill(label: "Séances", value: "\(parsed.sessionCount)")
                statPill(label: "Séries", value: "\(parsed.totalSets)")
            }
            
            if parsed.squat1RM > 0 || parsed.bench1RM > 0 || parsed.deadlift1RM > 0 {
                Text("1RM réf : S \(Int(parsed.squat1RM)) kg • B \(Int(parsed.bench1RM)) kg • D \(Int(parsed.deadlift1RM)) kg")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            Button(action: { injecter(parsed) }) {
                Text("Injecter dans PowerTrack")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundColor(.orange)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(white: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
