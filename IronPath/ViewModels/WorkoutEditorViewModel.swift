import Foundation
import SwiftUI

// MARK: - Workout Editor ViewModel

/// Shared ViewModel for editing workouts - used by both ActiveWorkoutView and WorkoutDetailView
/// Consolidates duplicated exercise management logic into a single source of truth
@Observable
@MainActor
final class WorkoutEditorViewModel {

    // MARK: - State

    var workout: Workout

    // Exercise removal state
    var exerciseToRemove: WorkoutExercise?
    var showRemoveConfirmation: Bool = false

    // Add exercise to group state
    var groupToAddExerciseTo: ExerciseGroup?

    // MARK: - Configuration

    /// Whether to prevent removing the last exercise (true for active workouts)
    var preventRemovingLastExercise: Bool = false

    // MARK: - Dependencies

    private var userProfile: UserProfile?

    // MARK: - Callbacks

    /// Called whenever the workout is modified
    var onWorkoutChanged: ((Workout) -> Void)?

    // MARK: - Initialization

    init(
        workout: Workout,
        userProfile: UserProfile? = nil
    ) {
        self.workout = workout
        self.userProfile = userProfile
    }

    // MARK: - Configuration Methods

    func updateUserProfile(_ profile: UserProfile?) {
        self.userProfile = profile
    }

    // MARK: - Exercise Management

    /// Add a new exercise from the library
    func addExerciseFromLibrary(_ exercise: Exercise) {
        let sets = (1...3).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                targetReps: 10,
                restPeriod: 90
            )
        }

        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: sets,
            orderIndex: workout.exercises.count,
            notes: ""
        )

        workout.exercises.append(workoutExercise)
        notifyWorkoutChanged()
    }

    /// Add a workout exercise directly (used when exercise already configured)
    func addExercise(_ exercise: WorkoutExercise) {
        var newExercise = exercise
        newExercise.orderIndex = workout.exercises.count
        workout.exercises.append(newExercise)
        notifyWorkoutChanged()
    }

    /// Add an exercise to an existing group (superset/circuit)
    func addExerciseToGroup(_ exercise: Exercise, group: ExerciseGroup) {
        // Create the workout exercise
        let sets = (1...3).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                targetReps: 10,
                restPeriod: 90
            )
        }

        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: sets,
            orderIndex: workout.exercises.count,
            notes: ""
        )

        // Add to workout
        workout.exercises.append(workoutExercise)

        // Add to the group
        if var groups = workout.exerciseGroups,
           let groupIndex = groups.firstIndex(where: { $0.id == group.id }) {
            groups[groupIndex].exerciseIds.append(workoutExercise.id)
            groups[groupIndex].groupType = ExerciseGroupType.suggestedType(for: groups[groupIndex].exerciseIds.count)
            workout.exerciseGroups = groups
        }

        // Rebuild exercise order to keep grouped exercises together
        workout.rebuildExercisesOrder()

        // Clear the group state
        groupToAddExerciseTo = nil

        notifyWorkoutChanged()
    }

    /// Remove an exercise from the workout
    func removeExercise(_ exercise: WorkoutExercise) {
        // Don't allow removing the last exercise if configured
        if preventRemovingLastExercise && workout.exercises.count <= 1 {
            return
        }

        // Remove exercise from any group it belongs to
        if var groups = workout.exerciseGroups {
            for i in groups.indices {
                if groups[i].exerciseIds.contains(exercise.id) {
                    // Remove the exercise from this group
                    groups[i].exerciseIds.removeAll { $0 == exercise.id }
                }
            }

            // Remove any groups that now have only 1 or 0 exercises
            // (a group with 1 exercise is no longer a valid superset/circuit)
            groups.removeAll { $0.exerciseIds.count <= 1 }

            // Update group types based on new exercise counts
            for i in groups.indices {
                groups[i].groupType = ExerciseGroupType.suggestedType(for: groups[i].exerciseIds.count)
            }

            workout.exerciseGroups = groups.isEmpty ? nil : groups
        }

        workout.exercises.removeAll { $0.id == exercise.id }

        // Reindex remaining exercises
        for i in workout.exercises.indices {
            workout.exercises[i].orderIndex = i
        }

        exerciseToRemove = nil
        notifyWorkoutChanged()
    }

    /// Update an exercise in the workout
    func updateExercise(_ updatedExercise: WorkoutExercise) {
        if let index = workout.exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            workout.exercises[index] = updatedExercise
        }
        notifyWorkoutChanged()
    }

    // MARK: - Remove Exercise Helpers

    /// Initiate exercise removal flow
    func initiateRemoval(for exercise: WorkoutExercise) {
        exerciseToRemove = exercise
        showRemoveConfirmation = true
    }

    /// Cancel exercise removal
    func cancelRemoval() {
        exerciseToRemove = nil
        showRemoveConfirmation = false
    }

    // MARK: - Computed Properties

    /// Exercises that are not part of any group
    var ungroupedExercises: [WorkoutExercise] {
        workout.exercises.filter { exercise in
            !workout.isGrouped(exercise.id)
        }
    }

    /// Names of exercises in the current workout (for filtering in add sheets)
    var existingExerciseNames: [String] {
        workout.exercises.map { $0.exercise.name }
    }

    // MARK: - Private Helpers

    private func notifyWorkoutChanged() {
        onWorkoutChanged?(workout)
    }
}
