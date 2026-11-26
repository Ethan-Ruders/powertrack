//
//  RankSystem.swift
//  PowerTrack
//
//  Moteur de calcul des rangs compétitifs (7 grades × 3 paliers) basé sur les 1RM/e1RM validés et DOTS.
//

import Foundation
import SwiftData
import Combine

// MARK: - Grades & Paliers (Fer → INVICTUS)

nonisolated enum RankGrade: String, CaseIterable, Identifiable, Codable, Sendable {
    case iron
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case invictus
    
    var id: String { rawValue }
    
    var order: Int {
        switch self {
        case .iron: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .platinum: return 4
        case .diamond: return 5
        case .invictus: return 6
        }
    }
    
    var displayName: String {
        switch self {
        case .iron: return "Fer"
        case .bronze: return "Bronze"
        case .silver: return "Argent"
        case .gold: return "Or"
        case .platinum: return "Platine"
        case .diamond: return "Diamant"
        case .invictus: return "INVICTUS"
        }
    }
    
    var badgeImageName: String {
        switch self {
        case .iron: return "RankBadgeIron"
        case .bronze: return "RankBadgeBronze"
        case .silver: return "RankBadgeSilver"
        case .gold: return "RankBadgeGold"
        case .platinum: return "RankBadgePlatinum"
        case .diamond: return "RankBadgeDiamond"
        case .invictus: return "RankBadgeInvictus"
        }
    }
    
    /// Repère court de niveau FFForce (sans phrase).
    var ffforceTag: String {
        switch self {
        case .iron: return "Débutant"
        case .bronze: return "Club"
        case .silver: return "FFF · Dép."
        case .gold: return "FFF · Régional"
        case .platinum: return "FFF · National"
        case .diamond: return "FFF · Élite"
        case .invictus: return "FFF · Intl."
        }
    }
    
    /// Seuils DOTS d'entrée pour les paliers I, II et III.
    var tierDOTSThresholds: [Double] {
        switch self {
        case .iron:     return [0, 190, 220]
        case .bronze:   return [250, 270, 290]
        case .silver:   return [310, 330, 345]
        case .gold:     return [350, 375, 395]
        case .platinum: return [415, 435, 455]
        case .diamond:  return [475, 495, 515]
        case .invictus: return [535, 560, 590]
        }
    }
    
    var isMythic: Bool {
        self == .invictus
    }
}

nonisolated struct RankTier: Equatable, Hashable, Identifiable, Sendable {
    let grade: RankGrade
    let tier: Int // 1, 2, 3
    let flatIndex: Int // 0...20
    let minDots: Double
    
    var id: Int { flatIndex }
    
    var roman: String {
        switch tier {
        case 1: return "I"
        case 2: return "II"
        default: return "III"
        }
    }
    
    var displayName: String {
        "\(grade.displayName) \(roman)"
    }
    
    static let allTiers: [RankTier] = {
        var result: [RankTier] = []
        var idx = 0
        for grade in RankGrade.allCases {
            for t in 1...3 {
                result.append(RankTier(
                    grade: grade,
                    tier: t,
                    flatIndex: idx,
                    minDots: grade.tierDOTSThresholds[t - 1]
                ))
                idx += 1
            }
        }
        return result
    }()
}

// MARK: - Instantané de Rang SBD & Par Mouvement

nonisolated struct RankSnapshot: Equatable, Sendable {
    let squatKg: Double
    let benchKg: Double
    let deadliftKg: Double
    let totalKg: Double
    let bodyweightKg: Double?
    let dots: Double?
    
    let globalRank: RankTier?
    let nextGlobalTier: RankTier?
    let progressToNext: Double
    let kgToNextTier: Double?
    
    let squatRank: RankTier?
    let benchRank: RankTier?
    let deadliftRank: RankTier?
    
    var hasCompleteSBD: Bool {
        squatKg > 0 && benchKg > 0 && deadliftKg > 0
    }
    
    func rank(for movement: MouvementParent) -> RankTier? {
        switch movement {
        case .squat: return squatRank
        case .bench: return benchRank
        case .deadlift: return deadliftRank
        case .autre: return nil
        }
    }
    
    /// Rang de référence le plus parlant (SBD si complet, sinon meilleur mouvement validé).
    var primaryDisplay: (rank: RankTier, scope: String)? {
        if hasCompleteSBD, let globalRank {
            return (globalRank, "SBD")
        }
        let singles: [(MouvementParent, RankTier?)] = [
            (.bench, benchRank),
            (.squat, squatRank),
            (.deadlift, deadliftRank)
        ]
        if let best = singles.compactMap({ m, r in r.map { (m, $0) } }).max(by: { $0.1.flatIndex < $1.1.flatIndex }) {
            return (best.1, best.0.nomAffichage)
        }
        if let globalRank {
            return (globalRank, "SBD")
        }
        return nil
    }
}

