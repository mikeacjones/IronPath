import Foundation
import CloudKit
import Combine

/// Manages iCloud sync for app data persistence across installs
/// Uses NSUbiquitousKeyValueStore for small data and CloudKit for larger data
class CloudSyncManager {
    static let shared = CloudSyncManager()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let container = CKContainer(identifier: "iCloud.com.kotrs.IronPath")
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }

    /// Check if iCloud is available (user is signed in)
    private var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // Keys for iCloud KV storage (small data)
    private enum KVKeys {
        static let userProfile = "cloud_user_profile"
        static let apiKey = "cloud_api_key"
        static let hasCompletedOnboarding = "cloud_has_completed_onboarding"
    }

    // CloudKit record types (large data)
    private enum RecordTypes {
        static let workoutHistory = "WorkoutHistory"
        static let gymSettings = "GymSettings"
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        // Only set up iCloud sync if signed in
        if isICloudAvailable {
            // Register for iCloud KV change notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(cloudDataDidChange),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: kvStore
            )

            // Sync on launch
            kvStore.synchronize()

            // Fetch CloudKit data on launch
            Task {
                await fetchCloudKitData()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - KV Store Sync Trigger

    @objc private func cloudDataDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        switch reason {
        case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange:
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cloudDataDidSync, object: nil)
            }
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            print("iCloud KV storage quota exceeded")
        case NSUbiquitousKeyValueStoreAccountChange:
            print("iCloud account changed")
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

        do {
            let record = try await privateDatabase.record(for: recordID)
            if let data = record["data"] as? Data,
               let cloudUpdatedAt = record["updatedAt"] as? Date {

                // Check if local data exists
                let localData = UserDefaults.standard.data(forKey: "workout_history")
                let localUpdatedAt = UserDefaults.standard.object(forKey: "workout_history_updated") as? Date ?? Date.distantPast

                // If local is empty (fresh install) or cloud is newer, use cloud data
                let localIsEmpty = localData == nil || (try? decoder.decode([Workout].self, from: localData!))?.isEmpty ?? true

                if localIsEmpty || cloudUpdatedAt > localUpdatedAt {
                    // Cloud is newer or local is empty, update local
                    UserDefaults.standard.set(data, forKey: "workout_history")
                    UserDefaults.standard.set(cloudUpdatedAt, forKey: "workout_history_updated")

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .cloudDataDidSync, object: nil)
                    }
                    print("CloudSync: Restored \((try? self.decoder.decode([Workout].self, from: data))?.count ?? 0) workouts from iCloud")
                } else if localData != nil && localUpdatedAt > cloudUpdatedAt {
                    // Local is newer and not empty, push to cloud
                    await saveWorkoutHistoryToCloud(localData!)
                }
            }
        } catch let error as CKError where error.code == .unknownItem {
            // No cloud record exists yet, push local data if available
            if let localData = UserDefaults.standard.data(forKey: "workout_history") {
                await saveWorkoutHistoryToCloud(localData)
                print("CloudSync: Pushed local workout history to iCloud (no cloud record existed)")
            }
        } catch let error as CKError where error.code == .notAuthenticated {
            // User not signed into iCloud - silently use local storage only
            print("CloudSync: User not signed into iCloud")
            return
        } catch {
            // Log error for debugging
            print("CloudSync: Error fetching workout history - \(error.localizedDescription)")
        }
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

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .cloudDataDidSync, object: nil)
                    }
                    print("CloudSync: Restored gym settings from iCloud")
                } else if localData != nil && localUpdatedAt > cloudUpdatedAt {
                    await saveGymSettingsToCloud(localData!)
                }
            }
        } catch let error as CKError where error.code == .unknownItem {
            if let localData = UserDefaults.standard.data(forKey: "gymProfiles") {
                await saveGymSettingsToCloud(localData)
                print("CloudSync: Pushed gym settings to iCloud (no cloud record existed)")
            }
        } catch let error as CKError where error.code == .notAuthenticated {
            print("CloudSync: User not signed into iCloud")
            return
        } catch {
            print("CloudSync: Error fetching gym settings - \(error.localizedDescription)")
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
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudDataDidSync = Notification.Name("cloudDataDidSync")
}
