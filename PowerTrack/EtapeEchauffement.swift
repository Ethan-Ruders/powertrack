//
//  EtapeEchauffement.swift
//  PowerTrack
//
//  Created by ethan ruders on 13/08/2026.
//

import SwiftUI

// MARK: - Modèle d'un Palier d'Échauffement

struct EtapeEchauffement: Identifiable {
    let id: Int
    let numeroPalier: Int
    let labelPourcentage: String
    let chargeKg: Double
    let reps: Int
    let roleDescription: String
    
    /// Formatage propre de la charge (ex: "85" ou "82.5")
    var chargeFormatee: String {
        if chargeKg.truncatingRemainder(dividingBy: 1.0) == 0 {
            return String(format: "%.0f", chargeKg)
        } else {
            return String(format: "%.1f", chargeKg)
        }
    }
    
    /// Format exact demandé : "Charge kg × Reps" (ex: "85 kg × 3 reps")
    var formatChargeReps: String {
        let motRep = reps > 1 ? "reps" : "rep"
        return "\(chargeFormatee) kg × \(reps) \(motRep)"
    }
}

// MARK: - Algorithme de Génération Spécifique au Top Set (SBD & Accessoires)

func genererPaliersEchauffement(pour exercice: Exercice, chargeCibleOverride: Double? = nil) -> [EtapeEchauffement] {
    let type = exercice.typeEchauffement
    let wCible = chargeCibleOverride ?? exercice.chargeCibleTopSet ?? 0.0
    let rCible = max(1, exercice.repsCiblesTopSet)
    let rpeCible = exercice.rpeCibleTopSet
    
    switch type {
    case .aucun:
        return []
        
    case .polyarticulaireAccessoire:
        // Cas B — Mouvements Polyarticulaires Accessoires (> 20 kg) :
        // 2 séries légères d'acclimatation uniquement (50% × 8 reps, puis 75% × 5 reps), sans barre à vide
        guard wCible > 20.0 else { return [] }
        
        var paliers: [EtapeEchauffement] = []
        let ciblesAccessoire: [(pct: Double, label: String, reps: Int, role: String)] = [
            (0.50, "50%", 8, "Acclimatation articulaire"),
            (0.75, "75%", 5, "Transition vers série de travail")
        ]
        
        var dernierPoids: Double = 0.0
        for item in ciblesAccessoire {
            let poidsArrondi = round((wCible * item.pct) / 2.5) * 2.5
            if poidsArrondi > 0 && poidsArrondi < wCible && poidsArrondi > dernierPoids {
                let num = paliers.count + 1
                paliers.append(
                    EtapeEchauffement(
                        id: num,
                        numeroPalier: num,
                        labelPourcentage: item.label,
                        chargeKg: poidsArrondi,
                        reps: item.reps,
                        roleDescription: item.role
                    )
                )
                dernierPoids = poidsArrondi
            }
        }
        return paliers
        
    case .sbdOuVariante:
        // Cas A — Mouvements SBD & Variantes : montée en gamme complète (5 paliers avec barre à vide)
        var paliers: [EtapeEchauffement] = []
        
        // Palier 1 (Déverrouillage articulaire) : Barre à vide (20 kg) × 10 reps (8 à 10 reps)
        paliers.append(
            EtapeEchauffement(
                id: 1,
                numeroPalier: 1,
                labelPourcentage: "Barre à vide",
                chargeKg: 20.0,
                reps: 10,
                roleDescription: "Déverrouillage articulaire"
            )
        )
        
        guard wCible > 20.0 else { return paliers }
        
        // Calcul des répétitions spécifiques calquées sur le Top Set (rCible)
        let repsPalier2 = (rCible == 1) ? 3 : rCible
        let repsPalier3 = rCible
        let repsPalier4 = (rCible <= 3) ? rCible : 3
        let repsPalier5 = (rpeCible <= 6.0) ? rCible : 1
        
        let matriceSBD: [(pct: Double, label: String, reps: Int, role: String)] = [
            (0.50, "50%", repsPalier2, "Calibrage technique"),
            (0.70, "70%", repsPalier3, "Montée spécifique"),
            (0.85, "85%", repsPalier4, "Pré-activation lourde"),
            (0.925, "92.5%", repsPalier5, "Activation nerveuse")
        ]
        
        var dernierPoids: Double = 20.0
        for item in matriceSBD {
            let poidsArrondi = round((wCible * item.pct) / 2.5) * 2.5
            // Ignorer tout palier <= 20 kg, >= wCible, ou doublon du palier précédent
            if poidsArrondi > 20.0 && poidsArrondi < wCible && poidsArrondi > dernierPoids {
                let num = paliers.count + 1
                paliers.append(
                    EtapeEchauffement(
                        id: num,
                        numeroPalier: num,
                        labelPourcentage: item.label,
                        chargeKg: poidsArrondi,
                        reps: item.reps,
                        roleDescription: item.role
                    )
                )
                dernierPoids = poidsArrondi
            }
        }
        
        return paliers
    }
}

