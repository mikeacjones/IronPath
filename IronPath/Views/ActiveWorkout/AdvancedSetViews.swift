import SwiftUI
import Combine

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
    /// When true, the rest timer will not auto-start after completing a set (used for supersets)
    let suppressRestTimer: Bool
    /// Called after a set is completed (used to notify parent for superset handling)
    let onSetCompleted: (() -> Void)?

    @State private var weight: String
    @State private var reps: String
    @State private var isCompleted: Bool
    @State private var showPlateCalculator: Bool = false
    @State private var showDropSetEditor: Bool = false
    @State private var showRestPauseEditor: Bool = false
    @ObservedObject private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment = .dumbbells,
        onUpdate: @escaping (ExerciseSet) -> Void,
        onWeightChanged: ((Int, Double) -> Void)? = nil,
        onRepsChanged: ((Int, Int) -> Void)? = nil,
        suppressRestTimer: Bool = false,
        onSetCompleted: (() -> Void)? = nil
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.onWeightChanged = onWeightChanged
        self.onRepsChanged = onRepsChanged
        self.suppressRestTimer = suppressRestTimer
        self.onSetCompleted = onSetCompleted

        let suggestedWeight = WorkoutDataManager.shared.getSuggestedWeight(
            for: exerciseName,
            targetReps: set.targetReps
        )

        _weight = State(initialValue: set.weight.map { String(format: "%.0f", $0) } ?? suggestedWeight.map { String(format: "%.0f", $0) } ?? "")
        _reps = State(initialValue: set.actualReps.map { String($0) } ?? String(set.targetReps))
        _isCompleted = State(initialValue: set.isCompleted)
    }

    private var isRestTimerActiveForThisSet: Bool {
        restTimerManager.isActive &&
        restTimerManager.exerciseName == exerciseName &&
        restTimerManager.setNumber == set.setNumber
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
                    suppressRestTimer: suppressRestTimer,
                    onSetCompleted: onSetCompleted
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
                    onSetCompleted: onSetCompleted
                )

            case .dropSet:
                DropSetRow(
                    set: set,
                    setIndex: setIndex,
                    exerciseName: exerciseName,
                    equipment: equipment,
                    onUpdate: onUpdate,
                    suppressRestTimer: suppressRestTimer,
                    onSetCompleted: onSetCompleted
                )

            case .restPause:
                RestPauseSetRow(
                    set: set,
                    setIndex: setIndex,
                    exerciseName: exerciseName,
                    equipment: equipment,
                    onUpdate: onUpdate,
                    suppressRestTimer: suppressRestTimer,
                    onSetCompleted: onSetCompleted
                )
            }

            // Rest timer appears inline after completing a set
            if isRestTimerActiveForThisSet {
                RestTimerView(
                    duration: restTimerManager.remainingTime,
                    onComplete: { },
                    onSkip: {
                        restTimerManager.skipTimer()
                    }
                )
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        // Sync local state when the set data changes from parent (e.g., propagation from earlier sets)
        .onChange(of: set.weight) { _, newWeight in
            if !isCompleted, let newWeight = newWeight {
                let newWeightString = String(format: "%.0f", newWeight)
                if weight != newWeightString {
                    weight = newWeightString
                }
            }
        }
        .onChange(of: set.actualReps) { _, newReps in
            if !isCompleted, let newReps = newReps {
                let newRepsString = String(newReps)
                if reps != newRepsString {
                    reps = newRepsString
                }
            }
        }
    }

    private var borderColor: Color {
        if isRestTimerActiveForThisSet {
            return .blue
        }
        if set.isCompleted {
            return .green.opacity(0.3)
        }
        return .gray.opacity(0.3)
    }

    private var borderWidth: CGFloat {
        isRestTimerActiveForThisSet ? 2 : 1
    }
}

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
    let suppressRestTimer: Bool
    let onSetCompleted: (() -> Void)?

    @State private var showPlateCalculator = false
    @ObservedObject private var restTimerManager = RestTimerManager.shared

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
        suppressRestTimer: Bool = false,
        onSetCompleted: (() -> Void)? = nil
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
        self.suppressRestTimer = suppressRestTimer
        self.onSetCompleted = onSetCompleted
    }

    var body: some View {
        HStack(spacing: 12) {
            // Set number with type indicator
            VStack(spacing: 2) {
                Text("Set \(set.setNumber)")
                    .font(.headline)
            }
            .frame(width: 50, alignment: .leading)

            // Weight input
            WeightInputView(
                weight: $weight,
                equipment: equipment,
                exerciseName: exerciseName,
                showPlateCalculator: $showPlateCalculator,
                onWeightChanged: { newWeight in
                    onWeightChanged?(setIndex, newWeight)
                }
            )

            // Reps input
            RepsInputView(
                reps: $reps,
                targetReps: set.targetReps,
                onRepsChanged: { newReps in
                    onRepsChanged?(setIndex, newReps)
                }
            )

            Spacer()

            // Complete button
            CompleteButton(isCompleted: isCompleted) {
                markComplete()
            }
        }
        .padding()
        .background(isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground))
        .sheet(isPresented: $showPlateCalculator) {
            PlateCalculatorView(
                totalWeight: Double(weight) ?? 0,
                equipment: equipment,
                exerciseName: exerciseName
            )
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

            // Only start rest timer if not suppressed (e.g., for supersets)
            if !suppressRestTimer {
                restTimerManager.startTimer(
                    duration: set.restPeriod,
                    exerciseName: exerciseName,
                    setNumber: set.setNumber
                )
            }

            // Notify parent that set was completed
            onSetCompleted?()
        } else {
            updatedSet.completedAt = nil
        }

        isCompleted.toggle()
        onUpdate(updatedSet)
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
    let onSetCompleted: (() -> Void)?

    @State private var showPlateCalculator = false
    @ObservedObject private var restTimerManager = RestTimerManager.shared

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
        onSetCompleted: (() -> Void)? = nil
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
        self.onSetCompleted = onSetCompleted
    }

    var body: some View {
        HStack(spacing: 12) {
            // Warmup indicator
            VStack(spacing: 2) {
                Image(systemName: "flame")
                    .foregroundStyle(.orange)
                Text("Warmup")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            .frame(width: 50, alignment: .leading)

            // Weight input
            WeightInputView(
                weight: $weight,
                equipment: equipment,
                exerciseName: exerciseName,
                showPlateCalculator: $showPlateCalculator,
                onWeightChanged: { _ in }
            )

            // Reps input
            RepsInputView(
                reps: $reps,
                targetReps: set.targetReps,
                onRepsChanged: { _ in }
            )

            Spacer()

            // Complete button
            CompleteButton(isCompleted: isCompleted) {
                markComplete()
            }
        }
        .padding()
        .background(isCompleted ? Color.orange.opacity(0.1) : Color.orange.opacity(0.05))
        .sheet(isPresented: $showPlateCalculator) {
            PlateCalculatorView(
                totalWeight: Double(weight) ?? 0,
                equipment: equipment,
                exerciseName: exerciseName
            )
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

            // Only start rest timer if not suppressed (e.g., for supersets)
            if !suppressRestTimer {
                restTimerManager.startTimer(
                    duration: set.restPeriod,
                    exerciseName: exerciseName,
                    setNumber: set.setNumber
                )
            }

            // Notify parent that set was completed
            onSetCompleted?()
        } else {
            updatedSet.completedAt = nil
        }

        isCompleted.toggle()
        onUpdate(updatedSet)
    }
}

