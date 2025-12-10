import Foundation
@testable import IronPath

// MARK: - Mock Workout Data Manager

/// Mock implementation of WorkoutDataManaging for testing
class MockWorkoutDataManager: WorkoutDataManaging {

    // MARK: - Test State

    var workouts: [Workout] = []
    var saveWorkoutCalled = false
    var lastSavedWorkout: Workout?
    var clearHistoryCalled = false
    var deleteWorkoutCalled = false
    var lastDeletedWorkoutId: UUID?
    var updateWorkoutCalled = false
    var lastUpdatedWorkout: Workout?

    // MARK: - Protocol Implementation

    func saveWorkout(_ workout: Workout) {
        saveWorkoutCalled = true
        lastSavedWorkout = workout
        // Prevent duplicates (mirroring real behavior)
        if !workouts.contains(where: { $0.id == workout.id }) {
            workouts.append(workout)
        }
    }

    func getWorkoutHistory() -> [Workout] {
        return workouts
    }

    func getLastWorkoutWith(exerciseName: String, excludeDeload: Bool) -> WorkoutExercise? {
        for workout in workouts.reversed() {
            if excludeDeload && workout.isDeload {
                continue
            }
            if let exercise = workout.exercises.first(where: { $0.exercise.name == exerciseName }) {
                return exercise
            }
        }
        return nil
    }

    func getSuggestedWeight(for exerciseName: String, targetReps: Int) -> Double? {
        guard let lastExercise = getLastWorkoutWith(exerciseName: exerciseName, excludeDeload: true) else {
            return nil
        }

        let completedSets = lastExercise.sets.filter { $0.isCompleted }
        guard !completedSets.isEmpty else { return nil }

        let totalWeight = completedSets.compactMap { $0.weight }.reduce(0, +)
        let avgWeight = totalWeight / Double(completedSets.count)

        // 2.5% increase for progressive overload
        return avgWeight * 1.025
    }

    func getSuggestedWeight(for exerciseName: String, targetReps: Int, equipment: Equipment) -> Double? {
        return getSuggestedWeight(for: exerciseName, targetReps: targetReps)
    }

    func getWorkoutStats() -> WorkoutStats {
        let completed = workouts.filter { $0.isCompleted }
        let totalVolume = completed.reduce(0) { $0 + $1.totalVolume }

        return WorkoutStats(
            totalWorkouts: completed.count,
            totalVolume: totalVolume,
            workoutsThisWeek: completed.count, // Simplified for testing
            averageWorkoutDuration: 3600 // Default 1 hour
        )
    }

    func clearHistory() {
        clearHistoryCalled = true
        workouts.removeAll()
    }

    func exportHistoryAsJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(workouts)
    }

    func exportHistoryAsCSV() -> String {
        var csv = "Workout Name,Date,Exercise,Set,Target Reps,Actual Reps,Weight,Completed\n"
        for workout in workouts {
            for exercise in workout.exercises {
                for set in exercise.sets {
                    csv += "\"\(workout.name)\",\(workout.completedAt?.description ?? ""),\"\(exercise.exercise.name)\",\(set.setNumber),\(set.targetReps),\(set.actualReps ?? 0),\(set.weight ?? 0),\(set.isCompleted)\n"
                }
            }
        }
        return csv
    }

    func getWorkout(byId id: UUID) -> Workout? {
        return workouts.first { $0.id == id }
    }

    func deleteWorkout(byId id: UUID) {
        deleteWorkoutCalled = true
        lastDeletedWorkoutId = id
        workouts.removeAll { $0.id == id }
    }

    func deleteWorkouts(byIds ids: Set<UUID>) {
        workouts.removeAll { ids.contains($0.id) }
    }

    func detectWorkoutPRs(in workout: Workout) -> [WorkoutPR] {
        // Simplified PR detection for testing
        var prs: [WorkoutPR] = []

        guard !workout.isDeload else { return [] }

        for exercise in workout.exercises {
            let completedSets = exercise.sets.filter { $0.isCompleted }
            guard let maxWeight = completedSets.compactMap({ $0.weight }).max() else { continue }

            // Check against history
            let historicalMax = workouts
                .filter { $0.id != workout.id && !$0.isDeload }
                .flatMap { $0.exercises }
                .filter { $0.exercise.name == exercise.exercise.name }
                .flatMap { $0.sets }
                .filter { $0.isCompleted }
                .compactMap { $0.weight }
                .max()

            if let prev = historicalMax, maxWeight > prev {
                prs.append(WorkoutPR(
                    exerciseName: exercise.exercise.name,
                    type: .weight,
                    newValue: maxWeight,
                    previousValue: prev
                ))
            } else if historicalMax == nil && maxWeight > 0 {
                prs.append(WorkoutPR(
                    exerciseName: exercise.exercise.name,
                    type: .weight,
                    newValue: maxWeight,
                    previousValue: nil
                ))
            }
        }

        return prs
    }

    // MARK: - Mock-specific methods

    func updateWorkout(_ workout: Workout) {
        updateWorkoutCalled = true
        lastUpdatedWorkout = workout
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
        }
    }

    func reset() {
        workouts = []
        saveWorkoutCalled = false
        lastSavedWorkout = nil
        clearHistoryCalled = false
        deleteWorkoutCalled = false
        lastDeletedWorkoutId = nil
        updateWorkoutCalled = false
        lastUpdatedWorkout = nil
    }
}