// MARK: - Vue Feuille d'Échauffement (WarmupSheet)

struct EchauffementSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    let exercice: Exercice
    
    @State private var poidsVise: Double? = nil
    @State private var paliersCoches: Set<Int> = []
    
    private var paliers: [EtapeEchauffement] {
        genererPaliersEchauffement(pour: exercice, chargeCibleOverride: poidsVise)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // En-tête récapitulatif du Top Set visé
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Objectif Top Set (\(exercice.repsCiblesTopSet) \(exercice.repsCiblesTopSet > 1 ? "reps" : "rep"))")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            Text(exercice.estSBDOuVariante ? "Montée SBD spécifique" : "Acclimatation polyarticulaire")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Champ compact de charge cible (pré-rempli depuis la 1ère série)
                        HStack(spacing: 4) {
                            TextField("Charge", value: $poidsVise, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.headline.weight(.bold).monospacedDigit())
                                .foregroundColor(.orange)
                                .frame(width: 64)
                            
                            Text("kg")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(16)
                    .background(Color(white: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Liste des paliers générés avec cases à cocher
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paliers d'échauffement")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(paliers.enumerated()), id: \.element.id) { index, palier in
                                let estCoche = paliersCoches.contains(palier.id)
                                
                                Button(action: {
                                    HapticAndSoundManager.shared.triggerSelection()
                                    withAnimation(.snappy(duration: 0.2)) {
                                        if estCoche {
                                            paliersCoches.remove(palier.id)
                                        } else {
                                            paliersCoches.insert(palier.id)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        // Numéro du palier & pourcentage
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Palier \(palier.numeroPalier) • \(palier.labelPourcentage)")
                                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                                .foregroundColor(estCoche ? .secondary : .white)
                                                .strikethrough(estCoche, color: .secondary)
                                                .lineLimit(1)
                                            
                                            Text(palier.roleDescription)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        // Format exact : Charge kg × Reps
                                        Text(palier.formatChargeReps)
                                            .font(.subheadline.weight(.bold).monospacedDigit())
                                            .foregroundColor(estCoche ? .secondary : .orange)
                                            .strikethrough(estCoche, color: .secondary)
                                            .lineLimit(1)
                                        
                                        // Case à cocher simple
                                        Image(systemName: estCoche ? "checkmark.circle.fill" : "circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(estCoche ? .green : Color(white: 0.35))
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 54)
                                    .contentShape(Rectangle())
                                    .opacity(estCoche ? 0.55 : 1.0)
                                }
                                .buttonStyle(.plain)
                                
                                if index < paliers.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.08))
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(white: 0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Échauffement • \(exercice.nom)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                if poidsVise == nil {
                    poidsVise = exercice.chargeCibleTopSet
                }
            }
        }
    }
}
