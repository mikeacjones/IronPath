import SwiftUI

@main
struct IronPathApp: App {
    @State private var appState = AppState()
    @State private var dependencyContainer = DependencyContainer.shared
    @State private var cloudSync = CloudSyncManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(dependencyContainer)
                .environment(\.dependencyContainer, dependencyContainer)
                .overlay(alignment: .top) {
                    // Show restoration banner if data was restored from iCloud
                    if cloudSync.restoredWorkoutsCount > 0 && cloudSync.hasCompletedInitialSync {
                        DataRestorationBanner(count: cloudSync.restoredWorkoutsCount)
                    }
                }
        }
    }
}

// MARK: - Data Restoration Banner

struct DataRestorationBanner: View {
    let count: Int
    @State private var isVisible = true

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundStyle(.green)

                Text("\(count) workout\(count == 1 ? "" : "s") restored from iCloud")
                    .font(.subheadline)

                Spacer()

                Button {
                    withAnimation {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 5 seconds
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    withAnimation {
                        isVisible = false
                    }
                }
            }
        }
    }
}

/// Global app state management
@Observable
@MainActor
final class AppState {
    var isOnboarded: Bool = false
    var userProfile: UserProfile? {
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
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleCloudSync()
            }
        }
    }

    // Note: AppState is owned by @State in App and lives for app lifetime, no deinit needed

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
