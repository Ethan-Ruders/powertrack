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
/// respectant la musique en arrière-plan (Spotify / Apple Music) via `.duckOthers` et fonctionnant en mode silencieux.
final class HapticAndSoundManager {
    static let shared = HapticAndSoundManager()
    
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private var audioPlayer: AVAudioPlayer?
    private var deactivationWorkItem: DispatchWorkItem?
    
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
    
    // MARK: - Audio Non-Intrusif (Playback + Mix & Ducking)
    
    /// Configure la session audio au repos sans baisser le volume de la musique tant qu'aucune alerte n'est jouée.
    func configureAudioSessionForDucking() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            print("Erreur de configuration AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    /// Joue une alerte sonore synthétisée en mémoire via `AVAudioPlayer` (audible même en mode silencieux)
    /// en baissant temporairement Spotify / Apple Music (`.duckOthers`), puis restaure le volume initial.
    func playRestFinishedAlert(isCritical: Bool = false) {
        deactivationWorkItem?.cancel()
        deactivationWorkItem = nil
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Erreur d'activation AVAudioSession: \(error.localizedDescription)")
        }
        
        let notes: [(freq: Double, duration: Double, gapAfter: Double)] = isCritical
            ? [(880.0, 0.14, 0.08), (1174.66, 0.22, 0.0)]
            : [(880.0, 0.18, 0.0)]
        
        let wavData = Self.makeToneWAVData(notes: notes)
        do {
            let player = try AVAudioPlayer(data: wavData)
            player.volume = 0.85
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            let fallbackID: SystemSoundID = isCritical ? 1005 : 1057
            AudioServicesPlayAlertSound(fallbackID)
        }
        
        if isCritical {
            heavyImpactGenerator.impactOccurred()
        } else {
            notificationGenerator.notificationOccurred(.warning)
        }
        
        // Relâche le ducking après ~0.85s pour que Spotify / Apple Music remonte à 100% sans pause
        let workItem = DispatchWorkItem {
            Task { @MainActor in
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                } catch {
                    print("Erreur de désactivation AVAudioSession: \(error.localizedDescription)")
                }
            }
        }
        deactivationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: workItem)
    }
    
    // MARK: - Synthèse PCM / WAV en Mémoire
    
    /// Génère des données WAV 16-bit PCM mono 44.1 kHz pour éviter toute dépendance à un fichier audio externe.
    private static func makeToneWAVData(notes: [(freq: Double, duration: Double, gapAfter: Double)]) -> Data {
        let sampleRate: Double = 44100.0
        var pcmSamples: [Int16] = []
        let fadeSamples = Int(sampleRate * 0.010) // 10 ms anti-clic
        
        for note in notes {
            let count = max(1, Int(sampleRate * note.duration))
            for i in 0..<count {
                let t = Double(i) / sampleRate
                var env = 1.0
                if i < fadeSamples {
                    env = Double(i) / Double(max(1, fadeSamples))
                } else if i > count - fadeSamples {
                    env = Double(max(0, count - i)) / Double(max(1, fadeSamples))
                }
                let decay = exp(-3.5 * t)
                let wave = sin(2.0 * Double.pi * note.freq * t)
                let amplitude = max(-1.0, min(1.0, wave * env * decay * 0.65))
                pcmSamples.append(Int16(amplitude * Double(Int16.max)))
            }
            
            let gapCount = max(0, Int(sampleRate * note.gapAfter))
            if gapCount > 0 {
                pcmSamples.append(contentsOf: repeatElement(Int16(0), count: gapCount))
            }
        }
        
        let dataByteCount = UInt32(pcmSamples.count * MemoryLayout<Int16>.size)
        let chunkSize = UInt32(36) + dataByteCount
        var data = Data()
        data.reserveCapacity(44 + Int(dataByteCount))
        
        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndianBytes: chunkSize)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndianBytes: UInt32(16))        // Subchunk1Size (PCM)
        data.append(littleEndianBytes: UInt16(1))         // AudioFormat (PCM = 1)
        data.append(littleEndianBytes: UInt16(1))         // NumChannels (Mono)
        data.append(littleEndianBytes: UInt32(44100))     // SampleRate
        data.append(littleEndianBytes: UInt32(44100 * 2)) // ByteRate
        data.append(littleEndianBytes: UInt16(2))         // BlockAlign
        data.append(littleEndianBytes: UInt16(16))        // BitsPerSample
        data.append(contentsOf: "data".utf8)
        data.append(littleEndianBytes: dataByteCount)
        
        for sample in pcmSamples {
            data.append(littleEndianBytes: sample)
        }
        return data
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndianBytes value: T) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { bytes in
            append(contentsOf: bytes)
        }
    }
}
