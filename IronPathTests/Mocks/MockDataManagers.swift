import Foundation
@testable import IronPath

// MARK: - Mock Workout Data Manager

@MainActor
final class MockWorkoutDataManager: WorkoutDataManaging {
    var savedWorkouts: [Workout] = []
    var workoutHistory: [Workout] = []
    var suggestedWeights: [String: Double] = [:]
    var shouldThrowOnSave = false

    func saveWorkout(_ workout: Workout) {
        savedWorkouts.append(workout)
        workoutHistory.append(workout)
    }

    func getWorkoutHistory() -> [Workout] {
        return workoutHistory
    }

    func getLastWorkoutWith(exerciseName: String, excludeDeload: Bool) -> WorkoutExercise? {
        for workout in workoutHistory.reversed() {
            if excludeDeload && workout.isDeload { continue }
            if let exercise = workout.exercises.first(where: { $0.exercise.name == exerciseName }) {
                return exercise
            }
        }
        return nil
    }

    func getSuggestedWeight(for exerciseName: String, targetReps: Int) -> Double? {
        return suggestedWeights[exerciseName]
    }

    func getSuggestedWeight(for exerciseName: String, targetReps: Int, equipment: Equipment) -> Double? {
        return suggestedWeights[exerciseName]
    }

    func getWorkoutStats() -> WorkoutStats {
        return WorkoutStats(
            totalWorkouts: workoutHistory.count,
            totalVolume: workoutHistory.reduce(0) { $0 + $1.totalVolume },
            workoutsThisWeek: 0,
            averageWorkoutDuration: 3600,
            weightUnit: .pounds
        )
    }

    func clearHistory() {
        workoutHistory.removeAll()
        savedWorkouts.removeAll()
    }

    func exportHistoryAsJSON() -> Data? {
        return try? JSONEncoder().encode(workoutHistory)
    }

    func exportHistoryAsCSV() -> String {
        return "workout,date\n"
    }

    func getWorkout(byId id: UUID) -> Workout? {
        return workoutHistory.first { $0.id == id }
    }

    func deleteWorkout(byId id: UUID) {
        workoutHistory.removeAll { $0.id == id }
    }

    func deleteWorkouts(byIds ids: Set<UUID>) {
        workoutHistory.removeAll { ids.contains($0.id) }
    }

    func updateWorkout(_ workout: Workout) {
        if let index = workoutHistory.firstIndex(where: { $0.id == workout.id }) {
            workoutHistory[index] = workout
        }
    }

    func detectWorkoutPRs(in workout: Workout) -> [WorkoutPR] {
        return []
    }
}

// MARK: - Mock Active Workout Manager

@MainActor
final class MockActiveWorkoutManager: ActiveWorkoutManaging {
    var activeWorkout: Workout?
    var workoutStartTime: Date?

    var hasActiveWorkout: Bool {
        activeWorkout != nil
    }

    var startedWorkouts: [Workout] = []
    var completedWorkouts: [Workout] = []
    var wasCancelled = false

    func startWorkout(_ workout: Workout) {
        activeWorkout = workout
        workoutStartTime = Date()
        startedWorkouts.append(workout)
    }

    func updateWorkout(_ workout: Workout) {
        activeWorkout = workout
    }

    func completeWorkout() -> Workout? {
        guard let workout = activeWorkout else { return nil }
        var completed = workout
        completed.completedAt = Date()
        completedWorkouts.append(completed)
        activeWorkout = nil
        workoutStartTime = nil
        return completed
    }

    func cancelWorkout() {
        wasCancelled = true
        activeWorkout = nil
        workoutStartTime = nil
    }
}

// MARK: - Mock Pending Workout Manager

@MainActor
final class MockPendingWorkoutManager: PendingWorkoutManaging {
    var pendingWorkout: Workout?

    var hasPendingWorkout: Bool {
        pendingWorkout != nil
    }

    func clearPendingWorkout() {
        pendingWorkout = nil
    }
}

// MARK: - Mock Rest Timer Manager

