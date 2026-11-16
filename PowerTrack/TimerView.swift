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
                Image(systemName: "timer")
                    .font(.headline)
                    .foregroundColor(couleurChrono)
                
                Text("Repos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(formatTime(timerManager.tempsEcoule))
                    .font(.headline.monospacedDigit())
                    .foregroundColor(couleurChrono)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    HapticAndSoundManager.shared.triggerLightImpact()
                    timerManager.ajouterTemps(30)
                }) {
                    Text("+30s")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    HapticAndSoundManager.shared.triggerLightImpact()
                    withAnimation(.snappy(duration: 0.25)) {
                        timerManager.stopTimer()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
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
            return .red
        } else if timerManager.minAlertDuration > 0 && timerManager.tempsEcoule >= timerManager.minAlertDuration {
            return .green
        } else {
            return .white
        }
    }
}
