//
//  RankCelebrationViews.swift
//  PowerTrack
//
//  Composants visuels du système de rangs (7×3), repères FFForce, Toast PR et cinématique silencieuse de montée en grade.
//

import SwiftUI

// MARK: - Tokens Couleur par Grade

extension RankGrade {
    var accentColor: Color {
        switch self {
        case .iron:     return Color(red: 0.61, green: 0.64, blue: 0.69)
        case .bronze:   return Color(red: 0.85, green: 0.47, blue: 0.21)
        case .silver:   return Color(red: 0.80, green: 0.84, blue: 0.90)
        case .gold:     return Color(red: 0.96, green: 0.69, blue: 0.14)
        case .platinum: return Color(red: 0.44, green: 0.86, blue: 0.98)
        case .diamond:  return Color(red: 0.16, green: 0.72, blue: 0.98)
        case .invictus: return Color(red: 0.96, green: 0.54, blue: 0.20)
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .invictus:
            return [
                Color(red: 0.99, green: 0.88, blue: 0.52),
                Color(red: 0.96, green: 0.62, blue: 0.16),
                Color(red: 0.87, green: 0.44, blue: 0.22)
            ]
        case .diamond:
            return [
                Color(red: 0.72, green: 0.94, blue: 1.0),
                Color(red: 0.22, green: 0.74, blue: 0.98)
            ]
        case .gold:
            return [
                Color(red: 1.0, green: 0.89, blue: 0.48),
                Color(red: 0.92, green: 0.65, blue: 0.10)
            ]
        default:
            return [accentColor.opacity(0.95), accentColor]
        }
    }
}

// MARK: - Badge Sculpté 3D + Paliers I / II / III

struct PTRankBadgeView: View {
    let grade: RankGrade
    let tier: Int
    var size: CGFloat = 56
    var showPips: Bool = true
    var animateMythicAura: Bool = true
    
    @State private var pulseMythic = false
    
    var body: some View {
        VStack(spacing: max(2, size * 0.05)) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                grade.accentColor.opacity(grade.isMythic ? 0.52 : 0.34),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: size * 0.68
                        )
                    )
                    .frame(width: size * 1.28, height: size * 1.28)
                    .scaleEffect(grade.isMythic && animateMythicAura && pulseMythic ? 1.12 : 0.96)
                
                Image(grade.badgeImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .shadow(color: grade.accentColor.opacity(0.35), radius: size * 0.12, y: size * 0.05)
            }
            
            if showPips {
                HStack(spacing: max(3, size * 0.06)) {
                    ForEach(1...3, id: \.self) { index in
                        Capsule()
                            .fill(index <= tier ? grade.accentColor : PTTheme.hairlineStrong)
                            .frame(width: max(8, size * 0.16), height: max(2.5, size * 0.05))
                            .shadow(color: index <= tier ? grade.accentColor.opacity(0.6) : .clear, radius: 4)
                    }
                }
            }
        }
        .onAppear {
            guard grade.isMythic && animateMythicAura else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulseMythic = true
            }
        }
    }
}

// MARK: - Pilule FFForce Courte (Sans Phrase)

struct PTFFForceTagPill: View {
    let grade: RankGrade
    
