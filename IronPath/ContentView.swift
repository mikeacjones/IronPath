import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Group {
            if appState.isOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
