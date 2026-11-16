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
    
    @Query(sort: \MacroBloc.nom) private var blocs: [MacroBloc]
    @ObservedObject private var progressTracker = SeanceProgressTracker.shared
    
    @State private var isShowingInitView = false
    @State private var messageConfirmation: String? = nil
    @State private var showingConfirmationAlert = false
    
    private var seanceEnCours: Seance? {
        _ = progressTracker.lastUpdateToken
        return progressTracker.findActiveSeance(in: blocs)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if blocs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("Aucun bloc de programmation")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Créez un bloc personnalisé ou injectez le programme Peak Force & PR.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: injecterBlocPredefini) {
                                Text("Injecter Peak Force & PR (S5-S8)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 20)
                    } else {
                        ForEach(blocs) { bloc in
                            NavigationLink(destination: SemaineListView(macroBloc: bloc)) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bloc.nom)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                        
                                        Text("\(bloc.semaines.count) semaines")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(.orange)
                                }
                                .padding(16)
                                .background(Color(white: 0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    supprimerBloc(bloc)
                                } label: {
                                    Label("Supprimer le bloc", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Mes Blocs")
            .safeAreaInset(edge: .bottom) {
                if let seanceActive = seanceEnCours {
                    ResumeWorkoutBannerView(seance: seanceActive)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { isShowingInitView = true }) {
                            Label("Nouveau Bloc Personnalisé", systemImage: "plus")
                        }
                        
                        Button(action: injecterBlocPredefini) {
                            Label("Injecter Peak Force & PR (S5-S8)", systemImage: "bolt.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $isShowingInitView) {
                BlocInitView()
            }
            .alert("Programmation", isPresented: $showingConfirmationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(messageConfirmation ?? "")
            }
        }
    }
    
    // MARK: - Actions SwiftData
    
    private func supprimerBloc(_ bloc: MacroBloc) {
        HapticAndSoundManager.shared.triggerLightImpact()
        modelContext.delete(bloc)
        try? modelContext.save()
    }
    
    private func injecterBlocPredefini() {
        do {
            let bloc = try PeakForceProgramInjector.injecterBlocPeakForce(into: modelContext)
            HapticAndSoundManager.shared.triggerSetValidated()
            messageConfirmation = "Le bloc '\(bloc.nom)' a été injecté avec succès."
            showingConfirmationAlert = true
        } catch {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            messageConfirmation = "Erreur : \(error.localizedDescription)"
            showingConfirmationAlert = true
        }
    }
}

// MARK: - Bannière Sobre de Reprise Rapide de Séance

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
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reprendre la séance en cours")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(nomSeance) • \(seance.validatedSeriesCount)/\(seance.totalSeriesCount) séries (\(pourcentage)%)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(white: 0.15))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                HapticAndSoundManager.shared.triggerLightImpact()
            }
        )
    }
}
