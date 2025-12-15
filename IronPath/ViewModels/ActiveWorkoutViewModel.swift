import Foundation
import SwiftUI

// MARK: - Active Workout ViewModel

/// ViewModel for managing an active workout session
/// Handles workout lifecycle, timing, completion, and superset navigation
@Observable
@MainActor
final class ActiveWorkoutViewModel {

    // MARK: - State

    /// The current workout being performed (synced with editorViewModel)
    var workout: Workout

    /// Start time of the workout session
    var workoutStartTime: Date

    /// Currently selected exercise for detail sheet
    var selectedExercise: WorkoutExercise?

    /// Whether the cancel confirmation dialog is showing
    var showCancelConfirmation: Bool = false

    /// Whether the completion summary sheet is showing
    var showCompletionSummary: Bool = false

    /// The completed workout to display in summary
    var completedWorkoutForSummary: Workout?

    /// Whether we're in the process of finishing (prevents double-tap)
    var isFinishing: Bool = false

    /// Flag to prevent onDisappear from dismissing during superset navigation
    var isNavigatingBetweenExercises: Bool = false

    // MARK: - Task Management

    /// Task handle for navigation delay (for cancellation)
    private var navigationTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Number of completed exercises
    var completedExercisesCount: Int {
        workout.exercises.filter { $0.isCompleted }.count
    }

    /// Whether all exercises are completed
    var allExercisesCompleted: Bool {
        workout.exercises.allSatisfy { $0.isCompleted }
    }

    /// Total number of exercises
    var totalExercisesCount: Int {
        workout.exercises.count
    }

    // MARK: - Dependencies

    private let activeWorkoutManager: ActiveWorkoutManaging
    private let workoutDataManager: WorkoutDataManaging
    private let restTimerManager: RestTimerManaging
    private let userProfile: UserProfile?

    // MARK: - Callbacks

    /// Called when workout is completed
    var onComplete: ((Workout) -> Void)?

    /// Called when workout is cancelled
    var onCancel: (() -> Void)?

    // MARK: - Initialization

    init(
        workout: Workout,
        userProfile: UserProfile?,
        activeWorkoutManager: ActiveWorkoutManaging? = nil,
        workoutDataManager: WorkoutDataManaging? = nil,
        restTimerManager: RestTimerManaging? = nil
    ) {
        self.workout = workout
        self.userProfile = userProfile
        self.activeWorkoutManager = activeWorkoutManager ?? ActiveWorkoutManager.shared
        self.workoutDataManager = workoutDataManager ?? WorkoutDataManager.shared
        self.restTimerManager = restTimerManager ?? RestTimerManager.shared

        // Use persisted start time from manager, falling back to workout's startedAt or current time
        self.workoutStartTime = self.activeWorkoutManager.workoutStartTime ?? workout.startedAt ?? Date()
    }

    // MARK: - Workout State Persistence

    /// Persist current workout state to survive app restarts
    func persistWorkoutState() {
        activeWorkoutManager.updateWorkout(workout)
    }

    // MARK: - Exercise Updates

