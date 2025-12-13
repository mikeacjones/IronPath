import Foundation
import CloudKit
import OSLog

/// Sync status for tracking data restoration progress
enum CloudSyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(String)

    var isLoading: Bool {
        if case .syncing = self { return true }
        return false
    }
}

/// Manages iCloud sync for app data persistence across installs
/// Uses NSUbiquitousKeyValueStore for small data and CloudKit for larger data
@Observable
@MainActor
final class CloudSyncManager {
    static let shared = CloudSyncManager()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let container = CKContainer(identifier: "iCloud.com.kotrs.IronPath")
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }

    /// Sync status for UI observation
    private(set) var syncStatus: CloudSyncStatus = .idle

    /// Whether initial sync has completed (important for fresh installs)
    var hasCompletedInitialSync = false

    /// Number of workouts restored from cloud (for UI feedback)
    private(set) var restoredWorkoutsCount: Int = 0

    /// Check if iCloud is available (user is signed in)
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // Keys for iCloud KV storage (small data)
    private enum KVKeys {
        static let userProfile = "cloud_user_profile"
        static let apiKey = "cloud_api_key"
        static let hasCompletedOnboarding = "cloud_has_completed_onboarding"
        static let activeGymProfileId = "cloud_active_gym_profile_id"
    }

    // CloudKit record types (large data)
    private enum RecordTypes {
        static let workoutHistory = "WorkoutHistory"
        static let gymSettings = "GymSettings"
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        // Register for iCloud KV change notifications (always register, check availability when handling)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDataDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )

        // Only set up iCloud sync if signed in
        if isICloudAvailable {
            // Sync on launch
            kvStore.synchronize()

            // Fetch CloudKit data on launch
            Task {
                await performInitialSync()
            }
        } else {
            // No iCloud, mark as completed immediately
            hasCompletedInitialSync = true
            AppLogger.cloud.info("iCloud not available, using local storage only")
        }
    }

    /// Perform initial sync on app launch - waits for CloudKit data
    private func performInitialSync() async {
        syncStatus = .syncing
        AppLogger.cloud.info("Starting initial sync...")

        do {
            await fetchCloudKitData()
            syncStatus = .completed
            hasCompletedInitialSync = true
            AppLogger.cloud.info("Initial sync completed successfully")
        } catch {
            syncStatus = .failed(error.localizedDescription)
            hasCompletedInitialSync = true // Still mark as completed so app isn't blocked
            AppLogger.cloud.error("Initial sync failed", error: error)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - KV Store Sync Trigger

    // Note: nonisolated because @objc selectors are called from NotificationCenter on arbitrary threads
    @objc nonisolated private func cloudDataDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        switch reason {
        case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange:
            Task { @MainActor in
                NotificationCenter.default.post(name: .cloudDataDidSync, object: nil)
            }
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            AppLogger.cloud.warning("iCloud KV storage quota exceeded")
        case NSUbiquitousKeyValueStoreAccountChange:
            AppLogger.cloud.info("iCloud account changed")
        default:
            break
        }
    }

    // MARK: - CloudKit Data Fetch

    private func fetchCloudKitData() async {
        await fetchWorkoutHistoryFromCloud()
        await fetchGymSettingsFromCloud()
    }

    // MARK: - User Profile (KV Store - small data)

    func saveUserProfile(_ profile: UserProfile) {
        guard let data = try? encoder.encode(profile) else { return }

        // Always save locally
        UserDefaults.standard.set(data, forKey: "user_profile")

        // Sync to iCloud if available
        if isICloudAvailable {
            kvStore.set(data, forKey: KVKeys.userProfile)
            kvStore.synchronize()
        }
    }

    func loadUserProfile() -> UserProfile? {
        // Try iCloud first if available
        if isICloudAvailable,
           let data = kvStore.data(forKey: KVKeys.userProfile),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            UserDefaults.standard.set(data, forKey: "user_profile")
            return profile
        }

        // Fallback to local
        if let data = UserDefaults.standard.data(forKey: "user_profile"),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            // Sync to iCloud if available
            if isICloudAvailable {
                kvStore.set(data, forKey: KVKeys.userProfile)
                kvStore.synchronize()
            }
            return profile
        }

        return nil
    }

    // MARK: - Onboarding Status (KV Store)

    func saveOnboardingCompleted(_ completed: Bool) {
        // Always save locally
        UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")

        // Sync to iCloud if available
        if isICloudAvailable {
            kvStore.set(completed, forKey: KVKeys.hasCompletedOnboarding)
            kvStore.synchronize()
        }
    }

    func loadOnboardingCompleted() -> Bool {
        // Try iCloud first if available
        if isICloudAvailable, kvStore.object(forKey: KVKeys.hasCompletedOnboarding) != nil {
            let cloudValue = kvStore.bool(forKey: KVKeys.hasCompletedOnboarding)
            UserDefaults.standard.set(cloudValue, forKey: "hasCompletedOnboarding")
            return cloudValue
        }

        // Fallback to local
        let localValue = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if localValue && isICloudAvailable {
            kvStore.set(localValue, forKey: KVKeys.hasCompletedOnboarding)
            kvStore.synchronize()
        }
        return localValue
    }

    // MARK: - Workout History (CloudKit - large data)

    func saveWorkoutHistory(_ workouts: [Workout]) {
        guard let data = try? encoder.encode(workouts) else { return }

        // Always save locally first with timestamp
        let now = Date()
        UserDefaults.standard.set(data, forKey: "workout_history")
        UserDefaults.standard.set(now, forKey: "workout_history_updated")

        // Save to CloudKit
        Task {
            await saveWorkoutHistoryToCloud(data)
        }
    }

    func loadWorkoutHistory() -> [Workout] {
        // Return local data immediately (CloudKit fetches async on init)
        if let data = UserDefaults.standard.data(forKey: "workout_history"),
           let workouts = try? decoder.decode([Workout].self, from: data) {
            return workouts
        }
        return []
    }

    /// Force fetch workout history from CloudKit (useful after reinstall)
    func fetchWorkoutHistorySync() async -> [Workout] {
        await fetchWorkoutHistoryFromCloud()
        return loadWorkoutHistory()
    }

    private func saveWorkoutHistoryToCloud(_ data: Data) async {
        let recordID = CKRecord.ID(recordName: "workout_history_v1")
        let record = CKRecord(recordType: RecordTypes.workoutHistory, recordID: recordID)
        record["data"] = data as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        do {
            _ = try await privateDatabase.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Record exists, fetch and update
            do {
                let existingRecord = try await privateDatabase.record(for: recordID)
                existingRecord["data"] = data as CKRecordValue
                existingRecord["updatedAt"] = Date() as CKRecordValue
                _ = try await privateDatabase.save(existingRecord)
            } catch {
                // Silently fail - local storage is the fallback
            }
        } catch let error as CKError where error.code == .notAuthenticated {
            // User not signed into iCloud - silently use local storage only
            return
        } catch {
            // Other errors - silently fail, local storage is the fallback
        }
    }

    private func fetchWorkoutHistoryFromCloud() async {
        guard isICloudAvailable else { return }

        let recordID = CKRecord.ID(recordName: "workout_history_v1")

        // Retry logic for transient failures
        var retryCount = 0
        let maxRetries = 3

        while retryCount < maxRetries {
            do {
                let record = try await privateDatabase.record(for: recordID)
                if let data = record["data"] as? Data,
                   let cloudUpdatedAt = record["updatedAt"] as? Date {

                    // Check if local data exists
                    let localData = UserDefaults.standard.data(forKey: "workout_history")
                    let localUpdatedAt = UserDefaults.standard.object(forKey: "workout_history_updated") as? Date ?? Date.distantPast

                    // If local is empty (fresh install) or cloud is newer, use cloud data
                    let localWorkouts = localData.flatMap { try? decoder.decode([Workout].self, from: $0) } ?? []
                    let localIsEmpty = localWorkouts.isEmpty

                    if localIsEmpty || cloudUpdatedAt > localUpdatedAt {
                        // Cloud is newer or local is empty, update local
                        UserDefaults.standard.set(data, forKey: "workout_history")
                        UserDefaults.standard.set(cloudUpdatedAt, forKey: "workout_history_updated")

                        let restoredCount = (try? decoder.decode([Workout].self, from: data))?.count ?? 0

                        self.restoredWorkoutsCount = restoredCount
                        NotificationCenter.default.post(name: .cloudDataDidSync, object: nil)
                        AppLogger.cloud.info("Restored \(restoredCount) workouts from iCloud")
                    } else if !localWorkouts.isEmpty && localUpdatedAt > cloudUpdatedAt {
                        // Local is newer and not empty, push to cloud
                        await saveWorkoutHistoryToCloud(localData!)
                    }
                }
                return // Success, exit retry loop

            } catch let error as CKError where error.code == .unknownItem {
                // No cloud record exists yet, push local data if available
                if let localData = UserDefaults.standard.data(forKey: "workout_history") {
                    await saveWorkoutHistoryToCloud(localData)
                    AppLogger.cloud.info("Pushed local workout history to iCloud (no cloud record existed)")
                }
                return

            } catch let error as CKError where error.code == .notAuthenticated {
                // User not signed into iCloud - silently use local storage only
                AppLogger.cloud.info("User not signed into iCloud")
                return

            } catch let error as CKError where error.code == .networkUnavailable || error.code == .networkFailure {
                // Network issue - retry
                retryCount += 1
                if retryCount < maxRetries {
                    AppLogger.cloud.warning("Network error, retrying (\(retryCount)/\(maxRetries))...")
                    try? await Task.sleep(nanoseconds: UInt64(retryCount) * 1_000_000_000) // Exponential backoff
                } else {
                    AppLogger.cloud.error("Network error after \(maxRetries) retries: \(error.localizedDescription)")
                }

            } catch let error as CKError where error.code == .serviceUnavailable || error.code == .requestRateLimited {
                // Service temporarily unavailable - retry with longer delay
                retryCount += 1
                if retryCount < maxRetries {
                    AppLogger.cloud.warning("Service unavailable, retrying (\(retryCount)/\(maxRetries))...")
                    try? await Task.sleep(nanoseconds: UInt64(retryCount * 2) * 1_000_000_000)
                } else {
                    AppLogger.cloud.error("Service unavailable after \(maxRetries) retries")
                }

            } catch {
                // Log error for debugging
                AppLogger.cloud.error("Error fetching workout history: \(error.localizedDescription)")
                return
            }
        }
    }

    // MARK: - Active Gym Profile ID (KV Store)

    func saveActiveGymProfileId(_ id: UUID?) {
        let idString = id?.uuidString

        // Always save locally
        UserDefaults.standard.set(idString, forKey: "activeGymProfileId")

        // Sync to iCloud if available
        if isICloudAvailable {
            if let idString = idString {
                kvStore.set(idString, forKey: KVKeys.activeGymProfileId)
            } else {
                kvStore.removeObject(forKey: KVKeys.activeGymProfileId)
            }
            kvStore.synchronize()
        }
    }

    func loadActiveGymProfileId() -> UUID? {
        // Try iCloud first if available
        if isICloudAvailable,
           let idString = kvStore.string(forKey: KVKeys.activeGymProfileId),
           let id = UUID(uuidString: idString) {
            UserDefaults.standard.set(idString, forKey: "activeGymProfileId")
            return id
        }

        // Fallback to local
        if let idString = UserDefaults.standard.string(forKey: "activeGymProfileId"),
           let id = UUID(uuidString: idString) {
            // Sync to iCloud if available
            if isICloudAvailable {
                kvStore.set(idString, forKey: KVKeys.activeGymProfileId)
                kvStore.synchronize()
            }
            return id
        }

        return nil
    }

    // MARK: - Gym Profiles (CloudKit - potentially large)

    func saveGymProfiles(_ data: Data) {
        UserDefaults.standard.set(data, forKey: "gymProfiles")
        UserDefaults.standard.set(Date(), forKey: "gym_settings_updated")

        Task {
            await saveGymSettingsToCloud(data)
        }
    }

    func loadGymProfiles() -> Data? {
        return UserDefaults.standard.data(forKey: "gymProfiles")
    }

    // Legacy compatibility
    func saveGymSettings(_ settings: GymSettings) {
        // This is called from GymProfileManager, which handles saving gym profiles
        // The actual save is done via saveGymProfiles
        if let data = UserDefaults.standard.data(forKey: "gymProfiles") {
            Task {
                await saveGymSettingsToCloud(data)
            }
        }
    }

    func loadGymSettings() -> GymSettings? {
        // GymSettings loads from GymProfileManager, not directly
        return nil
    }

    private func saveGymSettingsToCloud(_ data: Data) async {
        let recordID = CKRecord.ID(recordName: "gym_settings_v1")
        let record = CKRecord(recordType: RecordTypes.gymSettings, recordID: recordID)
        record["data"] = data as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        do {
            _ = try await privateDatabase.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            do {
                let existingRecord = try await privateDatabase.record(for: recordID)
                existingRecord["data"] = data as CKRecordValue
                existingRecord["updatedAt"] = Date() as CKRecordValue
                _ = try await privateDatabase.save(existingRecord)
            } catch {
                // Silently fail - local storage is the fallback
            }
        } catch let error as CKError where error.code == .notAuthenticated {
            // User not signed into iCloud - silently use local storage only
            return
        } catch {
            // Other errors - silently fail, local storage is the fallback
        }
    }

    private func fetchGymSettingsFromCloud() async {
        guard isICloudAvailable else { return }

        let recordID = CKRecord.ID(recordName: "gym_settings_v1")

        do {
            let record = try await privateDatabase.record(for: recordID)
            if let data = record["data"] as? Data,
               let cloudUpdatedAt = record["updatedAt"] as? Date {

                let localData = UserDefaults.standard.data(forKey: "gymProfiles")
                let localUpdatedAt = UserDefaults.standard.object(forKey: "gym_settings_updated") as? Date ?? Date.distantPast

                // If local is empty (fresh install) or cloud is newer, use cloud data
                let localIsEmpty = localData == nil

                if localIsEmpty || cloudUpdatedAt > localUpdatedAt {
                    UserDefaults.standard.set(data, forKey: "gymProfiles")
                    UserDefaults.standard.set(cloudUpdatedAt, forKey: "gym_settings_updated")

                    NotificationCenter.default.post(name: .cloudDataDidSync, object: nil)
                    AppLogger.cloud.info("Restored gym settings from iCloud")
                } else if localData != nil && localUpdatedAt > cloudUpdatedAt {
                    await saveGymSettingsToCloud(localData!)
                }
            }
        } catch let error as CKError where error.code == .unknownItem {
            if let localData = UserDefaults.standard.data(forKey: "gymProfiles") {
                await saveGymSettingsToCloud(localData)
                AppLogger.cloud.info("Pushed gym settings to iCloud (no cloud record existed)")
            }
        } catch let error as CKError where error.code == .notAuthenticated {
            AppLogger.cloud.info("User not signed into iCloud")
            return
        } catch {
            AppLogger.cloud.error("Error fetching gym settings: \(error.localizedDescription)")
        }
    }

    // MARK: - API Key (KV Store with obfuscation)

    func saveAPIKey(_ key: String) {
        // Always save locally
        UserDefaults.standard.set(key, forKey: "anthropic_api_key")

        // Sync to iCloud if available
        if isICloudAvailable {
            let obfuscated = Data(key.utf8).base64EncodedString()
            kvStore.set(obfuscated, forKey: KVKeys.apiKey)
            kvStore.synchronize()
        }
    }

    func loadAPIKey() -> String? {
        // Try iCloud first if available
        if isICloudAvailable,
           let obfuscated = kvStore.string(forKey: KVKeys.apiKey),
           let data = Data(base64Encoded: obfuscated),
           let key = String(data: data, encoding: .utf8), !key.isEmpty {
            UserDefaults.standard.set(key, forKey: "anthropic_api_key")
            return key
        }

        // Fallback to local
        if let key = UserDefaults.standard.string(forKey: "anthropic_api_key"), !key.isEmpty {
            // Sync to iCloud if available
            if isICloudAvailable {
                let obfuscated = Data(key.utf8).base64EncodedString()
                kvStore.set(obfuscated, forKey: KVKeys.apiKey)
                kvStore.synchronize()
            }
            return key
        }

        return nil
    }

    // MARK: - Force Sync

    func forceSync() {
        if isICloudAvailable {
            kvStore.synchronize()
        }
        Task {
            await fetchCloudKitData()
        }
    }

    // MARK: - Clear All Data

    /// Clears all app data from both local storage and iCloud
    func clearAllData() async {
        // Clear local UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "workout_history")
        defaults.removeObject(forKey: "workout_history_updated")
        defaults.removeObject(forKey: "user_profile")
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        defaults.removeObject(forKey: "gymProfiles")
        defaults.removeObject(forKey: "gym_settings_updated")
        defaults.removeObject(forKey: "activeGymProfileId")
        defaults.removeObject(forKey: "anthropic_api_key")
        defaults.removeObject(forKey: "exercisePreferences")

        // Clear iCloud KV Store
        if isICloudAvailable {
            kvStore.removeObject(forKey: KVKeys.userProfile)
            kvStore.removeObject(forKey: KVKeys.hasCompletedOnboarding)
            kvStore.removeObject(forKey: KVKeys.activeGymProfileId)
            kvStore.removeObject(forKey: KVKeys.apiKey)
            kvStore.synchronize()
        }

        // Delete CloudKit records
        await deleteCloudKitRecord(recordName: "workout_history_v1", recordType: RecordTypes.workoutHistory)
        await deleteCloudKitRecord(recordName: "gym_settings_v1", recordType: RecordTypes.gymSettings)

        // Reset restored count
        restoredWorkoutsCount = 0

        AppLogger.cloud.info("All data cleared from local and iCloud storage")
    }

    /// Delete a specific CloudKit record
    private func deleteCloudKitRecord(recordName: String, recordType: String) async {
        guard isICloudAvailable else { return }

        let recordID = CKRecord.ID(recordName: recordName)

        do {
            try await privateDatabase.deleteRecord(withID: recordID)
            AppLogger.cloud.debug("Deleted CloudKit record: \(recordName)")
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist, nothing to delete
            AppLogger.cloud.debug("CloudKit record \(recordName) doesn't exist, nothing to delete")
        } catch let error as CKError where error.code == .notAuthenticated {
            AppLogger.cloud.warning("Not authenticated to delete CloudKit record")
        } catch {
            AppLogger.cloud.error("Error deleting CloudKit record \(recordName): \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudDataDidSync = Notification.Name("cloudDataDidSync")
}
