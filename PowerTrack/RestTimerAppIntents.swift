//
//  RestTimerAppIntents.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import AppIntents
import ActivityKit

// MARK: - AppIntent : Ajouter 30 secondes (+30s)

struct AjouterTempsIntent: AppIntent {
    static var title: LocalizedStringResource = "+30s de repos"
    static var description = IntentDescription("Ajoute 30 secondes au compte à rebours de repos sur la Live Activity.")
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        for activity in Activity<RestTimerAttributes>.activities {
            let currentState = activity.content.state
            let nouvelleDateFin = currentState.dateFinRepos.addingTimeInterval(30)
            let updatedState = RestTimerAttributes.ContentState(
                nomExercice: currentState.nomExercice,
                numeroSerie: currentState.numeroSerie,
                dateDebutRepos: currentState.dateDebutRepos,
                dateFinRepos: nouvelleDateFin,
                dureeTotale: nouvelleDateFin.timeIntervalSince(currentState.dateDebutRepos)
            )
            await activity.update(.init(state: updatedState, staleDate: nouvelleDateFin))
        }
        return .result()
    }
}

// MARK: - AppIntent : Passer le repos

struct PasserReposIntent: AppIntent {
    static var title: LocalizedStringResource = "Passer le repos"
    static var description = IntentDescription("Termine immédiatement le repos et clôture la Live Activity.")
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        for activity in Activity<RestTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
