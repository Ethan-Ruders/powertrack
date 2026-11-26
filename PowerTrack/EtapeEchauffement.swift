//
//  EtapeEchauffement.swift
//  PowerTrack
//
//  Created by ethan ruders on 13/08/2026.
//

import Foundation

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

#if os(iOS)
import SwiftUI

// MARK: - Vue Feuille d'Échauffement (WarmupSheet)

struct EchauffementSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    let exercice: Exercice
    
    @State private var poidsVise: Double? = nil
    @State private var paliersCoches: Set<Int> = []
    
    private var paliers: [EtapeEchauffement] {
        genererPaliersEchauffement(pour: exercice, chargeCibleOverride: poidsVise)
    }
    
    private var platesBreakdown: String? {
        guard let w = poidsVise, w > 20.0, exercice.estSBDOuVariante else { return nil }
        return PTBarbellPlateHelper.formattedPlatesPerSide(totalKg: w)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // En-tête éditorial : Charge cible + décomposition des disques
                    VStack(alignment: .leading, spacing: 10) {
                        PTKicker(text: "Charge cible · \(exercice.repsCiblesTopSet) \(exercice.repsCiblesTopSet > 1 ? "reps" : "rep")")
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("0", value: $poidsVise, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold).monospacedDigit())
                                .foregroundColor(PTTheme.textPrimary)
                                .frame(maxWidth: 120, alignment: .leading)
                            
                            Text("kg")
                                .font(.headline.weight(.medium))
                                .foregroundColor(PTTheme.textSecondary)
                            
                            Spacer()
                            
                            Text(exercice.estSBDOuVariante ? "Montée SBD" : "Acclimatation")
                                .font(.caption.weight(.medium))
                                .foregroundColor(PTTheme.textSecondary)
                        }
                        
                        if let plates = platesBreakdown {
                            Text("Barre 20 kg · \(plates)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundColor(PTTheme.accent)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    
                    PTHairline()
                    
                    // Paliers générés en liste bord-à-bord
                    VStack(alignment: .leading, spacing: 0) {
                        PTKicker(text: "Paliers d'échauffement")
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                            .padding(.bottom, 10)
                        
                        PTHairline()
                        
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
                                    Text(String(format: "%02d", palier.numeroPalier))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(estCoche ? PTTheme.textTertiary : PTTheme.accent)
                                        .frame(width: 24, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(palier.labelPourcentage)
                                            .font(.subheadline.weight(.semibold).monospacedDigit())
                                            .foregroundColor(PTTheme.textPrimary)
                                            .strikethrough(estCoche, color: PTTheme.textSecondary)
                                            .lineLimit(1)
                                        
                                        Text(palier.roleDescription)
                                            .font(.caption)
                                            .foregroundColor(PTTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer(minLength: 6)
                                    
                                    Text(palier.formatChargeReps)
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                        .foregroundColor(estCoche ? PTTheme.textSecondary : PTTheme.textPrimary)
                                        .strikethrough(estCoche, color: PTTheme.textSecondary)
                                        .lineLimit(1)
                                    
                                    ZStack {
                                        if estCoche {
                                            Circle()
                                                .fill(PTTheme.textPrimary)
                                                .frame(width: 24, height: 24)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(PTTheme.bg)
                                        } else {
                                            Circle()
                                                .stroke(PTTheme.textTertiary, lineWidth: 1.5)
                                                .frame(width: 24, height: 24)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .frame(minHeight: 58)
                                .contentShape(Rectangle())
                                .opacity(estCoche ? 0.48 : 1.0)
                            }
                            .buttonStyle(.plain)
                            
                            if index < paliers.count - 1 {
                                PTHairline(leadingInset: 20)
                            } else {
                                PTHairline()
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle(exercice.nom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(PTTheme.textPrimary)
                    .fontWeight(.semibold)
                }
            }
            .ptAppearance()
            .onAppear {
                if poidsVise == nil {
                    poidsVise = exercice.chargeCibleTopSet
                }
            }
        }
    }
}
#endif
