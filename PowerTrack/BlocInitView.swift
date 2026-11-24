//
//  BlocInitView.swift
//  PowerTrack
//
//  Created by ethan ruders on 14/08/2026.
//

import SwiftUI
import SwiftData
import UIKit

struct BlocInitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Étape active (1: Mouvements, 2: Variantes, 3: 1RM & Finalisation)
    @State private var etapeCourante: Int = 1
    
    // Données du formulaire
    @State private var nomBloc: String = "Bloc Force Personnalisé"
    @State private var mouvementsSelectionnes: Set<MouvementCompetition> = [.squat, .bench, .deadlift]
    
    // Variantes sélectionnées par mouvement (ordre de sélection conservé)
    @State private var variantesParMouvement: [MouvementCompetition: [VarianteMouvement]] = [
        .squat: [.pauseSquat],
        .bench: [.benchTempo],
        .deadlift: [.pauseDeadlift]
    ]
    
    // Ratios personnalisés des variantes
    @State private var ratiosVariantes: [VarianteMouvement: Double] = [:]
    
    // 1RM
    @State private var squat1RM: Double = 165.0
    @State private var bench1RM: Double = 130.0
    @State private var deadlift1RM: Double = 190.0
    @State private var inclureSemaineTestPR: Bool = false
    
    // Gestion d'erreur
    @State private var messageErreur: String?
    @State private var showingErrorAlert: Bool = false
    
    private var stepTitle: String {
        switch etapeCourante {
        case 1: return "Mouvements & Gabarit"
        case 2: return "Variantes & Coefficients"
        case 3: return "1RM & Finalisation"
        default: return ""
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepperHeader
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch etapeCourante {
                        case 1:
                            etape1MouvementsView
                        case 2:
                            etape2VariantesView
                        case 3:
                            etape31RMView
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                
                navigationBottomBar
            }
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle("Nouveau Bloc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(PTTheme.textSecondary)
                }
            }
            .preferredColorScheme(.dark)
            .alert("Erreur", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(messageErreur ?? "Une erreur est survenue.")
            }
        }
    }
    
    // MARK: - En-tête de Progression
    
    private var stepperHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PTKicker(text: "Étape \(etapeCourante) sur 3", color: PTTheme.accent)
                Spacer()
                PTKicker(text: stepTitle, color: PTTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            
            PTProgressHairline(ratio: Double(etapeCourante) / 3.0)
        }
        .padding(.top, 10)
        .background(PTTheme.bg)
    }
    
    // MARK: - Étape 1 : Mouvements
    
    private var etape1MouvementsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                PTKicker(text: "Configuration générale")
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    PTHairline()
                    TextField("Nom du bloc", text: $nomBloc)
                        .font(.body.weight(.medium))
                        .foregroundColor(PTTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(PTTheme.surface)
                    PTHairline()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                PTKicker(text: "1. Mouvements de compétition")
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    PTHairline()
                    ForEach(MouvementCompetition.allCases) { mouv in
                        let isSelected = mouvementsSelectionnes.contains(mouv)
                        Button {
                            toggleMouvement(mouv)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mouv.rawValue)
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(PTTheme.textPrimary)
                                    
                                    Text(sousTitrePour(mouv))
                                        .font(.caption)
                                        .foregroundColor(PTTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? PTTheme.textPrimary : Color.clear)
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? PTTheme.textPrimary : PTTheme.hairlineStrong, lineWidth: 1)
                                        )
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(PTTheme.bg)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        PTHairline(leadingInset: 16)
                    }
                }
                
                Text("Sélectionnez au moins un mouvement. Un des 7 gabarits de programmation sera automatiquement assigné.")
                    .font(.caption)
                    .foregroundColor(PTTheme.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            
            if let gabarit = GabaritProgramme.determiner(mouvements: mouvementsSelectionnes) {
                VStack(alignment: .leading, spacing: 8) {
                    PTKicker(text: "Gabarit assigné")
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        PTHairline()
                        HStack(spacing: 10) {
                            Circle()
                                .fill(PTTheme.accent)
                                .frame(width: 6, height: 6)
                            Text(descriptionGabarit(gabarit))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(PTTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(PTTheme.surface)
                        PTHairline()
                    }
                }
            }
        }
    }
    
    // MARK: - Étape 2 : Variantes & Ratios
    
    private var etape2VariantesView: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(Array(mouvementsSelectionnes).sorted(by: { $0.rawValue < $1.rawValue })) { mouv in
                VStack(alignment: .leading, spacing: 8) {
                    PTKicker(text: "Variantes · \(mouv.rawValue)")
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        PTHairline()
                        
                        ForEach(mouv.variantesDisponibles) { variante in
                            let isSelected = isVarianteSelected(variante, for: mouv)
                            VStack(spacing: 12) {
                                HStack {
                                    Button {
                                        toggleVariante(variante, for: mouv)
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .fill(isSelected ? PTTheme.textPrimary : Color.clear)
                                                    .frame(width: 20, height: 20)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                            .stroke(isSelected ? PTTheme.textPrimary : PTTheme.hairlineStrong, lineWidth: 1)
                                                    )
                                                
                                                if isSelected {
                                                    if let rang = rangVariante(variante, for: mouv),
                                                       (variantesParMouvement[mouv]?.count ?? 0) > 1 {
                                                        Text("\(rang)")
                                                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                                                            .foregroundColor(PTTheme.bg)
                                                    } else {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundColor(PTTheme.bg)
                                                    }
                                                }
                                            }
                                            
                                            Text(variante.rawValue)
                                                .font(.body.weight(.medium))
                                                .foregroundColor(PTTheme.textPrimary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        let currentRatio = ratioFor(variante)
                                        Text("\(Int(round(currentRatio * 100)))% 1RM")
                                            .font(.caption.weight(.semibold).monospacedDigit())
                                            .foregroundColor(PTTheme.accent)
                                    }
                                }
                                
                                if isSelected {
                                    HStack(spacing: 12) {
                                        Text("Coefficient")
                                            .font(.caption)
                                            .foregroundColor(PTTheme.textSecondary)
                                        
                                        Slider(
                                            value: Binding(
                                                get: { ratioFor(variante) },
                                                set: { ratiosVariantes[variante] = $0 }
                                            ),
                                            in: 0.70...1.05,
                                            step: 0.01
                                        )
                                        .tint(PTTheme.accent)
                                        
                                        Text(String(format: "%.2f", ratioFor(variante)))
                                            .font(.caption.weight(.semibold).monospacedDigit())
                                            .foregroundColor(PTTheme.textPrimary)
                                            .frame(width: 40, alignment: .trailing)
                                    }
                                    .padding(.leading, 32)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            
                            PTHairline(leadingInset: 16)
                        }
                    }
                }
            }
            
            Text("Sélectionnez une ou plusieurs variantes (l'ordre de sélection définit leur priorité) et ajustez leur coefficient par rapport au 1RM. Toutes les variantes choisies sont réparties sur les séances du bloc.")
                .font(.caption)
                .foregroundColor(PTTheme.textTertiary)
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Étape 3 : Saisie des 1RM
    
    private var etape31RMView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                PTKicker(text: "1RM de référence (kg)")
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    PTHairline()
                    
                    if mouvementsSelectionnes.contains(.squat) {
                        oneRMRow(titre: "Squat", placeholder: "Squat", value: $squat1RM)
                        PTHairline(leadingInset: 16)
                    }
                    
                    if mouvementsSelectionnes.contains(.bench) {
                        oneRMRow(titre: "Bench Press", placeholder: "Bench", value: $bench1RM)
                        PTHairline(leadingInset: 16)
                    }
                    
                    if mouvementsSelectionnes.contains(.deadlift) {
                        oneRMRow(titre: "Deadlift", placeholder: "Deadlift", value: $deadlift1RM)
                        PTHairline(leadingInset: 16)
                    }
                }
                
                Text("Renseignez vos charges maximales pour les mouvements programmés. Toutes les séries et variantes seront calculées automatiquement.")
                    .font(.caption)
                    .foregroundColor(PTTheme.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                PTKicker(text: "Option fin de bloc")
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    PTHairline()
                    Toggle(isOn: $inclureSemaineTestPR) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ajouter Semaine 5 : Taper & Test PR")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(PTTheme.textPrimary)
                            Text("Taper lun/mer puis simulation plateau le samedi")
                                .font(.caption)
                                .foregroundColor(PTTheme.textSecondary)
                        }
                    }
                    .tint(PTTheme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    PTHairline()
                }
                
                Text("Par défaut, le bloc dure 4 semaines et culmine sur un pic contrôlé (RPE 8.5). Activez l'option Test PR pour ajouter une Semaine 5 (taper en début de semaine + tests PR en 1 journée).")
                    .font(.caption)
                    .foregroundColor(PTTheme.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                PTKicker(text: "Résumé du bloc")
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    PTHairline()
                    
                    HStack {
                        Text("Durée")
                            .font(.subheadline)
                            .foregroundColor(PTTheme.textSecondary)
                        Spacer()
                        Text(inclureSemaineTestPR ? "5 semaines (4 + Taper/PR)" : "4 semaines")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundColor(PTTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    
                    if let gabarit = GabaritProgramme.determiner(mouvements: mouvementsSelectionnes) {
                        PTHairline(leadingInset: 16)
                        HStack {
                            Text("Fréquence")
                                .font(.subheadline)
                                .foregroundColor(PTTheme.textSecondary)
                            Spacer()
                            Text(frequenceGabarit(gabarit))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundColor(PTTheme.accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    
                    PTHairline()
                }
            }
        }
    }
    
    private func oneRMRow(titre: String, placeholder: String, value: Binding<Double>) -> some View {
        HStack {
            Text(titre)
                .font(.body.weight(.medium))
                .foregroundColor(PTTheme.textPrimary)
            
            Spacer()
            
            HStack(spacing: 6) {
                TextField(placeholder, value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundColor(PTTheme.textPrimary)
                    .frame(width: 82)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PTTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PTTheme.hairline, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                Text("kg")
                    .font(.subheadline)
                    .foregroundColor(PTTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Barre de Navigation Inférieure
    
    private var navigationBottomBar: some View {
        VStack(spacing: 0) {
            PTHairline()
            
            HStack(spacing: 12) {
                if etapeCourante > 1 {
                    Button {
                        withAnimation {
                            etapeCourante -= 1
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.bold))
                            Text("Précédent")
                        }
                    }
                    .buttonStyle(PTSecondaryPillButtonStyle())
                }
                
                Spacer()
                
                if etapeCourante < 3 {
                    Button(action: allerEtapeSuivante) {
                        HStack(spacing: 6) {
                            Text("Suivant")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .buttonStyle(PTPrimaryPillButtonStyle(isDisabled: mouvementsSelectionnes.isEmpty))
                    .disabled(mouvementsSelectionnes.isEmpty)
                } else {
                    Button(action: validerEtGenerer) {
                        Text("Créer le bloc")
                    }
                    .buttonStyle(PTPrimaryPillButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(PTTheme.bg)
        }
    }
    
    // MARK: - Actions & Logique
    
    private func toggleMouvement(_ mouv: MouvementCompetition) {
        if mouvementsSelectionnes.contains(mouv) {
            if mouvementsSelectionnes.count > 1 {
                mouvementsSelectionnes.remove(mouv)
            }
        } else {
            mouvementsSelectionnes.insert(mouv)
            if variantesParMouvement[mouv] == nil || variantesParMouvement[mouv]!.isEmpty {
                variantesParMouvement[mouv] = Array(mouv.variantesDisponibles.prefix(1))
            }
        }
    }
    
    private func isVarianteSelected(_ variante: VarianteMouvement, for mouv: MouvementCompetition) -> Bool {
        variantesParMouvement[mouv]?.contains(variante) ?? false
    }
    
    private func rangVariante(_ variante: VarianteMouvement, for mouv: MouvementCompetition) -> Int? {
        guard let list = variantesParMouvement[mouv], let idx = list.firstIndex(of: variante) else {
            return nil
        }
        return idx + 1
    }
    
    private func toggleVariante(_ variante: VarianteMouvement, for mouv: MouvementCompetition) {
        var actuelles = variantesParMouvement[mouv] ?? []
        if let idx = actuelles.firstIndex(of: variante) {
            if actuelles.count > 1 {
                actuelles.remove(at: idx)
            }
        } else {
            actuelles.append(variante)
        }
        variantesParMouvement[mouv] = actuelles
    }
    
    private func ratioFor(_ variante: VarianteMouvement) -> Double {
        ratiosVariantes[variante] ?? variante.ratioParDefaut
    }
    
    private func allerEtapeSuivante() {
        if etapeCourante == 1 && mouvementsSelectionnes.isEmpty {
            messageErreur = "Veuillez sélectionner au moins un mouvement de compétition."
            showingErrorAlert = true
            return
        }
        withAnimation {
            etapeCourante += 1
        }
    }
    
    private func validerEtGenerer() {
        guard !mouvementsSelectionnes.isEmpty else {
            messageErreur = "Sélectionnez au moins un mouvement."
            showingErrorAlert = true
            return
        }
        
        var variantesFinales: [MouvementCompetition: [VarianteMouvement]] = [:]
        for mouv in mouvementsSelectionnes {
            let liste = variantesParMouvement[mouv] ?? []
            if liste.isEmpty {
                variantesFinales[mouv] = Array(mouv.variantesDisponibles.prefix(1))
            } else {
                variantesFinales[mouv] = liste
            }
        }
        
        let config = ProgramConfiguration(
            nomBloc: nomBloc.trimmingCharacters(in: .whitespacesAndNewlines),
            mouvements: mouvementsSelectionnes,
            variantesSelectionnees: variantesFinales,
            ratiosVariantes: ratiosVariantes,
            squat1RM: squat1RM,
            bench1RM: bench1RM,
            deadlift1RM: deadlift1RM,
            inclureSemaineTestPR: inclureSemaineTestPR,
            dateDebut: Date()
        )
        
        do {
            try ProgramGenerator.genererEtSauvegarder(config: config, into: modelContext)
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            dismiss()
        } catch {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.error)
            messageErreur = "Erreur lors de la génération : \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    // MARK: - Helpers UI
    
    private func sousTitrePour(_ mouv: MouvementCompetition) -> String {
        switch mouv {
        case .squat: return "Force des membres inférieurs"
        case .bench: return "Puissance pectoraux & chaîne antérieure"
        case .deadlift: return "Tirage lourd & chaîne postérieure"
        }
    }
    
    private func descriptionGabarit(_ gabarit: GabaritProgramme) -> String {
        switch gabarit {
        case .squatOnly: return "Cas 1 : Squat Only (4 séances / semaine)"
        case .deadliftOnly: return "Cas 2 : Deadlift Only (4 séances / semaine)"
        case .benchOnly: return "Cas 3 : Bench Only (4 séances / semaine)"
        case .squatBench: return "Cas 4 : Squat + Bench (4 séances / semaine)"
        case .squatDeadlift: return "Cas 5 : Squat + Deadlift (3 séances / semaine)"
        case .benchDeadlift: return "Cas 6 : Bench + Deadlift (4 séances / semaine)"
        case .fullSBD: return "Cas 7 : Full SBD (4 séances / semaine)"
        }
    }
    
    private func frequenceGabarit(_ gabarit: GabaritProgramme) -> String {
        switch gabarit {
        case .squatDeadlift: return "3 séances / semaine"
        case .squatOnly, .deadliftOnly, .benchOnly, .squatBench, .benchDeadlift, .fullSBD: return "4 séances / semaine"
        }
    }
}
