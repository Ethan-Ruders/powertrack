//
//  BlocListView.swift
//  PowerTrack
//
//  Created by ethan ruders on 11/07/2026.
//

import SwiftUI
import SwiftData

struct BlocListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \MacroBloc.dateDebut, order: .reverse) private var blocs: [MacroBloc]
    @ObservedObject private var progressTracker = SeanceProgressTracker.shared
    @ObservedObject private var exportManager = ExportManager.shared
    
    @State private var isShowingInitView = false
    @State private var isShowingProgramImport = false
    @State private var isShowingExportSettings = false
    @State private var isShowingRankLadder = false
    @State private var messageConfirmation: String? = nil
    @State private var showingConfirmationAlert = false
    
    private var globalRankSnapshot: RankSnapshot {
        RankCalculator.snapshot(from: blocs, bodyweightKg: exportManager.lastBodyweightKg, competitionOnly: true)
    }
    
    private var seanceEnCours: Seance? {
        _ = progressTracker.lastUpdateToken
        return progressTracker.findActiveSeance(in: blocs)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if blocs.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 0) {
                        PTHairline()
                        
                        ForEach(blocs) { bloc in
                            NavigationLink(destination: SemaineListView(macroBloc: bloc)) {
                                blocRow(for: bloc)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    supprimerBloc(bloc)
                                } label: {
                                    Label("Supprimer le bloc", systemImage: "trash")
                                }
                            }
                            
                            PTHairline(leadingInset: 20)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .ptAppBackground()
            .navigationTitle("Programmation")
            .safeAreaInset(edge: .bottom) {
                PTBottomOverlayStack(activeSeance: seanceEnCours)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { isShowingExportSettings = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "server.rack")
                                .font(.body)
                                .foregroundColor(PTTheme.textSecondary)
                            
                            if !exportManager.pendingQueue.isEmpty {
                                Circle()
                                    .fill(PTTheme.danger)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 3, y: -3)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        Button {
                            HapticAndSoundManager.shared.triggerLightImpact()
                            isShowingRankLadder = true
                        } label: {
                            if let primary = globalRankSnapshot.primaryDisplay {
                                HStack(spacing: 6) {
                                    PTRankBadgeView(grade: primary.rank.grade, tier: primary.rank.tier, size: 22, showPips: false, animateMythicAura: false)
                                    Text(primary.rank.displayName)
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(PTTheme.textPrimary)
                                    PTFFForceTagPill(grade: primary.rank.grade)
                                }
                                .padding(.leading, 6)
                                .padding(.trailing, 6)
                                .padding(.vertical, 3)
                                .background(PTTheme.surfaceElevated)
                                .overlay(
                                    Capsule()
                                        .stroke(primary.rank.grade.accentColor.opacity(0.4), lineWidth: 0.5)
                                )
                                .clipShape(Capsule())
                            } else {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.body)
                                    .foregroundColor(PTTheme.textSecondary)
                            }
                        }
                        .accessibilityLabel("Classement et Rangs")
                        
                        Menu {
                            Button(action: { isShowingInitView = true }) {
                                Label("Nouveau Bloc Personnalisé", systemImage: "plus")
                            }
                            
                            Button(action: { isShowingProgramImport = true }) {
                                Label("Importer un Bloc JSON (Coach)", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundColor(PTTheme.textPrimary)
                        }
                    }
                }
            }
            .onAppear {
                RankStateManager.shared.syncBaselineIfNeeded(from: globalRankSnapshot)
            }
            .sheet(isPresented: $isShowingInitView) {
                BlocInitView()
            }
            .sheet(isPresented: $isShowingProgramImport) {
                ProgramImportSheet { bloc in
                    messageConfirmation = "Le bloc '\(bloc.nom)' a été importé avec succès."
                    showingConfirmationAlert = true
                }
            }
            .sheet(isPresented: $isShowingExportSettings) {
                ExportSettingsView()
            }
            .sheet(isPresented: $isShowingRankLadder) {
                RankLadderSheetView(snapshot: globalRankSnapshot)
            }
            .alert("Programmation", isPresented: $showingConfirmationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(messageConfirmation ?? "")
            }
        }
    }
    
    // MARK: - Sous-vues Éditoriales
    
    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                PTKicker(text: "Programmation", color: PTTheme.accent)
                
                Text("Aucun bloc actif")
                    .font(.title2.weight(.bold))
                    .foregroundColor(PTTheme.textPrimary)
                
                Text("Crée un cycle sur 4 ou 5 semaines ou importe un programme JSON généré par ton coach.")
                    .font(.subheadline)
                    .foregroundColor(PTTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 10) {
                Button(action: { isShowingInitView = true }) {
                    Text("Nouveau bloc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PTPrimaryPillButtonStyle())
                
                Button(action: { isShowingProgramImport = true }) {
                    Text("Importer un bloc JSON")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PTSecondaryPillButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 48)
    }
    
    private func blocRow(for bloc: MacroBloc) -> some View {
        let ratio = bloc.progressionRatio
        let total = bloc.totalSeriesCount
        let pct = Int(round(ratio * 100.0))
        let isCompleted = total > 0 && ratio >= 1.0
        let isActive = ratio > 0 && !isCompleted
        
        let statusText: String
        let statusColor: Color
        if isCompleted {
            statusText = "Terminé · \(bloc.semaines.count) sem"
            statusColor = PTTheme.success
        } else if isActive, let semNum = bloc.activeSemaineNumero {
            statusText = "En cours · S\(semNum)/\(max(1, bloc.semaines.count))"
            statusColor = PTTheme.accent
        } else {
            statusText = "\(bloc.semaines.count) semaines"
            statusColor = PTTheme.textSecondary
        }
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    PTKicker(text: statusText, color: statusColor)
                    
                    Text(bloc.nom)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(PTTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    if let refLine = referenceMaxLine(for: bloc) {
                        Text(refLine)
                            .font(.caption.monospacedDigit())
                            .foregroundColor(PTTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 8)
                
                HStack(spacing: 8) {
                    Text("\(pct)%")
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundColor(isCompleted ? PTTheme.success : PTTheme.textPrimary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(PTTheme.textTertiary)
                }
            }
            
            PTProgressHairline(
                ratio: ratio,
                color: isCompleted ? PTTheme.success : PTTheme.accent
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
    
    private func referenceMaxLine(for bloc: MacroBloc) -> String? {
        var parts: [String] = []
        if bloc.squat1RM > 0 { parts.append("S \(PTFormat.weight(bloc.squat1RM))") }
        if bloc.bench1RM > 0 { parts.append("B \(PTFormat.weight(bloc.bench1RM))") }
        if bloc.deadlift1RM > 0 { parts.append("D \(PTFormat.weight(bloc.deadlift1RM))") }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ") + " kg"
    }
    
    // MARK: - Actions SwiftData
    
    private func supprimerBloc(_ bloc: MacroBloc) {
        HapticAndSoundManager.shared.triggerLightImpact()
        modelContext.delete(bloc)
        try? modelContext.save()
    }
}

// MARK: - Bannière Flottante Style Flighty (Reprise de Séance)

struct ResumeWorkoutBannerView: View {
    let seance: Seance
    
    private var nomSeance: String {
        seance.titre ?? seance.date.formatted(date: .abbreviated, time: .omitted)
    }
    
    private var pourcentage: Int {
        Int(round(seance.progressionRatio * 100.0))
    }
    
    var body: some View {
        NavigationLink(destination: SeanceDetailView(seance: seance)) {
            HStack(spacing: 12) {
                Circle()
                    .fill(PTTheme.accent)
                    .frame(width: 7, height: 7)
                
                VStack(alignment: .leading, spacing: 2) {
                    PTKicker(text: "Séance en cours", color: PTTheme.accent)
                    
                    Text("\(nomSeance) · \(seance.validatedSeriesCount)/\(seance.totalSeriesCount) (\(pourcentage)%)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(PTTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                
                Spacer(minLength: 6)
                
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(PTTheme.bg)
                    .frame(width: 28, height: 28)
                    .background(PTTheme.textPrimary)
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .background(PTTheme.surfaceElevated)
            .overlay(
                Capsule()
                    .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
            )
            .clipShape(Capsule())
            .shadow(color: PTTheme.floatingShadow, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                HapticAndSoundManager.shared.triggerLightImpact()
            }
        )
    }
}
