//
//  RestTimerActivityManager.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import Foundation
import ActivityKit
import UserNotifications

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
        // 1. Clôture de toute activité précédente
        endLiveActivity()
        
        // 2. Vérification de l'activation système des Live Activities
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities non autorisées sur cet appareil.")
            return
        }
        
        let dateDebut = Date()
        let dateFin = dateDebut.addingTimeInterval(dureeSecondes)
        
        let attributes = RestTimerAttributes(nomSeance: nomSeance)
        let state = RestTimerAttributes.ContentState(
            nomExercice: nomExercice,
            numeroSerie: numeroSerie,
            dateDebutRepos: dateDebut,
            dateFinRepos: dateFin,
            dureeTotale: dureeSecondes
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: dateFin),
                pushType: nil
            )
            self.currentActivity = activity
            print("✅ Live Activity démarrée (ID: \(activity.id)) - Fin prévue à \(dateFin)")
            
            // Programmer l'alerte sonore et la clôture automatique
            planifierNotificationFinRepos(dateFin: dateFin, nomExercice: nomExercice, numeroSerie: numeroSerie)
            programmerClotureAutomatique(a: dateFin)
            
        } catch {
            print("❌ Erreur lors du lancement de la Live Activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Mise à Jour Dynamique (+30s)
    
    /// Ajoute du temps au chrono actif et met à jour la Live Activity en temps réel
    public func ajouterTemps(_ secondes: TimeInterval = 30) {
        guard let activity = currentActivity else { return }
        
        let currentState = activity.content.state
        let nouvelleDateFin = currentState.dateFinRepos.addingTimeInterval(secondes)
        let nouvelleDureeTotale = nouvelleDateFin.timeIntervalSince(currentState.dateDebutRepos)
        
        let updatedState = RestTimerAttributes.ContentState(
            nomExercice: currentState.nomExercice,
            numeroSerie: currentState.numeroSerie,
            dateDebutRepos: currentState.dateDebutRepos,
            dateFinRepos: nouvelleDateFin,
            dureeTotale: nouvelleDureeTotale
        )
        
        Task {
            await activity.update(.init(state: updatedState, staleDate: nouvelleDateFin))
            print("⏱️ Live Activity mise à jour : +\(Int(secondes))s (Nouvelle fin : \(nouvelleDateFin))")
        }
        
        // Replanifier les alertes de fin
        planifierNotificationFinRepos(
            dateFin: nouvelleDateFin,
            nomExercice: currentState.nomExercice,
            numeroSerie: currentState.numeroSerie
        )
        programmerClotureAutomatique(a: nouvelleDateFin)
    }
    
    // MARK: - Clôture & Arrêt
    
    /// Clôture immédiatement la Live Activity (appui sur "Passer" ou expiration)
    public func endLiveActivity() {
        timerClotureAuto?.invalidate()
        timerClotureAuto = nil
        
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("🛑 Live Activity terminée.")
        }
        self.currentActivity = nil
    }
    
    // MARK: - Notifications & Timers Internes
    
    private func programmerClotureAutomatique(a dateFin: Date) {
        timerClotureAuto?.invalidate()
        let delai = dateFin.timeIntervalSinceNow
        guard delai > 0 else {
            endLiveActivity()
            return
        }
        
        timerClotureAuto = Timer.scheduledTimer(withTimeInterval: delai, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.endLiveActivity()
            }
        }
    }
    
    private func planifierNotificationFinRepos(dateFin: Date, nomExercice: String, numeroSerie: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["fin_repos_live_activity"])
        
        let delai = dateFin.timeIntervalSinceNow
        guard delai > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Repos terminé !"
        content.body = "Préparez-vous pour la série suivante de \(nomExercice)."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delai, repeats: false)
        let request = UNNotificationRequest(
            identifier: "fin_repos_live_activity",
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
}

// Rétro-compatibilité
public typealias LiveActivityManager = RestTimerActivityManager
