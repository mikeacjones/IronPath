import SwiftUI
import Combine

@main
struct IronPathApp: App {
    @StateObject private var appState = AppState()
    @ObservedObject private var cloudSync = CloudSyncManager.shared

    var body: some Scene {
        WindowGroup {
            if !cloudSync.hasCompletedInitialSync {
                // Show loading while restoring from iCloud
                CloudSyncLoadingView()
            } else {
                ContentView()
                    .environmentObject(appState)
                    .overlay(alignment: .top) {
                        // Show restoration banner if data was restored
                        if cloudSync.restoredWorkoutsCount > 0 {
                            DataRestorationBanner(count: cloudSync.restoredWorkoutsCount)
                        }
                    }
            }
        }
    }
}

// MARK: - Cloud Sync Loading View

struct CloudSyncLoadingView: View {
    @ObservedObject private var cloudSync = CloudSyncManager.shared
    @State private var showingManualContinue = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, options: .repeating)

            Text("Restoring Your Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Checking iCloud for your workout history...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 8)

            Spacer()

            // Show manual continue option after 5 seconds
            if showingManualContinue {
                Button {
                    // Force complete the sync
                    Task { @MainActor in
                        cloudSync.hasCompletedInitialSync = true
                    }
                } label: {
                    Text("Continue Without Waiting")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
        .padding()
        .task {
            // Show manual continue option after 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            showingManualContinue = true
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
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