@MainActor
final class MockRestTimerManager: RestTimerManaging {
    var isActive = false
    var totalDuration: TimeInterval = 0
    var exerciseName = ""
    var setNumber = 0
    var showCompletionBanner = false
    var remainingTime: TimeInterval = 0

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remainingTime / totalDuration)
    }

    var formattedTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var startedTimers: [(duration: TimeInterval, exerciseName: String, setNumber: Int)] = []
    var groupTimersStarted: [(duration: TimeInterval, groupType: ExerciseGroupType)] = []
    var wasSkipped = false
    var wasStopped = false

    func startTimer(duration: TimeInterval, exerciseName: String, setNumber: Int) {
        self.totalDuration = duration
        self.remainingTime = duration
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.isActive = true
        startedTimers.append((duration, exerciseName, setNumber))
    }

    func startGroupTimer(duration: TimeInterval, groupType: ExerciseGroupType, exerciseNames: [String], completedRound: Int) {
        self.totalDuration = duration
        self.remainingTime = duration
        self.exerciseName = exerciseNames.joined(separator: " → ")
        self.setNumber = completedRound
        self.isActive = true
        groupTimersStarted.append((duration, groupType))
    }

    func addTime(_ seconds: TimeInterval) {
        remainingTime += seconds
        totalDuration += seconds
    }

    func skipTimer() {
        wasSkipped = true
        stopTimer()
    }

    func stopTimer() {
        wasStopped = true
        isActive = false
        remainingTime = 0
    }

    func clearGroupRestPreference() {
        groupTimersStarted.removeAll()
    }
}

// MARK: - Mock Gym Profile Manager

@MainActor
final class MockGymProfileManager: GymProfileManaging {
    var profiles: [GymProfile] = []
    var activeProfileId: UUID?

    var activeProfile: GymProfile? {
        profiles.first { $0.id == activeProfileId }
    }

    func addProfile(_ profile: GymProfile) {
        profiles.append(profile)
        if activeProfileId == nil {
            activeProfileId = profile.id
        }
    }

    func updateProfile(_ profile: GymProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        }
    }

    func deleteProfile(_ profile: GymProfile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfileId == profile.id {
            activeProfileId = profiles.first?.id
        }
    }

    func switchToProfile(_ profile: GymProfile) {
        activeProfileId = profile.id
    }
}

// MARK: - Mock Exercise Similarity Service

@MainActor
final class MockExerciseSimilarityService: ExerciseSimilarityServicing {
    var suggestionsToReturn: [(Exercise, Double)] = []
    var similarExercises: [ExerciseSimilarity] = []

    func getReplacementSuggestions(
        for exercise: Exercise,
        excludingWorkoutExercises workoutExerciseNames: [String],
        availableEquipment: Set<Equipment>,
        availableMachines: Set<SpecificMachine>,
        limit: Int
    ) -> [(Exercise, Double)] {
        return Array(suggestionsToReturn.prefix(limit))
    }

    func getSimilarExercises(for exercise: Exercise, limit: Int) -> [ExerciseSimilarity] {
        return Array(similarExercises.prefix(limit))
    }
}

// MARK: - Mock AI Provider Manager

@MainActor
final class MockAIProviderManager: AIProviderManaging {
    var mockProvider: AIProvider = MockAIProvider()

    var currentProvider: AIProvider {
        mockProvider
    }

    var isConfigured: Bool = true
}

// MARK: - Mock AI Provider

final class MockAIProvider: AIProvider {
    var id = "mock"
    var displayName = "Mock Provider"
    var iconName = "wand.and.stars"
    var availableModels: [AIModel] = []
    var selectedModel: AIModel = AIModel(
        id: "mock-model",
        displayName: "Mock Model",
        description: "For testing",
        costTier: .low,
        providerId: "mock"
    )
    var isConfigured = true
    var apiKeyURL: URL? = nil
    var setupInstructions = "Mock setup"

    var generatedWorkout: Workout?
    var replacementExercise: WorkoutExercise?
    var formTips = "Keep good form"
    var shouldThrow = false

    func generateWorkout(
        profile: UserProfile,
        targetMuscleGroups: Set<MuscleGroup>?,
        workoutHistory: [Workout],
        workoutType: String?,
        userNotes: String?,
        isDeload: Bool,
        allowDeloadRecommendation: Bool,
        techniqueOptions: WorkoutGenerationOptions
    ) async throws -> Workout {
        if shouldThrow { throw AIProviderError.invalidResponse }
        return generatedWorkout ?? Workout(name: "Mock Workout")
    }

    func replaceExercise(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout
    ) async throws -> WorkoutExercise {
        if shouldThrow { throw AIProviderError.invalidResponse }
        return replacementExercise ?? exercise
    }

    func getFormTips(exercise: Exercise, userLevel: FitnessLevel) async throws -> String {
        if shouldThrow { throw AIProviderError.invalidResponse }
        return formTips
    }

    func generateCustomExercise(description: String, profile: UserProfile) async throws -> Exercise {
        throw AIProviderError.unsupportedOperation
    }

