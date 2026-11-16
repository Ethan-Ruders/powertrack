//
//  HapticAndSoundManager.swift
//  PowerTrack
//
//  Created by ethan ruders on 10/11/2026.
//

import UIKit
import AVFoundation
import AudioToolbox

/// Gestionnaire centralisé pour les retours haptiques différenciés et les alertes sonores
/// respectant la musique en arrière-plan (Spotify / Apple Music) via `.duckOthers`.
final class HapticAndSoundManager {
    static let shared = HapticAndSoundManager()
    
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        prepareGenerators()
    }
    
    /// Prépare les moteurs haptiques pour une latence minimale ("In-Gym")
    func prepareGenerators() {
        selectionGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    // MARK: - Retours Haptiques Contextuels
    
    /// Incrémentation des boutons +/- ou sélection d'une pilule RPE : retour très sec à chaque cran
    func triggerSelection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    /// Impact léger pour les interactions secondaires
    func triggerLightImpact() {
        lightImpactGenerator.impactOccurred()
        lightImpactGenerator.prepare()
    }
    
    /// Validation d'une série standard : impact moyen + notification de succès
    func triggerSetValidated() {
        mediumImpactGenerator.impactOccurred()
        notificationGenerator.notificationOccurred(.success)
        mediumImpactGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    /// Validation d'un Top Set ou d'un nouveau record (e1RM max battu) : double vibration lourde (.heavy)
    func triggerPRValidated() {
        heavyImpactGenerator.impactOccurred(intensity: 1.0)
        notificationGenerator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            self?.heavyImpactGenerator.impactOccurred(intensity: 1.0)
            self?.heavyImpactGenerator.prepare()
        }
    }
    
    // MARK: - Audio Non-Intrusif (Audio Mix & Ducking)
    
    /// Configure la session audio pour ne jamais couper la musique en arrière-plan
    func configureAudioSessionForDucking() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers, .duckOthers])
        } catch {
            print("Erreur de configuration AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    /// Joue l'alerte sonore de fin de repos en baissant légèrement le volume de la musique
    /// pendant ~1 seconde (.duckOthers), puis restaure le volume initial sans pause.
    func playRestFinishedAlert(isCritical: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Erreur d'activation AVAudioSession: \(error.localizedDescription)")
        }
        
        // Son système clair + vibration de fin de repos
        let soundID: SystemSoundID = isCritical ? 1005 : 1057
        AudioServicesPlayAlertSound(soundID)
        
        if isCritical {
            heavyImpactGenerator.impactOccurred()
        } else {
            notificationGenerator.notificationOccurred(.warning)
        }
        
        // Relâche le ducking après 1 seconde pour que Spotify/Apple Music remonte à 100%
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            do {
                try session.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                print("Erreur de désactivation AVAudioSession: \(error.localizedDescription)")
            }
        }
    }
}
