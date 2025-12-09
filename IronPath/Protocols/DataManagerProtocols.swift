import Foundation

// MARK: - Data Manager Protocols

/// These protocols enable dependency injection and make components testable.
/// Views can depend on protocols instead of concrete singleton implementations.

// MARK: - Workout Data Managing

/// Protocol for managing workout history and data persistence
protocol WorkoutDataManaging {
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

    /// Detect personal records in a workout
    func detectWorkoutPRs(in workout: Workout) -> [WorkoutPR]
}

// MARK: - Active Workout Managing

/// Protocol for managing the currently active workout session
protocol ActiveWorkoutManaging: AnyObject {
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
protocol PendingWorkoutManaging: AnyObject {
    /// The pending generated workout
    var pendingWorkout: Workout? { get set }

    /// Check if there's a pending workout
    var hasPendingWorkout: Bool { get }

    /// Clear the pending workout
    func clearPendingWorkout()
}

// MARK: - API Key Managing

/// Protocol for managing API key storage
protocol APIKeyManaging {
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
protocol GymProfileManaging: AnyObject {
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
protocol RestTimerManaging: AnyObject {
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

    /// Add time to the current timer
    func addTime(_ seconds: TimeInterval)

    /// Skip the current timer
    func skipTimer()

    /// Stop the timer
    func stopTimer()
}

// MARK: - Default Conformances

extension WorkoutDataManager: WorkoutDataManaging {}
extension ActiveWorkoutManager: ActiveWorkoutManaging {}
extension PendingWorkoutManager: PendingWorkoutManaging {}
extension APIKeyManager: APIKeyManaging {}
extension GymProfileManager: GymProfileManaging {}
extension RestTimerManager: RestTimerManaging {}
