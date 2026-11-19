import SwiftUI
import SwiftData

struct SemaineListView: View {
    let macroBloc: MacroBloc
    @ObservedObject private var progressTracker = SeanceProgressTracker.shared
    
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
        .safeAreaInset(edge: .bottom) {
            if let seanceActive = seanceEnCours {
                ResumeWorkoutBannerView(seance: seanceActive)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