// MARK: - Drop Set Row

struct DropSetRow: View {
    let set: ExerciseSet
    let setIndex: Int
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let suppressRestTimer: Bool
    let onSetCompleted: (() -> Void)?

    @State private var localConfig: DropSetConfig
    @State private var showEditSheet = false
    @ObservedObject private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment,
        onUpdate: @escaping (ExerciseSet) -> Void,
        suppressRestTimer: Bool = false,
        onSetCompleted: (() -> Void)? = nil
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.suppressRestTimer = suppressRestTimer
        self.onSetCompleted = onSetCompleted
        _localConfig = State(initialValue: set.dropSetConfig ?? DropSetConfig())
    }

    var isCompleted: Bool {
        localConfig.drops.allSatisfy { $0.isCompleted }
    }

    var completedDropsCount: Int {
        localConfig.drops.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.purple)
                    Text("Drop Set \(set.setNumber)")
                        .font(.headline)
                }

                Spacer()

                Text("\(completedDropsCount)/\(localConfig.drops.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Drop entries
            ForEach(localConfig.drops.indices, id: \.self) { index in
                DropEntryRow(
                    drop: localConfig.drops[index],
                    isFirstDrop: index == 0,
                    onUpdate: { updatedDrop in
                        localConfig.drops[index] = updatedDrop
                        saveConfig()

                        // Start short rest timer after completing a drop (except last one)
                        if updatedDrop.isCompleted && index < localConfig.drops.count - 1 {
                            // No rest between drops - that's the point of drop sets!
                        } else if updatedDrop.isCompleted && index == localConfig.drops.count - 1 {
                            // Start normal rest after completing the entire drop set (unless suppressed)
                            if !suppressRestTimer {
                                restTimerManager.startTimer(
                                    duration: set.restPeriod,
                                    exerciseName: exerciseName,
                                    setNumber: set.setNumber
                                )
                            }
                            // Notify parent that the drop set was completed
                            onSetCompleted?()
                        }
                    }
                )
            }

            // Total volume display
            if isCompleted {
                HStack {
                    Text("Total:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(totalReps) reps")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.bottom, 8)
            }
        }
        .background(isCompleted ? Color.purple.opacity(0.1) : Color.purple.opacity(0.05))
        .sheet(isPresented: $showEditSheet) {
            DropSetConfigEditor(
                config: $localConfig,
                startingWeight: set.weight,
                onSave: saveConfig
            )
        }
    }

    private var totalReps: Int {
        localConfig.drops.compactMap { $0.actualReps }.reduce(0, +)
    }

    private func saveConfig() {
        var updatedSet = set
        updatedSet.dropSetConfig = localConfig

        // Update completedAt if all drops are done
        if localConfig.drops.allSatisfy({ $0.isCompleted }) {
            updatedSet.completedAt = Date()
        } else {
            updatedSet.completedAt = nil
        }

        onUpdate(updatedSet)
    }
}

