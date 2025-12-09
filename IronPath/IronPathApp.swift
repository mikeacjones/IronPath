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

    private var cloudSyncObserver: NSObjectProtocol?

    init() {
        // Load saved profile from iCloud/local storage
        loadProfile()
        // Check if user has completed onboarding (from iCloud first)
        self.isOnboarded = CloudSyncManager.shared.loadOnboardingCompleted()

        // Listen for iCloud sync changes
        cloudSyncObserver = NotificationCenter.default.addObserver(
            forName: .cloudDataDidSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCloudSync()
        }
    }

    deinit {
        if let observer = cloudSyncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func completeOnboarding(profile: UserProfile) {
        self.userProfile = profile
        self.isOnboarded = true
        CloudSyncManager.shared.saveOnboardingCompleted(true)
    }

    func updateProfile(_ profile: UserProfile) {
        self.userProfile = profile
    }

    private func saveProfile() {
        guard let profile = userProfile else { return }
        CloudSyncManager.shared.saveUserProfile(profile)
    }

    private func loadProfile() {
        if let profile = CloudSyncManager.shared.loadUserProfile() {
            self.userProfile = profile
        }
    }

    private func handleCloudSync() {
        // Reload data when iCloud sync occurs
        loadProfile()
        let wasOnboarded = isOnboarded
        isOnboarded = CloudSyncManager.shared.loadOnboardingCompleted()

        // If profile was restored from cloud, update onboarding state
        if !wasOnboarded && userProfile != nil {
            isOnboarded = true
        }
    }
}
