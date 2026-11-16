//
//  SeanceExportDTO.swift
//  PowerTrack
//
//  Created by ethan ruders on 13/08/2026.
//


import Foundation

// MARK: - Structures DTO (Data Transfer Objects) pour le JSON
struct SeanceExportDTO: Codable {
    let date: String
    let semaineNom: String
    let exercices: [ExerciceExportDTO]
}

struct ExerciceExportDTO: Codable {
    let nom: String
    let series: [SerieExportDTO]
}

struct SerieExportDTO: Codable {
    let reps: Int
    let charge: Double
    let rpe: Double
    let e1RM: Double
}

// MARK: - Manager d'Export
class ExportManager {
    // Utilisation d'un singleton pour un accès facile
    static let shared = ExportManager()
    
    private init() {} // Empêche l'initialisation multiple
    
    /// Transforme une séance en JSON et l'envoie via une requête POST
    func exporterSeance(seance: Seance, webhookURL: String) async {
        // 1. Préparation de la date
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: seance.date)
        
        // 2. Mapping des exercices et des séries validées
        var exercicesExport = [ExerciceExportDTO]()
        
        let exercicesTries = seance.exercices.sorted { $0.ordre < $1.ordre }
        
        for exercice in exercicesTries {
            var seriesExport = [SerieExportDTO]()
            
            // On ne filtre que les séries validées
            let seriesValidees = exercice.series.filter { $0.estValidee }
            
            for serie in seriesValidees {
                // On s'assure que les données saisies existent
                if let charge = serie.chargeSaisie, let rpe = serie.rpeSaisi {
                    let e1rm = calculerE1RM(charge: charge, reps: serie.repsCibles, rpe: rpe)
                    
                    let serieDTO = SerieExportDTO(
                        reps: serie.repsCibles,
                        charge: charge,
                        rpe: rpe,
                        e1RM: e1rm
                    )
                    seriesExport.append(serieDTO)
                }
            }
            
            // On n'ajoute l'exercice au JSON que s'il contient des séries validées
            if !seriesExport.isEmpty {
                let exerciceDTO = ExerciceExportDTO(nom: exercice.nom, series: seriesExport)
                exercicesExport.append(exerciceDTO)
            }
        }
        
        // 3. Construction de l'objet final (On présume que ta relation inverse vers Semaine s'appelle 'semaine')
        // Si la relation inverse n'est pas codée, tu peux simplement mettre "Semaine actuelle" ou la passer en paramètre.
        let nomSemaine = "Semaine en cours" // Remplace par `seance.semaine.nom` si la relation inverse existe
        
        let exportData = SeanceExportDTO(
            date: dateString,
            semaineNom: nomSemaine,
            exercices: exercicesExport
        )
        
        // 4. Envoi de la requête réseau
        guard let url = URL(string: webhookURL) else {
            print("URL de webhook invalide")
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Encodage en JSON
            let encoder = JSONEncoder()
            // Optionnel : formate le JSON pour qu'il soit lisible dans la console
            encoder.outputFormatting = .prettyPrinted 
            request.httpBody = try encoder.encode(exportData)
            
            // Pour débugger, affichons le JSON dans la console Xcode
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("📤 Préparation de l'envoi JSON :\n\(jsonString)")
            }
            
            // Exécution de la requête
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Statut de la réponse : \(httpResponse.statusCode)")
            }
            
        } catch {
            print("❌ Erreur lors de l'exportation : \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Mathématique
    private func calculerE1RM(charge: Double, reps: Int, rpe: Double) -> Double {
        guard charge > 0, reps > 0, rpe > 0, rpe <= 10 else { return 0 }
        let repsALechecTheorique = Double(reps) + (10.0 - rpe)
        
        if repsALechecTheorique <= 1.0 {
            return round(charge / 2.5) * 2.5
        }
        let e1rmBrut = charge * (1.0 + repsALechecTheorique / 30.0)
        return round(e1rmBrut / 2.5) * 2.5
    }
}