    var body: some View {
        Text(grade.ffforceTag.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.6)
            .foregroundColor(grade.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(grade.accentColor.opacity(0.14))
            .overlay(
                Capsule()
                    .stroke(grade.accentColor.opacity(0.40), lineWidth: 0.5)
            )
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

// MARK: - Toast PR Style Flighty (Silencieux)

struct PTCelebrationToastView: View {
    let toast: PTCelebrationToast
    var onDismiss: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PTTheme.success)
                .frame(width: 8, height: 8)
                .shadow(color: PTTheme.success.opacity(0.7), radius: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                PTKicker(text: toast.kicker, color: PTTheme.accent)
                Text(toast.title)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundColor(PTTheme.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            Text(toast.badgeText)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundColor(PTTheme.bg)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(PTTheme.success)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(PTTheme.surfaceElevated.opacity(0.82))
        .overlay(
            Capsule()
                .stroke(PTTheme.accent.opacity(0.45), lineWidth: 0.75)
        )
        .clipShape(Capsule())
        .shadow(color: PTTheme.floatingShadow, radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onTapGesture(perform: onDismiss)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Cinématique Silencieuse de Montée en Grade

struct RankUpOverlayView: View {
    let event: RankPromotionEvent
    let onDismiss: () -> Void
    
    @State private var ringProgress: CGFloat = 0.0
    @State private var isCharging: Bool = true
    @State private var chargeShakeX: CGFloat = 0
    @State private var showNewCrest: Bool = false
    @State private var crestScale: CGFloat = 2.15
    @State private var crestOpacity: Double = 0
    @State private var crestRotationY: Double = -34
    @State private var flashOpacity: Double = 0
    @State private var screenShakeX: CGFloat = 0
    @State private var screenShakeY: CGFloat = 0
    @State private var shock1: CGFloat = 0.45
    @State private var shock1Opacity: Double = 0
    @State private var shock2: CGFloat = 0.45
    @State private var shock2Opacity: Double = 0
    @State private var shock3: CGFloat = 0.45
    @State private var shock3Opacity: Double = 0
    @State private var rayRotation: Double = 0
    @State private var raysOpacity: Double = 0
    @State private var sparkExpand: CGFloat = 0
    @State private var sparkOpacity: Double = 0
    @State private var sheenOffset: CGFloat = -220
    @State private var titleTracking: CGFloat = 10
    @State private var contentOpacity: Double = 0
    @State private var litPipsCount: Int = 0
    @State private var levitating: Bool = false
    
    private var grade: RankGrade { event.newTier.grade }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.90)
                .ignoresSafeArea()
                .onTapGesture {
                    if showNewCrest { onDismiss() }
                }
            
            // Rayons volumétriques rotatifs
            AngularGradient(
                stops: (0..<12).flatMap { idx -> [Gradient.Stop] in
                    let pos = Double(idx) / 12.0
                    let next = pos + 0.038
                    return [
                        .init(color: grade.accentColor.opacity(0.28), location: pos),
                        .init(color: .clear, location: min(0.999, next))
                    ]
                },
                center: .center
            )
            .frame(width: 560, height: 560)
            .mask(
                RadialGradient(
                    colors: [.white, .white.opacity(0.7), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 270
                )
            )
            .rotationEffect(.degrees(rayRotation))
            .opacity(raysOpacity)
            .offset(y: -48)
            .allowsHitTesting(false)
            
            // Particules radiales (36 éclats métalliques)
            ZStack {
                ForEach(0..<36, id: \.self) { i in
                    let angle = (Double(i) / 36.0) * 360.0
                    let dist = CGFloat(105 + (i % 5) * 32)
                    Capsule()
                        .fill(i % 2 == 0 ? grade.accentColor : Color.white)
                        .frame(width: 3.5, height: 18)
                        .shadow(color: grade.accentColor, radius: 5)
                        .offset(y: -dist * sparkExpand)
                        .rotationEffect(.degrees(angle))
                        .opacity(sparkOpacity)
                }
            }
            .offset(y: -48)
            .allowsHitTesting(false)
            
            // Contenu principal avec secousse caméra
            VStack(spacing: 18) {
                PTKicker(text: event.kicker, color: grade.accentColor)
                    .opacity(showNewCrest ? 1 : 0.75)
                
                ZStack {
                    // Cercle d'énergie
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 3)
                        .frame(width: 236, height: 236)
                    
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            LinearGradient(colors: grade.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 236, height: 236)
                        .rotationEffect(.degrees(-90))
                    
                    // 3 Ondes de choc
                    Circle()
                        .stroke(grade.accentColor, lineWidth: 3)
                        .frame(width: 170, height: 170)
                        .scaleEffect(shock1)
                        .opacity(shock1Opacity)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                        .frame(width: 170, height: 170)
                        .scaleEffect(shock2)
                        .opacity(shock2Opacity)
                    
                    Circle()
                        .stroke(grade.accentColor.opacity(0.8), lineWidth: 1.5)
                        .frame(width: 170, height: 170)
                        .scaleEffect(shock3)
                        .opacity(shock3Opacity)
                    
                    // Blason 3D Sculpté
                    ZStack {
                        if isCharging && !showNewCrest {
                            Image(grade.badgeImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                                .opacity(0.45)
                                .blur(radius: 2)
                                .offset(x: chargeShakeX)
                        }
                        
                        if showNewCrest {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [grade.accentColor.opacity(0.55), .clear],
                                            center: .center,
                                            startRadius: 10,
                                            endRadius: 130
                                        )
                                    )
                                    .frame(width: 240, height: 240)
                                
                                Image(grade.badgeImageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 184, height: 184)
                                    .overlay(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.65), .clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        .frame(width: 90)
                                        .rotationEffect(.degrees(24))
                                        .offset(x: sheenOffset)
                                        .mask(
                                            Image(grade.badgeImageName)
                                                .resizable()
                                                .scaledToFit()
                                        )
                                    )
                            }
                            .scaleEffect(crestScale)
                            .opacity(crestOpacity)
                            .rotation3DEffect(.degrees(crestRotationY), axis: (x: 0, y: 1, z: 0))
                            .offset(y: levitating ? -6 : 0)
                        }
                    }
                }
                .frame(height: 250)
                
                VStack(spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 30, weight: .black))
                        .tracking(titleTracking)
                        .foregroundStyle(
                            LinearGradient(
                                colors: grade.isMythic ? grade.gradientColors : [.white, .white.opacity(0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 8) {
                        PTFFForceTagPill(grade: grade)
                        Text(event.metricPill)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundColor(.white.opacity(0.82))
                    }
                    
                    Text(event.subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.68))
                        .multilineTextAlignment(.center)
                    
                    // Paliers I / II / III verrouillés séquentiellement
                    HStack(spacing: 10) {
                        ForEach(1...3, id: \.self) { idx in
                            let lit = idx <= litPipsCount
                            Capsule()
                                .fill(lit ? grade.accentColor : Color.white.opacity(0.16))
                                .frame(width: 36, height: 7)
                                .shadow(color: lit ? grade.accentColor : .clear, radius: 10)
                                .scaleEffect(lit ? 1.1 : 1.0)
                                .animation(.spring(response: 0.32, dampingFraction: 0.6), value: lit)
                        }
                    }
                    .padding(.top, 6)
                }
                .opacity(contentOpacity)
                .padding(.horizontal, 24)
                
                Button(action: onDismiss) {
                    Text("Continuer")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color(red: 0.035, green: 0.035, blue: 0.043))
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: grade.isMythic ? grade.gradientColors : [.white, .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .padding(.top, 12)
                .opacity(contentOpacity)
            }
            .offset(x: screenShakeX, y: screenShakeY)
            
            // Flash d'impact plein écran
            RadialGradient(
                colors: [.white, grade.accentColor.opacity(0.8), .clear],
                center: .center,
                startRadius: 4,
                endRadius: 420
            )
            .ignoresSafeArea()
            .opacity(flashOpacity)
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
        .onAppear {
            runBlockbusterSequence()
        }
    }
    
    private func runBlockbusterSequence() {
        HapticAndSoundManager.shared.triggerRankUpHaptic(isMythic: event.isMythic)
        
        // Rotation continue des rayons
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            rayRotation = 360
        }
        
        // Phase 0: Montée en énergie + vibration pré-impact (0.0 -> 0.48s)
        withAnimation(.easeIn(duration: 0.46)) {
            ringProgress = 1.0
        }
        withAnimation(.linear(duration: 0.05).repeatCount(9, autoreverses: true)) {
            chargeShakeX = 4
        }
        
        // Phase 1 & 2: Impact + Flash + Caméra Shake + 3 Ondes + 36 Étincelles + Slam 3D (0.48s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            isCharging = false
            showNewCrest = true
            flashOpacity = 0.92
            raysOpacity = 0.90
            sparkOpacity = 1.0
            shock1Opacity = 0.95
            shock2Opacity = 0.85
            shock3Opacity = 0.75
            
            withAnimation(.easeOut(duration: 0.55)) {
                flashOpacity = 0
            }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.62)) {
                crestScale = 1.0
                crestOpacity = 1.0
                crestRotationY = 0
            }
            withAnimation(.easeOut(duration: 0.60)) {
                titleTracking = 0
                contentOpacity = 1.0
            }
            
