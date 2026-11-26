import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SeanceDetailView: View {
    let seance: Seance
    
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var timerManager = TimerManager.shared
    @ObservedObject private var progressTracker = SeanceProgressTracker.shared
    
    @State private var exercicePourEchauffement: Exercice? = nil
    @State private var exerciceAEditer: Exercice? = nil
    @State private var isShowingAddExerciceSheet = false
    @State private var isShowingSummarySheet = false
    @State private var isShowingExportSheet = false
    @State private var dateDebutSeance: Date? = nil
    @State private var prSerieIDs: Set<PersistentIdentifier> = []
    
    // Série dont le tiroir d'édition rapide est actuellement déplié
    @State private var expandedSerieID: PersistentIdentifier? = nil
    
    private var exercicesTries: [Exercice] {
        seance.exercices.sorted { $0.ordre < $1.ordre }
    }
    
    private var prochaineSerieActive: Serie? {
        for exercice in exercicesTries {
            if let firstUnvalidated = exercice.seriesTriees.first(where: { !$0.estValidee }) {
                return firstUnvalidated
            }
        }
        return nil
    }
    
    private var prochainExerciceActif: Exercice? {
        exercicesTries.first { ex in
            ex.seriesTriees.contains { !$0.estValidee }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SeanceProgressHeaderView(
                seance: seance,
                dateDebutSeance: dateDebutSeance
            )
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(exercicesTries.enumerated()), id: \.element.persistentModelID) { exIndex, exercice in
                            let seriesTriees = exercice.seriesTriees
                            VStack(alignment: .leading, spacing: 0) {
                                ExerciceSectionHeaderView(
                                    numeroExercice: exIndex + 1,
                                    exercice: exercice,
                                    meilleurE1RM: meilleurE1RMActuel(pour: exercice),
                                    dernierePerformance: dernierePerformance(pour: exercice),
                                    onTapWarmup: {
                                        HapticAndSoundManager.shared.triggerLightImpact()
                                        exercicePourEchauffement = exercice
                                    },
                                    onAddSet: {
                                        ajouterSerie(a: exercice)
                                    },
                                    onEditExercice: {
                                        HapticAndSoundManager.shared.triggerLightImpact()
                                        exerciceAEditer = exercice
                                    },
                                    onDeleteExercice: {
                                        supprimerExercice(exercice)
                                    }
                                )
                                .id(exercice.persistentModelID)
                                
                                if let suggestionDelta = detecterDepassementRPETopSet(pour: exercice) {
                                    BackoffAdaptationBannerView(
                                        rpeDepassement: suggestionDelta,
                                        onApplyReduction: { reductionKg in
                                            appliquerAllegementBackoffs(pour: exercice, reductionKg: reductionKg)
                                        }
                                    )
                                }
                                
                                PTHairline()
                                
                                ForEach(Array(seriesTriees.enumerated()), id: \.element.persistentModelID) { index, serie in
                                    let isActive = (prochaineSerieActive?.persistentModelID == serie.persistentModelID)
                                    let isExpanded = (expandedSerieID == serie.persistentModelID)
                                    let isPR = estNouveauPRTheorique(serie: serie, dans: exercice)
                                    let isTopSet = estUnTopSet(serie: serie, index: index, dans: exercice)
                                    
                                    SerieCompactRowView(
                                        serie: serie,
                                        numeroSerie: index + 1,
                                        isTopSet: isTopSet,
                                        isNextActiveSet: isActive,
                                        isExpanded: isExpanded,
                                        isTheoreticalPR: isPR,
                                        canDeleteSerie: seriesTriees.count > 1,
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
                                        },
                                        onDeleteSerie: {
                                            supprimerSerie(serie, dans: exercice)
                                        }
                                    )
                                    .id(serie.persistentModelID)
                                    
                                    if index < seriesTriees.count - 1 {
                                        PTHairline(leadingInset: 20)
                                    } else {
                                        PTHairline()
                                    }
                                }
                            }
                        }
                        
                        VStack(spacing: 10) {
                            Button(action: {
                                HapticAndSoundManager.shared.triggerLightImpact()
                                isShowingAddExerciceSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.bold))
                                    Text("Ajouter un exercice")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PTSecondaryPillButtonStyle())
                            
                            // Bouton de fin de séance sobre (capsule blanche)
                            Button(action: {
                                HapticAndSoundManager.shared.triggerPRValidated()
                                timerManager.stopTimer()
                                SeanceProgressTracker.shared.markSeanceClosed(seance)
                                isShowingSummarySheet = true
                            }) {
                                Text("Terminer la séance")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PTPrimaryPillButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    dateDebutSeance = SeanceProgressTracker.shared.sessionStartDate(for: seance)
                    demanderAutorisationNotifications()
                    HapticAndSoundManager.shared.prepareGenerators()
                    
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
        .background(PTTheme.bg.ignoresSafeArea())
        .navigationTitle(seance.titre ?? seance.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticAndSoundManager.shared.triggerLightImpact()
                    isShowingExportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(PTTheme.textPrimary)
                }
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: {
                    HapticAndSoundManager.shared.triggerSelection()
                    hideKeyboard()
                }) {
                    Text("OK")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(PTTheme.accent)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            PTBottomOverlayStack()
        }
        .sheet(item: $exercicePourEchauffement) { exerciceAechauffer in
            EchauffementSheetView(exercice: exerciceAechauffer)
                .presentationDetents([.fraction(0.65), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $exerciceAEditer) { exercice in
            ExerciceEditorSheet(
                seance: seance,
                exerciceToEdit: exercice,
                nextOrder: exercice.ordre
            )
        }
        .sheet(isPresented: $isShowingAddExerciceSheet) {
            ExerciceEditorSheet(
                seance: seance,
                exerciceToEdit: nil,
                nextOrder: (exercicesTries.last?.ordre ?? -1) + 1
            )
        }
        .sheet(isPresented: $isShowingSummarySheet) {
            SeanceSummarySheet(seance: seance)
        }
        .sheet(isPresented: $isShowingExportSheet) {
            SeanceExportSheet(seance: seance)
        }
    }
    
    // MARK: - Actions d'Édition Libre (Séries & Exercices)
    
    private func ajouterSerie(a exercice: Exercice) {
        HapticAndSoundManager.shared.triggerLightImpact()
        let seriesTriees = exercice.seriesTriees
        for (idx, s) in seriesTriees.enumerated() where s.ordre != idx {
            s.ordre = idx
        }
        let template = seriesTriees.last
        let nouvelle = Serie(
            repsCibles: template?.repsCibles ?? 5,
            rpeCible: template?.rpeCible ?? 7.5,
            chargeSaisie: template?.chargeSaisie,
            rpeSaisi: nil,
            estValidee: false,
            ordre: seriesTriees.count
        )
        nouvelle.exercice = exercice
        withAnimation(.snappy(duration: 0.25)) {
            exercice.series.append(nouvelle)
            expandedSerieID = nouvelle.persistentModelID
        }
        try? modelContext.save()
    }
    
    private func supprimerSerie(_ serie: Serie, dans exercice: Exercice) {
        guard exercice.series.count > 1 else { return }
        HapticAndSoundManager.shared.triggerLightImpact()
        let deletedID = serie.persistentModelID
        prSerieIDs.remove(deletedID)
        if expandedSerieID == deletedID {
            expandedSerieID = nil
        }
        withAnimation(.snappy(duration: 0.25)) {
            exercice.series.removeAll { $0.persistentModelID == deletedID }
            modelContext.delete(serie)
            for (idx, s) in exercice.seriesTriees.enumerated() {
                s.ordre = idx
            }
        }
        SeanceProgressTracker.shared.recordSetUnvalidation(for: seance)
        dateDebutSeance = SeanceProgressTracker.shared.sessionStartDate(for: seance)
        try? modelContext.save()
    }
    
    private func supprimerExercice(_ exercice: Exercice) {
        HapticAndSoundManager.shared.triggerLightImpact()
        let exID = exercice.persistentModelID
        for s in exercice.series {
            prSerieIDs.remove(s.persistentModelID)
            if expandedSerieID == s.persistentModelID {
                expandedSerieID = nil
            }
        }
        withAnimation(.snappy(duration: 0.25)) {
            seance.exercices.removeAll { $0.persistentModelID == exID }
            modelContext.delete(exercice)
            for (idx, ex) in seance.exercices.sorted(by: { $0.ordre < $1.ordre }).enumerated() {
                ex.ordre = idx
            }
        }
        SeanceProgressTracker.shared.recordSetUnvalidation(for: seance)
        dateDebutSeance = SeanceProgressTracker.shared.sessionStartDate(for: seance)
        try? modelContext.save()
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
            prSerieIDs.remove(serie.persistentModelID)
            SeanceProgressTracker.shared.recordSetUnvalidation(for: seance)
            dateDebutSeance = SeanceProgressTracker.shared.sessionStartDate(for: seance)
            HapticAndSoundManager.shared.triggerLightImpact()
            try? modelContext.save()
            return
        }
        
        if serie.rpeSaisi == nil {
            serie.rpeSaisi = serie.rpeCible
        }
        
        hideKeyboard()
        SeanceProgressTracker.shared.recordSetValidation(for: seance)
        dateDebutSeance = SeanceProgressTracker.shared.sessionStartDate(for: seance)
        
        // Propagation intelligente vers la série N+1 si sa charge est vide
        let series = exercice.seriesTriees
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
        
        try? modelContext.save()
        timerManager.startTimer(for: serie, exercice: exercice)
        
        // Si l'exercice est terminé, auto-scroll vers le prochain exercice actif
        let toutesValideesDansExercice = series.allSatisfy(\.estValidee)
        if toutesValideesDansExercice, let nextEx = prochainExerciceActif {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.snappy) {
                    scrollProxy.scrollTo(nextEx.persistentModelID, anchor: .top)
                }
            }
        }
    }
    
    private func meilleurE1RMActuel(pour exercice: Exercice) -> Double? {
        let e1rmsExercice = exercice.seriesTriees.compactMap { s -> Double? in
            guard let charge = s.chargeSaisie, charge > 0 else { return nil }
            return s.calculerE1RM(charge: charge, reps: s.repsCibles, rpe: s.rpeSaisi ?? s.rpeCible)
        }
        if let maxLocal = e1rmsExercice.max(), maxLocal > 0 {
            return maxLocal
        }
        let hist = meilleurE1RMPrecedent(pour: exercice, excluant: nil)
        return hist > 0 ? hist : nil
    }
    
    private func dernierePerformance(pour exercice: Exercice) -> String? {
        guard let bloc = seance.semaine?.macroBloc else { return nil }
        let cleCible = exercice.cleComparaisonPR
        
        var seancesCandidates: [Seance] = []
        for sem in bloc.semaines {
            for s in sem.seances where s.persistentModelID != seance.persistentModelID && s.date <= seance.date {
                seancesCandidates.append(s)
            }
        }
        seancesCandidates.sort { $0.date > $1.date }
        
        for candidate in seancesCandidates {
            let exCorrespondants = candidate.exercices.filter { $0.cleComparaisonPR == cleCible }
            var bestSerie: Serie? = nil
            var bestScore: Double = 0
            
            for ex in exCorrespondants {
                for s in ex.seriesTriees where s.estValidee {
                    guard let charge = s.chargeSaisie, charge > 0 else { continue }
                    let score = s.calculerE1RM() ?? charge
                    if bestSerie == nil || score > bestScore || (score == bestScore && charge > (bestSerie?.chargeSaisie ?? 0)) {
                        bestSerie = s
                        bestScore = score
                    }
                }
            }
            
            if let best = bestSerie, let charge = best.chargeSaisie {
                let rpe = best.rpeSaisi ?? best.rpeCible
                return "Dernière fois · \(PTFormat.weight(charge)) kg × \(best.repsCibles) @ \(PTFormat.rpe(rpe))"
            }
        }
        
        return nil
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
        let cleCible = exercice.cleComparaisonPR
        
        if let bloc = seance.semaine?.macroBloc {
            if exercice.estMouvementCompetitionPur {
                switch exercice.mouvementParent {
                case .squat where bloc.squat1RM > 0:
                    maxE1RM = max(maxE1RM, bloc.squat1RM)
                case .bench where bloc.bench1RM > 0:
                    maxE1RM = max(maxE1RM, bloc.bench1RM)
                case .deadlift where bloc.deadlift1RM > 0:
                    maxE1RM = max(maxE1RM, bloc.deadlift1RM)
                default:
                    break
                }
            }
            
            for sem in bloc.semaines {
                for s in sem.seances {
                    for ex in s.exercices where ex.cleComparaisonPR == cleCible {
                        for ser in ex.seriesTriees where ser.estValidee && ser.persistentModelID != serieExclue?.persistentModelID {
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
    
    private func detecterDepassementRPETopSet(pour exercice: Exercice) -> Double? {
        guard exercice.categorie == .competition || exercice.nom.lowercased().contains("back-off") else {
            return nil
        }
        let seriesTriees = exercice.seriesTriees
        guard seriesTriees.contains(where: { !$0.estValidee }) else {
            return nil
        }
        
        if let premiereSerie = seriesTriees.first,
           premiereSerie.estValidee,
           let rpeReel = premiereSerie.rpeSaisi {
            let delta = rpeReel - premiereSerie.rpeCible
            if delta >= 1.0 { return delta }
        }
        
        let parent = exercice.mouvementParent
        guard parent != .autre else { return nil }
        for exPrecedent in exercicesTries where exPrecedent.ordre < exercice.ordre && exPrecedent.mouvementParent == parent {
            for s in exPrecedent.seriesTriees where s.estValidee {
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
            for serie in exercice.seriesTriees where !serie.estValidee {
                if let chargeActuelle = serie.chargeSaisie {
                    serie.chargeSaisie = max(0, chargeActuelle - reductionKg)
                }
            }
        }
        try? modelContext.save()
    }
    
    private func demanderAutorisationNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

// MARK: - En-tête d'Exercice Éditorial (Sans Emojis ni Boîtes)

struct ExerciceSectionHeaderView: View {
    let numeroExercice: Int
    let exercice: Exercice
    let meilleurE1RM: Double?
    var dernierePerformance: String? = nil
    let onTapWarmup: () -> Void
    var onAddSet: () -> Void = {}
    var onEditExercice: () -> Void = {}
    var onDeleteExercice: () -> Void = {}
    
    private var labelCategorie: String {
        let num = String(format: "%02d", numeroExercice)
        switch exercice.categorie {
        case .competition: return "\(num) · Compétition"
        case .polyarticulaire: return "\(num) · Polyarticulaire"
        case .isolation: return "\(num) · Isolation"
        }
    }
    
    private var texteBadgeEchauffement: String {
        if let charge = exercice.chargeCibleTopSet, charge > 0 {
            return "Échauffement · \(PTFormat.weight(charge)) kg"
        } else {
            let reps = exercice.repsCiblesTopSet
            let motRep = reps > 1 ? "reps" : "rep"
            return "Échauffement · \(reps) \(motRep)"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                PTKicker(text: labelCategorie)
                
                Spacer(minLength: 6)
                
                if let e1rm = meilleurE1RM {
                    Text("e1RM \(PTFormat.weight(e1rm)) kg")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(PTTheme.accent)
                        .lineLimit(1)
                }
                
                Menu {
                    Button(action: onAddSet) {
                        Label("Ajouter une série", systemImage: "plus")
                    }
                    Button(action: onEditExercice) {
                        Label("Modifier l'exercice", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive, action: onDeleteExercice) {
                        Label("Supprimer l'exercice", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(PTTheme.textTertiary)
                        .frame(width: 26, height: 22)
                        .contentShape(Rectangle())
                }
            }
            
            Text(exercice.nom)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(PTTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            if let indications = exercice.indications, !indications.isEmpty {
                Text(indications)
                    .font(.caption)
                    .foregroundColor(PTTheme.textSecondary)
                    .lineLimit(2)
            }
            
            if let derniere = dernierePerformance {
                Text(derniere)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(PTTheme.textTertiary)
                    .lineLimit(1)
            }
            
            if exercice.necessiteEchauffement {
                Button(action: onTapWarmup) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame")
                            .font(.caption2.weight(.semibold))
                        Text(texteBadgeEchauffement)
                            .font(.caption.weight(.semibold).monospacedDigit())
                    }
                    .foregroundColor(PTTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PTTheme.surface)
                    .overlay(
                        Capsule()
                            .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - Ligne de Série Bord-à-Bord + Tiroir Dépliable

struct SerieCompactRowView: View {
    @Bindable var serie: Serie
    
    let numeroSerie: Int
    let isTopSet: Bool
    let isNextActiveSet: Bool
    let isExpanded: Bool
    let isTheoreticalPR: Bool
    var canDeleteSerie: Bool = false
    let onTapRow: () -> Void
    let onValidateSerie: () -> Void
    var onDeleteSerie: (() -> Void)? = nil
    
    private let rpeOptions: [Double] = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0]
    
    private var rowIndexLabel: String {
        isTopSet ? "Top" : String(format: "%02d", numeroSerie)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Ligne principale
            HStack(spacing: 10) {
                Text(rowIndexLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isNextActiveSet ? PTTheme.accent : PTTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 30, alignment: .leading)
                
                HStack(spacing: 6) {
                    Text("\(serie.repsCibles) reps @ \(PTFormat.rpe(serie.rpeCible))")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundColor(PTTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    if isTheoreticalPR {
                        Text("PR")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(PTTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTapRow)
                
                // Champ Charge épuré
                HStack(spacing: 2) {
                    TextField("-", value: $serie.chargeSaisie, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundColor(PTTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text("kg")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(PTTheme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .frame(width: 78, height: 34)
                .background(PTTheme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PTTheme.hairline, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Bouton RPE discret
                Button(action: onTapRow) {
                    let displayRPE = serie.rpeSaisi ?? serie.rpeCible
                    Text("@\(PTFormat.rpe(displayRPE))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(serie.rpeSaisi != nil ? PTTheme.textPrimary : PTTheme.textSecondary)
                        .lineLimit(1)
                        .frame(width: 44, height: 34)
                        .background(PTTheme.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PTTheme.hairline, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // Bouton de validation circulaire (26pt)
                Button(action: onValidateSerie) {
                    ZStack {
                        if serie.estValidee {
                            Circle()
                                .fill(PTTheme.textPrimary)
                                .frame(width: 26, height: 26)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(PTTheme.bg)
                        } else {
                            Circle()
                                .stroke(isNextActiveSet ? PTTheme.accent : PTTheme.textTertiary, lineWidth: 1.5)
                                .frame(width: 26, height: 26)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(serie.estValidee ? "Série validée" : "Valider la série")
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 54)
            
            // Tiroir d'édition rapide (Charge, RPE, Répétitions, Suppression)
            if isExpanded {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        CompactStepButton(
                            label: "-2.5",
                            onTap: { ajusterCharge(-2.5) },
                            onLongPress: { ajusterCharge(-5.0) }
                        )
                        
                        CompactStepButton(
                            label: "+2.5",
                            onTap: { ajusterCharge(2.5) },
                            onLongPress: { ajusterCharge(5.0) }
                        )
                        
                        Rectangle()
                            .fill(PTTheme.hairline)
                            .frame(width: 0.5, height: 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(rpeOptions, id: \.self) { rpeValue in
                                    let currentRPE = serie.rpeSaisi ?? serie.rpeCible
                                    let isSelected = abs(currentRPE - rpeValue) < 0.01
                                    
                                    Button(action: {
                                        HapticAndSoundManager.shared.triggerSelection()
                                        withAnimation(.snappy(duration: 0.2)) {
                                            serie.rpeSaisi = rpeValue
                                        }
                                    }) {
                                        Text(PTFormat.rpe(rpeValue))
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundColor(isSelected ? PTTheme.bg : PTTheme.textSecondary)
                                            .lineLimit(1)
                                            .frame(minWidth: 32, minHeight: 28)
                                            .padding(.horizontal, 4)
                                            .background(isSelected ? PTTheme.textPrimary : PTTheme.surfaceElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button(action: { ajusterReps(-1) }) {
                            Text("-1 rep")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundColor(PTTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(PTTheme.surfaceElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(serie.repsCibles) \(serie.repsCibles > 1 ? "reps" : "rep")")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundColor(PTTheme.textSecondary)
                            .frame(minWidth: 54, alignment: .center)
                        
                        Button(action: { ajusterReps(1) }) {
                            Text("+1 rep")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundColor(PTTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(PTTheme.surfaceElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        if canDeleteSerie, let onDeleteSerie {
                            Button(role: .destructive, action: onDeleteSerie) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(PTTheme.danger)
                                    .frame(width: 30, height: 28)
                                    .background(PTTheme.surfaceElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(PTTheme.hairline, lineWidth: 0.5)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Supprimer la série")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isNextActiveSet || isExpanded ? PTTheme.surface : Color.clear)
        .overlay(alignment: .leading) {
            if isNextActiveSet {
                Rectangle()
                    .fill(PTTheme.accent)
                    .frame(width: 2)
            }
        }
        .opacity(serie.estValidee ? 0.48 : 1.0)
        .animation(.snappy(duration: 0.25), value: serie.estValidee)
        .animation(.snappy(duration: 0.25), value: isExpanded)
    }
    
    // MARK: - Helpers
    
    private func ajusterCharge(_ delta: Double) {
        HapticAndSoundManager.shared.triggerSelection()
        let base = serie.chargeSaisie ?? 0.0
        serie.chargeSaisie = max(0.0, base + delta)
    }
    
    private func ajusterReps(_ delta: Int) {
        HapticAndSoundManager.shared.triggerSelection()
        serie.repsCibles = max(1, serie.repsCibles + delta)
    }
}

// MARK: - Bouton Stepper Compact (Tap instantané ±2.5 kg, Appui long ±5 kg)

struct CompactStepButton: View {
    let label: String
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Text(label)
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundColor(PTTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(width: 46, height: 28)
            .background(PTTheme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                onLongPress()
            }
    }
}

// MARK: - Header de Télémétrie de Séance (Style Flighty)

struct SeanceProgressHeaderView: View {
    let seance: Seance
    let dateDebutSeance: Date?
    
    private var totalSeries: Int { seance.totalSeriesCount }
    private var seriesValidees: Int { seance.validatedSeriesCount }
    private var pourcentage: Int {
        guard totalSeries > 0 else { return 0 }
        return Int(round(seance.progressionRatio * 100.0))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                PTKicker(text: "\(seriesValidees) / \(totalSeries) séries · \(pourcentage)%")
                
                Spacer()
                
                if let start = dateDebutSeance {
                    TimelineView(.periodic(from: start, by: 1.0)) { context in
                        Text(formatDuration(from: start, to: context.date))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundColor(PTTheme.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Prêt")
                        .font(.caption.weight(.medium))
                        .foregroundColor(PTTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            PTProgressHairline(
                ratio: seance.progressionRatio,
                color: (seriesValidees == totalSeries && totalSeries > 0) ? PTTheme.success : PTTheme.accent
            )
        }
        .background(PTTheme.bg)
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

// MARK: - Modale Ajout / Modification d'Exercice

struct ExerciceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let seance: Seance
    let exerciceToEdit: Exercice?
    let nextOrder: Int
    
    @State private var nom = ""
    @State private var categorie: CategorieExercice = .polyarticulaire
    @State private var indications = ""
    @State private var nbSeries = 3
    @State private var repsCibles = 8
    @State private var rpeCible = 7.5
    @State private var chargeCible: Double? = nil
    
    private var isEditing: Bool { exerciceToEdit != nil }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        PTKicker(text: "Exercice")
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            PTHairline()
                            TextField("Nom de l'exercice", text: $nom)
                                .font(.body.weight(.semibold))
                                .foregroundColor(PTTheme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(PTTheme.surface)
                            PTHairline(leadingInset: 20)
                            TextField("Indications techniques (optionnel)", text: $indications, axis: .vertical)
                                .lineLimit(1...3)
                                .font(.subheadline)
                                .foregroundColor(PTTheme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(PTTheme.surface)
                            PTHairline()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        PTKicker(text: "Catégorie")
                            .padding(.horizontal, 20)
                        
                        HStack(spacing: 8) {
                            categoriePill("Compétition", value: .competition)
                            categoriePill("Polyarticulaire", value: .polyarticulaire)
                            categoriePill("Isolation", value: .isolation)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    if !isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            PTKicker(text: "Séries initiales")
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                PTHairline()
                                integerStepperRow(label: "Séries", value: $nbSeries, range: 1...8)
                                PTHairline(leadingInset: 20)
                                integerStepperRow(label: "Répétitions", value: $repsCibles, range: 1...25)
                                PTHairline(leadingInset: 20)
                                
                                HStack {
                                    Text("RPE cible")
                                        .font(.subheadline)
                                        .foregroundColor(PTTheme.textSecondary)
                                    Spacer()
                                    HStack(spacing: 10) {
                                        stepperMiniButton("-") {
                                            rpeCible = max(5.0, rpeCible - 0.5)
                                        }
                                        Text("@\(PTFormat.rpe(rpeCible))")
                                            .font(.subheadline.weight(.bold).monospacedDigit())
                                            .foregroundColor(PTTheme.textPrimary)
                                            .frame(minWidth: 44)
                                        stepperMiniButton("+") {
                                            rpeCible = min(10.0, rpeCible + 0.5)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                
                                PTHairline(leadingInset: 20)
                                
                                HStack {
                                    Text("Charge (optionnel)")
                                        .font(.subheadline)
                                        .foregroundColor(PTTheme.textSecondary)
                                    Spacer()
                                    HStack(spacing: 6) {
                                        TextField("Auto", value: $chargeCible, format: .number)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .font(.subheadline.weight(.bold).monospacedDigit())
                                            .foregroundColor(PTTheme.textPrimary)
                                            .frame(width: 72)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(PTTheme.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .stroke(PTTheme.hairline, lineWidth: 0.5)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        Text("kg")
                                            .font(.caption)
                                            .foregroundColor(PTTheme.textTertiary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                
                                PTHairline()
                            }
                        }
                    }
                    
                    Button(action: sauvegarder) {
                        Text(isEditing ? "Enregistrer les modifications" : "Ajouter à la séance")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PTPrimaryPillButtonStyle(isDisabled: nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .disabled(nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle(isEditing ? "Modifier l'exercice" : "Nouvel exercice")
            .navigationBarTitleDisplayMode(.inline)
            .ptAppearance()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(PTTheme.textSecondary)
                }
            }
            .onAppear {
                if let ex = exerciceToEdit {
                    nom = ex.nom
                    categorie = ex.categorie
                    indications = ex.indications ?? ""
                }
            }
        }
    }
    
    private func categoriePill(_ titre: String, value: CategorieExercice) -> some View {
        let isSelected = (categorie == value)
        return Button {
            HapticAndSoundManager.shared.triggerSelection()
            categorie = value
        } label: {
            Text(titre)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? PTTheme.bg : PTTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? PTTheme.textPrimary : PTTheme.surface)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : PTTheme.hairline, lineWidth: 0.5)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func integerStepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(PTTheme.textSecondary)
            Spacer()
            HStack(spacing: 10) {
                stepperMiniButton("-") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                }
                Text("\(value.wrappedValue)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundColor(PTTheme.textPrimary)
                    .frame(minWidth: 32)
                stepperMiniButton("+") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func stepperMiniButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticAndSoundManager.shared.triggerSelection()
            action()
        } label: {
            Text(label)
                .font(.subheadline.weight(.bold))
                .foregroundColor(PTTheme.textPrimary)
                .frame(width: 30, height: 28)
                .background(PTTheme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(PTTheme.hairlineStrong, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func sauvegarder() {
        let nomNettoye = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nomNettoye.isEmpty else { return }
        let indic = indications.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let ex = exerciceToEdit {
            ex.nom = nomNettoye
            ex.categorie = categorie
            ex.indications = indic.isEmpty ? nil : indic
        } else {
            let ex = Exercice(
                nom: nomNettoye,
                categorie: categorie,
                indications: indic.isEmpty ? nil : indic,
                ordre: nextOrder
            )
            ex.seance = seance
            for idx in 0..<nbSeries {
                let s = Serie(
                    repsCibles: repsCibles,
                    rpeCible: rpeCible,
                    chargeSaisie: chargeCible,
                    ordre: idx
                )
                s.exercice = ex
                ex.series.append(s)
            }
            seance.exercices.append(ex)
        }
        
        try? modelContext.save()
        HapticAndSoundManager.shared.triggerSetValidated()
        dismiss()
    }
}

// MARK: - Bandeau Discret d'Adaptation Back-offs

struct BackoffAdaptationBannerView: View {
    let rpeDepassement: Double
    let onApplyReduction: (Double) -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Text("Top Set +\(String(format: "%.1f", rpeDepassement)) RPE · Alléger")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundColor(PTTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Spacer(minLength: 4)
            
            Button(action: { onApplyReduction(2.5) }) {
                Text("-2.5 kg")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(PTTheme.textPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(PTTheme.surfaceElevated)
                    .overlay(Capsule().stroke(PTTheme.hairlineStrong, lineWidth: 0.5))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button(action: { onApplyReduction(5.0) }) {
                Text("-5 kg")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(PTTheme.bg)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(PTTheme.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(PTTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(PTTheme.accent)
                .frame(width: 2)
        }
    }
}

extension View {
    /// Masque le clavier virtuel
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