// MARK: - Mock Active Workout Manager

/// Mock implementation of ActiveWorkoutManaging for testing
class MockActiveWorkoutManager: ActiveWorkoutManaging {

    // MARK: - Test State

    var startWorkoutCalled = false
    var updateWorkoutCalled = false
    var completeWorkoutCalled = false
    var cancelWorkoutCalled = false

    // MARK: - Protocol Implementation

    var activeWorkout: Workout?
    var workoutStartTime: Date?

    var hasActiveWorkout: Bool {
        activeWorkout != nil
    }

    func startWorkout(_ workout: Workout) {
        startWorkoutCalled = true
        activeWorkout = workout
        workoutStartTime = Date()
    }

    func updateWorkout(_ workout: Workout) {
        updateWorkoutCalled = true
        activeWorkout = workout
    }

    func completeWorkout() -> Workout? {
        completeWorkoutCalled = true
        guard var workout = activeWorkout else { return nil }

        // Mark as completed
        let completedWorkout = Workout(
            id: workout.id,
            name: workout.name,
            exercises: workout.exercises,
            createdAt: workout.createdAt,
            startedAt: workoutStartTime,
            completedAt: Date()
        )

        activeWorkout = nil
        workoutStartTime = nil

        return completedWorkout
    }

    func cancelWorkout() {
        cancelWorkoutCalled = true
        activeWorkout = nil
        workoutStartTime = nil
    }

    // MARK: - Mock-specific methods

    func reset() {
        activeWorkout = nil
        workoutStartTime = nil
        startWorkoutCalled = false
        updateWorkoutCalled = false
        completeWorkoutCalled = false
        cancelWorkoutCalled = false
    }
}

// MARK: - Mock Rest Timer Manager

/// Mock implementation of RestTimerManaging for testing
class MockRestTimerManager: RestTimerManaging {

    // MARK: - Test State

    var startTimerCalled = false
    var addTimeCalled = false
    var lastAddedTime: TimeInterval = 0
    var skipTimerCalled = false
    var stopTimerCalled = false

    // MARK: - Protocol Implementation

    var isActive: Bool = false
    var totalDuration: TimeInterval = 0
    var exerciseName: String = ""
    var setNumber: Int = 0
    var showCompletionBanner: Bool = false

    /// Stored remaining time for predictable testing
    private var _remainingTime: TimeInterval = 0

    var remainingTime: TimeInterval {
        return max(0, _remainingTime)
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remainingTime / totalDuration)
    }

    var formattedTime: String {
        let time = remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func startTimer(duration: TimeInterval, exerciseName: String, setNumber: Int) {
        startTimerCalled = true
        self.totalDuration = duration
        self._remainingTime = duration
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.isActive = true
        self.showCompletionBanner = false
    }

    func addTime(_ seconds: TimeInterval) {
        addTimeCalled = true
        lastAddedTime = seconds
        _remainingTime += seconds
        totalDuration += seconds
    }

    func skipTimer() {
        skipTimerCalled = true
        stopTimer()
    }

    func stopTimer() {
        stopTimerCalled = true
        isActive = false
        _remainingTime = 0
    }

    // MARK: - Mock-specific methods

    /// Simulate timer completion for testing
    func simulateCompletion() {
        isActive = false
        _remainingTime = 0
        showCompletionBanner = true
    }

    /// Set a specific remaining time for testing
    func setRemainingTime(_ time: TimeInterval) {
        _remainingTime = time
    }

    func reset() {
        isActive = false
        totalDuration = 0
        exerciseName = ""
        setNumber = 0
        showCompletionBanner = false
        _remainingTime = 0
        startTimerCalled = false
        addTimeCalled = false
        lastAddedTime = 0
        skipTimerCalled = false
        stopTimerCalled = false
    }
}

// MARK: - Mock Pending Workout Manager

/// Mock implementation of PendingWorkoutManaging for testing
class MockPendingWorkoutManager: PendingWorkoutManaging {

    var pendingWorkout: Workout?

    var hasPendingWorkout: Bool {
        pendingWorkout != nil
    }

    func clearPendingWorkout() {
        pendingWorkout = nil
    }

    func reset() {
        pendingWorkout = nil
    }
}

// MARK: - Mock API Key Manager

/// Mock implementation of APIKeyManaging for testing
class MockAPIKeyManager: APIKeyManaging {

    private var storedKey: String?

    var hasAPIKey: Bool {
        storedKey != nil && !storedKey!.isEmpty
    }

    func saveAPIKey(_ key: String) {
        storedKey = key
    }

    func getAPIKey() -> String? {
        return storedKey
    }

    func clearAPIKey() {
        storedKey = nil
    }

    func reset() {
        storedKey = nil
    }
}

// MARK: - Mock Gym Profile Manager

/// Mock implementation of GymProfileManaging for testing
class MockGymProfileManager: GymProfileManaging {

    var profiles: [GymProfile] = []
    var activeProfileId: UUID?

    var activeProfile: GymProfile? {
        guard let id = activeProfileId else { return profiles.first }
        return profiles.first { $0.id == id }
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

    func reset() {
        profiles = []
        activeProfileId = nil
    }
}
