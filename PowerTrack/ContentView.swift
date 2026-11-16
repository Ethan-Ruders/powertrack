import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            BlocListView()
                .tabItem {
                    Label("Programmation", systemImage: "dumbbell.fill")
                }
            
            PerformanceDashboardView()
                .tabItem {
                    Label("Performance", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(.orange)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MacroBloc.self, inMemory: true)
}
