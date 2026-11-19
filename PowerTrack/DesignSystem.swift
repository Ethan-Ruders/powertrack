//
//  DesignSystem.swift
//  PowerTrack
//
//  Created by PowerTrack on 19/11/2026.
//

import SwiftUI

// MARK: - Palette & Tokens Swiss Editorial / Flighty

enum PTTheme {
    static let bg = Color(red: 0.035, green: 0.035, blue: 0.043)              // #09090B
    static let surface = Color(red: 0.067, green: 0.067, blue: 0.078)         // #111114
    static let surfaceElevated = Color(red: 0.094, green: 0.094, blue: 0.110) // #18181C
    
    static let hairline = Color.white.opacity(0.09)
    static let hairlineStrong = Color.white.opacity(0.16)
    
    static let textPrimary = Color(red: 0.961, green: 0.961, blue: 0.969)     // #F5F5F7
    static let textSecondary = Color(red: 0.541, green: 0.541, blue: 0.580)   // #8A8A94
    static let textTertiary = Color(red: 0.369, green: 0.369, blue: 0.408)    // #5E5E68
    
    static let accent = Color(red: 0.871, green: 0.478, blue: 0.259)          // #DE7A42 (Cuivre mat)
    static let success = Color(red: 0.290, green: 0.871, blue: 0.502)         // #4ADE80
    static let danger = Color(red: 0.937, green: 0.267, blue: 0.267)          // #EF4444
}

// MARK: - Primitives Éditoriales Réutilisables

/// Filet séparateur fin de 0.5pt style éditorial.
struct PTHairline: View {
    var leadingInset: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(PTTheme.hairline)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

/// Sur-titre uppercase espacé pour hiérarchie de télémétrie.
struct PTKicker: View {
    let text: String
    var color: Color = PTTheme.textSecondary
    
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.1)
            .foregroundColor(color)
            .lineLimit(1)
    }
}

/// Barre de progression ultra-fine (2pt) sans boîte englobante.
struct PTProgressHairline: View {
    let ratio: Double
    var color: Color = PTTheme.accent
    
    private var clampedRatio: Double {
        min(1.0, max(0.0, ratio))
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(PTTheme.hairline)
                
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * clampedRatio)
                    .animation(.snappy(duration: 0.25), value: clampedRatio)
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Styles de Boutons Capsule

struct PTPrimaryPillButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundColor(PTTheme.bg)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(isDisabled ? PTTheme.textTertiary : PTTheme.textPrimary)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct PTSecondaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(PTTheme.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(PTTheme.surfaceElevated)
            .overlay(
                Capsule()
                    .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Formatage Numérique & Chargeur de Disques

enum PTFormat {
    static func weight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1.0) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    static func rpe(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1.0) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

enum PTBarbellPlateHelper {
    private static let availablePlates: [Double] = [20.0, 15.0, 10.0, 5.0, 2.5, 1.25]
    
    /// Calcule la répartition des disques par côté pour une barre olympique standard (20 kg).
    static func platesPerSide(totalKg: Double, barKg: Double = 20.0) -> [Double] {
        guard totalKg > barKg else { return [] }
        var remainingPerSide = (totalKg - barKg) / 2.0
        var plates: [Double] = []
        
        for plate in availablePlates {
            while remainingPerSide + 0.001 >= plate {
                plates.append(plate)
                remainingPerSide -= plate
            }
        }
        return plates
    }
    
    /// Retourne une chaîne concise des disques par côté (ex: "20 + 20 + 20 + 1.25 kg / côté").
    static func formattedPlatesPerSide(totalKg: Double, barKg: Double = 20.0) -> String? {
        let plates = platesPerSide(totalKg: totalKg, barKg: barKg)
        guard !plates.isEmpty else { return nil }
        let joined = plates.map { PTFormat.weight($0) }.joined(separator: " + ")
        return "\(joined) kg / côté"
    }
}
