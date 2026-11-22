//
//  RestTimerActivityManager.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import Foundation
import ActivityKit

@MainActor
public final class RestTimerActivityManager {
    public static let shared = RestTimerActivityManager()
    
    private var currentActivity: Activity<RestTimerAttributes>?
    private var timerClotureAuto: Timer?
    
    private init() {}
    
    // MARK: - Démarrage du Décompte Persistant
    
    /// Démarre la Live Activity sur l'écran verrouillé dès la validation d'une série
    public func startLiveActivity(
        nomExercice: String,
        numeroSerie: Int,
        dureeSecondes: TimeInterval,
        nomSeance: String = "Séance PowerTrack"
    ) {
        timerClotureAuto?.invalidate()
        timerClotureAuto = nil
        
        let previousActivities = collectTrackedActivities()
        currentActivity = nil
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities non autorisées sur cet appareil.")
            if !previousActivities.isEmpty {
                Task {
                    for prev in previousActivities {
                        await prev.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
            return
        }
        
        let dateDebut = Date()
        let dateFin = dateDebut.addingTimeInterval(max(0, dureeSecondes))
        
        let attributes = RestTimerAttributes(nomSeance: nomSeance)
        let state = RestTimerAttributes.ContentState(
            nomExercice: nomExercice,
            numeroSerie: numeroSerie,
            dateDebutRepos: dateDebut,
            dateFinRepos: dateFin,
            dureeTotale: max(0, dureeSecondes)
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: dateFin),
                pushType: nil
            )
            self.currentActivity = activity
            programmerClotureAutomatique(a: dateFin)
            print("✅ Live Activity démarrée (ID: \(activity.id)) - Fin prévue à \(dateFin)")
            
            if !previousActivities.isEmpty {
                let newId = activity.id
                Task {
                    for prev in previousActivities where prev.id != newId {
                        await prev.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
        } catch {
            print("❌ Erreur lors du lancement de la Live Activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Mise à Jour Dynamique (+30s)
    
    /// Met à jour toutes les Live Activities actives avec une date de fin explicite.
    public func mettreAJourDateFinAsync(_ nouvelleDateFin: Date) async {
        let activities = collectTrackedActivities()
        guard !activities.isEmpty else { return }
        
        for activity in activities {
            let currentState = activity.content.state
            let dureeTotale = max(0, nouvelleDateFin.timeIntervalSince(currentState.dateDebutRepos))
            
            let updatedState = RestTimerAttributes.ContentState(
                nomExercice: currentState.nomExercice,
                numeroSerie: currentState.numeroSerie,
                dateDebutRepos: currentState.dateDebutRepos,
                dateFinRepos: nouvelleDateFin,
                dureeTotale: dureeTotale
            )
            
            await activity.update(.init(state: updatedState, staleDate: nouvelleDateFin))
            self.currentActivity = activity
        }
        
        programmerClotureAutomatique(a: nouvelleDateFin)
        print("⏱️ Live Activity mise à jour (Nouvelle fin : \(nouvelleDateFin))")
    }
    
    /// Ajoute directement du temps aux Live Activities actives (utile au réveil à froid via LiveActivityIntent).
    @discardableResult
    public func ajouterTempsDirectAsync(_ secondes: TimeInterval = 30) async -> RestTimerAttributes.ContentState? {
        let activities = collectTrackedActivities()
        guard !activities.isEmpty else { return nil }
        
        let now = Date()
        var lastUpdatedState: RestTimerAttributes.ContentState?
        
        for activity in activities {
            let currentState = activity.content.state
            let nouvelleDateFin = max(now, currentState.dateFinRepos).addingTimeInterval(secondes)
            let dureeTotale = max(0, nouvelleDateFin.timeIntervalSince(currentState.dateDebutRepos))
            
            let updatedState = RestTimerAttributes.ContentState(
                nomExercice: currentState.nomExercice,
                numeroSerie: currentState.numeroSerie,
                dateDebutRepos: currentState.dateDebutRepos,
                dateFinRepos: nouvelleDateFin,
                dureeTotale: dureeTotale
            )
            
            await activity.update(.init(state: updatedState, staleDate: nouvelleDateFin))
            self.currentActivity = activity
            lastUpdatedState = updatedState
        }
        
        if let lastUpdatedState {
            programmerClotureAutomatique(a: lastUpdatedState.dateFinRepos)
            print("⏱️ Live Activity mise à jour : +\(Int(secondes))s (Nouvelle fin : \(lastUpdatedState.dateFinRepos))")
        }
        
        return lastUpdatedState
    }
    
    /// Ajoute du temps au chrono actif et met à jour la Live Activity en temps réel
    public func ajouterTemps(_ secondes: TimeInterval = 30) {
        Task {
            _ = await ajouterTempsDirectAsync(secondes)
        }
    }
    
    // MARK: - Clôture & Arrêt
    
    /// Clôture immédiatement et de manière asynchrone toutes les Live Activities actives.
    public func endLiveActivityAsync() async {
        timerClotureAuto?.invalidate()
        timerClotureAuto = nil
        
        let activities = collectTrackedActivities()
        currentActivity = nil
        guard !activities.isEmpty else { return }
        
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        print("🛑 Live Activity terminée.")
    }
    
    /// Clôture immédiatement la Live Activity (appui sur "Passer" ou expiration)
    public func endLiveActivity() {
        timerClotureAuto?.invalidate()
        timerClotureAuto = nil
        
        let activities = collectTrackedActivities()
        currentActivity = nil
        guard !activities.isEmpty else { return }
        
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            print("🛑 Live Activity terminée.")
        }
    }
    
    // MARK: - Utilitaires & Timers Internes
    
    private func collectTrackedActivities() -> [Activity<RestTimerAttributes>] {
        var activities = Activity<RestTimerAttributes>.activities
        if let current = currentActivity,
           !activities.contains(where: { $0.id == current.id }) {
            activities.append(current)
        }
        return activities
    }
    
    private func programmerClotureAutomatique(a dateFin: Date) {
        timerClotureAuto?.invalidate()
        let delai = dateFin.timeIntervalSinceNow
        guard delai > 0 else {
            endLiveActivity()
            return
        }
        
        timerClotureAuto = Timer.scheduledTimer(withTimeInterval: delai, repeats: false) { _ in
            Task { @MainActor in
                RestTimerActivityManager.shared.endLiveActivity()
            }
        }
    }
}

// Rétro-compatibilité
public typealias LiveActivityManager = RestTimerActivityManager
