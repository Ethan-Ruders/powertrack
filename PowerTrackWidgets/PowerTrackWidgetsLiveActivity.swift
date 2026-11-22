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

// MARK: - Palette Locale Widget (Flighty / Swiss Editorial)

private enum PTWidgetPalette {
    static let bg = Color(red: 0.035, green: 0.035, blue: 0.043)         // #09090B
    static let surfacePill = Color(red: 0.094, green: 0.094, blue: 0.110) // #18181C
    static let hairline = Color.white.opacity(0.12)
    static let chalkWhite = Color(red: 0.961, green: 0.961, blue: 0.969)  // #F5F5F7
    static let copper = Color(red: 0.871, green: 0.478, blue: 0.259)      // #DE7A42
    static let muted = Color(red: 0.541, green: 0.541, blue: 0.580)       // #8A8A94
}

// MARK: - Widget Live Activity Dédié

public struct RestTimerLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Interface Écran Verrouillé & Centre de notifications
            RestTimerLiveActivityView(state: context.state)
                .activityBackgroundTint(PTWidgetPalette.bg.opacity(0.92))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REPOS · SÉRIE \(context.state.numeroSerie)")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.9)
                            .foregroundColor(PTWidgetPalette.copper)
                        Text(context.state.nomExercice)
                            .font(.caption.weight(.bold))
                            .foregroundColor(PTWidgetPalette.chalkWhite)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.timerRange, pauseTime: nil, countsDown: true)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundColor(PTWidgetPalette.chalkWhite)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        ProgressView(timerInterval: context.state.timerRange, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(PTWidgetPalette.copper)
                        
                        HStack {
                            Button(intent: AjouterTempsIntent()) {
                                Label("+30s", systemImage: "goforward.30")
                                    .font(.caption2.weight(.bold))
                            }
                            .tint(PTWidgetPalette.copper)
                            
                            Spacer()
                            
                            Button(intent: PasserReposIntent()) {
                                Text("Passer")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(PTWidgetPalette.bg)
                            }
                            .tint(PTWidgetPalette.chalkWhite)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(PTWidgetPalette.copper)
            } compactTrailing: {
                Text(timerInterval: context.state.timerRange, pauseTime: nil, countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(PTWidgetPalette.chalkWhite)
                    .frame(width: 45)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(PTWidgetPalette.copper)
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
            // 1. En-tête : Sur-titre télémétrie, exercice & décompte temps réel
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(PTWidgetPalette.copper)
                            .frame(width: 6, height: 6)
                        
                        Text("REPOS · SÉRIE \(state.numeroSerie)")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.0)
                            .foregroundColor(PTWidgetPalette.copper)
                    }
                    
                    Text(state.nomExercice)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(PTWidgetPalette.chalkWhite)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Compte à rebours dynamique natif Apple (décompte fluide continu)
                Text(timerInterval: state.timerRange, pauseTime: nil, countsDown: true)
                    .font(.system(size: 32, weight: .bold).monospacedDigit())
                    .foregroundColor(PTWidgetPalette.chalkWhite)
            }
            
            // 2. Barre de progression cuivre ultra-fine
            ProgressView(timerInterval: state.timerRange, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(LinearProgressViewStyle(tint: PTWidgetPalette.copper))
            .clipShape(Capsule())
            
            // 3. Pied avec actions LiveActivityIntent style Flighty
            HStack(spacing: 10) {
                Text("FIN · \(state.dateFinRepos.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .tracking(0.8)
                    .foregroundColor(PTWidgetPalette.muted)
                
                Spacer()
                
                Button(intent: AjouterTempsIntent()) {
                    Label("+30s", systemImage: "goforward.30")
                        .font(.caption.weight(.bold))
                        .foregroundColor(PTWidgetPalette.copper)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(PTWidgetPalette.surfacePill)
                        .overlay(
                            Capsule()
                                .stroke(PTWidgetPalette.hairline, lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: PasserReposIntent()) {
                    Text("Passer")
                        .font(.caption.weight(.bold))
                        .foregroundColor(PTWidgetPalette.bg)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(PTWidgetPalette.chalkWhite)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(PTWidgetPalette.bg)
        .preferredColorScheme(.dark)
    }
}
