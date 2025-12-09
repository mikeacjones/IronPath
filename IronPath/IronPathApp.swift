import SwiftUI
import Combine

@main
struct IronPathApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Global app state management
class AppState: ObservableObject {
    @Published var isOnboarded: Bool = false
    @Published var userProfile: UserProfile? {
        didSet {
            saveProfile()
        }
    }

    private let profileKey = "user_profile"

    init() {
        // Load saved profile
        loadProfile()
        // Check if user has completed onboarding
        self.isOnboarded = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding(profile: UserProfile) {
        self.userProfile = profile
        self.isOnboarded = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func updateProfile(_ profile: UserProfile) {
        self.userProfile = profile
    }

    private func saveProfile() {
        guard let profile = userProfile else {
            UserDefaults.standard.removeObject(forKey: profileKey)
            return
        }

        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(profile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
        }
    }

    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: profileKey) else {
            return
        }

        let decoder = JSONDecoder()
        if let profile = try? decoder.decode(UserProfile.self, from: data) {
            self.userProfile = profile
        }
    }
}
