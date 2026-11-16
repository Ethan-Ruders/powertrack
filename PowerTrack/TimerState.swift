//
//  TimerState.swift
//  PowerTrack
//
//  Created by ethan ruders on 16/07/2026.
//

import Foundation
import UserNotifications
import Combine

/// Les différents états possibles du chronomètre
enum TimerState {
    case inactive
    case running
    case paused
    case finished
}

class TimerManager: ObservableObject {
    // MARK: - Propriétés Publiques (UI)
    @Published var state: TimerState = .inactive
    @Published var tempsEcoule: TimeInterval = 0
    @Published var tempsRestantMin: TimeInterval = 0
    @Published var tempsRestantMax: TimeInterval = 0
    
    // Propriétés de référence pour l'interface
    @Published var minAlertDuration: TimeInterval = 0
    @Published var maxAlertDuration: TimeInterval = 0
    
    // MARK: - Propriétés Privées (Logique interne)
    private var timer: Timer?
    private var dateDemarrage: Date?
    private var tempsEcouleAvantPause: TimeInterval = 0
    private var aJoueAlerteMin: Bool = false
    private var aJoueAlerteMax: Bool = false
    
    // MARK: - Initialisation
    init() {
        demanderAutorisationNotifications()
        HapticAndSoundManager.shared.configureAudioSessionForDucking()
    }
    
    // MARK: - Méthodes Principales
    
    /// Démarre le chronomètre en fonction de la série validée
    func startTimer(for serie: Serie, exercice: Exercice) {
        // 1. Nettoyage d'un éventuel chronomètre précédent
        stopTimer()
        
        // 2. Calcul des durées selon la matrice de force athlétique
        let rpePourChrono = serie.rpeSaisi ?? serie.rpeCible
        let durees = calculerDureesAlerte(categorie: exercice.categorie, rpe: rpePourChrono)
        self.minAlertDuration = durees.min
        self.maxAlertDuration = durees.max
        
        // 3. Initialisation des temps
        self.tempsEcoule = 0
        self.tempsRestantMin = minAlertDuration
        self.tempsRestantMax = maxAlertDuration
        self.tempsEcouleAvantPause = 0
        self.aJoueAlerteMin = false
        self.aJoueAlerteMax = false
        self.dateDemarrage = Date()
        
        // 4. Lancement de la boucle de rafraîchissement (pour l'UI)
        self.state = .running
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTemps()
        }
        
        // 5. Planification des notifications locales
        planifierNotifications(minDuration: minAlertDuration, maxDuration: maxAlertDuration)
        