            // 3 Shockwaves échelonnées
            withAnimation(.easeOut(duration: 0.85)) {
                shock1 = 2.6
                shock1Opacity = 0
            }
            withAnimation(.easeOut(duration: 1.05).delay(0.10)) {
                shock2 = 2.9
                shock2Opacity = 0
            }
            withAnimation(.easeOut(duration: 1.20).delay(0.20)) {
                shock3 = 3.2
                shock3Opacity = 0
            }
            
            // 36 Éclats directionnels
            withAnimation(.easeOut(duration: 0.78)) {
                sparkExpand = 1.0
            }
            withAnimation(.easeIn(duration: 0.42).delay(0.36)) {
                sparkOpacity = 0
            }
            
            // Reflet métallique diagonal sur le blason
            withAnimation(.easeOut(duration: 0.75).delay(0.14)) {
                sheenOffset = 220
            }
            
            // Secousse caméra rapide
            triggerCameraShake(heavy: event.isMythic || event.isDivisionPromotion)
            
            // Allumage séquentiel des paliers I / II / III
            for idx in 1...event.newTier.tier {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22 + Double(idx - 1) * 0.16) {
                    litPipsCount = idx
                }
            }
        }
        
        // Lévitation douce post-impact
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                levitating = true
            }
        }
    }
    
    private func triggerCameraShake(heavy: Bool) {
        let mag: CGFloat = heavy ? 11 : 7
        let steps: [(TimeInterval, CGFloat, CGFloat)] = [
            (0.00, -mag, mag * 0.6),
            (0.05, mag, -mag * 0.7),
            (0.10, -mag * 0.7, -mag * 0.4),
            (0.15, mag * 0.5, mag * 0.4),
            (0.20, -mag * 0.25, 0),
            (0.26, 0, 0)
        ]
        for (delay, dx, dy) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.045)) {
                    screenShakeX = dx
                    screenShakeY = dy
                }
            }
        }
    }
}

