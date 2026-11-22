//
//  TimerState.swift
//  PowerTrack
//
//  Created by ethan ruders on 16/07/2026.
//

import Foundation
import UserNotifications
import Combine
import UIKit
import ActivityKit

/// Les différents états possibles du chronomètre
enum TimerState {
    case inactive
    case running
    case paused
    case finished
}

@MainActor
final class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
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
    private var dateFinMin: Date?
    private var dateFinMax: Date?
    private var tempsEcouleAvantPause: TimeInterval = 0
    private var aJoueAlerteMin: Bool = false
    private var aJoueAlerteMax: Bool = false
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Initialisation
    init() {
        demanderAutorisationNotifications()
        HapticAndSoundManager.shared.configureAudioSessionForDucking()
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { _ in
                Task { @MainActor in
                    TimerManager.shared.rafraichirDepuisHorloge()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Méthodes Principales
    
    /// Démarre le chronomètre en fonction de la série validée
    func startTimer(for serie: Serie, exercice: Exercice) {
        // 1. Nettoyage local sans clôture asynchrone superflue (startLiveActivity clôture les anciennes)
        reinitialiserEtatLocal()
        
        // 2. Calcul des durées selon la matrice de force athlétique
        let rpePourChrono = serie.rpeSaisi ?? serie.rpeCible
        let durees = calculerDureesAlerte(categorie: exercice.categorie, rpe: rpePourChrono)
        self.minAlertDuration = durees.min
        self.maxAlertDuration = durees.max
        
        // 3. Initialisation des horodatages absolus
        let now = Date()
        self.dateDemarrage = now
        self.dateFinMin = now.addingTimeInterval(minAlertDuration)
        self.dateFinMax = now.addingTimeInterval(maxAlertDuration)
        self.tempsEcoule = 0
        self.tempsRestantMin = minAlertDuration
        self.tempsRestantMax = maxAlertDuration
        self.tempsEcouleAvantPause = 0
        self.aJoueAlerteMin = false
        self.aJoueAlerteMax = false
        
        // 4. Lancement de la boucle de rafraîchissement (pour l'UI)
        self.state = .running
        demarrerBoucleTimer()
        
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
        updateTemps()
        timer?.invalidate()
        timer = nil
        tempsEcouleAvantPause = tempsEcoule
        dateDemarrage = nil
        dateFinMin = nil
        dateFinMax = nil
        state = .paused
        
        // On annule les notifications car les temps cibles vont changer
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Reprend le chronomètre après une pause
    func resumeTimer() {
        guard state == .paused else { return }
        let now = Date()
        dateDemarrage = now.addingTimeInterval(-tempsEcouleAvantPause)
        dateFinMin = now.addingTimeInterval(tempsRestantMin)
        dateFinMax = now.addingTimeInterval(tempsRestantMax)
        state = .running
        
        demarrerBoucleTimer()
        planifierNotifications(minDuration: tempsRestantMin, maxDuration: tempsRestantMax)
    }
    
    /// Arrête le chronomètre et réinitialise les valeurs
    func stopTimer() {
        reinitialiserEtatLocal()
        LiveActivityManager.shared.endLiveActivity()
    }
    
    /// Arrête le chronomètre depuis une LiveActivityIntent et attend la clôture ActivityKit.
    func stopTimerDepuisIntent() async {
        reinitialiserEtatLocal()
        await LiveActivityManager.shared.endLiveActivityAsync()
    }
    
    /// Ajoute du temps au chronomètre en cours (+30s par défaut)
    func ajouterTemps(_ secondes: TimeInterval = 30) {
        if let nouvelleDateFin = appliquerAjoutTempsLocal(secondes) {
            Task {
                await LiveActivityManager.shared.mettreAJourDateFinAsync(nouvelleDateFin)
            }
        } else if state == .inactive {
            Task {
                await ajouterTempsDepuisIntent(secondes)
            }
        }
    }
    
    /// Ajoute du temps depuis une LiveActivityIntent et attend la mise à jour ActivityKit.
    func ajouterTempsDepuisIntent(_ secondes: TimeInterval = 30) async {
        if let nouvelleDateFin = appliquerAjoutTempsLocal(secondes) {
            await LiveActivityManager.shared.mettreAJourDateFinAsync(nouvelleDateFin)
        } else if state == .inactive {
            if let updated = await LiveActivityManager.shared.ajouterTempsDirectAsync(secondes) {
                self.dateDemarrage = updated.dateDebutRepos
                self.dateFinMin = updated.dateFinRepos
                self.dateFinMax = updated.dateFinRepos
                self.minAlertDuration = updated.dureeTotale
                self.maxAlertDuration = updated.dureeTotale
                self.tempsEcouleAvantPause = 0
                self.aJoueAlerteMin = false
                self.aJoueAlerteMax = false
                self.state = .running
                updateTemps()
                demarrerBoucleTimer()
                planifierNotifications(minDuration: tempsRestantMin, maxDuration: tempsRestantMax)
            }
        }
    }
    
    /// Resynchronise le chronomètre avec l'horloge absolue et la Live Activity au retour au premier plan.
    func rafraichirDepuisHorloge() {
        if state == .running {
            updateTemps()
        } else if state == .inactive {
            if let activity = Activity<RestTimerAttributes>.activities.first {
                let st = activity.content.state
                if st.dateFinRepos > Date() {
                    self.dateDemarrage = st.dateDebutRepos
                    self.dateFinMin = st.dateFinRepos
                    self.dateFinMax = st.dateFinRepos
                    self.minAlertDuration = st.dureeTotale
                    self.maxAlertDuration = st.dureeTotale
                    self.tempsEcouleAvantPause = 0
                    self.aJoueAlerteMin = false
                    self.aJoueAlerteMax = false
                    self.state = .running
                    updateTemps()
                    demarrerBoucleTimer()
                }
            }
        }
    }
    
    // MARK: - Logique Interne
    
    private func reinitialiserEtatLocal() {
        timer?.invalidate()
        timer = nil
        dateDemarrage = nil
        dateFinMin = nil
        dateFinMax = nil
        state = .inactive
        tempsEcoule = 0
        tempsRestantMin = 0
        tempsRestantMax = 0
        minAlertDuration = 0
        maxAlertDuration = 0
        tempsEcouleAvantPause = 0
        aJoueAlerteMin = false
        aJoueAlerteMax = false
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    private func demarrerBoucleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                TimerManager.shared.updateTemps()
            }
        }
    }
    
    private func appliquerAjoutTempsLocal(_ secondes: TimeInterval) -> Date? {
        if state == .paused {
            minAlertDuration += secondes
            maxAlertDuration += secondes
            tempsRestantMin += secondes
            tempsRestantMax += secondes
            return nil
        }
        
        guard state == .running || state == .finished else {
            return nil
        }
        
        let now = Date()
        let baseStart = dateDemarrage ?? now.addingTimeInterval(-tempsEcoule)
        dateDemarrage = baseStart
        
        let oldMax = dateFinMax ?? now
        let nouvelleDateFinMax = max(now, oldMax).addingTimeInterval(secondes)
        let wasSameMinMax = abs(maxAlertDuration - minAlertDuration) < 0.5
        
        dateFinMax = nouvelleDateFinMax
        if wasSameMinMax {
            dateFinMin = nouvelleDateFinMax
        } else if let oldMin = dateFinMin, oldMin > now {
            dateFinMin = oldMin.addingTimeInterval(secondes)
        }
        
        let effectiveFinMin = dateFinMin ?? now
        minAlertDuration = max(0, effectiveFinMin.timeIntervalSince(baseStart))
        maxAlertDuration = max(0, nouvelleDateFinMax.timeIntervalSince(baseStart))
        tempsEcoule = max(0, now.timeIntervalSince(baseStart))
        tempsRestantMin = max(0, effectiveFinMin.timeIntervalSince(now))
        tempsRestantMax = max(0, nouvelleDateFinMax.timeIntervalSince(now))
        
        aJoueAlerteMin = (tempsRestantMin <= 0)
        aJoueAlerteMax = false
        
        if state == .finished || timer == nil {
            state = .running
            demarrerBoucleTimer()
        }
        
        planifierNotifications(minDuration: tempsRestantMin, maxDuration: tempsRestantMax)
        return nouvelleDateFinMax
    }
    
    /// Mise à jour continue calculée sur le delta de temps absolu (Robuste en arrière-plan)
    private func updateTemps() {
        guard state == .running, let dateDemarrage = dateDemarrage else { return }
        
        let now = Date()
        let finMin = dateFinMin ?? dateDemarrage.addingTimeInterval(minAlertDuration)
        let finMax = dateFinMax ?? dateDemarrage.addingTimeInterval(maxAlertDuration)
        
        tempsEcoule = max(0, now.timeIntervalSince(dateDemarrage))
        tempsRestantMin = max(0, finMin.timeIntervalSince(now))
        tempsRestantMax = max(0, finMax.timeIntervalSince(now))
        
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
            timer = nil
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
        center.requestAuthorization(options: [.alert, .sound]) { _, erreur in
            if let erreur = erreur {
                print("Erreur d'autorisation pour les notifications : \(erreur.localizedDescription)")
            }
        }
    }
    
    private func planifierNotifications(minDuration: TimeInterval, maxDuration: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests() // Nettoyage de sécurité
        
        // 1. Notification de l'alerte minimale
        if minDuration >= 0.5 {
            let contentMin = UNMutableNotificationContent()
            contentMin.title = "Repos terminé"
            contentMin.body = "Alerte minimale atteinte : Tu peux repartir !"
            contentMin.sound = .default
            
            let triggerMin = UNTimeIntervalNotificationTrigger(timeInterval: minDuration, repeats: false)
            let requestMin = UNNotificationRequest(identifier: "alerteMin", content: contentMin, trigger: triggerMin)
            center.add(requestMin)
        }
        
        // 2. Notification de l'alerte maximale (uniquement si elle est différente de l'alerte min)
        if maxDuration >= 0.5 && maxDuration > minDuration {
            let contentMax = UNMutableNotificationContent()
            contentMax.title = "Fin du temps de repos"
            contentMax.body = "Alerte maximale atteinte : Il est temps de repartir !"
            contentMax.sound = .default
            
            let triggerMax = UNTimeIntervalNotificationTrigger(timeInterval: maxDuration, repeats: false)
            let requestMax = UNNotificationRequest(identifier: "alerteMax", content: contentMax, trigger: triggerMax)
            center.add(requestMax)
        }
    }
}