// MARK: - Calculateur Pur

nonisolated enum RankCalculator {
    static let squatRatioThresholds: [Double]    = [1.0, 1.5, 1.85, 2.25, 2.6, 3.0, 3.35]
    static let benchRatioThresholds: [Double]    = [0.75, 1.0, 1.25, 1.55, 1.85, 2.15, 2.4]
    static let deadliftRatioThresholds: [Double] = [1.25, 1.75, 2.15, 2.6, 3.0, 3.4, 3.8]
    
    static func tier(forDOTS dots: Double) -> RankTier {
        var resolved = RankTier.allTiers[0]
        for candidate in RankTier.allTiers {
            if dots >= candidate.minDots {
                resolved = candidate
            }
        }
        return resolved
    }
    
    static func nextTier(after current: RankTier) -> RankTier? {
        let nextIdx = current.flatIndex + 1
        guard nextIdx < RankTier.allTiers.count else { return nil }
        return RankTier.allTiers[nextIdx]
    }
    
    static func totalKgRequired(forDOTS targetDots: Double, bodyweightKg: Double) -> Double? {
        guard targetDots > 0, bodyweightKg > 0,
              let dotsPerKg = PowerliftingScoring.dotsMale(totalKg: 1.0, bodyweightKg: bodyweightKg),
              dotsPerKg > 0 else {
            return nil
        }
        return targetDots / dotsPerKg
    }
    
    static func progressToNextTier(dots: Double, bodyweightKg: Double?) -> (progress: Double, kgNeeded: Double?, nextTier: RankTier?) {
        let current = tier(forDOTS: dots)
        guard let next = nextTier(after: current) else {
            return (1.0, nil, nil)
        }
        let span = max(1.0, next.minDots - current.minDots)
        let ratio = min(1.0, max(0.04, (dots - current.minDots) / span))
        let kgNeeded: Double? = bodyweightKg.flatMap { bw in
            guard let targetTotal = totalKgRequired(forDOTS: next.minDots, bodyweightKg: bw),
                  let currentTotal = totalKgRequired(forDOTS: dots, bodyweightKg: bw) else { return nil }
            return max(0.5, targetTotal - currentTotal)
        }
        return (ratio, kgNeeded, next)
    }
    
    static func liftRank(e1rmKg: Double, bodyweightKg: Double, movement: MouvementParent) -> RankTier? {
        guard e1rmKg > 0, bodyweightKg > 0 else { return nil }
        let thresholds: [Double]
        switch movement {
        case .squat: thresholds = squatRatioThresholds
        case .bench: thresholds = benchRatioThresholds
        case .deadlift: thresholds = deadliftRatioThresholds
        case .autre: return nil
        }
        
        let ratio = e1rmKg / bodyweightKg
        var gradeIndex = 0
        for i in 0..<thresholds.count {
            if ratio >= thresholds[i] {
                gradeIndex = i
            }
        }
        let lo = thresholds[gradeIndex]
        let hi = gradeIndex < thresholds.count - 1 ? thresholds[gradeIndex + 1] : (lo + 0.35)
        let frac = min(0.99, max(0.0, (ratio - lo) / max(0.01, hi - lo)))
        let subTier = frac < 0.34 ? 1 : (frac < 0.68 ? 2 : 3)
        let flatIndex = gradeIndex * 3 + (subTier - 1)
        return RankTier.allTiers[flatIndex]
    }
    
    static func snapshot(
        from blocs: [MacroBloc],
        bodyweightKg: Double?,
        competitionOnly: Bool = true
    ) -> RankSnapshot {
        let squatBest = bestValidatedE1RM(for: .squat, in: blocs, competitionOnly: competitionOnly)
        let benchBest = bestValidatedE1RM(for: .bench, in: blocs, competitionOnly: competitionOnly)
        let deadliftBest = bestValidatedE1RM(for: .deadlift, in: blocs, competitionOnly: competitionOnly)
        let total = squatBest + benchBest + deadliftBest
        
        let validBW = (bodyweightKg ?? 0) > 0 ? bodyweightKg : nil
        let dots = validBW.flatMap { PowerliftingScoring.dotsMale(totalKg: total, bodyweightKg: $0) }
        let globalRank = dots.map { tier(forDOTS: $0) }
        
        let prog: (progress: Double, kgNeeded: Double?, nextTier: RankTier?) = dots.map {
            progressToNextTier(dots: $0, bodyweightKg: validBW)
        } ?? (progress: 0.0, kgNeeded: nil, nextTier: nil)
        
        let sqRank = validBW.flatMap { liftRank(e1rmKg: squatBest, bodyweightKg: $0, movement: .squat) }
        let bnRank = validBW.flatMap { liftRank(e1rmKg: benchBest, bodyweightKg: $0, movement: .bench) }
        let dlRank = validBW.flatMap { liftRank(e1rmKg: deadliftBest, bodyweightKg: $0, movement: .deadlift) }
        
        return RankSnapshot(
            squatKg: squatBest,
            benchKg: benchBest,
            deadliftKg: deadliftBest,
            totalKg: total,
            bodyweightKg: validBW,
            dots: dots,
            globalRank: globalRank,
            nextGlobalTier: prog.nextTier,
            progressToNext: prog.progress,
            kgToNextTier: prog.kgNeeded,
            squatRank: sqRank,
            benchRank: bnRank,
            deadliftRank: dlRank
        )
    }
    
    private static func bestValidatedE1RM(
        for movement: MouvementParent,
        in blocs: [MacroBloc],
        competitionOnly: Bool
    ) -> Double {
        var best: Double = 0.0
        for bloc in blocs {
            for sem in bloc.semaines {
                for seance in sem.seances {
                    for ex in seance.exercices where ex.mouvementParent == movement {
                        if competitionOnly && !ex.estMouvementCompetitionPur { continue }
                        for s in ex.seriesTriees where s.estValidee {
                            guard let charge = s.chargeSaisie, charge > 0,
                                  let e1rm = s.calculerE1RM() else { continue }
                            if e1rm > best { best = e1rm }
                        }
                    }
                }
            }
        }
        return best
    }
}

