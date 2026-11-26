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
import UIKit

// MARK: - Palette Locale Widget (Flighty / Swiss Editorial — Jour & Nuit)

private enum PTWidgetPalette {
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
    
    // Tokens adaptatifs pour l'écran verrouillé / centre de notifications
    static let bg = dynamic(
        light: UIColor(red: 0.980, green: 0.980, blue: 0.984, alpha: 1.0),
        dark: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1.0)
    )
    static let surfacePill = dynamic(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.0),
        dark: UIColor(red: 0.094, green: 0.094, blue: 0.110, alpha: 1.0)
    )
    static let hairline = dynamic(
        light: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 0.14),
        dark: UIColor(white: 1.0, alpha: 0.12)
    )
    static let textPrimary = dynamic(
        light: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1.0),
        dark: UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
    )
    static let copper = dynamic(
        light: UIColor(red: 0.776, green: 0.384, blue: 0.165, alpha: 1.0),
        dark: UIColor(red: 0.871, green: 0.478, blue: 0.259, alpha: 1.0)
    )
    static let muted = dynamic(
        light: UIColor(red: 0.369, green: 0.369, blue: 0.408, alpha: 1.0),
        dark: UIColor(red: 0.541, green: 0.541, blue: 0.580, alpha: 1.0)
    )
    
    // Tokens fixes pour la Dynamic Island (toujours sur fond matériel noir)
    static let islandBg = Color(red: 0.035, green: 0.035, blue: 0.043)
    static let islandText = Color(red: 0.961, green: 0.961, blue: 0.969)
    static let islandCopper = Color(red: 0.871, green: 0.478, blue: 0.259)
    static let islandMuted = Color(red: 0.541, green: 0.541, blue: 0.580)
}

// MARK: - Widget Live Activity Dédié

public struct RestTimerLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Interface Écran Verrouillé & Centre de notifications (suit automatiquement Jour / Nuit iOS)
            RestTimerLiveActivityView(state: context.state)
                .activityBackgroundTint(PTWidgetPalette.bg.opacity(0.94))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REPOS · SÉRIE \(context.state.numeroSerie)")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.9)
                            .foregroundColor(PTWidgetPalette.islandCopper)
                        Text(context.state.nomExercice)
                            .font(.caption.weight(.bold))
                            .foregroundColor(PTWidgetPalette.islandText)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.timerRange, pauseTime: nil, countsDown: true)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundColor(PTWidgetPalette.islandText)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        ProgressView(timerInterval: context.state.timerRange, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(PTWidgetPalette.islandCopper)
                        
                        HStack(spacing: 8) {
                            Button(intent: RetirerTempsIntent()) {
                                Label("-30s", systemImage: "gobackward.30")
                                    .font(.caption2.weight(.bold))
                            }
                            .tint(PTWidgetPalette.islandMuted)
                            
                            Button(intent: AjouterTempsIntent()) {
                                Label("+30s", systemImage: "goforward.30")
                                    .font(.caption2.weight(.bold))
                            }
                            .tint(PTWidgetPalette.islandCopper)
                            
                            Spacer()
                            
                            Button(intent: PasserReposIntent()) {
                                Text("Passer")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(PTWidgetPalette.islandBg)
                            }
                            .tint(PTWidgetPalette.islandText)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(PTWidgetPalette.islandCopper)
            } compactTrailing: {
                Text(timerInterval: context.state.timerRange, pauseTime: nil, countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(PTWidgetPalette.islandText)
                    .frame(width: 45)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(PTWidgetPalette.islandCopper)
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
                        .foregroundColor(PTWidgetPalette.textPrimary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Compte à rebours dynamique natif Apple (décompte fluide continu)
                Text(timerInterval: state.timerRange, pauseTime: nil, countsDown: true)
                    .font(.system(size: 32, weight: .bold).monospacedDigit())
                    .foregroundColor(PTWidgetPalette.textPrimary)
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
            HStack(spacing: 8) {
                Text("FIN · \(state.dateFinRepos.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .tracking(0.8)
                    .foregroundColor(PTWidgetPalette.muted)
                    .lineLimit(1)
                
                Spacer()
                
                Button(intent: RetirerTempsIntent()) {
                    Label("-30s", systemImage: "gobackward.30")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .foregroundColor(PTWidgetPalette.textPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 11)
                        .background(PTWidgetPalette.surfacePill)
                        .overlay(
                            Capsule()
                                .stroke(PTWidgetPalette.hairline, lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: AjouterTempsIntent()) {
                    Label("+30s", systemImage: "goforward.30")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .foregroundColor(PTWidgetPalette.copper)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 11)
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
                        .lineLimit(1)
                        .foregroundColor(PTWidgetPalette.bg)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(PTWidgetPalette.textPrimary)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(PTWidgetPalette.bg)
    }
}
