//
//  PowerTrackWidgetsLiveActivity.swift
//  PowerTrackWidgets
//
//  Created by ethan ruders on 17/09/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Modèle d'Attributs de l'Activité (partagé)

public struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var nomExercice: String
        public var numeroSerie: Int
        public var dateDebutRepos: Date
        public var dateFinRepos: Date
        public var dureeTotale: TimeInterval
        
        public init(
            nomExercice: String,
            numeroSerie: Int,
            dateDebutRepos: Date,
            dateFinRepos: Date,
            dureeTotale: TimeInterval
        ) {
            self.nomExercice = nomExercice
            self.numeroSerie = numeroSerie
            self.dateDebutRepos = dateDebutRepos
            self.dateFinRepos = dateFinRepos
            self.dureeTotale = dureeTotale
        }
    }
    
    public var nomSeance: String
    
    public init(nomSeance: String = "Séance PowerTrack") {
        self.nomSeance = nomSeance
    }
}

// MARK: - AppIntents Interactifs Écran Verrouillé

struct WidgetAjouterTempsIntent: AppIntent {
    static var title: LocalizedStringResource = "+30s de repos"
    static var description = IntentDescription("Ajoute 30 secondes au compte à rebours de repos sur la Live Activity.")
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        for activity in Activity<RestTimerAttributes>.activities {
            let currentState = activity.content.state
            let nouvelleDateFin = currentState.dateFinRepos.addingTimeInterval(30)
            let updatedState = RestTimerAttributes.ContentState(
                nomExercice: currentState.nomExercice,
                numeroSerie: currentState.numeroSerie,
                dateDebutRepos: currentState.dateDebutRepos,
                dateFinRepos: nouvelleDateFin,
                dureeTotale: nouvelleDateFin.timeIntervalSince(currentState.dateDebutRepos)
            )
            await activity.update(.init(state: updatedState, staleDate: nouvelleDateFin))
        }
        return .result()
    }
}

struct WidgetPasserReposIntent: AppIntent {
    static var title: LocalizedStringResource = "Passer le repos"
    static var description = IntentDescription("Termine immédiatement le repos et clôture la Live Activity.")
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        for activity in Activity<RestTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}

// MARK: - Widget Live Activity Dédié

public struct RestTimerLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Interface Écran Verrouillé & Centre de notifications
            RestTimerLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.nomExercice, systemImage: "figure.strengthtraining.traditional")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.dateFinRepos, pauseTime: nil, countsDown: true)
                        .font(.title2.monospacedDigit())
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(timerInterval: Date()...context.state.dateFinRepos)
                            .tint(.orange)
                        
                        HStack {
                            Button(intent: WidgetAjouterTempsIntent()) {
                                Label("+30s", systemImage: "goforward.30")
                                    .font(.caption2.bold())
                            }
                            .tint(.orange)
                            
                            Spacer()
                            
                            Button(intent: WidgetPasserReposIntent()) {
                                Label("Passer", systemImage: "xmark")
                                    .font(.caption2.bold())
                            }
                            .tint(.gray)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.dateFinRepos, pauseTime: nil, countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(.orange)
                    .frame(width: 45)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Vue Écran Verrouillé Dédiée (RestTimerLiveActivityView)

public struct RestTimerLiveActivityView: View {
    public let state: RestTimerAttributes.ContentState
    
    public init(state: RestTimerAttributes.ContentState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 1. En-tête : Exercice, Série & Décompte temps réel
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 38, height: 38)
                        Image(systemName: "timer")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.nomExercice)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("Série \(state.numeroSerie) validée • Temps de repos")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Compte à rebours dynamique natif Apple (décompte fluide continu sans surcoût batterie)
                Text(timerInterval: Date()...state.dateFinRepos, pauseTime: nil, countsDown: true)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }
            
            // 2. Barre de progression visuelle continue
            ProgressView(timerInterval: Date()...state.dateFinRepos)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(x: 1, y: 1.6, anchor: .center)
                .clipShape(Capsule())
            
            // 3. Pied avec boutons interactifs AppIntents
            HStack(spacing: 12) {
                Text("Fin : \(state.dateFinRepos.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Bouton interactif +30s
                Button(intent: WidgetAjouterTempsIntent()) {
                    Label("+30s", systemImage: "goforward.30")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Bouton interactif Passer
                Button(intent: WidgetPasserReposIntent()) {
                    Label("Passer", systemImage: "xmark")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(UIColor.systemBackground).opacity(0.2))
        .preferredColorScheme(.dark)
    }
}
