//
//  BlocInitView.swift
//  PowerTrack
//
//  Created by ethan ruders on 14/08/2026.
//

import SwiftUI
import SwiftData

struct BlocInitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Étape active (1: Mouvements, 2: Variantes, 3: 1RM & Finalisation)
    @State private var etapeCourante: Int = 1
    
    // Données du formulaire
    @State private var nomBloc: String = "Bloc Force Personnalisé"
    @State private var mouvementsSelectionnes: Set<MouvementCompetition> = [.squat, .bench, .deadlift]
    
    // Variantes sélectionnées par mouvement
    @State private var variantesParMouvement: [MouvementCompetition: Set<VarianteMouvement>] = [
        .squat: [.pauseSquat],
        .bench: [.spotoPress, .larsenPress],
        .deadlift: [.deficitDeadlift]
    ]
    
    // Ratios personnalisés des variantes
    @State private var ratiosVariantes: [VarianteMouvement: Double] = [:]
    
    // 1RM
    @State private var squat1RM: Double = 165.0
    @State private var bench1RM: Double = 120.0
    @State private var deadlift1RM: Double = 190.0
    
    // Gestion d'erreur
    @State private var messageErreur: String?
    @State private var showingErrorAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Indicateur d'étape (Entonnoir)
                stepperHeader
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.4))
                
                // Formulaire selon étape
                Form {
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
                .scrollContentBackground(.hidden)
                .background(Color.black)
                
                // Barre de navigation inférieure
                navigationBottomBar
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.3))
            }
            .navigationTitle("Nouveau Bloc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
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
        HStack(spacing: 12) {
            etapeBadge(numero: 1, titre: "Mouvements")
            chevronDivider
            etapeBadge(numero: 2, titre: "Variantes")
            chevronDivider
            etapeBadge(numero: 3, titre: "1RM")
        }
        .padding(.horizontal)
    }
    
    private func etapeBadge(numero: Int, titre: String) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(etapeCourante == numero ? Color.orange : (etapeCourante > numero ? Color.green : Color.gray.opacity(0.4)))
                    .frame(width: 24, height: 24)
                
                if etapeCourante > numero {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundColor(.black)
                } else {
                    Text("\(numero)")
                        .font(.caption2.bold())
                        .foregroundColor(etapeCourante == numero ? .black : .white)
                }
            }
            
            Text(titre)
                .font(.caption)
                .fontWeight(etapeCourante == numero ? .bold : .regular)
                .foregroundColor(etapeCourante == numero ? .orange : .gray)
        }
    }
    
    private var chevronDivider: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundColor(.gray.opacity(0.5))
    }
    
    // MARK: - Étape 1 : Mouvements
    
    private var etape1MouvementsView: some View {
        Group {
            Section(header: Text("Configuration générale")) {
                TextField("Nom du bloc", text: $nomBloc)
                    .font(.body)
            }
            
            Section(
                header: Text("1. Mouvements de Compétition"),
                footer: Text("Sélectionnez au moins un mouvement. Un des 7 gabarits de programmation sera automatiquement assigné.")
                    .font(.caption)
                    .foregroundColor(.gray)
            ) {
                ForEach(MouvementCompetition.allCases) { mouv in
                    let isSelected = mouvementsSelectionnes.contains(mouv)
                    Button(action: {
                        toggleMouvement(mouv)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mouv.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(sousTitrePour(mouv))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(isSelected ? .orange : .gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if let gabarit = GabaritProgramme.determiner(mouvements: mouvementsSelectionnes) {
                Section(header: Text("Gabarit assigné")) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.orange)
                        Text(descriptionGabarit(gabarit))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Étape 2 : Variantes & Ratios
    
    private var etape2VariantesView: some View {
        Group {
            ForEach(Array(mouvementsSelectionnes).sorted(by: { $0.rawValue < $1.rawValue })) { mouv in
                Section(
                    header: Text("Variantes \(mouv.rawValue)"),
                    footer: Text("Sélectionnez les variantes souhaitées et ajustez le ratio appliqué au 1RM de référence.")
                        .font(.caption)
                        .foregroundColor(.gray)
                ) {
                    ForEach(mouv.variantesDisponibles) { variante in
                        let isSelected = isVarianteSelected(variante, for: mouv)
                        VStack(spacing: 8) {
                            HStack {
                                Button(action: {
                                    toggleVariante(variante, for: mouv)
                                }) {
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                            .foregroundColor(isSelected ? .orange : .gray)
                                            .font(.title3)
                                        
                                        Text(variante.rawValue)
                                            .font(.body)
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Spacer()
                                
                                if isSelected {
                                    let currentRatio = ratioFor(variante)
                                    Text("\(Int(currentRatio * 100))% du 1RM")
                                        .font(.caption.bold())
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if isSelected {
                                HStack {
                                    Text("Coefficient:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Slider(
                                        value: Binding(
                                            get: { ratioFor(variante) },
                                            set: { ratiosVariantes[variante] = $0 }
                                        ),
                                        in: 0.70...1.05,
                                        step: 0.01
                                    )
                                    .tint(.orange)
                                    
                                    Text(String(format: "%.2f", ratioFor(variante)))
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.white)
                                        .frame(width: 38, alignment: .trailing)
                                }
                                .padding(.leading, 28)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Étape 3 : Saisie des 1RM
    
    private var etape31RMView: some View {
        Group {
            Section(
                header: Text("1RM de Référence (kg)"),
                footer: Text("Renseignez vos charges maximales pour les mouvements programmés. Toutes les séries et variantes seront calculées automatiquement.")
                    .font(.caption)
                    .foregroundColor(.gray)
            ) {
                if mouvementsSelectionnes.contains(.squat) {
                    HStack {
                        Label("Squat", systemImage: "figure.cross.training")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("Squat", value: $squat1RM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.headline)
                            .frame(width: 90)
                        Text("kg")
                            .foregroundColor(.gray)
                    }
                }
                
                if mouvementsSelectionnes.contains(.bench) {
                    HStack {
                        Label("Bench Press", systemImage: "figure.strengthtraining.traditional")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("Bench", value: $bench1RM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.headline)
                            .frame(width: 90)
                        Text("kg")
                            .foregroundColor(.gray)
                    }
                }
                
                if mouvementsSelectionnes.contains(.deadlift) {
                    HStack {
                        Label("Deadlift", systemImage: "scalemass.fill")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("Deadlift", value: $deadlift1RM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.headline)
                            .frame(width: 90)
                        Text("kg")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Section(header: Text("Résumé du Bloc")) {
                HStack {
                    Text("Durée")
                    Spacer()
                    Text("4 Semaines")
                        .foregroundColor(.gray)
                }
                
                if let gabarit = GabaritProgramme.determiner(mouvements: mouvementsSelectionnes) {
                    HStack {
                        Text("Fréquence")
                        Spacer()
                        Text(frequenceGabarit(gabarit))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }
    
    // MARK: - Barre de Navigation Inférieure
    
    private var navigationBottomBar: some View {
        HStack {
            if etapeCourante > 1 {
                Button(action: {
                    withAnimation {
                        etapeCourante -= 1
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Précédent")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color(UIColor.darkGray))
                    .cornerRadius(10)
                }
            }
            
            Spacer()
            
            if etapeCourante < 3 {
                Button(action: allerEtapeSuivante) {
                    HStack {
                        Text("Suivant")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(mouvementsSelectionnes.isEmpty ? Color.gray : Color.orange)
                    .cornerRadius(10)
                }
                .disabled(mouvementsSelectionnes.isEmpty)
            } else {
                Button(action: validerEtGenerer) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Générer le Bloc")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
            }
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
                variantesParMouvement[mouv] = Set(mouv.variantesDisponibles.prefix(1))
            }
        }
    }
    
    private func isVarianteSelected(_ variante: VarianteMouvement, for mouv: MouvementCompetition) -> Bool {
        return variantesParMouvement[mouv]?.contains(variante) ?? false
    }
    
    private func toggleVariante(_ variante: VarianteMouvement, for mouv: MouvementCompetition) {
        var actuelles = variantesParMouvement[mouv] ?? []
        if actuelles.contains(variante) {
            if actuelles.count > 1 {
                actuelles.remove(variante)
            }
        } else {
            actuelles.insert(variante)
        }
        variantesParMouvement[mouv] = actuelles
    }
    
    private func ratioFor(_ variante: VarianteMouvement) -> Double {
        return ratiosVariantes[variante] ?? variante.ratioParDefaut
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
            let set = variantesParMouvement[mouv] ?? []
            if set.isEmpty {
                variantesFinales[mouv] = Array(mouv.variantesDisponibles.prefix(1))
            } else {
                variantesFinales[mouv] = Array(set)
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
        case .squatOnly: return "Cas 1 : Squat Only (2 séances / semaine)"
        case .deadliftOnly: return "Cas 2 : Deadlift Only (2 séances / semaine)"
        case .benchOnly: return "Cas 3 : Bench Only (3 séances / semaine)"
        case .squatBench: return "Cas 4 : Squat + Bench (4 séances / semaine)"
        case .squatDeadlift: return "Cas 5 : Squat + Deadlift (3 séances / semaine)"
        case .benchDeadlift: return "Cas 6 : Bench + Deadlift (3 séances / semaine)"
        case .fullSBD: return "Cas 7 : Full SBD (4 séances / semaine)"
        }
    }
    
    private func frequenceGabarit(_ gabarit: GabaritProgramme) -> String {
        switch gabarit {
        case .squatOnly, .deadliftOnly: return "2 séances / semaine"
        case .benchOnly, .squatDeadlift, .benchDeadlift: return "3 séances / semaine"
        case .squatBench, .fullSBD: return "4 séances / semaine"
        }
    }
}
