import SwiftUI
import SwiftData

struct SeanceListView: View {
    let semaine: Semaine
    
    private var seancesTriees: [Seance] {
        semaine.seances.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(seancesTriees) { seance in
                    NavigationLink(destination: SeanceDetailView(seance: seance)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(seance.titre ?? seance.date.formatted(date: .abbreviated, time: .omitted).capitalized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                
                                HStack(spacing: 6) {
                                    Text(seance.date.formatted(date: .abbreviated, time: .omitted))
                                    Text("•")
                                    Text("\(seance.exercices.count) exercices")
                                    if seance.validatedSeriesCount > 0 {
                                        Text("• \(seance.validatedSeriesCount)/\(seance.totalSeriesCount)")
                                    }
                                }
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
        .navigationTitle(semaine.nom)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}
