import SwiftUI

// MARK: - Set Row View

/// A single set row within an exercise, showing weight, reps, and completion status
struct SetRowView: View {
    let set: ExerciseSet
    let setIndex: Int  // 0-based index of this set
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let onWeightChanged: ((Int, Double) -> Void)?  // Callback when weight changes (setIndex, newWeight)
    let onRepsChanged: ((Int, Int) -> Void)?  // Callback when reps change (setIndex, newReps)

    // Dependencies injected via init
    private let workoutDataManager: WorkoutDataManaging
    private let restTimerManager: RestTimerManaging
    private let gymSettings: GymSettingsProviding

    @State private var weight: String
    @State private var reps: String
    @State private var isCompleted: Bool
    @State private var showPlateCalculator: Bool = false

    // Cached suggested weight for display purposes
    private let suggestedWeight: Double?

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment = .dumbbells,
        onUpdate: @escaping (ExerciseSet) -> Void,
        onWeightChanged: ((Int, Double) -> Void)? = nil,
        onRepsChanged: ((Int, Int) -> Void)? = nil,
        workoutDataManager: WorkoutDataManaging = WorkoutDataManager.shared,
        restTimerManager: RestTimerManaging = RestTimerManager.shared,
        gymSettings: GymSettingsProviding = GymSettings.shared
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.onWeightChanged = onWeightChanged
        self.onRepsChanged = onRepsChanged
        self.workoutDataManager = workoutDataManager
        self.restTimerManager = restTimerManager
        self.gymSettings = gymSettings

        // Get suggested weight from history if available
        let suggested = workoutDataManager.getSuggestedWeight(
            for: exerciseName,
            targetReps: set.targetReps
        )
        self.suggestedWeight = suggested

        _weight = State(initialValue: set.weight.map { String(format: "%.0f", $0) } ?? suggested.map { String(format: "%.0f", $0) } ?? "")
        _reps = State(initialValue: set.actualReps.map { String($0) } ?? String(set.targetReps))
        _isCompleted = State(initialValue: set.isCompleted)
    }

    /// Check if rest timer is active for THIS specific set
    private var isRestTimerActiveForThisSet: Bool {
        restTimerManager.isActive &&
        restTimerManager.exerciseName == exerciseName &&
        restTimerManager.setNumber == set.setNumber
    }

    private var showPlateCalcButton: Bool {
        switch equipment {
        case .barbell, .squat, .legPress, .smithMachine:
            return true  // Plate-loaded equipment
        case .cables:
            return true  // Cable machine weight selector
        default:
            return false
        }
    }

    /// Whether this equipment uses standard plates (vs cable weight stack)
    private var usesPlates: Bool {
        switch equipment {
        case .barbell, .squat, .legPress, .smithMachine:
            return true
        default:
            return false
        }
    }

    /// Check if current weight is valid for cable machine
    private var isInvalidCableWeight: Bool {
        guard equipment == .cables, let weightValue = Double(weight), weightValue > 0 else {
            return false
        }
        let config = gymSettings.cableConfig(for: exerciseName)
        return !config.isValidWeight(weightValue)
    }

    /// Get pin location for current weight (cable machines only)
    private var currentPinLocation: Int? {
        guard equipment == .cables, let weightValue = Double(weight), weightValue > 0 else {
            return nil
        }
        let config = gymSettings.cableConfig(for: exerciseName)
        return config.pinLocation(for: weightValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Set number
                Text("Set \(set.setNumber)")
                    .font(.headline)
                    .frame(width: 50, alignment: .leading)

                // Weight input
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isInvalidCableWeight ? Color.orange : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: weight) { _, newValue in
                                if let weightValue = Double(newValue) {
                                    onWeightChanged?(setIndex, weightValue)
                                }
                            }
                        Text("lbs")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Plate calculator button for plate-loaded and cable exercises
                        if showPlateCalcButton {
                            Button {
                                showPlateCalculator = true
                            } label: {
                                Image(systemName: usesPlates ? "circle.grid.2x2" : "slider.horizontal.3")
                                    .font(.caption)
                                    .foregroundStyle(isInvalidCableWeight ? .orange : .blue)
                            }
                        }
                    }

                    // Show pin location for valid cable weights
                    if let pin = currentPinLocation {
                        HStack(spacing: 2) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                            Text("Pin \(pin)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.blue)
                    }

                    // Show invalid weight warning for cables
                    if isInvalidCableWeight {
                        Button {
                            showPlateCalculator = true
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text("Invalid weight - tap to fix")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.orange)
                        }
                    }

                    // Show if this is a suggested weight from history
                    if let suggested = suggestedWeight, !weight.isEmpty, Double(weight) == suggested {
                        Text("↑ +2.5%")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                // Reps input
                HStack(spacing: 4) {
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .onChange(of: reps) { _, newValue in
                            if let repsValue = Int(newValue) {
                                onRepsChanged?(setIndex, repsValue)
                            }
                        }
                    Text("× \(set.targetReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Complete button
                Button {
                    markComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isCompleted ? .green : .gray)
                }
            }
            .padding()
            .background(isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground))

            // Rest timer appears inline after completing a set (only for this specific set)
            if isRestTimerActiveForThisSet {
                RestTimerView(
                    duration: restTimerManager.totalDuration,
                    remainingTime: restTimerManager.remainingTime,
                    onComplete: {
                        // Handled by RestTimerManager
                    },
                    onSkip: {
                        restTimerManager.skipTimer()
                    }
                )
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRestTimerActiveForThisSet ? Color.blue : (isCompleted ? Color.green : Color.gray.opacity(0.3)), lineWidth: isRestTimerActiveForThisSet ? 2 : 1)
        )
        .sheet(isPresented: $showPlateCalculator) {
            if usesPlates {
                PlateCalculatorView(
                    totalWeight: Double(weight) ?? 0,
                    equipment: equipment,
                    exerciseName: exerciseName
                )
            } else {
                CableWeightCalculatorView(
                    targetWeight: Double(weight) ?? 0,
                    exerciseName: exerciseName,
                    onSelectWeight: { selectedWeight in
                        weight = String(format: "%.0f", selectedWeight)
                        showPlateCalculator = false
                    }
                )
            }
        }
        .onChange(of: set.weight) { _, newWeight in
            // Update local state when external weight changes (propagation from set 1)
            if let newWeight = newWeight {
                weight = String(format: "%.0f", newWeight)
            }
        }
        .onChange(of: set.actualReps) { _, newReps in
            // Update local state when external reps changes (propagation from set 1)
            if let newReps = newReps {
                reps = String(newReps)
            }
        }
    }

    private func markComplete() {
        var updatedSet = set

        if !isCompleted {
            // Mark as complete
            if let weightValue = Double(weight) {
                updatedSet.weight = weightValue
            }
            if let repsValue = Int(reps) {
                updatedSet.actualReps = repsValue
            }
            updatedSet.completedAt = Date()

            // Start global rest timer
            restTimerManager.startTimer(
                duration: set.restPeriod,
                exerciseName: exerciseName,
                setNumber: set.setNumber
            )
        } else {
            // Unmark
            updatedSet.completedAt = nil
            // Stop rest timer if it was for this set
            if isRestTimerActiveForThisSet {
                restTimerManager.stopTimer()
            }
        }

        isCompleted.toggle()
        onUpdate(updatedSet)
    }
}
