import Foundation

// MARK: - Exercise Preference Manager

/// Manages user preferences for exercise suggestions
/// Persists to iCloud via CloudSyncManager
@Observable
@MainActor
final class ExercisePreferenceManager {
    static let shared = ExercisePreferenceManager()

    private(set) var preferences: [String: ExercisePreferenceEntry] = [:]

    private let storageKey = "exercise_preferences"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        loadPreferences()

        // Listen for iCloud sync changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudSync),
            name: .cloudDataDidSync,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc nonisolated private func handleCloudSync() {
        Task { @MainActor in
            loadPreferences()
        }
    }

    // MARK: - Public API

    /// Get the preference for a specific exercise
    func getPreference(for exerciseName: String) -> ExerciseSuggestionPreference {
        preferences[exerciseName.lowercased()]?.preference ?? .normal
    }

    /// Set the preference for a specific exercise
    func setPreference(_ preference: ExerciseSuggestionPreference, for exerciseName: String) {
        let key = exerciseName.lowercased()

        if preference == .normal {
            // Remove the entry if setting back to normal (no need to store defaults)
            preferences.removeValue(forKey: key)
        } else {
            preferences[key] = ExercisePreferenceEntry(
                exerciseName: exerciseName,
                preference: preference,
                updatedAt: Date()
            )
        }

        savePreferences()
    }

    /// Get all exercises with non-normal preferences
    func getAllCustomPreferences() -> [ExercisePreferenceEntry] {
        Array(preferences.values).sorted { $0.exerciseName < $1.exerciseName }
    }

    /// Get exercises that should be preferred
    func getPreferredExercises() -> [String] {
        preferences.values
            .filter { $0.preference == .preferMore }
            .map { $0.exerciseName }
    }

    /// Get exercises that should be avoided
    func getAvoidedExercises() -> [String] {
        preferences.values
            .filter { $0.preference == .preferLess }
            .map { $0.exerciseName }
    }

    /// Get exercises that should never be suggested
    func getBlockedExercises() -> [String] {
        preferences.values
            .filter { $0.preference == .doNotSuggest }
            .map { $0.exerciseName }
    }

    /// Check if an exercise should be excluded from suggestions
    func isExerciseBlocked(_ exerciseName: String) -> Bool {
        getPreference(for: exerciseName) == .doNotSuggest
    }

    /// Clear all preferences
    func clearAllPreferences() {
        preferences.removeAll()
        savePreferences()
    }

    /// Remove preference for a specific exercise (reset to normal)
    func resetPreference(for exerciseName: String) {
        setPreference(.normal, for: exerciseName)
    }

    // MARK: - Prompt Generation

    /// Generate prompt text for AI to respect exercise preferences
    func generatePreferencePrompt() -> String? {
        let preferred = getPreferredExercises()
        let avoided = getAvoidedExercises()
        let blocked = getBlockedExercises()

        // Only generate if there are custom preferences
        guard !preferred.isEmpty || !avoided.isEmpty || !blocked.isEmpty else {
            return nil
        }

        var prompt = "\nUSER EXERCISE PREFERENCES:\n"

        if !blocked.isEmpty {
            prompt += "⛔ DO NOT USE these exercises (user has blocked them):\n"
            prompt += blocked.map { "- \($0)" }.joined(separator: "\n")
            prompt += "\n\n"
        }

        if !preferred.isEmpty {
            prompt += "⭐ PREFER these exercises when possible (user likes them):\n"
            prompt += preferred.map { "- \($0)" }.joined(separator: "\n")
            prompt += "\n\n"
        }

        if !avoided.isEmpty {
            prompt += "⚠️ AVOID these exercises unless necessary (user prefers alternatives):\n"
            prompt += avoided.map { "- \($0)" }.joined(separator: "\n")
            prompt += "\n"
        }

        return prompt
    }

    // MARK: - Persistence

    private func loadPreferences() {
        // Try loading from iCloud first, fall back to local
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: storageKey) ??
                      UserDefaults.standard.data(forKey: storageKey),
           let entries = try? decoder.decode([ExercisePreferenceEntry].self, from: data) {
            preferences = Dictionary(
                uniqueKeysWithValues: entries.map { ($0.exerciseName.lowercased(), $0) }
            )
        }
    }

    private func savePreferences() {
        let entries = Array(preferences.values)

        guard let data = try? encoder.encode(entries) else { return }

        // Save to both local and iCloud
        UserDefaults.standard.set(data, forKey: storageKey)
        NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

// MARK: - Exercise Filtering Extension

extension ExercisePreferenceManager {
    /// Filter a list of exercises based on preferences
    /// Returns exercises with blocked ones removed
    func filterExercises(_ exercises: [Exercise]) -> [Exercise] {
        let blocked = Set(getBlockedExercises().map { $0.lowercased() })
        return exercises.filter { !blocked.contains($0.name.lowercased()) }
    }

    /// Sort exercises by preference (preferred first, avoided last)
    func sortByPreference(_ exercises: [Exercise]) -> [Exercise] {
        exercises.sorted { ex1, ex2 in
            let pref1 = getPreference(for: ex1.name)
            let pref2 = getPreference(for: ex2.name)

            // Order: preferMore > normal > preferLess > doNotSuggest
            let order: [ExerciseSuggestionPreference] = [.preferMore, .normal, .preferLess, .doNotSuggest]
            let idx1 = order.firstIndex(of: pref1) ?? 1
            let idx2 = order.firstIndex(of: pref2) ?? 1

            return idx1 < idx2
        }
    }
}
