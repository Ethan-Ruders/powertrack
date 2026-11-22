import SwiftUI
import SwiftData

struct SemaineListView: View {
    let macroBloc: MacroBloc
    @ObservedObject private var progressTracker = SeanceProgressTracker.shared
    @State private var isShowingEditSheet = false
    
    private var seanceEnCours: Seance? {
        _ = progressTracker.lastUpdateToken
        return progressTracker.findActiveSeance(in: [macroBloc])
    }
    
    private var semainesTriees: [Semaine] {
        macroBloc.semaines.sorted { $0.numero < $1.numero }
    }
    
    private var referenceText: String {
        var parts: [String] = []
        if macroBloc.squat1RM > 0 { parts.append("S \(PTFormat.weight(macroBloc.squat1RM))") }
        if macroBloc.bench1RM > 0 { parts.append("B \(PTFormat.weight(macroBloc.bench1RM))") }
        if macroBloc.deadlift1RM > 0 { parts.append("D \(PTFormat.weight(macroBloc.deadlift1RM))") }
        return parts.isEmpty ? "\(semainesTriees.count) semaines" : parts.joined(separator: " · ") + " kg"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerSummary
                PTHairline()
                
                ForEach(semainesTriees) { semaine in
                    NavigationLink(destination: SeanceListView(semaine: semaine)) {
                        semaineRow(for: semaine)
                    }
                    .buttonStyle(.plain)
                    
                    PTHairline(leadingInset: 20)
                }
            }
        }
        .background(PTTheme.bg.ignoresSafeArea())
        .navigationTitle(macroBloc.nom)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticAndSoundManager.shared.triggerLightImpact()
                    isShowingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundColor(PTTheme.textPrimary)
                }
                .accessibilityLabel("Modifier le bloc")
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            BlocEditSheet(macroBloc: macroBloc)
        }
        .safeAreaInset(edge: .bottom) {
            PTBottomOverlayStack(activeSeance: seanceEnCours)
        }
    }
    
    // MARK: - Sous-vues Éditoriales
    
    private var headerSummary: some View {
        let ratio = macroBloc.progressionRatio
        let pct = Int(round(ratio * 100.0))
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    PTKicker(text: "1RM de référence")
                    Text(referenceText)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(PTTheme.textPrimary)
                }
                
                Spacer()
                
                Text("\(pct)%")
                    .font(.system(size: 24, weight: .bold).monospacedDigit())
                    .foregroundColor(ratio >= 1.0 && macroBloc.totalSeriesCount > 0 ? PTTheme.success : PTTheme.textPrimary)
            }
            
            PTProgressHairline(
                ratio: ratio,
                color: ratio >= 1.0 && macroBloc.totalSeriesCount > 0 ? PTTheme.success : PTTheme.accent
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func semaineRow(for semaine: Semaine) -> some View {
        let ratio = semaine.progressionRatio
        let pct = Int(round(ratio * 100.0))
        let isActive = macroBloc.activeSemaineNumero == semaine.numero && ratio < 1.0
        let isDone = semaine.totalSeriesCount > 0 && ratio >= 1.0
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(String(format: "S%02d", semaine.numero))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isDone ? PTTheme.success : (isActive ? PTTheme.accent : PTTheme.textSecondary))
                    .frame(width: 34, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(semaine.nom)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(PTTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text("\(semaine.completedSeancesCount)/\(semaine.seances.count) séances · \(semaine.validatedSeriesCount)/\(semaine.totalSeriesCount) séries")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(PTTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 6)
                
                HStack(spacing: 8) {
                    Text("\(pct)%")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundColor(isDone ? PTTheme.success : PTTheme.textSecondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(PTTheme.textTertiary)
                }
            }
            
            if ratio > 0 {
                PTProgressHairline(
                    ratio: ratio,
                    color: isDone ? PTTheme.success : PTTheme.accent
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Modale d'Édition de Bloc (Nom & 1RM de référence)

struct BlocEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let macroBloc: MacroBloc
    
    @State private var nom: String = ""
    @State private var squat1RM: Double = 0
    @State private var bench1RM: Double = 0
    @State private var deadlift1RM: Double = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        PTKicker(text: "Nom du bloc")
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            PTHairline()
                            TextField("Nom du bloc", text: $nom)
                                .font(.body.weight(.medium))
                                .foregroundColor(PTTheme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(PTTheme.surface)
                            PTHairline()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        PTKicker(text: "1RM de référence (kg)")
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            PTHairline()
                            oneRMInputRow(titre: "Squat", value: $squat1RM)
                            PTHairline(leadingInset: 20)
                            oneRMInputRow(titre: "Bench Press", value: $bench1RM)
                            PTHairline(leadingInset: 20)
                            oneRMInputRow(titre: "Deadlift", value: $deadlift1RM)
                            PTHairline()
                        }
                    }
                    
                    Button(action: enregistrer) {
                        Text("Enregistrer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PTPrimaryPillButtonStyle())
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PTTheme.bg.ignoresSafeArea())
            .navigationTitle("Modifier le bloc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(PTTheme.textSecondary)
                }
            }
            .onAppear {
                nom = macroBloc.nom
                squat1RM = macroBloc.squat1RM
                bench1RM = macroBloc.bench1RM
                deadlift1RM = macroBloc.deadlift1RM
            }
        }
    }
    
    private func oneRMInputRow(titre: String, value: Binding<Double>) -> some View {
        HStack {
            Text(titre)
                .font(.body.weight(.medium))
                .foregroundColor(PTTheme.textPrimary)
            
            Spacer()
            
            HStack(spacing: 6) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundColor(PTTheme.textPrimary)
                    .frame(width: 82)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func enregistrer() {
        let trimmed = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            macroBloc.nom = trimmed
        }
        macroBloc.squat1RM = max(0, squat1RM)
        macroBloc.bench1RM = max(0, bench1RM)
        macroBloc.deadlift1RM = max(0, deadlift1RM)
        try? modelContext.save()
        HapticAndSoundManager.shared.triggerSetValidated()
        dismiss()
    }
}
