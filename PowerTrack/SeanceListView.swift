import SwiftUI
import SwiftData

struct SeanceListView: View {
    let semaine: Semaine
    
    @ObservedObject private var progressTracker = SeanceProgressTracker.shared
    @ObservedObject private var exportManager = ExportManager.shared
    
    private var seancesTriees: [Seance] {
        semaine.seances.sorted { $0.date < $1.date }
    }
    
    private var seanceEnCours: Seance? {
        _ = progressTracker.lastUpdateToken
        guard let bloc = semaine.macroBloc else { return nil }
        return progressTracker.findActiveSeance(in: [bloc])
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerStrip
                PTHairline()
                
                ForEach(seancesTriees) { seance in
                    NavigationLink(destination: SeanceDetailView(seance: seance)) {
                        seanceRow(for: seance)
                    }
                    .buttonStyle(.plain)
                    
                    PTHairline(leadingInset: 20)
                }
            }
        }
        .background(PTTheme.bg.ignoresSafeArea())
        .navigationTitle(semaine.nom)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PTBottomOverlayStack(activeSeance: seanceEnCours)
        }
    }
    
    // MARK: - Sous-vues Éditoriales
    
    private var headerStrip: some View {
        let ratio = semaine.progressionRatio
        let pct = Int(round(ratio * 100.0))
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                PTKicker(text: "\(semaine.completedSeancesCount) / \(semaine.seances.count) séances terminées")
                Spacer()
                Text("\(pct)%")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundColor(ratio >= 1.0 && semaine.totalSeriesCount > 0 ? PTTheme.success : PTTheme.textPrimary)
            }
            
            PTProgressHairline(
                ratio: ratio,
                color: ratio >= 1.0 && semaine.totalSeriesCount > 0 ? PTTheme.success : PTTheme.accent
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    private func seanceRow(for seance: Seance) -> some View {
        let validated = seance.validatedSeriesCount
        let total = seance.totalSeriesCount
        let isDone = total > 0 && validated == total
        let isInProgress = validated > 0 && !isDone
        let isSynced = exportManager.isSeanceExported(seance)
        let isPending = exportManager.isSeancePendingExport(seance)
        
        let statusColor: Color = isDone ? PTTheme.success : (isInProgress ? PTTheme.accent : PTTheme.textTertiary)
        let dateLabel = seance.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                PTKicker(
                    text: dateLabel,
                    color: isInProgress ? PTTheme.accent : PTTheme.textSecondary
                )
                
                Text(seance.titre ?? seance.date.formatted(date: .abbreviated, time: .omitted).capitalized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PTTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Text("\(seance.exercices.count) exercices · \(validated)/\(total) séries")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(PTTheme.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 6)
            
            HStack(spacing: 10) {
                if isSynced {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Sync")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(PTTheme.textTertiary)
                } else if isPending {
                    Text("En file")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(PTTheme.accent)
                }
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(PTTheme.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }
}
