import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject private var rankManager = RankStateManager.shared
    
    var body: some View {
        ZStack {
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
            .tint(PTTheme.accent)
            
            if let promotion = rankManager.activePromotion {
                RankUpOverlayView(event: promotion) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        rankManager.dismissPromotion()
                    }
                }
                .zIndex(90)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let toast = rankManager.activeToast {
                PTCelebrationToastView(toast: toast) {
                    withAnimation(.snappy(duration: 0.25)) {
                        rankManager.dismissToast()
                    }
                }
                .zIndex(80)
            }
        }
        .animation(.snappy(duration: 0.32), value: rankManager.activeToast?.id)
        .ptAppearance()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MacroBloc.self, inMemory: true)
}
