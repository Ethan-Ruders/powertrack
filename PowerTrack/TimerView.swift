//
//  TimerView.swift
//  PowerTrack
//
//  Created by ethan ruders on 16/07/2026.
//

import SwiftUI

struct TimerView: View {
    @ObservedObject var timerManager: TimerManager
    
    var body: some View {
        if timerManager.state != .inactive {
            HStack(spacing: 12) {
                Circle()
                    .fill(couleurChrono)
                    .frame(width: 8, height: 8)
                
                Text(formatTime(timerManager.tempsEcoule))
                    .font(.system(size: 19, weight: .bold).monospacedDigit())
                    .foregroundColor(couleurChrono)
                    .lineLimit(1)
                
                Text("Repos")
                    .font(.caption.weight(.medium))
                    .foregroundColor(PTTheme.textSecondary)
                    .lineLimit(1)
                
                Spacer(minLength: 6)
                
                Button(action: {
                    HapticAndSoundManager.shared.triggerLightImpact()
                    timerManager.ajouterTemps(30)
                }) {
                    Text("+30s")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(PTTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(PTTheme.surface)
                        .overlay(
                            Capsule()
                                .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    HapticAndSoundManager.shared.triggerLightImpact()
                    withAnimation(.snappy(duration: 0.25)) {
                        timerManager.stopTimer()
                    }
                }) {
                    Text("Passer")
                        .font(.caption.weight(.bold))
                        .foregroundColor(PTTheme.bg)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(PTTheme.textPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.vertical, 9)
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
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var couleurChrono: Color {
        if timerManager.maxAlertDuration > 0 && timerManager.tempsEcoule >= timerManager.maxAlertDuration {
            return PTTheme.danger
        } else if timerManager.minAlertDuration > 0 && timerManager.tempsEcoule >= timerManager.minAlertDuration {
            return PTTheme.success
        } else {
            return PTTheme.textPrimary
        }
    }
}