    func generateEquipmentExercises(
        equipmentName: String,
        equipmentType: CustomEquipment.CustomEquipmentType,
        existingExerciseNames: [String]
    ) async throws -> [ExerciseDraft] {
        return []
    }

    func estimateCaloriesBurned(workoutSummary: String) async throws -> Int {
        return 300
    }

    func generateWorkoutAgentic(
        builder: AgentWorkoutBuilder,
        progressCallback: ((AgentProgress) -> Void)?
    ) async throws -> Workout {
        if shouldThrow { throw AIProviderError.invalidResponse }
        return generatedWorkout ?? Workout(name: "Mock Workout")
    }

    func generateWorkoutSummary(
        workout: Workout,
        recentWorkouts: [Workout],
        personalRecords: [WorkoutPR]
    ) async throws -> String {
        return "Great workout!"
    }
}

// MARK: - Mock Exercise Preference Manager

@MainActor
final class MockExercisePreferenceManager: ExercisePreferenceManaging {
    var preferences: [String: ExerciseSuggestionPreference] = [:]

    func getPreference(for exerciseName: String) -> ExerciseSuggestionPreference {
        return preferences[exerciseName] ?? .normal
    }

    func setPreference(_ preference: ExerciseSuggestionPreference, for exerciseName: String) {
        preferences[exerciseName] = preference
    }

    func isExerciseBlocked(_ exerciseName: String) -> Bool {
        return preferences[exerciseName] == .doNotSuggest
    }

    func getAllCustomPreferences() -> [ExercisePreferenceEntry] {
        return preferences.map {
            ExercisePreferenceEntry(exerciseName: $0.key, preference: $0.value)
        }
    }

    func generatePreferencePrompt() -> String? {
        return nil
    }
}

// MARK: - Mock App Settings

@MainActor
final class MockAppSettings: AppSettingsProviding {
    var showYouTubeVideos = true
    var showFormTips = true
    var showAIWorkoutSummary = true
}

// MARK: - Mock Gym Settings

@MainActor
final class MockGymSettings: GymSettingsProviding {
    var preferredWeightUnit: WeightUnit = .pounds
    var cableMachineConfigs: [String: CableMachineConfig] { cableConfigs }
    var cableConfigs: [String: CableMachineConfig] = [:]
    var defaultConfig: CableMachineConfig = .defaultConfig
    var defaultAvailablePlates: [AvailablePlate] = [
        AvailablePlate(weight: 45, count: 0),
        AvailablePlate(weight: 35, count: 0),
        AvailablePlate(weight: 25, count: 0),
        AvailablePlate(weight: 10, count: 0),
        AvailablePlate(weight: 5, count: 0),
        AvailablePlate(weight: 2.5, count: 0),
    ]
    var exercisePlateConfigs: [String: [AvailablePlate]] = [:]

    func cableConfig(for exerciseName: String) -> CableMachineConfig {
        return cableConfigs[exerciseName] ?? defaultConfig
    }

    func setCableConfig(_ config: CableMachineConfig, for exerciseName: String) {
        cableConfigs[exerciseName] = config
    }

    func availablePlates(for exerciseName: String) -> [AvailablePlate] {
        exercisePlateConfigs[exerciseName] ?? defaultAvailablePlates
    }

    func setAvailablePlates(_ plates: [AvailablePlate], for exerciseName: String) {
        exercisePlateConfigs[exerciseName] = plates
    }

    func hasCustomPlateConfig(for exerciseName: String) -> Bool {
        exercisePlateConfigs[exerciseName] != nil
    }

    func resetPlateConfig(for exerciseName: String) {
        exercisePlateConfigs.removeValue(forKey: exerciseName)
    }

    func roundToValidWeight(_ weight: Double, for equipment: Equipment, exerciseName: String?) -> Double {
        switch equipment {
        case .dumbbells:
            return (weight / 5).rounded() * 5
        case .cables:
            return (weight / 2.5).rounded() * 2.5
        default:
            return weight
        }
    }

    func validWeights(for equipment: Equipment, exerciseName: String?) -> [Double] {
        switch equipment {
        case .dumbbells:
            return stride(from: 5, through: 100, by: 5).map { Double($0) }
        case .cables:
            return defaultConfig.availableWeights
        default:
            return []
        }
    }

    func machineWeight(for exerciseName: String, equipment: Equipment) -> Double {
        return 45.0
    }

    func isSingleSided(for exerciseName: String) -> Bool {
        return false
    }
}
