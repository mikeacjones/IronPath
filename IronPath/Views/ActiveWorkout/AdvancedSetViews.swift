import SwiftUI

// MARK: - Advanced Set Row View

/// A row view that handles all set types (standard, warmup, drop set, rest-pause)
struct AdvancedSetRowView: View {
    let set: ExerciseSet
    let setIndex: Int
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let onWeightChanged: ((Int, Double) -> Void)?
    let onRepsChanged: ((Int, Int) -> Void)?
    let onRestPeriodChanged: ((Int, TimeInterval) -> Void)?
    let onDurationChanged: ((Int, TimeInterval) -> Void)?
    let onAddedWeightChanged: ((Int, Double?) -> Void)?
    let suppressRestTimer: Bool
    let isLastSet: Bool
    let onSetCompleted: (() -> Void)?
    let isLiveWorkout: Bool
    let isPendingWorkout: Bool
    let workingSetNumber: Int?
    let previousSetWeight: Double?
    let isFirstIncompleteSet: Bool

    @State private var weight: String
    @State private var reps: String
    @State private var isCompleted: Bool
    @State private var showPlateCalculator: Bool = false
    @State private var showDropSetEditor: Bool = false
    @State private var showRestPauseEditor: Bool = false
    @State private var restTimerManager = RestTimerManager.shared
    @State private var exerciseTimerManager = ExerciseTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment = .dumbbells,
        onUpdate: @escaping (ExerciseSet) -> Void,
        onWeightChanged: ((Int, Double) -> Void)? = nil,
        onRepsChanged: ((Int, Int) -> Void)? = nil,
        onRestPeriodChanged: ((Int, TimeInterval) -> Void)? = nil,
        onDurationChanged: ((Int, TimeInterval) -> Void)? = nil,
        onAddedWeightChanged: ((Int, Double?) -> Void)? = nil,
        suppressRestTimer: Bool = false,
        isLastSet: Bool = false,
        onSetCompleted: (() -> Void)? = nil,
        isLiveWorkout: Bool = true,
        isPendingWorkout: Bool = false,
        workingSetNumber: Int? = nil,
        previousSetWeight: Double? = nil,
        isFirstIncompleteSet: Bool = false
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.onWeightChanged = onWeightChanged
        self.onRepsChanged = onRepsChanged
        self.onRestPeriodChanged = onRestPeriodChanged
        self.onDurationChanged = onDurationChanged
        self.onAddedWeightChanged = onAddedWeightChanged
        self.suppressRestTimer = suppressRestTimer
        self.isLastSet = isLastSet
        self.onSetCompleted = onSetCompleted
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
        self.workingSetNumber = workingSetNumber
        self.previousSetWeight = previousSetWeight
        self.isFirstIncompleteSet = isFirstIncompleteSet

        let suggestedWeight = WorkoutDataManager.shared.getSuggestedWeight(
            for: exerciseName,
            targetReps: set.targetReps
        )

