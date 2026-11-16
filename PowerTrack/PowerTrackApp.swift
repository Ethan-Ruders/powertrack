import SwiftUI
import SwiftData

@main
struct PowerTrackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: MacroBloc.self)
    }
}
