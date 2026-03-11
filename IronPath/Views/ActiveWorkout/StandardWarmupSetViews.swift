import SwiftUI

// MARK: - Standard Set Row

struct StandardSetRow: View {
    let set: ExerciseSet
    let setIndex: Int
    let exerciseName: String
    let equipment: Equipment
    @Binding var weight: String
    @Binding var reps: String
    @Binding var isCompleted: Bool
    let onUpdate: (ExerciseSet) -> Void
    let onWeightChanged: ((Int, Double) -> Void)?
    let onRepsChanged: ((Int, Int) -> Void)?
    let onRestPeriodChanged: ((Int, TimeInterval) -> Void)?
    let suppressRestTimer: Bool
    let isLastSet: Bool
    let onSetCompleted: (() -> Void)?
    let isLiveWorkout: Bool
    let isPendingWorkout: Bool
    let workingSetNumber: Int?
    let previousSetWeight: Double?
    let weightUnit: WeightUnit

    @State private var showPlateCalculator = false
    @State private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment,
        weight: Binding<String>,
        reps: Binding<String>,
        isCompleted: Binding<Bool>,
        onUpdate: @escaping (ExerciseSet) -> Void,
        onWeightChanged: ((Int, Double) -> Void)? = nil,
        onRepsChanged: ((Int, Int) -> Void)? = nil,
        onRestPeriodChanged: ((Int, TimeInterval) -> Void)? = nil,
        suppressRestTimer: Bool = false,
        isLastSet: Bool = false,
        onSetCompleted: (() -> Void)? = nil,
        isLiveWorkout: Bool = true,
        isPendingWorkout: Bool = false,
        workingSetNumber: Int? = nil,
        previousSetWeight: Double? = nil,
        weightUnit: WeightUnit = .pounds
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self._weight = weight
        self._reps = reps
        self._isCompleted = isCompleted
        self.onUpdate = onUpdate
        self.onWeightChanged = onWeightChanged
        self.onRepsChanged = onRepsChanged
        self.onRestPeriodChanged = onRestPeriodChanged
        self.suppressRestTimer = suppressRestTimer
        self.isLastSet = isLastSet
        self.onSetCompleted = onSetCompleted
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
        self.workingSetNumber = workingSetNumber
        self.previousSetWeight = previousSetWeight
        self.weightUnit = weightUnit
    }

    private var displayNumber: Int {
        workingSetNumber ?? set.setNumber
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("Set \(displayNumber)")
                    .font(.headline)
            }
            .frame(width: 50, alignment: .leading)

            WeightInputView(
                weight: $weight,
                equipment: equipment,
                exerciseName: exerciseName,
                showPlateCalculator: $showPlateCalculator,
                weightUnitOverride: weightUnit,
                onWeightChanged: { newWeight in
                    onWeightChanged?(setIndex, newWeight)
                    var updatedSet = set
                    updatedSet.weight = newWeight
                    if !isLiveWorkout && updatedSet.completedAt == nil {
                        updatedSet.completedAt = Date()
                    }
                    onUpdate(updatedSet)
                }
            )

            RepsInputView(
                reps: $reps,
                targetReps: set.targetReps,
                onRepsChanged: { newReps in
                    onRepsChanged?(setIndex, newReps)
                    var updatedSet = set
                    if isPendingWorkout {
                        updatedSet.targetReps = newReps
                    } else {
                        updatedSet.actualReps = newReps
                        if !isLiveWorkout && updatedSet.completedAt == nil {
                            updatedSet.completedAt = Date()
                        }
                    }
                    onUpdate(updatedSet)
                }
            )

            Spacer()

            if isLiveWorkout && !isPendingWorkout {
                CompleteButton(isCompleted: isCompleted) {
                    markComplete()
                }
            }
        }
        .padding()
        .background(isCompleted || !isLiveWorkout ? Color.green.opacity(0.1) : Color(.systemBackground))
        .sheet(isPresented: $showPlateCalculator) {
            if equipment == .cables {
                CableWeightCalculatorView(
                    targetWeight: Double(weight) ?? 0,
                    exerciseName: exerciseName,
                    weightUnit: weightUnit,
                    onSelectWeight: { selectedWeight in
                        weight = formatWeight(selectedWeight)
                        showPlateCalculator = false
                    }
                )
            } else {
                PlateCalculatorView(
                    totalWeight: Double(weight) ?? 0,
                    equipment: equipment,
                    exerciseName: exerciseName,
                    weightUnitOverride: weightUnit,
                    previousWeight: previousSetWeight
                )
            }
        }
    }

    private func markComplete() {
        var updatedSet = set

        if !isCompleted {
            if let weightValue = Double(weight) {
                updatedSet.weight = weightValue
            }
            if let repsValue = Int(reps) {
                updatedSet.actualReps = repsValue
            }
            updatedSet.completedAt = Date()

            if !suppressRestTimer && !isLastSet {
                restTimerManager.startTimer(
                    duration: set.restPeriod,
                    exerciseName: exerciseName,
                    setNumber: set.setNumber
                )
            }
        } else {
            updatedSet.completedAt = nil
        }

        isCompleted.toggle()
        onUpdate(updatedSet)

        if updatedSet.completedAt != nil {
            onSetCompleted?()
        }
    }
}

