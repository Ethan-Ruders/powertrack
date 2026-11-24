//
//  TimerView.swift
//  PowerTrack
//
//  Created by ethan ruders on 16/07/2026.
//

import SwiftUI

struct TimerView: View {
    @ObservedObject var timerManager: TimerManager
    
    private var peutRetirerTemps: Bool {
        timerManager.tempsRestantMax > 0
    }
    
    var body: some View {
        if timerManager.state != .inactive {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(couleurChrono)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(formatTime(timerManager.tempsRestantMax))
                            .font(.system(size: 18, weight: .bold).monospacedDigit())
                            .foregroundColor(couleurChrono)
                            .lineLimit(1)
                        
                        Text(labelStatut)
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundColor(couleurStatut)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 6)
                
                HStack(spacing: 6) {
                    Button(action: {
                        HapticAndSoundManager.shared.triggerLightImpact()
                        timerManager.retirerTemps(30)
                    }) {
                        Text("-30s")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundColor(PTTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(PTTheme.surface)
                            .overlay(
                                Capsule()
                                    .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!peutRetirerTemps)
                    .opacity(peutRetirerTemps ? 1.0 : 0.4)
                    .accessibilityLabel("Retirer 30 secondes")
                    
                    Button(action: {
                        HapticAndSoundManager.shared.triggerLightImpact()
                        timerManager.ajouterTemps(30)
                    }) {
                        Text("+30s")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundColor(PTTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(PTTheme.surface)
                            .overlay(
                                Capsule()
                                    .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ajouter 30 secondes")
                    
                    Button(action: {
                        HapticAndSoundManager.shared.triggerLightImpact()
                        withAnimation(.snappy(duration: 0.25)) {
                            timerManager.stopTimer()
                        }
                    }) {
                        Text("Passer")
                            .font(.caption.weight(.bold))
                            .foregroundColor(PTTheme.bg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(PTTheme.textPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Passer le repos")
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .background(PTTheme.surfaceElevated)
            .overlay(
                Capsule()
                    .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(ceil(max(0, interval)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var labelStatut: String {
        if timerManager.tempsRestantMax <= 0 {
            return "Terminé"
        } else if timerManager.minAlertDuration > 0 && timerManager.tempsRestantMin <= 0 {
            return "Prêt"
        } else if timerManager.minAlertDuration > 0 && timerManager.minAlertDuration < timerManager.maxAlertDuration {
            return "Min \(formatTime(timerManager.tempsRestantMin))"
        } else {
            return "Repos"
        }
    }
    
    private var couleurStatut: Color {
        if timerManager.tempsRestantMax <= 0 {
            return PTTheme.danger
        } else if timerManager.minAlertDuration > 0 && timerManager.tempsRestantMin <= 0 {
            return PTTheme.success
        } else {
            return PTTheme.textSecondary
        }
    }
    
    private var couleurChrono: Color {
        if timerManager.tempsRestantMax <= 0 {
            return PTTheme.danger
        } else if timerManager.minAlertDuration > 0 && timerManager.tempsRestantMin <= 0 {
            return PTTheme.success
        } else {
            return PTTheme.textPrimary
        }
    }
}

/// Pile globale de bannières inférieures (Chrono de repos + Reprise de séance), affichable sur tous les écrans.
struct PTBottomOverlayStack: View {
    var activeSeance: Seance? = nil
    @ObservedObject private var timerManager = TimerManager.shared
    
    var body: some View {
        if timerManager.state != .inactive || activeSeance != nil {
            VStack(spacing: 0) {
                if timerManager.state != .inactive {
                    TimerView(timerManager: timerManager)
                }
                if let seance = activeSeance {
                    ResumeWorkoutBannerView(seance: seance)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}
