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
        kvStore.set(data, forKey: KVKeys.userProfile)
        kvStore.synchronize()
        UserDefaults.standard.set(data, forKey: "user_profile")
    }

    func loadUserProfile() -> UserProfile? {
        // Try iCloud first
        if let data = kvStore.data(forKey: KVKeys.userProfile),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            UserDefaults.standard.set(data, forKey: "user_profile")
            return profile
        }

        // Fallback to local
        if let data = UserDefaults.standard.data(forKey: "user_profile"),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            kvStore.set(data, forKey: KVKeys.userProfile)
            kvStore.synchronize()
            return profile
        }

        return nil
    }

    // MARK: - Onboarding Status (KV Store)

    func saveOnboardingCompleted(_ completed: Bool) {
        kvStore.set(completed, forKey: KVKeys.hasCompletedOnboarding)
        kvStore.synchronize()
        UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")
    }

    func loadOnboardingCompleted() -> Bool {
        if kvStore.object(forKey: KVKeys.hasCompletedOnboarding) != nil {
            let cloudValue = kvStore.bool(forKey: KVKeys.hasCompletedOnboarding)
            UserDefaults.standard.set(cloudValue, forKey: "hasCompletedOnboarding")
            return cloudValue
        }

        let localValue = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if localValue {
            kvStore.set(localValue, forKey: KVKeys.hasCompletedOnboarding)
            kvStore.synchronize()
        }
        return localValue
    }

    // MARK: - Workout History (CloudKit - large data)

    func saveWorkoutHistory(_ workouts: [Workout]) {
        guard let data = try? encoder.encode(workouts) else { return }

        // Always save locally first
        UserDefaults.standard.set(data, forKey: "workout_history")

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
                print("CloudKit update error: \(error)")
            }
        } catch {
            print("CloudKit save error: \(error)")
        }
    }

    private func fetchWorkoutHistoryFromCloud() async {
        let recordID = CKRecord.ID(recordName: "workout_history_v1")

        do {
            let record = try await privateDatabase.record(for: recordID)
            if let data = record["data"] as? Data,
               let cloudUpdatedAt = record["updatedAt"] as? Date {

                // Check if cloud data is newer than local
                let localUpdatedAt = UserDefaults.standard.object(forKey: "workout_history_updated") as? Date ?? Date.distantPast

                if cloudUpdatedAt > localUpdatedAt {
                    // Cloud is newer, update local
                    UserDefaults.standard.set(data, forKey: "workout_history")
                    UserDefaults.standard.set(cloudUpdatedAt, forKey: "workout_history_updated")

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .cloudDataDidSync, object: nil)
                    }
                } else if let localData = UserDefaults.standard.data(forKey: "workout_history"),
                          localUpdatedAt > cloudUpdatedAt {
                    // Local is newer, push to cloud
                    await saveWorkoutHistoryToCloud(localData)
                }
            }
        } catch let error as CKError where error.code == .unknownItem {
            // No cloud record exists yet, push local data if available
            if let localData = UserDefaults.standard.data(forKey: "workout_history") {
                await saveWorkoutHistoryToCloud(localData)
            }
        } catch {
            print("CloudKit fetch error: \(error)")
        }
    }

    // MARK: - Gym Profiles (CloudKit - potentially large)

    func saveGymProfiles(_ data: Data) {
        UserDefaults.standard.set(data, forKey: "gymProfiles")

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
                print("CloudKit gym settings update error: \(error)")
            }
        } catch {
            print("CloudKit gym settings save error: \(error)")
        }
    }

    private func fetchGymSettingsFromCloud() async {
        let recordID = CKRecord.ID(recordName: "gym_settings_v1")

        do {
            let record = try await privateDatabase.record(for: recordID)
            if let data = record["data"] as? Data,
               let cloudUpdatedAt = record["updatedAt"] as? Date {

                let localUpdatedAt = UserDefaults.standard.object(forKey: "gym_settings_updated") as? Date ?? Date.distantPast

                if cloudUpdatedAt > localUpdatedAt {
                    UserDefaults.standard.set(data, forKey: "gym_settings")
                    UserDefaults.standard.set(cloudUpdatedAt, forKey: "gym_settings_updated")

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .cloudDataDidSync, object: nil)
                    }
                } else if let localData = UserDefaults.standard.data(forKey: "gym_settings"),
                          localUpdatedAt > cloudUpdatedAt {
                    await saveGymSettingsToCloud(localData)
                }
            }
        } catch let error as CKError where error.code == .unknownItem {
            if let localData = UserDefaults.standard.data(forKey: "gym_settings") {
                await saveGymSettingsToCloud(localData)
            }
        } catch {
            print("CloudKit gym settings fetch error: \(error)")
        }
    }

    // MARK: - API Key (KV Store with obfuscation)

    func saveAPIKey(_ key: String) {
        let obfuscated = Data(key.utf8).base64EncodedString()
        kvStore.set(obfuscated, forKey: KVKeys.apiKey)
        kvStore.synchronize()
        UserDefaults.standard.set(key, forKey: "anthropic_api_key")
    }

    func loadAPIKey() -> String? {
        if let obfuscated = kvStore.string(forKey: KVKeys.apiKey),
           let data = Data(base64Encoded: obfuscated),
           let key = String(data: data, encoding: .utf8), !key.isEmpty {
            UserDefaults.standard.set(key, forKey: "anthropic_api_key")
            return key
        }

        if let key = UserDefaults.standard.string(forKey: "anthropic_api_key"), !key.isEmpty {
            let obfuscated = Data(key.utf8).base64EncodedString()
            kvStore.set(obfuscated, forKey: KVKeys.apiKey)
            kvStore.synchronize()
            return key
        }

        return nil
    }

    // MARK: - Force Sync

    func forceSync() {
        kvStore.synchronize()
        Task {
            await fetchCloudKitData()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudDataDidSync = Notification.Name("cloudDataDidSync")
}