// MARK: - Drop Entry Row

struct DropEntryRow: View {
    let drop: DropSetEntry
    let isFirstDrop: Bool
    let onUpdate: (DropSetEntry) -> Void

    @State private var weight: String
    @State private var reps: String

    init(drop: DropSetEntry, isFirstDrop: Bool, onUpdate: @escaping (DropSetEntry) -> Void) {
        self.drop = drop
        self.isFirstDrop = isFirstDrop
        self.onUpdate = onUpdate

        _weight = State(initialValue: (drop.actualWeight ?? drop.targetWeight).map { String(format: "%.0f", $0) } ?? "")
        _reps = State(initialValue: drop.actualReps.map { String($0) } ?? String(drop.targetReps))
    }

    var body: some View {
        HStack(spacing: 12) {
            // Drop indicator
            VStack(spacing: 2) {
                if isFirstDrop {
                    Text("Start")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("Drop \(drop.dropNumber)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 40)

            // Weight
            TextField("lbs", text: $weight)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)

            Text("×")
                .foregroundStyle(.secondary)

            // Reps
            TextField("reps", text: $reps)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)

            Spacer()

            // Complete button
            Button {
                markComplete()
            } label: {
                Image(systemName: drop.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(drop.isCompleted ? .green : .gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func markComplete() {
        var updatedDrop = drop

        if !drop.isCompleted {
            updatedDrop.actualWeight = Double(weight)
            updatedDrop.actualReps = Int(reps)
            updatedDrop.completedAt = Date()
        } else {
            updatedDrop.completedAt = nil
        }

        onUpdate(updatedDrop)
    }
}

// MARK: - Rest-Pause Set Row

struct RestPauseSetRow: View {
    let set: ExerciseSet
    let setIndex: Int
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let suppressRestTimer: Bool
    let onSetCompleted: (() -> Void)?

    @State private var localConfig: RestPauseConfig
    @State private var weight: String
    @State private var showEditSheet = false
    @State private var activePauseTimer: Int? = nil
    @ObservedObject private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment,
        onUpdate: @escaping (ExerciseSet) -> Void,
        suppressRestTimer: Bool = false,
        onSetCompleted: (() -> Void)? = nil
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.suppressRestTimer = suppressRestTimer
        self.onSetCompleted = onSetCompleted
        _localConfig = State(initialValue: set.restPauseConfig ?? RestPauseConfig())
        _weight = State(initialValue: set.weight.map { String(format: "%.0f", $0) } ?? "")
    }

    var isCompleted: Bool {
        localConfig.miniSets.allSatisfy { $0.isCompleted }
    }

    var completedMiniSetsCount: Int {
        localConfig.miniSets.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.green)
                    Text("Rest-Pause \(set.setNumber)")
                        .font(.headline)
                }

                Spacer()

                Text("\(completedMiniSetsCount)/\(localConfig.miniSets.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Weight (same for all mini-sets)
            HStack {
                Text("Weight:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("lbs", text: $weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onChange(of: weight) { _, newValue in
                        if let weightValue = Double(newValue) {
                            var updatedSet = set
                            updatedSet.weight = weightValue
                            onUpdate(updatedSet)
                        }
                    }

                Text("lbs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal)

            // Mini-set entries
            ForEach(localConfig.miniSets.indices, id: \.self) { index in
                MiniSetRow(
                    miniSet: localConfig.miniSets[index],
                    isFirstSet: index == 0,
                    pauseDuration: localConfig.pauseDuration,
                    isPauseTimerActive: activePauseTimer == index,
                    onUpdate: { updatedMiniSet in
                        localConfig.miniSets[index] = updatedMiniSet
                        saveConfig()

                        // Start brief pause timer after completing a mini-set (except last one)
                        if updatedMiniSet.isCompleted && index < localConfig.miniSets.count - 1 {
                            activePauseTimer = index + 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + localConfig.pauseDuration) {
                                activePauseTimer = nil
                            }
                        } else if updatedMiniSet.isCompleted && index == localConfig.miniSets.count - 1 {
                            // Start normal rest after completing the entire rest-pause set (unless suppressed)
                            if !suppressRestTimer {
                                restTimerManager.startTimer(
                                    duration: set.restPeriod,
                                    exerciseName: exerciseName,
                                    setNumber: set.setNumber
                                )
                            }
                            // Notify parent that the rest-pause set was completed
                            onSetCompleted?()
                        }
                    }
                )
            }

            // Total reps display
            if isCompleted {
                HStack {
                    Text("Total:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(totalReps) reps")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.bottom, 8)
            }
        }
        .background(isCompleted ? Color.green.opacity(0.1) : Color.green.opacity(0.05))
        .sheet(isPresented: $showEditSheet) {
            RestPauseConfigEditor(
                config: $localConfig,
                onSave: saveConfig
            )
        }
    }

    private var totalReps: Int {
        localConfig.miniSets.compactMap { $0.actualReps }.reduce(0, +)
    }

    private func saveConfig() {
        var updatedSet = set
        updatedSet.restPauseConfig = localConfig

        // Update completedAt if all mini-sets are done
        if localConfig.miniSets.allSatisfy({ $0.isCompleted }) {
            updatedSet.completedAt = Date()
        } else {
            updatedSet.completedAt = nil
        }

        onUpdate(updatedSet)
    }
}

// MARK: - Mini Set Row

struct MiniSetRow: View {
    let miniSet: RestPauseMiniSet
    let isFirstSet: Bool
    let pauseDuration: TimeInterval
    let isPauseTimerActive: Bool
    let onUpdate: (RestPauseMiniSet) -> Void

    @State private var reps: String

    init(
        miniSet: RestPauseMiniSet,
        isFirstSet: Bool,
        pauseDuration: TimeInterval,
        isPauseTimerActive: Bool,
        onUpdate: @escaping (RestPauseMiniSet) -> Void
    ) {
        self.miniSet = miniSet
        self.isFirstSet = isFirstSet
        self.pauseDuration = pauseDuration
        self.isPauseTimerActive = isPauseTimerActive
        self.onUpdate = onUpdate

        _reps = State(initialValue: miniSet.actualReps.map { String($0) } ?? String(miniSet.targetReps))
    }

    var body: some View {
        VStack(spacing: 4) {
            // Pause timer indicator
            if isPauseTimerActive {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.green)
                    Text("Rest \(Int(pauseDuration))s...")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 12) {
                // Mini-set indicator
                VStack(spacing: 2) {
                    if isFirstSet {
                        Text("Initial")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "pause")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Pause \(miniSet.miniSetNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 50)

                // Target reps indicator
                Text("Target: \(miniSet.targetReps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Reps input
                TextField("reps", text: $reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)

                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Complete button
                Button {
                    markComplete()
                } label: {
                    Image(systemName: miniSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(miniSet.isCompleted ? .green : .gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private func markComplete() {
        var updatedMiniSet = miniSet

        if !miniSet.isCompleted {
            updatedMiniSet.actualReps = Int(reps)
            updatedMiniSet.completedAt = Date()
        } else {
            updatedMiniSet.completedAt = nil
        }

        onUpdate(updatedMiniSet)
    }
}

// MARK: - Shared Components

struct WeightInputView: View {
    @Binding var weight: String
    let equipment: Equipment
    let exerciseName: String
    @Binding var showPlateCalculator: Bool
    let onWeightChanged: (Double) -> Void

    private var showPlateCalcButton: Bool {
        switch equipment {
        case .barbell, .squat, .legPress, .smithMachine, .cables:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                TextField("Weight", text: $weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onChange(of: weight) { _, newValue in
                        if let weightValue = Double(newValue) {
                            onWeightChanged(weightValue)
                        }
                    }
                Text("lbs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showPlateCalcButton {
                    Button {
                        showPlateCalculator = true
                    } label: {
                        Image(systemName: "circle.grid.2x2")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}

struct RepsInputView: View {
    @Binding var reps: String
    let targetReps: Int
    let onRepsChanged: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            TextField("Reps", text: $reps)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .onChange(of: reps) { _, newValue in
                    if let repsValue = Int(newValue) {
                        onRepsChanged(repsValue)
                    }
                }
            Text("× \(targetReps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CompleteButton: View {
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isCompleted ? .green : .gray)
        }
    }
}

// MARK: - Configuration Editors

struct DropSetConfigEditor: View {
    @Binding var config: DropSetConfig
    let startingWeight: Double?
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var numberOfDrops: Int
    @State private var dropPercentage: Double

    init(config: Binding<DropSetConfig>, startingWeight: Double?, onSave: @escaping () -> Void) {
        self._config = config
        self.startingWeight = startingWeight
        self.onSave = onSave
        _numberOfDrops = State(initialValue: config.wrappedValue.numberOfDrops)
        _dropPercentage = State(initialValue: config.wrappedValue.dropPercentage * 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Number of Drops: \(numberOfDrops)", value: $numberOfDrops, in: 1...5)

                    VStack(alignment: .leading) {
                        Text("Weight Reduction: \(Int(dropPercentage))%")
                        Slider(value: $dropPercentage, in: 10...40, step: 5)
                    }
                } header: {
                    Text("Drop Set Configuration")
                } footer: {
                    Text("Each drop reduces weight by \(Int(dropPercentage))%. Typical: 20-25%")
                }

                if let weight = startingWeight {
                    Section {
                        let suggestedWeights = DropSetConfig(
                            numberOfDrops: numberOfDrops,
                            dropPercentage: dropPercentage / 100
                        ).suggestedWeights(startingWeight: weight)

                        ForEach(0..<suggestedWeights.count, id: \.self) { index in
                            HStack {
                                Text(index == 0 ? "Starting" : "Drop \(index)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(suggestedWeights[index])) lbs")
                                    .fontWeight(.medium)
                            }
                        }
                    } header: {
                        Text("Suggested Weights")
                    }
                }
            }
            .navigationTitle("Edit Drop Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyChanges()
                        dismiss()
                    }
                }
            }
        }
    }

    private func applyChanges() {
        config.numberOfDrops = numberOfDrops
        config.dropPercentage = dropPercentage / 100

        // Rebuild drops array if count changed
        if config.drops.count != numberOfDrops + 1 {
            let suggestedWeights = config.suggestedWeights(startingWeight: startingWeight ?? 100)
            config.drops = (0...numberOfDrops).map { index in
                DropSetEntry(
                    dropNumber: index,
                    targetWeight: suggestedWeights[safe: index],
                    targetReps: 8
                )
            }
        }

        onSave()
    }
}

struct RestPauseConfigEditor: View {
    @Binding var config: RestPauseConfig
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var numberOfPauses: Int
    @State private var pauseDuration: Double

    init(config: Binding<RestPauseConfig>, onSave: @escaping () -> Void) {
        self._config = config
        self.onSave = onSave
        _numberOfPauses = State(initialValue: config.wrappedValue.numberOfPauses)
        _pauseDuration = State(initialValue: config.wrappedValue.pauseDuration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Number of Pauses: \(numberOfPauses)", value: $numberOfPauses, in: 1...4)

                    VStack(alignment: .leading) {
                        Text("Pause Duration: \(Int(pauseDuration)) seconds")
                        Slider(value: $pauseDuration, in: 5...30, step: 5)
                    }
                } header: {
                    Text("Rest-Pause Configuration")
                } footer: {
                    Text("Rest-pause uses brief \(Int(pauseDuration))s rests to extend the set. Typical: 10-20s")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How Rest-Pause Works:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("1. Perform reps to near failure")
                        Text("2. Rest \(Int(pauseDuration)) seconds")
                        Text("3. Perform more reps (typically 2-4)")
                        Text("4. Repeat \(numberOfPauses) time(s)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Rest-Pause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyChanges()
                        dismiss()
                    }
                }
            }
        }
    }

    private func applyChanges() {
        config.numberOfPauses = numberOfPauses
        config.pauseDuration = pauseDuration

        // Rebuild mini-sets array if count changed
        let expectedCount = numberOfPauses + 1
        if config.miniSets.count != expectedCount {
            config.miniSets = [RestPauseMiniSet(miniSetNumber: 0, targetReps: 8)]
            for i in 1...numberOfPauses {
                config.miniSets.append(RestPauseMiniSet(miniSetNumber: i, targetReps: 4))
            }
        }

        onSave()
    }
}

// MARK: - Add Set Type Picker

struct SetTypePickerView: View {
    let onSelectType: (SetType) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(SetType.allCases, id: \.self) { setType in
                    Button {
                        onSelectType(setType)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: setType.iconName)
                                .font(.title2)
                                .foregroundStyle(colorForSetType(setType))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(setType.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(setType.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func colorForSetType(_ type: SetType) -> Color {
        switch type {
        case .standard: return .blue
        case .warmup: return .orange
        case .dropSet: return .purple
        case .restPause: return .green
        }
    }
}
