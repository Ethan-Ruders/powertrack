//
//  DesignSystem.swift
//  PowerTrack
//
//  Created by PowerTrack on 19/11/2026.
//

import SwiftUI
import UIKit

// MARK: - Mode d'Apparence (Système / Jour / Nuit)

enum PTAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .system: return "Système"
        case .light: return "Jour"
        case .dark: return "Nuit"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct PTAppearanceModifier: ViewModifier {
    @AppStorage("pt_appearance_mode") private var modeRaw: String = PTAppearanceMode.system.rawValue
    
    private var resolvedScheme: ColorScheme? {
        (PTAppearanceMode(rawValue: modeRaw) ?? .system).colorScheme
    }
    
    func body(content: Content) -> some View {
        content.preferredColorScheme(resolvedScheme)
    }
}

extension View {
    /// Applique le mode d'apparence choisi (Système par défaut, Jour ou Nuit).
    func ptAppearance() -> some View {
        modifier(PTAppearanceModifier())
    }
}

// MARK: - Palette & Tokens Swiss Editorial / Flighty (Adaptatifs Jour / Nuit)

enum PTTheme {
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
    
    /// Toile de fond principale — Encre profonde (#09090B) / Papier éditorial (#FAFAFB)
    static let bg = dynamic(
        light: UIColor(red: 0.980, green: 0.980, blue: 0.984, alpha: 1.0),
        dark: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1.0)
    )
    
    /// Surface secondaire subtile — #111114 / #F2F2F5
    static let surface = dynamic(
        light: UIColor(red: 0.949, green: 0.949, blue: 0.961, alpha: 1.0),
        dark: UIColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 1.0)
    )
    
    /// Surface surélevée (pilules flottantes, boutons secondaires, contrôles) — #18181C / #FFFFFF
    static let surfaceElevated = dynamic(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.0),
        dark: UIColor(red: 0.094, green: 0.094, blue: 0.110, alpha: 1.0)
    )
    
    /// Filets éditoriaux 0.5pt
    static let hairline = dynamic(
        light: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 0.09),
        dark: UIColor(white: 1.0, alpha: 0.09)
    )
    
    static let hairlineStrong = dynamic(
        light: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 0.16),
        dark: UIColor(white: 1.0, alpha: 0.16)
    )
    
    /// Hiérarchie typographique — Blanc craie (#F5F5F7) / Encre profonde (#09090B)
    static let textPrimary = dynamic(
        light: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1.0),
        dark: UIColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
    )
    
    static let textSecondary = dynamic(
        light: UIColor(red: 0.369, green: 0.369, blue: 0.408, alpha: 1.0),
        dark: UIColor(red: 0.541, green: 0.541, blue: 0.580, alpha: 1.0)
    )
    
    static let textTertiary = dynamic(
        light: UIColor(red: 0.557, green: 0.557, blue: 0.596, alpha: 1.0),
        dark: UIColor(red: 0.369, green: 0.369, blue: 0.408, alpha: 1.0)
    )
    
    /// Accent cuivre mat — #DE7A42 en nuit / #C6622A plus contrasté en jour
    static let accent = dynamic(
        light: UIColor(red: 0.776, green: 0.384, blue: 0.165, alpha: 1.0),
        dark: UIColor(red: 0.871, green: 0.478, blue: 0.259, alpha: 1.0)
    )
    
    static let success = dynamic(
        light: UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1.0),
        dark: UIColor(red: 0.290, green: 0.871, blue: 0.502, alpha: 1.0)
    )
    
    static let danger = dynamic(
        light: UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1.0),
        dark: UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1.0)
    )
    
    /// Teinte discrète pour la série « Accessoire » dans les graphiques empilés
    static let chartMuted = dynamic(
        light: UIColor(red: 0.831, green: 0.831, blue: 0.863, alpha: 1.0),
        dark: UIColor(red: 0.165, green: 0.165, blue: 0.196, alpha: 1.0)
    )
    
    /// Ombre douce adaptée aux pilules flottantes
    static let floatingShadow = dynamic(
        light: UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 0.12),
        dark: UIColor.black.withAlphaComponent(0.45)
    )
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
