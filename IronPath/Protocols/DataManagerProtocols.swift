import Foundation

// MARK: - Data Manager Protocols

/// These protocols enable dependency injection and make components testable.
/// Views can depend on protocols instead of concrete singleton implementations.
///
/// Note on actor isolation:
/// - Protocols with `AnyObject` are marked `@MainActor` because their implementations
///   are `@Observable @MainActor` classes that manage UI state.
/// - Value-type focused protocols are marked `Sendable` for safe cross-actor use.

// MARK: - Workout Data Managing

/// Protocol for managing workout history and data persistence
@MainActor
protocol WorkoutDataManaging: AnyObject, Sendable {
    /// Save a completed workout to history
    func saveWorkout(_ workout: Workout)

    /// Get all workout history
    func getWorkoutHistory() -> [Workout]

    /// Get the most recent workout containing a specific exercise
    func getLastWorkoutWith(exerciseName: String, excludeDeload: Bool) -> WorkoutExercise?

    /// Get suggested weight for progressive overload
    func getSuggestedWeight(for exerciseName: String, targetReps: Int) -> Double?

    /// Get suggested weight with equipment type specified
    func getSuggestedWeight(for exerciseName: String, targetReps: Int, equipment: Equipment) -> Double?

    /// Get workout statistics
    func getWorkoutStats() -> WorkoutStats

    /// Clear all workout history
    func clearHistory()

    /// Export history as JSON data
    func exportHistoryAsJSON() -> Data?

    /// Export history as CSV string
    func exportHistoryAsCSV() -> String

    /// Get workout by ID
    func getWorkout(byId id: UUID) -> Workout?

    /// Delete a workout by ID
    func deleteWorkout(byId id: UUID)

    /// Delete multiple workouts by IDs
    func deleteWorkouts(byIds ids: Set<UUID>)

    /// Update an existing workout in history
    func updateWorkout(_ workout: Workout)

    /// Detect personal records in a workout
    func detectWorkoutPRs(in workout: Workout) -> [WorkoutPR]
}

// MARK: - Active Workout Managing

/// Protocol for managing the currently active workout session
@MainActor
protocol ActiveWorkoutManaging: AnyObject, Sendable {
    /// The currently active workout, if any
    var activeWorkout: Workout? { get }

    /// The start time of the current workout
    var workoutStartTime: Date? { get }

    /// Check if there's an active workout
    var hasActiveWorkout: Bool { get }

    /// Start a new workout session
    func startWorkout(_ workout: Workout)

    /// Update the current workout state
    func updateWorkout(_ workout: Workout)

    /// Complete and save the current workout
    func completeWorkout() -> Workout?

    /// Cancel the current workout without saving
    func cancelWorkout()
}

// MARK: - Pending Workout Managing

/// Protocol for managing generated workouts that haven't been started yet
@MainActor
protocol PendingWorkoutManaging: AnyObject, Sendable {
    /// The pending generated workout
    var pendingWorkout: Workout? { get set }

    /// Check if there's a pending workout
    var hasPendingWorkout: Bool { get }

    /// Clear the pending workout
    func clearPendingWorkout()
}

// MARK: - API Key Managing

/// Protocol for managing API key storage
protocol APIKeyManaging: Sendable {
    /// Check if an API key is stored
    var hasAPIKey: Bool { get }

    /// Save the API key
    func saveAPIKey(_ key: String)

    /// Retrieve the stored API key
    func getAPIKey() -> String?

    /// Clear the stored API key
    func clearAPIKey()
}

// MARK: - Gym Profile Managing

/// Protocol for managing gym profiles
@MainActor
protocol GymProfileManaging: AnyObject, Sendable {
    /// All stored gym profiles
    var profiles: [GymProfile] { get }

    /// The ID of the currently active profile
    var activeProfileId: UUID? { get }

    /// The currently active gym profile
    var activeProfile: GymProfile? { get }

    /// Add a new gym profile
    func addProfile(_ profile: GymProfile)

    /// Update an existing gym profile
    func updateProfile(_ profile: GymProfile)

    /// Delete a gym profile
    func deleteProfile(_ profile: GymProfile)

    /// Switch to a different gym profile
    func switchToProfile(_ profile: GymProfile)
}

// MARK: - Rest Timer Managing

/// Protocol for managing the rest timer
@MainActor
protocol RestTimerManaging: AnyObject, Sendable {
    /// Whether the timer is currently active
    var isActive: Bool { get }

    /// Total duration of the timer
    var totalDuration: TimeInterval { get }

    /// The exercise name associated with this timer
    var exerciseName: String { get }