// MARK: - Warmup Set Row

struct WarmupSetRow: View {
    let set: ExerciseSet
    let setIndex: Int
    let exerciseName: String
    let equipment: Equipment
    @Binding var weight: String
    @Binding var reps: String
    @Binding var isCompleted: Bool
    let onUpdate: (ExerciseSet) -> Void
    let suppressRestTimer: Bool
    let isLastSet: Bool
    let onSetCompleted: (() -> Void)?
    let isLiveWorkout: Bool
    let isPendingWorkout: Bool
    let weightUnit: WeightUnit

    @State private var showPlateCalculator = false
    @State private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment,
        weight: Binding<String>,
        reps: Binding<String>,
        isCompleted: Binding<Bool>,
        onUpdate: @escaping (ExerciseSet) -> Void,
        suppressRestTimer: Bool = false,
        isLastSet: Bool = false,
        onSetCompleted: (() -> Void)? = nil,
        isLiveWorkout: Bool = true,
        isPendingWorkout: Bool = false,
        weightUnit: WeightUnit = .pounds
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self._weight = weight
        self._reps = reps
        self._isCompleted = isCompleted
        self.onUpdate = onUpdate
        self.suppressRestTimer = suppressRestTimer
        self.isLastSet = isLastSet
        self.onSetCompleted = onSetCompleted
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
        self.weightUnit = weightUnit
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Image(systemName: "flame")
                    .foregroundStyle(.orange)
                Text("Warmup")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            .frame(width: 50, alignment: .leading)

            WeightInputView(
                weight: $weight,
                equipment: equipment,
                exerciseName: exerciseName,
                showPlateCalculator: $showPlateCalculator,
                weightUnitOverride: weightUnit,
                onWeightChanged: { newWeight in
                    var updatedSet = set
                    updatedSet.weight = newWeight
                    if !isLiveWorkout && updatedSet.completedAt == nil {
                        updatedSet.completedAt = Date()
                    }
                    onUpdate(updatedSet)
                }
            )

            RepsInputView(
                reps: $reps,
                targetReps: set.targetReps,
                onRepsChanged: { newReps in
                    var updatedSet = set
                    if isPendingWorkout {
                        updatedSet.targetReps = newReps
                    } else {
                        updatedSet.actualReps = newReps
                        if !isLiveWorkout && updatedSet.completedAt == nil {
                            updatedSet.completedAt = Date()
                        }
                    }
                    onUpdate(updatedSet)
                }
            )

            Spacer()

            if isLiveWorkout && !isPendingWorkout {
                CompleteButton(isCompleted: isCompleted) {
                    markComplete()
                }
            }
        }
        .padding()
        .background(isCompleted || !isLiveWorkout ? Color.orange.opacity(0.1) : Color.orange.opacity(0.05))
        .sheet(isPresented: $showPlateCalculator) {
            if equipment == .cables {
                CableWeightCalculatorView(
                    targetWeight: Double(weight) ?? 0,
                    exerciseName: exerciseName,
                    weightUnit: weightUnit,
                    onSelectWeight: { selectedWeight in
                        weight = formatWeight(selectedWeight)
                        showPlateCalculator = false
                    }
                )
            } else {
                PlateCalculatorView(
                    totalWeight: Double(weight) ?? 0,
                    equipment: equipment,
                    exerciseName: exerciseName,
                    weightUnitOverride: weightUnit
                )
            }
        }
    }

    private func markComplete() {
        var updatedSet = set

        if !isCompleted {
            if let weightValue = Double(weight) {
                updatedSet.weight = weightValue
            }
            if let repsValue = Int(reps) {
                updatedSet.actualReps = repsValue
            }
            updatedSet.completedAt = Date()

            if !suppressRestTimer && !isLastSet {
                restTimerManager.startTimer(
                    duration: set.restPeriod,
                    exerciseName: exerciseName,
                    setNumber: set.setNumber
                )
            }
        } else {
            updatedSet.completedAt = nil
        }

        isCompleted.toggle()
        onUpdate(updatedSet)
    }
}