        _weight = State(initialValue: set.weight.map { formatWeight($0) } ?? suggestedWeight.map { formatWeight($0) } ?? "")
        _reps = State(initialValue: isPendingWorkout ? String(set.targetReps) : (set.actualReps.map { String($0) } ?? String(set.targetReps)))
        _isCompleted = State(initialValue: set.isCompleted)
    }

    private var isRestTimerActiveForThisSet: Bool {
        restTimerManager.isActive &&
        restTimerManager.exerciseName == exerciseName &&
        restTimerManager.setNumber == set.setNumber
    }

    private var shouldShowExerciseTimerForThisSet: Bool {
        guard self.set.setType == .timed &&
              !self.set.isCompleted &&
              isLiveWorkout &&
              !isPendingWorkout else {
            return false
        }

        // Only show for this specific set when timer is active
        if exerciseTimerManager.isActive {
            return exerciseTimerManager.exerciseName == self.exerciseName &&
                   exerciseTimerManager.setNumber == self.set.setNumber
        }

        // Show for inactive timer (start button) only if this is the first incomplete set
        return isFirstIncompleteSet
    }

    var body: some View {
        VStack(spacing: 0) {
            switch set.setType {
            case .standard:
                StandardSetRow(
                    set: set,
                    setIndex: setIndex,
                    exerciseName: exerciseName,
                    equipment: equipment,
                    weight: $weight,
                    reps: $reps,
                    isCompleted: $isCompleted,
                    onUpdate: onUpdate,
                    onWeightChanged: onWeightChanged,
                    onRepsChanged: onRepsChanged,
                    onRestPeriodChanged: onRestPeriodChanged,
                    suppressRestTimer: suppressRestTimer,
                    isLastSet: isLastSet,
                    onSetCompleted: onSetCompleted,
                    isLiveWorkout: isLiveWorkout,
                    isPendingWorkout: isPendingWorkout,
                    workingSetNumber: workingSetNumber,
                    previousSetWeight: previousSetWeight
                )

            case .warmup:
                WarmupSetRow(
                    set: set,
                    setIndex: setIndex,
                    exerciseName: exerciseName,
                    equipment: equipment,
                    weight: $weight,
                    reps: $reps,
                    isCompleted: $isCompleted,
                    onUpdate: onUpdate,
                    suppressRestTimer: suppressRestTimer,
                    isLastSet: isLastSet,
                    onSetCompleted: onSetCompleted,
                    isLiveWorkout: isLiveWorkout,
                    isPendingWorkout: isPendingWorkout
                )

            case .dropSet:
                DropSetRow(
                    set: set,
                    setIndex: setIndex,
                    exerciseName: exerciseName,
                    equipment: equipment,
                    onUpdate: onUpdate,
                    suppressRestTimer: suppressRestTimer,
                    isLastSet: isLastSet,
                    onSetCompleted: onSetCompleted,
                    isLiveWorkout: isLiveWorkout,
                    isPendingWorkout: isPendingWorkout
                )

            case .restPause:
                RestPauseSetRow(
                    set: set,
                    setIndex: setIndex,
                    exerciseName: exerciseName,
                    equipment: equipment,
                    onUpdate: onUpdate,
                    isLastSet: isLastSet,
                    suppressRestTimer: suppressRestTimer,
                    onSetCompleted: onSetCompleted,
                    isLiveWorkout: isLiveWorkout,
                    isPendingWorkout: isPendingWorkout
                )

            case .timed:
                TimedSetRow(
                    set: set,
                    setIndex: setIndex,
                    exerciseName: exerciseName,
                    equipment: equipment,
                    onUpdate: onUpdate,
                    onDurationChanged: onDurationChanged,
                    onAddedWeightChanged: onAddedWeightChanged,
                    suppressRestTimer: suppressRestTimer,
                    isLastSet: isLastSet,
                    onSetCompleted: onSetCompleted,
                    isLiveWorkout: isLiveWorkout,
                    isPendingWorkout: isPendingWorkout
                )
            }

            if isRestTimerActiveForThisSet {
                RestTimerView(
                    duration: restTimerManager.totalDuration,
                    remainingTime: restTimerManager.remainingTime,
                    onComplete: { },
                    onSkip: {
                        restTimerManager.skipTimer()
                    },
                    onRestTimeChanged: { newDuration in
                        onRestPeriodChanged?(setIndex, newDuration)
                    }
                )
            }

            if shouldShowExerciseTimerForThisSet {
                ExerciseTimerView(
                    timerManager: exerciseTimerManager,
                    exerciseName: exerciseName,
                    setNumber: set.setNumber,
                    targetDuration: set.timedSetConfig?.targetDuration ?? 30,
                    onTimerComplete: { duration in
                        completeTimedSet(withDuration: duration)
                    }
                )
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .onChange(of: set.weight) { _, newWeight in
            if !isCompleted, let newWeight = newWeight {
                let newWeightString = formatWeight(newWeight)
                if weight != newWeightString {
                    weight = newWeightString
                }
            }
        }
        .onChange(of: set.actualReps) { _, newReps in
            if !isCompleted && !isPendingWorkout, let newReps = newReps {
                let newRepsString = String(newReps)
                if reps != newRepsString {
                    reps = newRepsString
                }
            }
        }
        .onChange(of: set.targetReps) { _, newTargetReps in
            if !isCompleted && isPendingWorkout {
                let newRepsString = String(newTargetReps)
                if reps != newRepsString {
                    reps = newRepsString
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func completeTimedSet(withDuration duration: TimeInterval) {
        var updatedSet = set
        updatedSet.timedSetConfig?.actualDuration = duration
        updatedSet.completedAt = Date()
        isCompleted = true
        onUpdate(updatedSet)

        // Start rest timer if applicable
        if !suppressRestTimer && !isLastSet {
            restTimerManager.startTimer(
                duration: set.restPeriod,
                exerciseName: exerciseName,
                setNumber: set.setNumber
            )
        }

        // Call completion callback
        onSetCompleted?()
    }

    private var borderColor: Color {
        if shouldShowExerciseTimerForThisSet && exerciseTimerManager.isActive {
            return .cyan
        }
        if isRestTimerActiveForThisSet {
            return .blue
        }
        if set.isCompleted {
            return .green.opacity(0.3)
        }
        return .gray.opacity(0.3)
    }

    private var borderWidth: CGFloat {
        (isRestTimerActiveForThisSet || (shouldShowExerciseTimerForThisSet && exerciseTimerManager.isActive)) ? 2 : 1
    }
}