    /// The set number for this rest period
    var setNumber: Int { get }

    /// Whether to show the completion banner
    var showCompletionBanner: Bool { get }

    /// Remaining time on the timer
    var remainingTime: TimeInterval { get }

    /// Progress as a value from 0 to 1
    var progress: Double { get }

    /// Formatted time string (e.g., "1:30")
    var formattedTime: String { get }

    /// Start a new timer
    func startTimer(duration: TimeInterval, exerciseName: String, setNumber: Int)

    /// Start a rest timer after completing all exercises in a superset/circuit round
    func startGroupTimer(
        duration: TimeInterval,
        groupType: ExerciseGroupType,
        exerciseNames: [String],
        completedRound: Int
    )

    /// Add time to the current timer
    func addTime(_ seconds: TimeInterval)

    /// Skip the current timer
    func skipTimer()

    /// Stop the timer
    func stopTimer()
}

// MARK: - Exercise Timer Managing

/// Protocol for managing timed exercise countdown and timer
@MainActor
protocol ExerciseTimerManaging: AnyObject, Sendable {
    /// Whether a timer is currently active
    var isActive: Bool { get }

    /// Whether we're in countdown phase (3-2-1)
    var isCountdown: Bool { get }

    /// Countdown value (3, 2, 1)
    var countdownRemaining: Int { get }

    /// Exercise being timed
    var exerciseName: String { get }

    /// Set number being timed
    var setNumber: Int { get }

    /// Elapsed time since timer started
    var elapsedTime: TimeInterval { get }

    /// Formatted elapsed time (MM:SS)
    var formattedElapsedTime: String { get }

    /// Remaining time until target
    var remainingTime: TimeInterval { get }

    /// Progress (0.0 to 1.0+)
    var progress: Double { get }

    /// Start a 3-2-1 countdown
    func startCountdown(exerciseName: String, setNumber: Int, onComplete: @escaping () -> Void)

    /// Skip countdown and start timer immediately
    func skipCountdown()

    /// Start the main exercise timer
    func startExerciseTimer(targetDuration: TimeInterval, onComplete: ((TimeInterval) -> Void)?)

    /// Stop the timer and return final duration
    func stopTimer() -> TimeInterval?

    /// Pause the timer
    func pauseTimer()

    /// Resume the timer
    func resumeTimer()

    /// Cancel the timer without returning duration
    func cancelTimer()
}

// MARK: - AI Provider Managing

/// Protocol for managing AI provider access
@MainActor
protocol AIProviderManaging: AnyObject, Sendable {
    /// Get the currently selected provider
    var currentProvider: AIProvider { get }

    /// Check if the current provider is configured
    var isConfigured: Bool { get }
}

// MARK: - Exercise Similarity Servicing

/// Protocol for exercise similarity calculations
@MainActor
protocol ExerciseSimilarityServicing: AnyObject, Sendable {
    /// Get replacement suggestions for an exercise
    func getReplacementSuggestions(
        for exercise: Exercise,
        excludingWorkoutExercises workoutExerciseNames: [String],
        availableEquipment: Set<Equipment>,
        availableMachines: Set<SpecificMachine>,
        limit: Int
    ) -> [(Exercise, Double)]

    /// Get similar exercises for a given exercise
    func getSimilarExercises(for exercise: Exercise, limit: Int) -> [ExerciseSimilarity]
}

// MARK: - App Settings Providing

/// Protocol for accessing app-wide settings
@MainActor
protocol AppSettingsProviding: AnyObject, Sendable {
    /// Whether to show YouTube video demonstrations
    var showYouTubeVideos: Bool { get }

    /// Whether to show form tips in exercise details
    var showFormTips: Bool { get }

    /// Whether to show AI-generated workout summary
    var showAIWorkoutSummary: Bool { get }
}

// MARK: - Exercise Preference Managing

/// Protocol for managing user exercise preferences
@MainActor
protocol ExercisePreferenceManaging: AnyObject, Sendable {
    /// Get the preference for a specific exercise
    func getPreference(for exerciseName: String) -> ExerciseSuggestionPreference

    /// Set the preference for a specific exercise
    func setPreference(_ preference: ExerciseSuggestionPreference, for exerciseName: String)

    /// Check if an exercise should be excluded from suggestions
    func isExerciseBlocked(_ exerciseName: String) -> Bool

    /// Get all exercises with non-normal preferences
    func getAllCustomPreferences() -> [ExercisePreferenceEntry]

    /// Generate prompt text for AI to respect exercise preferences
    func generatePreferencePrompt() -> String?
}

