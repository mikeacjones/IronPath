import Foundation
import SwiftUI

// MARK: - Exercise Detail ViewModel

/// ViewModel for managing exercise detail sheet state and business logic
/// Handles exercise history, set manipulation, and settings access
@Observable
@MainActor
final class ExerciseDetailViewModel {

    // MARK: - State

    /// The exercise being edited (mutable copy)
    var exercise: WorkoutExercise

    /// Notes for the exercise
    var notes: String

    /// Whether to show add set type picker
    var showAddSetTypePicker: Bool = false

    /// Whether to show exercise history section expanded
    var showHistory: Bool = false

    // MARK: - Configuration

    /// When true, rest timers and live workout features are enabled
    let isLiveWorkout: Bool

    /// When true, this is editing a pending (not started) workout
    let isPendingWorkout: Bool

    /// Override for showing YouTube videos (nil = use app settings)
    let showVideosOverride: Bool?

    /// Override for showing form tips (nil = use app settings)
    let showFormTipsOverride: Bool?

    /// Group information if exercise is part of a superset/circuit
    let groupInfo: ExerciseGroupInfo?

    /// Next exercise in the group (for navigation)
    let nextExerciseInGroup: WorkoutExercise?

    // MARK: - Dependencies

    private let workoutDataManager: WorkoutDataManaging
    private let appSettings: AppSettingsProviding

    // MARK: - Callbacks

    /// Called when exercise is updated (with dismissal)
    var onUpdate: ((WorkoutExercise) -> Void)?

    /// Called when exercise is updated without dismissing (for superset navigation)
    var onUpdateWithoutDismiss: ((WorkoutExercise) -> Void)?

    /// Called to navigate to next exercise in group
    var onNavigateToNextInGroup: (() -> Void)?

    // MARK: - Computed Properties

    /// Whether this exercise is part of a superset/circuit
    var isInSuperset: Bool {
        groupInfo != nil
    }

    /// Whether to show YouTube videos
    var shouldShowVideos: Bool {
        showVideosOverride ?? appSettings.showYouTubeVideos
    }

    /// Whether to show form tips
    var shouldShowFormTips: Bool {
        showFormTipsOverride ?? appSettings.showFormTips
    }

    /// Historical sessions for this exercise (most recent first, up to 5)
    var exerciseHistory: [(date: Date, sets: [ExerciseSet])] {
        let history = workoutDataManager.getWorkoutHistory()
        var sessions: [(date: Date, sets: [ExerciseSet])] = []

        for workout in history.reversed() {
            // Skip deload workouts for clearer progression view
            if workout.isDeload { continue }

            if let matchingExercise = workout.exercises.first(where: { $0.exercise.name == exercise.exercise.name }) {
                let completedSets = matchingExercise.sets.filter { $0.isCompleted }
                if !completedSets.isEmpty, let date = workout.completedAt {
                    sessions.append((date: date, sets: completedSets))
                }
            }

            if sessions.count >= 5 { break }
        }

        return sessions
    }

    /// Navigation title based on context
    var navigationTitle: String {
        if isLiveWorkout && isInSuperset {
            return groupInfo?.group.groupType.displayName ?? "Log Sets"
        }
        return isLiveWorkout ? "Log Sets" : "Edit Exercise"
    }

    // MARK: - Initialization

    init(
        exercise: WorkoutExercise,
        isLiveWorkout: Bool = true,
        isPendingWorkout: Bool = false,
        showVideosOverride: Bool? = nil,
        showFormTipsOverride: Bool? = nil,
        groupInfo: ExerciseGroupInfo? = nil,
        nextExerciseInGroup: WorkoutExercise? = nil,
        workoutDataManager: WorkoutDataManaging? = nil,
        appSettings: AppSettingsProviding? = nil
    ) {
        self.exercise = exercise
        self.notes = exercise.notes
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
        self.showVideosOverride = showVideosOverride
        self.showFormTipsOverride = showFormTipsOverride
        self.groupInfo = groupInfo
        self.nextExerciseInGroup = nextExerciseInGroup
        self.workoutDataManager = workoutDataManager ?? WorkoutDataManager.shared
        self.appSettings = appSettings ?? AppSettings.shared
    }

    // MARK: - Set Manipulation