// MARK: - Événements de Promotion & Toast PR

nonisolated struct RankPromotionEvent: Equatable, Identifiable, Sendable {
    let id = UUID()
    let kicker: String
    let title: String
    let subtitle: String
    let metricPill: String
    let newTier: RankTier
    let isDivisionPromotion: Bool
    
    var isMythic: Bool {
        newTier.grade.isMythic
    }
}

nonisolated struct PTCelebrationToast: Equatable, Identifiable, Sendable {
    let id = UUID()
    let kicker: String
    let title: String
    let badgeText: String
}

// MARK: - Gestionnaire d'État des Rangs (Silencieux, Haptique Uniquement)

final class RankStateManager: ObservableObject {
    static let shared = RankStateManager()
    
    @Published var activePromotion: RankPromotionEvent? = nil
    @Published var activeToast: PTCelebrationToast? = nil
    
    private let defaults: UserDefaults
    private var toastDismissWorkItem: DispatchWorkItem?
    
    private enum Keys {
        static let global   = "pt_highest_rank_global"
        static let squat    = "pt_highest_rank_squat"
        static let bench    = "pt_highest_rank_bench"
        static let deadlift = "pt_highest_rank_deadlift"
    }
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    private func storedIndex(forKey key: String) -> Int {
        guard defaults.object(forKey: key) != nil else { return -1 }
        return defaults.integer(forKey: key)
    }
    
    /// Enregistre silencieusement l'état initial si aucune référence n'est encore stockée.
    func syncBaselineIfNeeded(from snapshot: RankSnapshot) {
        if snapshot.hasCompleteSBD, let global = snapshot.globalRank, storedIndex(forKey: Keys.global) == -1 {
            defaults.set(global.flatIndex, forKey: Keys.global)
        }
        if let sq = snapshot.squatRank, storedIndex(forKey: Keys.squat) == -1 {
            defaults.set(sq.flatIndex, forKey: Keys.squat)
        }
        if let bn = snapshot.benchRank, storedIndex(forKey: Keys.bench) == -1 {
            defaults.set(bn.flatIndex, forKey: Keys.bench)
        }
        if let dl = snapshot.deadliftRank, storedIndex(forKey: Keys.deadlift) == -1 {
            defaults.set(dl.flatIndex, forKey: Keys.deadlift)
        }
    }
    
