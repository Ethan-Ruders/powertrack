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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(semainesTriees) { semaine in
                    NavigationLink(destination: SeanceListView(semaine: semaine)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(semaine.nom)
                                    .font(.headline.monospacedDigit())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                
                                Text("\(semaine.seances.count) séances")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.orange)
                        }
                        .padding(16)
                        .background(Color(white: 0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
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
}
