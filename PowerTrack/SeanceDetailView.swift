import SwiftUI
import SwiftData
import UserNotifications

struct SeanceDetailView: View {
    let seance: Seance
    
    @StateObject private var timerManager = TimerManager()
    @ObservedObject private var progressTracker = SeanceProgressTracker.shared
    
    @State private var exercicePourEchauffement: Exercice? = nil
    @State private var isShowingSummarySheet = false
    @State private var dateDebutSeance: Date = Date()
    @State private var prSerieIDs: Set<PersistentIdentifier> = []
    
    // Série dont le tiroir d'édition rapide est actuellement déplié
    @State private var expandedSerieID: PersistentIdentifier? = nil
    
    private var exercicesTries: [Exercice] {
        seance.exercices.sorted { $0.ordre < $1.ordre }
    }
    
    private var prochaineSerieActive: Serie? {
        for exercice in exercicesTries {
            if let firstUnvalidated = exercice.series.first(where: { !$0.estValidee }) {
                return firstUnvalidated
            }
        }
        return nil
    }
    
    private var prochainExerciceActif: Exercice? {
        exercicesTries.first { ex in
            ex.series.contains { !$0.estValidee }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header minimaliste de progression en temps réel
            SeanceProgressHeaderView(
                seance: seance,
                dateDebutSeance: dateDebutSeance
            )
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(exercicesTries.enumerated()), id: \.element.persistentModelID) { exIndex, exercice in
                            VStack(alignment: .leading, spacing: 10) {
                                // MARK: - En-tête d'exercice clair (Numéro, Nom, e1RM discret & badge d'échauffement filtré)
                                ExerciceSectionHeaderView(
                                    numeroExercice: exIndex + 1,
                                    exercice: exercice,
                                    meilleurE1RM: meilleurE1RMActuel(pour: exercice),
                                    onTapWarmup: {
                                        HapticAndSoundManager.shared.triggerLightImpact()
                                        exercicePourEchauffement = exercice
                                    }
                                )
                                .id(exercice.persistentModelID)
                                
                                // Suggestion discrète d'adaptation Back-offs si dépassement RPE sur Top Set
                                if let suggestionDelta = detecterDepassementRPETopSet(pour: exercice) {
                                    BackoffAdaptationBannerView(
                                        rpeDepassement: suggestionDelta,
                                        onApplyReduction: { reductionKg in
                                            appliquerAllegementBackoffs(pour: exercice, reductionKg: reductionKg)
                                        }
                                    )
                                }
                                
                                // MARK: - Carte unifiée regroupant toutes les séries de l'exercice
                                VStack(spacing: 0) {
                                    ForEach(Array(exercice.series.enumerated()), id: \.element.persistentModelID) { index, serie in
                                        let isActive = (prochaineSerieActive?.persistentModelID == serie.persistentModelID)
                                        let isExpanded = (expandedSerieID == serie.persistentModelID)
                                        let isPR = estNouveauPRTheorique(serie: serie, dans: exercice)
                                        
                                        SerieCompactRowView(
                                            serie: serie,
                                            numeroSerie: index + 1,
                                            isNextActiveSet: isActive,
                                            isExpanded: isExpanded,
                                            isTheoreticalPR: isPR,
                                            onTapRow: {
                                                HapticAndSoundManager.shared.triggerSelection()
                                                withAnimation(.snappy(duration: 0.25)) {
                                                    if expandedSerieID == serie.persistentModelID {
                                                        expandedSerieID = nil
                                                    } else {
                                                        expandedSerieID = serie.persistentModelID
                                                    }
                                                }
                                            },
                                            onValidateSerie: {
                                                gererValidationSerie(
                                                    serie: serie,
                                                    index: index,
                                                    exercice: exercice,
                                                    scrollProxy: scrollProxy
                                                )
                                            }
                                        )
                                        .id(serie.persistentModelID)
                                        
                                        if index < exercice.series.count - 1 {
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
                        
                        // Bouton de fin de séance épuré
                        Button(action: {
                            HapticAndSoundManager.shared.triggerPRValidated()
                            timerManager.stopTimer()
                            SeanceProgressTracker.shared.markSeanceClosed(seance)
                            isShowingSummarySheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "flag.checkered")
                                    .font(.headline)
                                Text("Terminer la séance")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.black)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    dateDebutSeance = SeanceProgressTracker.shared.ensureSessionStartDate(for: seance)
                    demanderAutorisationNotifications()
                    HapticAndSoundManager.shared.prepareGenerators()
                    
                    // Ouvre par défaut le tiroir sur la série active en cours
                    expandedSerieID = prochaineSerieActive?.persistentModelID
                    
                    if let targetEx = prochainExerciceActif {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.snappy) {
                                scrollProxy.scrollTo(targetEx.persistentModelID, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(seance.titre ?? seance.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticAndSoundManager.shared.triggerLightImpact()
                    Task {
                        let webhookTestURL = "https://webhook.site/7be51dbd-0546-476b-8690-56228dc2d0ed"
                        await ExportManager.shared.exporterSeance(seance: seance, webhookURL: webhookTestURL)
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(.orange)
                }
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: {
                    HapticAndSoundManager.shared.triggerSelection()
                    hideKeyboard()
                }) {
                    Text("OK / Fermer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            TimerView(timerManager: timerManager)
        }
        .sheet(item: $exercicePourEchauffement) { exerciceAechauffer in
            EchauffementSheetView(exercice: exerciceAechauffer)
                .presentationDetents([.fraction(0.65), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingSummarySheet) {
            SeanceSummarySheet(seance: seance)
        }
    }
    
    // MARK: - Logique Métier (Validation, Propagation, PR, Auto-Scroll)
    
    private func gererValidationSerie(
        serie: Serie,
        index: Int,
        exercice: Exercice,
        scrollProxy: ScrollViewProxy
    ) {
        withAnimation(.snappy(duration: 0.25)) {
            serie.estValidee.toggle()
            
            if serie.estValidee {
                if expandedSerieID == serie.persistentModelID {
                    expandedSerieID = nil
                }
            } else {
                expandedSerieID = serie.persistentModelID
            }
        }
        
        guard serie.estValidee else {
            HapticAndSoundManager.shared.triggerLightImpact()
            return
        }
        
        if serie.rpeSaisi == nil {
            serie.rpeSaisi = serie.rpeCible
        }
        
        hideKeyboard()
        SeanceProgressTracker.shared.recordSetValidation(for: seance)
        
        // Propagation intelligente vers la série N+1 si sa charge est vide
        let series = exercice.series
        if index + 1 < series.count {
            let serieSuivante = series[index + 1]
            if serieSuivante.chargeSaisie == nil || serieSuivante.chargeSaisie == 0 {
                serieSuivante.chargeSaisie = serie.chargeSaisie
                serieSuivante.repsCibles = serie.repsCibles
            }
        }
        
        let isPR = verifierEtEnregistrerPR(serie: serie, dans: exercice)
        let isTopSet = estUnTopSet(serie: serie, index: index, dans: exercice)
        
        if isPR || isTopSet {
            HapticAndSoundManager.shared.triggerPRValidated()
        } else {
            HapticAndSoundManager.shared.triggerSetValidated()
        }
        
        timerManager.startTimer(for: serie, exercice: exercice)
        
        // Si l'exercice est terminé, auto-scroll vers le prochain exercice actif
        let toutesValideesDansExercice = exercice.series.allSatisfy(\.estValidee)
        if toutesValideesDansExercice, let nextEx = prochainExerciceActif {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.snappy) {
                    scrollProxy.scrollTo(nextEx.persistentModelID, anchor: .top)
                }
            }
        }
    }
    
    private func meilleurE1RMActuel(pour exercice: Exercice) -> Double? {
        let e1rmsExercice = exercice.series.compactMap { s -> Double? in
            guard let charge = s.chargeSaisie, charge > 0 else { return nil }
            return s.calculerE1RM(charge: charge, reps: s.repsCibles, rpe: s.rpeSaisi ?? s.rpeCible)
        }
        if let maxLocal = e1rmsExercice.max(), maxLocal > 0 {
            return maxLocal
        }
        let hist = meilleurE1RMPrecedent(pour: exercice, excluant: nil)
        return hist > 0 ? hist : nil
    }
    
    private func estUnTopSet(serie: Serie, index: Int, dans exercice: Exercice) -> Bool {
        let nomLower = exercice.nom.lowercased()
        if nomLower.contains("top set") || nomLower.contains("single") || nomLower.contains("pr") {
            return true
        }
        if exercice.categorie == .competition && index == 0 {
            return true
        }
        return false
    }
    
    private func verifierEtEnregistrerPR(serie: Serie, dans exercice: Exercice) -> Bool {
        guard serie.estValidee, let currentE1RM = serie.calculerE1RM(), currentE1RM > 0 else {
            prSerieIDs.remove(serie.persistentModelID)
            return false
        }
        
        let previousBest = meilleurE1RMPrecedent(pour: exercice, excluant: serie)
        if currentE1RM > previousBest && previousBest > 0 {
            prSerieIDs.insert(serie.persistentModelID)
            return true
        }
        
        prSerieIDs.remove(serie.persistentModelID)
        return false
    }
    
    private func estNouveauPRTheorique(serie: Serie, dans exercice: Exercice) -> Bool {
        guard serie.estValidee else { return false }
        if prSerieIDs.contains(serie.persistentModelID) {
            return true
        }
        guard let currentE1RM = serie.calculerE1RM(), currentE1RM > 0 else { return false }
        let previousBest = meilleurE1RMPrecedent(pour: exercice, excluant: serie)
        return previousBest > 0 && currentE1RM > previousBest
    }
    
    private func meilleurE1RMPrecedent(pour exercice: Exercice, excluant serieExclue: Serie?) -> Double {
        var maxE1RM: Double = 0.0
        let nomCible = racineNomMouvement(exercice.nom)
        
        if let bloc = seance.semaine?.macroBloc {
            if nomCible.contains("squat") && bloc.squat1RM > 0 {
                maxE1RM = max(maxE1RM, bloc.squat1RM)
            } else if nomCible.contains("bench") && bloc.bench1RM > 0 {
                maxE1RM = max(maxE1RM, bloc.bench1RM)
            } else if nomCible.contains("deadlift") && bloc.deadlift1RM > 0 {
                maxE1RM = max(maxE1RM, bloc.deadlift1RM)
            }
            
            for sem in bloc.semaines {
                for s in sem.seances {
                    for ex in s.exercices where racineNomMouvement(ex.nom) == nomCible {
                        for ser in ex.series where ser.estValidee && ser.persistentModelID != serieExclue?.persistentModelID {
                            if let e1rm = ser.calculerE1RM() {
                                maxE1RM = max(maxE1RM, e1rm)
                            }
                        }
                    }
                }
            }
        }
        
        return maxE1RM
    }
    
    private func racineNomMouvement(_ nom: String) -> String {
        let lower = nom.lowercased()
        if lower.contains("bench") || lower.contains("développé couché") { return "bench" }
        if lower.contains("squat") { return "squat" }
        if lower.contains("deadlift") || lower.contains("soulevé de terre") { return "deadlift" }
        return lower
    }
    
    private func detecterDepassementRPETopSet(pour exercice: Exercice) -> Double? {
        guard exercice.categorie == .competition || exercice.nom.lowercased().contains("back-off") else {
            return nil
        }
        guard exercice.series.contains(where: { !$0.estValidee }) else {
            return nil
        }
        
        if let premiereSerie = exercice.series.first,
           premiereSerie.estValidee,
           let rpeReel = premiereSerie.rpeSaisi {
            let delta = rpeReel - premiereSerie.rpeCible
            if delta >= 1.0 { return delta }
        }
        
        let racine = racineNomMouvement(exercice.nom)
        for exPrecedent in exercicesTries where exPrecedent.ordre < exercice.ordre && racineNomMouvement(exPrecedent.nom) == racine {
            for s in exPrecedent.series where s.estValidee {
                if let rpeReel = s.rpeSaisi {
                    let delta = rpeReel - s.rpeCible
                    if delta >= 1.0 { return delta }
                }
            }
        }
        return nil
    }
    
    private func appliquerAllegementBackoffs(pour exercice: Exercice, reductionKg: Double) {
        HapticAndSoundManager.shared.triggerSelection()
        withAnimation(.snappy) {
            for serie in exercice.series where !serie.estValidee {
                if let chargeActuelle = serie.chargeSaisie {
                    serie.chargeSaisie = max(0, chargeActuelle - reductionKg)
                }
            }
        }
    }
    
    private func demanderAutorisationNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

// MARK: - En-tête d'Exercice Clair & Badge d'Échauffement Intelligent

struct ExerciceSectionHeaderView: View {
    let numeroExercice: Int
    let exercice: Exercice
    let meilleurE1RM: Double?
    let onTapWarmup: () -> Void
    
    private var texteBadgeEchauffement: String {
        let reps = exercice.repsCiblesTopSet
        let motRep = reps > 1 ? "reps" : "rep"
        if let charge = exercice.chargeCibleTopSet, charge > 0 {
            let chargeStr = charge.truncatingRemainder(dividingBy: 1.0) == 0
                ? String(format: "%.0f", charge)
                : String(format: "%.1f", charge)
            return "🔥 Échauffement (vers \(reps) \(motRep) @ \(chargeStr) kg)"
        } else {
            return "🔥 Échauffement (vers \(reps) \(motRep))"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text("\(numeroExercice). \(exercice.nom)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Spacer(minLength: 4)
                
                if let e1rm = meilleurE1RM {
                    Text("e1RM \(e1rm, specifier: "%.1f") kg")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            HStack(alignment: .center, spacing: 8) {
                // Affiché uniquement si l'exercice nécessite un échauffement (masqué pour l'isolation et poids du corps)
                if exercice.necessiteEchauffement {
                    Button(action: onTapWarmup) {
                        Text(texteBadgeEchauffement)
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(white: 0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                if let indications = exercice.indications, !indications.isEmpty {
                    Text(indications)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Ligne de Série Compacte (~50pt) + Tiroir Dépliable à la Demande

struct SerieCompactRowView: View {
    @Bindable var serie: Serie
    
    let numeroSerie: Int
    let isNextActiveSet: Bool
    let isExpanded: Bool
    let isTheoreticalPR: Bool
    let onTapRow: () -> Void
    let onValidateSerie: () -> Void
    
    private let rpeOptions: [Double] = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0]
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Ligne principale compacte (~50pt)
            HStack(spacing: 10) {
                // 1. Badge numéro (#1, #2...)
                Text("#\(numeroSerie)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(isNextActiveSet ? .orange : .secondary)
                    .lineLimit(1)
                    .frame(width: 28, alignment: .leading)
                
                // 2. Cible compacte sur une seule ligne (ex: 5 reps @ 6)
                HStack(spacing: 5) {
                    Text("\(serie.repsCibles) reps @ \(formatRPE(serie.rpeCible))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    if isTheoreticalPR {
                        Text("PR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTapRow)
                
                // 3. Champ Charge épuré (125 kg)
                HStack(spacing: 2) {
                    TextField("-", value: $serie.chargeSaisie, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text("kg")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .frame(width: 76, height: 34)
                .background(Color(white: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // 4. Champ RPE épuré (RPE 6) — ouvre/ferme le tiroir au tap
                Button(action: onTapRow) {
                    let displayRPE = serie.rpeSaisi ?? serie.rpeCible
                    Text("RPE \(formatRPE(displayRPE))")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundColor(serie.rpeSaisi != nil ? .white : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 8)
                        .frame(width: 64, height: 34)
                        .background(Color(white: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // 5. Bouton de validation circulaire simple (28x28pt)
                Button(action: onValidateSerie) {
                    Image(systemName: serie.estValidee ? "checkmark.circle.fill" : "circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(
                            serie.estValidee
                                ? .green
                                : (isNextActiveSet ? .orange : Color(white: 0.35))
                        )
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(serie.estValidee ? "Série validée" : "Valider la série")
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            
            // MARK: Tiroir d'édition dépliable (Steppers sobres + Pilules RPE sobres)
            if isExpanded {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        CompactStepButton(
                            label: "-2.5",
                            onTap: { ajusterCharge(-2.5) },
                            onLongOrDouble: { ajusterCharge(-5.0) }
                        )
                        
                        CompactStepButton(
                            label: "+2.5",
                            onTap: { ajusterCharge(2.5) },
                            onLongOrDouble: { ajusterCharge(5.0) }
                        )
                        
                        Divider()
                            .frame(height: 20)
                            .background(Color.white.opacity(0.12))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(rpeOptions, id: \.self) { rpeValue in
                                    let currentRPE = serie.rpeSaisi ?? serie.rpeCible
                                    let isSelected = abs(currentRPE - rpeValue) < 0.01
                                    let selectedColor = couleurSelectionRPE(rpeValue)
                                    
                                    Button(action: {
                                        HapticAndSoundManager.shared.triggerSelection()
                                        withAnimation(.snappy(duration: 0.2)) {
                                            serie.rpeSaisi = rpeValue
                                        }
                                    }) {
                                        Text(formatRPE(rpeValue))
                                            .font(.caption.weight(.semibold).monospacedDigit())
                                            .foregroundColor(isSelected ? .black : .secondary)
                                            .lineLimit(1)
                                            .frame(minWidth: 32, minHeight: 28)
                                            .padding(.horizontal, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(isSelected ? selectedColor : Color(white: 0.18))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isNextActiveSet || isExpanded ? Color(white: 0.15) : Color.clear)
        .overlay(alignment: .leading) {
            if isNextActiveSet {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 3)
            }
        }
        .opacity(serie.estValidee ? 0.55 : 1.0)
        .animation(.snappy(duration: 0.25), value: serie.estValidee)
        .animation(.snappy(duration: 0.25), value: isExpanded)
    }
    
    // MARK: - Helpers
    
    private func ajusterCharge(_ delta: Double) {
        HapticAndSoundManager.shared.triggerSelection()
        let base = serie.chargeSaisie ?? 0.0
        serie.chargeSaisie = max(0.0, base + delta)
    }
    
    private func formatRPE(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1.0) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private func couleurSelectionRPE(_ rpe: Double) -> Color {
        if rpe <= 7.0 {
            return .green
        } else if rpe <= 8.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Bouton Stepper Compact sans Sous-Texte

struct CompactStepButton: View {
    let label: String
    let onTap: () -> Void
    let onLongOrDouble: () -> Void
    
    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(width: 44, height: 28)
            .background(Color(white: 0.20))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture(count: 2).onEnded { onLongOrDouble() }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in onLongOrDouble() }
            )
            .onTapGesture {
                onTap()
            }
    }
}

// MARK: - Header de Progression Minimaliste

struct SeanceProgressHeaderView: View {
    let seance: Seance
    let dateDebutSeance: Date
    
    private var totalSeries: Int { seance.totalSeriesCount }
    private var seriesValidees: Int { seance.validatedSeriesCount }
    private var pourcentage: Int {
        guard totalSeries > 0 else { return 0 }
        return Int(round(seance.progressionRatio * 100.0))
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(seriesValidees) / \(totalSeries) séries • \(pourcentage)%")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                TimelineView(.periodic(from: dateDebutSeance, by: 1.0)) { context in
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDuration(from: dateDebutSeance, to: context.date))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(white: 0.15))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(seriesValidees == totalSeries && totalSeries > 0 ? Color.green : Color.orange)
                        .frame(width: max(0, geo.size.width * seance.progressionRatio), height: 3)
                        .animation(.snappy, value: seriesValidees)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .background(Color(white: 0.08))
    }
    
    private func formatDuration(from start: Date, to now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Bandeau Discret d'Adaptation Back-offs

struct BackoffAdaptationBannerView: View {
    let rpeDepassement: Double
    let onApplyReduction: (Double) -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
                .font(.subheadline)
            
            Text("Top Set +\(String(format: "%.1f", rpeDepassement)) RPE : alléger Back-offs ?")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Spacer(minLength: 4)
            
            Button(action: { onApplyReduction(2.5) }) {
                Text("-2.5 kg")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button(action: { onApplyReduction(5.0) }) {
                Text("-5 kg")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(white: 0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension View {
    /// Masque le clavier virtuel
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