    /// Add a new set of the specified type
    func addSet(type: SetType) {
        let lastSet = exercise.sets.last
        // Find first working set for warmup weight reference
        let firstWorkingSet = exercise.sets.first { $0.setType != .warmup }

        // Use actual reps if user changed them, otherwise fall back to target reps
        let repsFromLastSet = lastSet?.actualReps ?? lastSet?.targetReps ?? 10

        let newSet: ExerciseSet
        switch type {
        case .standard:
            newSet = ExerciseSet(
                setNumber: 0, // Will be renumbered
                setType: .standard,
                targetReps: repsFromLastSet,
                weight: lastSet?.weight,
                restPeriod: lastSet?.restPeriod ?? 90
            )
            exercise.sets.append(newSet)
        case .warmup:
            // Use working set weight for warmup calculation, or last set as fallback
            let referenceWeight = firstWorkingSet?.weight ?? lastSet?.weight ?? 100
            newSet = ExerciseSet.createWarmupSet(
                setNumber: 0, // Will be renumbered
                targetReps: 10,
                weight: referenceWeight * 0.5, // 50% of working weight
                restPeriod: 60
            )
            // Insert warmup at the beginning (before all other sets)
            exercise.sets.insert(newSet, at: 0)
        case .dropSet:
            newSet = ExerciseSet.createDropSet(
                setNumber: 0, // Will be renumbered
                targetReps: repsFromLastSet > 0 ? repsFromLastSet : 8,
                weight: lastSet?.weight,
                restPeriod: lastSet?.restPeriod ?? 90,
                numberOfDrops: 2,
                dropPercentage: 0.2
            )
            exercise.sets.append(newSet)
        case .restPause:
            newSet = ExerciseSet.createRestPauseSet(
                setNumber: 0, // Will be renumbered
                targetReps: repsFromLastSet > 0 ? repsFromLastSet : 8,
                weight: lastSet?.weight,
                restPeriod: lastSet?.restPeriod ?? 90,
                numberOfPauses: 2,
                pauseDuration: 15
            )
            exercise.sets.append(newSet)
        case .timed:
            // Get previous timed set duration if available, otherwise use 30 seconds default
            let previousDuration = lastSet?.timedSetConfig?.targetDuration ?? 30
            newSet = ExerciseSet.createTimedSet(
                setNumber: 0, // Will be renumbered
                targetDuration: previousDuration,
                addedWeight: lastSet?.timedSetConfig?.addedWeight,
                restPeriod: lastSet?.restPeriod ?? 90
            )
            exercise.sets.append(newSet)
        }

        renumberSets()
    }

    /// Remove a set at the specified index
    func removeSet(at index: Int) {
        guard exercise.sets.count > 1 else { return }
        exercise.sets.remove(at: index)
        renumberSets()
    }

    /// Renumber all sets after insertion/removal
    private func renumberSets() {
        for i in exercise.sets.indices {
            exercise.sets[i].setNumber = i + 1
        }
    }

    // MARK: - Set Value Propagation

    /// Update a set and propagate weight changes to subsequent sets
    func updateSet(at index: Int, with updatedSet: ExerciseSet) {
        exercise.sets[index] = updatedSet
    }

    /// Propagate weight change to subsequent incomplete standard sets
    func propagateWeight(from setIndex: Int, newWeight: Double) {
        for i in (setIndex + 1)..<exercise.sets.count {
            if !exercise.sets[i].isCompleted && exercise.sets[i].setType == .standard {
                exercise.sets[i].weight = newWeight
            }
        }
    }

    /// Propagate reps change to subsequent incomplete standard sets
    func propagateReps(from setIndex: Int, newReps: Int) {
        for i in (setIndex + 1)..<exercise.sets.count {
            if !exercise.sets[i].isCompleted && exercise.sets[i].setType == .standard {
                // For pending workouts, update targetReps instead of actualReps
                if isPendingWorkout {
                    exercise.sets[i].targetReps = newReps
                } else {
                    exercise.sets[i].actualReps = newReps
                }
            }
        }
    }

    /// Propagate rest period change to subsequent incomplete standard sets
    func propagateRestPeriod(from setIndex: Int, newRestPeriod: TimeInterval) {
        for i in (setIndex + 1)..<exercise.sets.count {
            if !exercise.sets[i].isCompleted && exercise.sets[i].setType == .standard {
                exercise.sets[i].restPeriod = newRestPeriod
            }
        }
    }

    /// Propagate duration change to subsequent incomplete timed sets
    func propagateDuration(from setIndex: Int, newDuration: TimeInterval) {
        for i in (setIndex + 1)..<exercise.sets.count {
            if !exercise.sets[i].isCompleted && exercise.sets[i].setType == .timed {
                exercise.sets[i].timedSetConfig?.targetDuration = newDuration
            }
        }
    }

    /// Propagate added weight change to subsequent incomplete timed sets
    func propagateAddedWeight(from setIndex: Int, newWeight: Double?) {
        for i in (setIndex + 1)..<exercise.sets.count {
            if !exercise.sets[i].isCompleted && exercise.sets[i].setType == .timed {
                exercise.sets[i].timedSetConfig?.addedWeight = newWeight
            }
        }
    }

