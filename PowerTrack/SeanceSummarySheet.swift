//
//  SeanceSummarySheet.swift
//  PowerTrack
//
//  Created by ethan ruders on 17/09/2026.
//

import SwiftUI

struct TopSetSummaryItem: Identifiable {
    let id = UUID()
    let nomExercice: String
    let charge: Double
    let reps: Int
    let rpeCible: Double
    let rpeReel: Double?
    let e1RM: Double?
}

struct SeanceSummarySheet: View {
    let seance: Seance
    @Environment(\.dismiss) private var dismiss
    
    // Calculs de synthèse
    private var seriesValidees: [(exercice: Exercice, serie: Serie)] {
        var res: [(exercice: Exercice, serie: Serie)] = []
        for ex in seance.exercices {
            for s in ex.series where s.estValidee {
                res.append((exercice: ex, serie: s))
            }
        }
        return res
    }
    
    private var tonnageTotalKg: Double {
        seriesValidees.reduce(0) { total, item in
            let charge = item.serie.chargeSaisie ?? 0
            return total + (charge * Double(item.serie.repsCibles))
        }
    }
    
    private var tonnageTotalTonnes: Double {
        tonnageTotalKg / 1000.0
    }
    
    private var meilleurE1RMSession: (exercice: String, charge: Double)? {
        var top: (exercice: String, charge: Double)? = nil
        for item in seriesValidees {
            if let e1rm = item.serie.calculerE1RM() {
                if top == nil || e1rm > top!.charge {
                    top = (item.exercice.nom, e1rm)
                }
            }
        }
        return top
    }
    
    private var topSetsRealises: [TopSetSummaryItem] {
        var items: [TopSetSummaryItem] = []
        for ex in seance.exercices {
            // Prendre la série la plus lourde de l'exercice
            let seriesVal = ex.series.filter { $0.estValidee }
            if let heaviest = seriesVal.max(by: { ($0.chargeSaisie ?? 0) < ($1.chargeSaisie ?? 0) }) {
                items.append(TopSetSummaryItem(
                    nomExercice: ex.nom,
                    charge: heaviest.chargeSaisie ?? 0,
                    reps: heaviest.repsCibles,
                    rpeCible: heaviest.rpeCible,
                    rpeReel: heaviest.rpeSaisi,
                    e1RM: heaviest.calculerE1RM()
                ))
            }
        }
        return items
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Badge de félicitation
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.orange)
                        
                        Text("Séance Terminée !")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(seance.titre ?? seance.date.formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)
                    
                    // Grille KPI
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        kpiCard(
                            titre: "Tonnage Total",
                            valeur: String(format: "%.2f t", tonnageTotalTonnes),
                            detail: "\(Int(tonnageTotalKg)) kg déplacés",
                            systemImage: "scalemass.fill",
                            couleur: .orange
                        )
                        
                        kpiCard(
                            titre: "Meilleur e1RM",
                            valeur: meilleurE1RMSession != nil ? "\(Int(meilleurE1RMSession!.charge)) kg" : "-",
                            detail: meilleurE1RMSession?.exercice ?? "Aucun calculé",
                            systemImage: "flame.fill",
                            couleur: .red
                        )
                        
                        kpiCard(
                            titre: "Séries Validées",
                            valeur: "\(seriesValidees.count)",
                            detail: "sur \(seance.exercices.reduce(0) { $0 + $1.series.count }) programmées",
                            systemImage: "checklist.checked",
                            couleur: .green
                        )
                        
                        kpiCard(
                            titre: "Durée Estimée",
                            valeur: dureeEstimeeTexte,
                            detail: "Repos & Exécution",
                            systemImage: "stopwatch.fill",
                            couleur: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // Liste des Top Sets avec RPE Réel vs Cible
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Sets & Intensité")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            ForEach(topSetsRealises) { top in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(top.nomExercice)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 6) {
                                            Text("\(Int(top.charge)) kg × \(top.reps)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                            
                                            if let e1rm = top.e1RM {
                                                Text("• e1RM: \(Int(e1rm)) kg")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Badge RPE Cible vs Réel
                                    VStack(alignment: .trailing, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text("RPE")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            
                                            if let reel = top.rpeReel {
                                                Text(String(format: "%.1f", reel))
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(couleurPourRPE(reel: reel, cible: top.rpeCible))
                                            } else {
                                                Text("-")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        Text("cible: @\(String(format: "%.0f", top.rpeCible))")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(UIColor.darkGray).opacity(0.4))
                                    .cornerRadius(8)
                                }
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        let impact = UINotificationFeedbackGenerator()
                        impact.notificationOccurred(.success)
                        dismiss()
                    }) {
                        Text("Valider et Fermer")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Helpers UI
    
    private func kpiCard(titre: String, valeur: String, detail: String, systemImage: String, couleur: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(couleur)
                Spacer()
            }
            
            Text(valeur)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(titre)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(couleur.opacity(0.8))
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
        .cornerRadius(14)
    }
    
    private var dureeEstimeeTexte: String {
        // Estimation basée sur les temps de repos des séries validées (~3 min / série + warmup)
        let minutes = max(45, seriesValidees.count * 4)
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }
    
    private func couleurPourRPE(reel: Double, cible: Double) -> Color {
        let diff = reel - cible
        if diff <= 0.0 {
            return .green // Respect parfait ou plus facile
        } else if diff <= 0.5 {
            return .orange // Légèrement plus dur
        } else {
            return .red // Dépassement d'effort
        }
    }
}