// MARK: - Feuille Grille des 7 Rangs & Repères FFForce

struct RankLadderSheetView: View {
    let snapshot: RankSnapshot
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTierNumber: Int = 1
    
    private var referenceBW: Double {
        snapshot.bodyweightKg ?? 75.0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let primary = snapshot.primaryDisplay {
                        currentSummaryCard(rank: primary.rank, scope: primary.scope)
                    }
                    
                    // Sélecteur de palier I / II / III
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { t in
                            let roman = t == 1 ? "I" : (t == 2 ? "II" : "III")
                            let isSelected = selectedTierNumber == t
                            Button {
                                HapticAndSoundManager.shared.triggerSelection()
                                selectedTierNumber = t
                            } label: {
                                Text("Palier \(roman)")
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? PTTheme.bg : PTTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? PTTheme.textPrimary : PTTheme.surface)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.clear : PTTheme.hairline, lineWidth: 0.5)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        PTHairline()
                        ForEach(RankGrade.allCases) { grade in
                            let tierObj = RankTier.allTiers[grade.order * 3 + (selectedTierNumber - 1)]
                            let isCurrent = snapshot.primaryDisplay?.rank.grade == grade
                            let totalEst = RankCalculator.totalKgRequired(forDOTS: tierObj.minDots, bodyweightKg: referenceBW)
                            
                            HStack(spacing: 14) {
                                PTRankBadgeView(grade: grade, tier: selectedTierNumber, size: 54, showPips: true, animateMythicAura: false)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(tierObj.displayName)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundColor(grade.isMythic ? grade.accentColor : PTTheme.textPrimary)
                                        
                                        if isCurrent {
                                            Text("ACTUEL")
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundColor(PTTheme.accent)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(PTTheme.accent.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        PTFFForceTagPill(grade: grade)
                                        
                                        if let totalEst, tierObj.minDots > 0 {
                                            Text("\(Int(tierObj.minDots))+ DOTS · ~\(Int(round(totalEst))) kg")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundColor(PTTheme.textSecondary)
                                        } else {
                                            Text("Entrée")
                                                .font(.caption2)
                                                .foregroundColor(PTTheme.textSecondary)
                                        }
                                    }
                                }
                                
                                Spacer(minLength: 6)
                                
                                Button {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        RankStateManager.shared.previewPromotion(to: tierObj)
                                    }
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.caption2)
                                        .foregroundColor(grade.accentColor)
                                        .frame(width: 30, height: 30)
                                        .background(grade.accentColor.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Prévisualiser \(tierObj.displayName)")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            PTHairline(leadingInset: 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .ptAppBackground()
            .navigationTitle("Rangs & Classement FFF")
            .navigationBarTitleDisplayMode(.inline)
            .ptAppearance()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(PTTheme.textSecondary)
                }
            }
            .onAppear {
                if let current = snapshot.primaryDisplay?.rank {
                    selectedTierNumber = current.tier
                }
            }
        }
    }
    
    private func currentSummaryCard(rank: RankTier, scope: String) -> some View {
        HStack(spacing: 16) {
            PTRankBadgeView(grade: rank.grade, tier: rank.tier, size: 68)
            
            VStack(alignment: .leading, spacing: 5) {
                PTKicker(text: "Rang Actuel · \(scope)", color: rank.grade.accentColor)
                Text(rank.displayName)
                    .font(.title2.weight(.heavy))
                    .foregroundColor(PTTheme.textPrimary)
                HStack(spacing: 8) {
                    PTFFForceTagPill(grade: rank.grade)
                    if let dots = snapshot.dots, snapshot.hasCompleteSBD {
                        Text(String(format: "%.1f DOTS", dots))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundColor(PTTheme.textSecondary)
                    } else if let bw = snapshot.bodyweightKg {
                        Text("PDC \(PTFormat.weight(bw)) kg")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(PTTheme.textSecondary)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(PTTheme.surface.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(rank.grade.accentColor.opacity(0.35), lineWidth: 0.75)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }
}