    // MARK: - Notes

    /// Update notes and sync to exercise
    func updateNotes(_ newNotes: String) {
        notes = newNotes
        exercise.notes = newNotes
    }

    // MARK: - Superset Handling

    /// Handle set completion in a superset/circuit context
    /// Warmup sets do NOT trigger navigation - they're prep work before the superset rotation
    func handleSupersetSetCompletion(forSetIndex setIndex: Int) {
        guard groupInfo != nil else { return }
        guard setIndex >= 0, setIndex < exercise.sets.count else { return }

        let completedSet = exercise.sets[setIndex]

        // Warmup sets don't trigger navigation - user rests and continues with the same exercise
        if completedSet.setType == .warmup {
            // Just save the exercise state, don't navigate
            if let updateWithoutDismiss = onUpdateWithoutDismiss {
                updateWithoutDismiss(exercise)
            } else {
                onUpdate?(exercise)
            }
            return
        }

        // Save current exercise state without dismissing (so navigation works)
        if let updateWithoutDismiss = onUpdateWithoutDismiss {
            updateWithoutDismiss(exercise)
        } else {
            onUpdate?(exercise)
        }

        // Navigation and rest timer are handled by the callback
        onNavigateToNextInGroup?()
    }

    // MARK: - Actions

    /// Save changes and dismiss
    func saveAndDismiss() {
        onUpdate?(exercise)
    }

    /// Navigate to next exercise in group (for manual navigation button)
    func navigateToNextInGroup() {
        onUpdate?(exercise)
        onNavigateToNextInGroup?()
    }

    // MARK: - Helper Methods

    /// Get previous set weight for plate calculator comparison
    func previousSetWeight(forSetIndex index: Int) -> Double? {
        guard index > 0, index <= exercise.sets.count else { return nil }
        return exercise.sets[index - 1].weight
    }

    /// Get working set number (excludes warmups from count)
    func workingSetNumber(forSetIndex index: Int) -> Int? {
        guard index >= 0, index < exercise.sets.count else { return nil }
        let set = exercise.sets[index]
        guard set.setType != .warmup else { return nil }
        // Count non-warmup sets before this one, then add 1
        let previousWorkingSets = exercise.sets.prefix(index)
            .filter { $0.setType != .warmup }
            .count
        return previousWorkingSets + 1
    }

    /// Check if a set is the last set
    func isLastSet(index: Int) -> Bool {
        guard index >= 0, index < exercise.sets.count else { return false }
        return index == exercise.sets.count - 1
    }

    /// Whether rest timer should be suppressed for a set
    /// Note: Warmup sets in supersets still get their rest timer (warmups are prep work, not part of rotation)
    func suppressRestTimer(for setType: SetType) -> Bool {
        if !isLiveWorkout || isPendingWorkout {
            return true
        }
        // In supersets, suppress rest timer for working sets (they move to next exercise)
        // but allow warmup sets to have their rest timer (warmups are done before rotation starts)
        if isInSuperset && setType != .warmup {
            return true
        }
        return false
    }

    /// Legacy property for backward compatibility - assumes standard set type
    var suppressRestTimer: Bool {
        suppressRestTimer(for: .standard)
    }

    // MARK: - Timed Mode Support

    /// Whether this exercise is currently in timed mode
    var isTimedMode: Bool {
        get { exercise.isTimedMode }
        set { toggleMode(to: newValue) }
    }

    /// Toggle between reps and timed mode
    func toggleMode(to timedMode: Bool) {
        guard exercise.exercise.supportsTiming else { return }
        exercise.isTimedMode = timedMode
        convertSetsForMode(timedMode: timedMode)
    }

    /// Convert sets between standard and timed modes
    private func convertSetsForMode(timedMode: Bool) {
        for i in exercise.sets.indices {
            let set = exercise.sets[i]

            // Only convert incomplete standard or timed sets
            guard !set.isCompleted else { continue }
            guard set.setType == .standard || set.setType == .timed else { continue }

            if timedMode && set.setType == .standard {
                // Convert to timed: suggest duration based on reps (3 seconds per rep)
                let suggestedDuration = Double(set.targetReps) * 3.0
                exercise.sets[i].setType = .timed
                exercise.sets[i].timedSetConfig = TimedSetConfig(targetDuration: suggestedDuration)
            } else if !timedMode && set.setType == .timed {
                // Convert to reps: suggest 10 reps as default
                exercise.sets[i].setType = .standard
                exercise.sets[i].targetReps = 10
                exercise.sets[i].timedSetConfig = nil
            }
        }

        renumberSets()
    }
}