    /// Évalue une éventuelle montée de palier ou de grade après validation d'une série.
    func evaluateAfterSetValidation(
        blocs: [MacroBloc],
        bodyweightKg: Double?,
        validatedMovement: MouvementParent
    ) {
        let snapshot = RankCalculator.snapshot(from: blocs, bodyweightKg: bodyweightKg, competitionOnly: true)
        
        // 1. Promotion Globale SBD (lorsque les 3 mouvements ont des séries validées)
        if snapshot.hasCompleteSBD, let global = snapshot.globalRank {
            let prevIdx = storedIndex(forKey: Keys.global)
            if prevIdx == -1 {
                defaults.set(global.flatIndex, forKey: Keys.global)
            } else if global.flatIndex > prevIdx {
                let prevTier = RankTier.allTiers[max(0, min(RankTier.allTiers.count - 1, prevIdx))]
                defaults.set(global.flatIndex, forKey: Keys.global)
                let isDiv = prevTier.grade != global.grade
                let dotsStr = snapshot.dots.map { String(format: "%.1f DOTS", $0) } ?? ""
                activePromotion = RankPromotionEvent(
                    kicker: global.grade.isMythic ? "ASCENSION INVICTUS" : (isDiv ? "PROMOTION DE GRADE" : "PALIER SUPÉRIEUR"),
                    title: "\(prevTier.displayName) → \(global.displayName)",
                    subtitle: "\(global.grade.ffforceTag) · \(dotsStr)",
                    metricPill: String(format: "%.0f kg SBD", snapshot.totalKg),
                    newTier: global,
                    isDivisionPromotion: isDiv
                )
                return
            }
        }
        
        // 2. Promotion sur le mouvement validé (ex: Bench Only)
        if let liftKey = movementKey(for: validatedMovement),
           let newLiftRank = snapshot.rank(for: validatedMovement) {
            let prevIdx = storedIndex(forKey: liftKey)
            if prevIdx == -1 {
                defaults.set(newLiftRank.flatIndex, forKey: liftKey)
            } else if newLiftRank.flatIndex > prevIdx {
                let prevTier = RankTier.allTiers[max(0, min(RankTier.allTiers.count - 1, prevIdx))]
                defaults.set(newLiftRank.flatIndex, forKey: liftKey)
                let isDiv = prevTier.grade != newLiftRank.grade
                let bestKg = bestKgValue(snapshot: snapshot, movement: validatedMovement)
                activePromotion = RankPromotionEvent(
                    kicker: newLiftRank.grade.isMythic ? "ASCENSION INVICTUS" : "\(validatedMovement.nomAffichage.uppercased()) · \(isDiv ? "NOUVEAU GRADE" : "PALIER")",
                    title: "\(prevTier.displayName) → \(newLiftRank.displayName)",
                    subtitle: "\(newLiftRank.grade.ffforceTag) · \(validatedMovement.nomAffichage)",
                    metricPill: String(format: "%.1f kg e1RM", bestKg),
                    newTier: newLiftRank,
                    isDivisionPromotion: isDiv
                )
            }
        }
    }
    
    func showPRToast(exerciseName: String, e1rmKg: Double, deltaKg: Double) {
        toastDismissWorkItem?.cancel()
        let deltaLabel = deltaKg > 0 ? String(format: "+%.1f kg", deltaKg) : "NOUVEAU PR"
        let weightStr = e1rmKg.truncatingRemainder(dividingBy: 1.0) == 0
            ? String(format: "%.0f kg", e1rmKg)
            : String(format: "%.1f kg", e1rmKg)
        activeToast = PTCelebrationToast(
            kicker: "RECORD PERSONNEL",
            title: "\(exerciseName) · \(weightStr)",
            badgeText: deltaLabel
        )
        let work = DispatchWorkItem { [weak self] in
            self?.activeToast = nil
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: work)
    }
    
    func previewPromotion(to target: RankTier, dotsEstimate: Double? = nil) {
        let prev = RankTier.allTiers[max(0, target.flatIndex - 1)]
        let isDiv = prev.grade != target.grade || target.flatIndex == 0
        let dotsText = String(format: "%.0f+ DOTS", dotsEstimate ?? target.minDots)
        activePromotion = RankPromotionEvent(
            kicker: target.grade.isMythic ? "ASCENSION INVICTUS" : (isDiv ? "PROMOTION DE GRADE" : "PALIER SUPÉRIEUR"),
            title: target.flatIndex > 0 ? "\(prev.displayName) → \(target.displayName)" : target.displayName,
            subtitle: "\(target.grade.ffforceTag) · \(dotsText)",
            metricPill: target.grade.ffforceTag,
            newTier: target,
            isDivisionPromotion: isDiv
        )
    }
    
    func dismissPromotion() {
        activePromotion = nil
    }
    
    func dismissToast() {
        toastDismissWorkItem?.cancel()
        activeToast = nil
    }
    
    func resetStoredBaselinesForTests() {
        defaults.removeObject(forKey: Keys.global)
        defaults.removeObject(forKey: Keys.squat)
        defaults.removeObject(forKey: Keys.bench)
        defaults.removeObject(forKey: Keys.deadlift)
        activePromotion = nil
        activeToast = nil
    }
    
    private func movementKey(for movement: MouvementParent) -> String? {
        switch movement {
        case .squat: return Keys.squat
        case .bench: return Keys.bench
        case .deadlift: return Keys.deadlift
        case .autre: return nil
        }
    }
    
    private func bestKgValue(snapshot: RankSnapshot, movement: MouvementParent) -> Double {
        switch movement {
        case .squat: return snapshot.squatKg
        case .bench: return snapshot.benchKg
        case .deadlift: return snapshot.deadliftKg
        case .autre: return 0
        }
    }
}