    /// Update an exercise in the workout
    func updateExercise(_ updatedExercise: WorkoutExercise, dismissSheet: Bool = true) {
        if let index = workout.exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            workout.exercises[index] = updatedExercise
        }
        if dismissSheet {
            selectedExercise = nil
        }
        persistWorkoutState()
    }

    /// Handle exercise update from sheet dismissal (via Done button or swipe-to-dismiss)
    /// This method properly handles the case where a stale onDisappear fires from an old sheet
    /// during superset navigation (due to .id() modifier causing view recreation)
    func handleExerciseUpdateFromSheet(_ updatedExercise: WorkoutExercise) {
        // Skip entirely if we're in the middle of navigating between exercises
        guard !isNavigatingBetweenExercises else { return }

        // Check if this update is from a stale sheet (different exercise than currently selected)
        // This happens when .id() changes and SwiftUI destroys the old view, triggering onDisappear
        let isStaleUpdate = selectedExercise != nil && selectedExercise?.id != updatedExercise.id

        // Always persist the exercise data, but only dismiss if it's not a stale update
        updateExercise(updatedExercise, dismissSheet: !isStaleUpdate)
    }

    /// Update exercise and navigate to next in group (for superset navigation)
    func updateExerciseAndNavigateToNext(_ updatedExercise: WorkoutExercise) {
        // First update the workout with the new exercise state
        if let index = workout.exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            workout.exercises[index] = updatedExercise
        }
        persistWorkoutState()

        // Now use the UPDATED workout to find the next exercise
        // The updatedExercise has the newly completed set
        navigateToNextInSuperset(from: updatedExercise)
    }

    // MARK: - Workout Completion

    /// Finish the workout and save to history
    func finishWorkout() {
        // Prevent double-finishing (e.g., from double-tap)
        guard !isFinishing else { return }
        isFinishing = true

        // Stop any active rest timers and cancel pending notifications
        restTimerManager.skipTimer()
        // Clear user's group rest preference so next workout starts fresh
        restTimerManager.clearGroupRestPreference()

        var completedWorkout = workout
        completedWorkout.completedAt = Date()

        // Set the workout for summary BEFORE saving and showing sheet
        // This ensures the sheet content is ready when it appears
        completedWorkoutForSummary = completedWorkout

        // Save to history
        workoutDataManager.saveWorkout(completedWorkout)

        // Show the summary sheet
        showCompletionSummary = true
    }

    /// Cancel the workout
    func cancelWorkout() {
        // Stop any active rest timers and cancel pending notifications
        restTimerManager.skipTimer()
        // Clear user's group rest preference so next workout starts fresh
        restTimerManager.clearGroupRestPreference()
        onCancel?()
    }

    /// Dismiss completion summary and notify completion
    func dismissCompletionSummary() {
        showCompletionSummary = false
        if let completedWorkout = completedWorkoutForSummary {
            onComplete?(completedWorkout)
        }
    }

    /// Reset finishing state (used when summary sheet is dismissed unexpectedly)
    func resetFinishingState() {
        isFinishing = false
    }

    // MARK: - Superset Navigation

    /// Get grouping information for an exercise
    func getGroupInfo(for exercise: WorkoutExercise) -> ExerciseGroupInfo? {
        guard let group = workout.group(for: exercise.id) else { return nil }

        let position = group.position(of: exercise.id) ?? 0
        let isFirst = group.isFirst(exercise.id)
        let isLast = group.isLast(exercise.id)

        return ExerciseGroupInfo(
            group: group,
            position: position,
            isFirst: isFirst,
            isLast: isLast
        )
    }

    /// Get the next exercise in the group that still has incomplete sets (for superset navigation)
    /// Returns nil if all exercises in the superset are fully complete
    func getNextExerciseInGroup(for exercise: WorkoutExercise) -> WorkoutExercise? {
        return findNextExerciseWithIncompleteSets(for: exercise)?.exercise
    }

    /// Find the next exercise in the group that has incomplete sets
    /// Returns the exercise, its position, and whether navigation wraps around (completing a round)
    private func findNextExerciseWithIncompleteSets(for exercise: WorkoutExercise) -> (exercise: WorkoutExercise, position: Int, wrapsAround: Bool)? {
        guard let group = workout.group(for: exercise.id),
              let currentPosition = group.position(of: exercise.id) else {
            return nil
        }

        let exerciseCount = group.exerciseCount

        // Try each position in order, starting from the next one and wrapping around
        for offset in 1..<exerciseCount {
            let candidatePosition = (currentPosition + offset) % exerciseCount

            guard candidatePosition < group.exerciseIds.count else { continue }
            let candidateExerciseId = group.exerciseIds[candidatePosition]

            // Get the exercise and check if it has incomplete sets
            if let candidateExercise = workout.exercises.first(where: { $0.id == candidateExerciseId }) {
                let hasIncompleteSets = candidateExercise.sets.contains { !$0.isCompleted }
                if hasIncompleteSets {
                    // Check if we wrapped around (candidate position is <= current position)
                    let wrapsAround = candidatePosition <= currentPosition
                    return (candidateExercise, candidatePosition, wrapsAround)
                }
            }
        }

        // All other exercises in the superset are complete
        return nil
    }

    /// Navigate to next exercise in superset, handling rest timer if completing a round
    /// The exercise parameter should have the most recent state (with newly completed set)
    private func navigateToNextInSuperset(from exercise: WorkoutExercise) {
        guard let group = workout.group(for: exercise.id) else {
            return
        }

        // Find the next exercise with incomplete sets using the updated workout
        guard let nextInfo = findNextExerciseWithIncompleteSets(for: exercise) else {
            // All exercises complete - just dismiss
            selectedExercise = nil
            return
        }

        // If wrapping around, we've completed a round - start rest timer
        if nextInfo.wrapsAround {
            // Count completed sets in current exercise to determine round number
            let completedSets = exercise.sets.filter { $0.isCompleted }.count
            let completedRound = completedSets

            restTimerManager.startGroupTimer(
                duration: group.restAfterGroup,
                groupType: group.groupType,
                exerciseNames: [nextInfo.exercise.exercise.name, exercise.exercise.name],
                completedRound: completedRound
            )
        }

        // Navigate to the next exercise
        // Set flag to prevent onDisappear from calling onUpdate (which would dismiss)
        isNavigatingBetweenExercises = true
        let nextExerciseId = nextInfo.exercise.id
        selectedExercise = nil

        // Cancel any existing navigation task
        navigationTask?.cancel()

        navigationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            // Get fresh exercise from workout at navigation time
            self.selectedExercise = self.workout.exercises.first { $0.id == nextExerciseId }
            // Reset flag after navigation is complete
            self.isNavigatingBetweenExercises = false
        }
    }

    // MARK: - Cleanup

    /// Cancel any pending tasks when the ViewModel is no longer needed
    func cleanup() {
        navigationTask?.cancel()
        navigationTask = nil
    }

    // MARK: - Exercise Selection Helpers

    /// Get the current version of an exercise from the workout
    func getCurrentExercise(_ exercise: WorkoutExercise) -> WorkoutExercise {
        workout.exercises.first { $0.id == exercise.id } ?? exercise
    }

    /// Select an exercise for detail view
    func selectExercise(_ exercise: WorkoutExercise) {
        selectedExercise = exercise
    }

    /// Dismiss the selected exercise
    func dismissSelectedExercise() {
        selectedExercise = nil
    }
}
