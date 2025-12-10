import SwiftUI

// MARK: - Main Tab View

/// The main tab navigation container for the app
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .tag(1)

            ProgressTabView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(3)
        }
    }
}