// MARK: - Gym Settings Providing

/// Protocol for accessing gym settings
@MainActor
protocol GymSettingsProviding: AnyObject, Sendable {
    /// Get cable config for specific exercise
    func cableConfig(for exerciseName: String) -> CableMachineConfig

    /// Round weight to nearest valid for equipment
    func roundToValidWeight(_ weight: Double, for equipment: Equipment, exerciseName: String?) -> Double

    /// Get valid weights for equipment type
    func validWeights(for equipment: Equipment, exerciseName: String?) -> [Double]

    /// Get machine weight for exercise
    func machineWeight(for exerciseName: String, equipment: Equipment) -> Double

    /// Check if exercise is single-sided
    func isSingleSided(for exerciseName: String) -> Bool
}

// MARK: - Custom Equipment Storing

/// Protocol for managing custom equipment created by users
@MainActor
protocol CustomEquipmentStoring: AnyObject, Sendable {
    /// All custom equipment
    var customEquipment: [CustomEquipment] { get }

    /// Add new custom equipment
    func addEquipment(_ equipment: CustomEquipment) throws

    /// Update existing custom equipment
    func updateEquipment(_ equipment: CustomEquipment) throws

    /// Delete custom equipment by ID
    func deleteEquipment(id: UUID)

    /// Get custom equipment by ID
    func getEquipment(id: UUID) -> CustomEquipment?

    /// Get all equipment of a specific type
    func getEquipment(ofType type: CustomEquipment.CustomEquipmentType) -> [CustomEquipment]

    /// Check if equipment with the given name already exists
    func exists(name: String) -> Bool
}

// MARK: - Custom Exercise Storing

/// Protocol for managing custom exercises created by users
@MainActor
protocol CustomExerciseStoring: AnyObject, Sendable {
    /// All custom exercises
    var exercises: [Exercise] { get }

    /// Check if an exercise with the given name already exists
    func exerciseExists(name: String) -> Bool

    /// Add a single exercise with duplicate checking
    func addExercise(_ exercise: Exercise) throws

    /// Delete an exercise by ID
    func deleteExercise(id: UUID)

    /// Update an existing exercise
    func updateExercise(_ exercise: Exercise)
}

// MARK: - Exercise Database Providing

/// Protocol for accessing the exercise database
@MainActor
protocol ExerciseDatabaseProviding: AnyObject, Sendable {
    /// All available exercises (built-in)
    var exercises: [Exercise] { get }
}

// MARK: - Equipment Managing

/// Protocol for managing equipment options (standard and custom)
/// Provides the single source of truth for equipment selection across the app
@MainActor
protocol EquipmentManaging: AnyObject, Sendable {
    /// All equipment options including custom equipment (for gym profile editor)
    var allEquipmentOptions: [EquipmentManager.EquipmentOption] { get }

    /// Standard equipment only (for onboarding wizard)
    var standardEquipmentOptions: [EquipmentManager.EquipmentOption] { get }

    /// All machine options including custom machines (for gym profile editor)
    var allMachineOptions: [EquipmentManager.MachineOption] { get }

    /// Standard machines only (for onboarding wizard)
    var standardMachineOptions: [EquipmentManager.MachineOption] { get }

    /// Check if equipment with the given name exists (standard or custom)
    func equipmentExists(name: String) -> Bool

    /// Refresh all equipment options (call after adding custom equipment)
    func refreshAllOptions()

    /// Get icon for standard equipment type
    func iconForEquipment(_ equipment: Equipment) -> String
}

// MARK: - Default Conformances

extension WorkoutDataManager: WorkoutDataManaging {}
extension ActiveWorkoutManager: ActiveWorkoutManaging {}
extension PendingWorkoutManager: PendingWorkoutManaging {}
extension APIKeyManager: APIKeyManaging {}
extension GymProfileManager: GymProfileManaging {}
extension RestTimerManager: RestTimerManaging {}
extension ExerciseTimerManager: ExerciseTimerManaging {}
extension AIProviderManager: AIProviderManaging {}
extension ExerciseSimilarityService: ExerciseSimilarityServicing {}
extension AppSettings: AppSettingsProviding {}
extension ExercisePreferenceManager: ExercisePreferenceManaging {}
extension GymSettings: GymSettingsProviding {}
extension EquipmentManager: EquipmentManaging {}
extension CustomEquipmentStore: CustomEquipmentStoring {}
extension CustomExerciseStore: CustomExerciseStoring {}
extension ExerciseDatabase: ExerciseDatabaseProviding {}
