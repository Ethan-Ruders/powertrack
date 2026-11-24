//
//  RestTimerAppIntents.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import AppIntents
import ActivityKit

// MARK: - LiveActivityIntent : Ajouter 30 secondes (+30s)

nonisolated public struct AjouterTempsIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "+30s de repos"
    public static var description = IntentDescription("Ajoute 30 secondes au compte à rebours de repos sur la Live Activity.")
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await TimerManager.shared.ajouterTempsDepuisIntent(30)
        #endif
        return .result()
    }
}

// MARK: - LiveActivityIntent : Retirer 30 secondes (-30s)

nonisolated public struct RetirerTempsIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "-30s de repos"
    public static var description = IntentDescription("Retire 30 secondes au compte à rebours de repos sur la Live Activity.")
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await TimerManager.shared.retirerTempsDepuisIntent(30)
        #endif
        return .result()
    }
}

// MARK: - LiveActivityIntent : Passer le repos

nonisolated public struct PasserReposIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Passer le repos"
    public static var description = IntentDescription("Termine immédiatement le repos et clôture la Live Activity.")
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await TimerManager.shared.stopTimerDepuisIntent()
        #endif
        return .result()
    }
}