        // 6. Démarrage de la Live Activity sur l'écran de verrouillage
        let dureeChrono = maxAlertDuration > 0 ? maxAlertDuration : minAlertDuration
        let numSerie = (exercice.series.firstIndex(where: { $0.id == serie.id }) ?? 0) + 1
        LiveActivityManager.shared.startLiveActivity(
            nomExercice: exercice.nom,
            numeroSerie: numSerie,
            dureeSecondes: dureeChrono
        )
    }
    
    /// Met le chronomètre en pause
    func pauseTimer() {
        guard state == .running else { return }
        timer?.invalidate()
        tempsEcouleAvantPause = tempsEcoule
        dateDemarrage = nil
        state = .paused
        
        // On annule les notifications car les temps cibles vont changer
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Reprend le chronomètre après une pause
    func resumeTimer() {
        guard state == .paused else { return }
        dateDemarrage = Date()
        state = .running
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTemps()
        }
        
        // Re-planification des notifications avec le temps restant
        planifierNotifications(minDuration: tempsRestantMin, maxDuration: tempsRestantMax)
    }
    
    /// Arrête le chronomètre et réinitialise les valeurs
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        dateDemarrage = nil
        state = .inactive
        tempsEcoule = 0
        tempsRestantMin = 0
        tempsRestantMax = 0
        tempsEcouleAvantPause = 0
        aJoueAlerteMin = false
        aJoueAlerteMax = false
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        LiveActivityManager.shared.endLiveActivity()
    }
    
    /// Ajoute du temps au chronomètre en cours (+30s par défaut)
    func ajouterTemps(_ secondes: TimeInterval = 30) {
        minAlertDuration += secondes
        maxAlertDuration += secondes
        tempsRestantMin += secondes
        tempsRestantMax += secondes
        if tempsRestantMin > 0 { aJoueAlerteMin = false }
        if tempsRestantMax > 0 { aJoueAlerteMax = false }
        LiveActivityManager.shared.ajouterTemps(secondes)
        planifierNotifications(minDuration: tempsRestantMin, maxDuration: tempsRestantMax)
    }
    
    // MARK: - Logique Interne
    
    /// Mise à jour continue calculée sur le delta de temps absolu (Robuste en arrière-plan)
    private func updateTemps() {
        guard let dateDemarrage = dateDemarrage else { return }
        
        let delta = Date().timeIntervalSince(dateDemarrage)
        tempsEcoule = tempsEcouleAvantPause + delta
        
        // Empêche les temps restants de passer en négatif dans l'UI
        tempsRestantMin = max(0, minAlertDuration - tempsEcoule)
        tempsRestantMax = max(0, maxAlertDuration - tempsEcoule)
        
        // Alerte sonore non-intrusive (.duckOthers) au palier minimal
        if minAlertDuration > 0 && tempsRestantMin == 0 && !aJoueAlerteMin {
            aJoueAlerteMin = true
            HapticAndSoundManager.shared.playRestFinishedAlert(isCritical: false)
        }
        
        if tempsRestantMax == 0 {
            if !aJoueAlerteMax && maxAlertDuration > minAlertDuration {
                aJoueAlerteMax = true
                HapticAndSoundManager.shared.playRestFinishedAlert(isCritical: true)
            }
            state = .finished
            timer?.invalidate()
        }
    }
    
    /// Matrice de calcul des temps de repos
    private func calculerDureesAlerte(categorie: CategorieExercice, rpe: Double) -> (min: TimeInterval, max: TimeInterval) {
        if rpe < 5.0 {
            switch categorie {
            case .isolation:
                return (0, 30) // Repos très court
            case .polyarticulaire, .competition:
                break // On sort du if pour appliquer le repos normal ci-dessous
            }
        }
        
        switch categorie {
        case .isolation:
            return (90, 90)
        case .polyarticulaire:
            return (180, 180)
        case .competition:
            if rpe <= 6.0 {
                return (180, 240)
            } else if rpe <= 7.0 {
                return (240, 300)
            } else if rpe <= 8.0 {
                return (300, 360)
            } else if rpe <= 9.0 {
                return (420, 540)
            } else {
                return (420, 600)
            }
        }
    }
    
    // MARK: - Système de Notifications Locales
    
    private func demanderAutorisationNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { accorde, erreur in
            if let erreur = erreur {
                print("Erreur d'autorisation pour les notifications : \(erreur.localizedDescription)")
            }
        }
    }
    
    private func planifierNotifications(minDuration: TimeInterval, maxDuration: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests() // Nettoyage de sécurité
        
        // 1. Notification de l'alerte minimale
        if minDuration > 0 {
            let contentMin = UNMutableNotificationContent()
            contentMin.title = "Repos terminé"
            contentMin.body = "Alerte minimale atteinte : Tu peux repartir !"
            contentMin.sound = .default
            
            let triggerMin = UNTimeIntervalNotificationTrigger(timeInterval: minDuration, repeats: false)
            let requestMin = UNNotificationRequest(identifier: "alerteMin", content: contentMin, trigger: triggerMin)
            center.add(requestMin)
        }
        
        // 2. Notification de l'alerte maximale (uniquement si elle est différente de l'alerte min)
        if maxDuration > 0 && maxDuration > minDuration {
            let contentMax = UNMutableNotificationContent()
            contentMax.title = "Fin du temps de repos"
            contentMax.body = "Alerte maximale atteinte : Il est temps de repartir !"
            contentMax.sound = .defaultCritical
            
            let triggerMax = UNTimeIntervalNotificationTrigger(timeInterval: maxDuration, repeats: false)
            let requestMax = UNNotificationRequest(identifier: "alerteMax", content: contentMax, trigger: triggerMax)
            center.add(requestMax)
        }
    }
}
