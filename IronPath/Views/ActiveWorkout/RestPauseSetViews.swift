import SwiftUI

// MARK: - Rest-Pause Set Row

struct RestPauseSetRow: View {
    let set: ExerciseSet
    let setIndex: Int
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let isLastSet: Bool
    let suppressRestTimer: Bool
    let onSetCompleted: (() -> Void)?
    let isLiveWorkout: Bool
    let isPendingWorkout: Bool
    let weightUnit: WeightUnit

    private let gymSettings: GymSettingsProviding

    @State private var localConfig: RestPauseConfig
    @State private var weight: String
    @State private var showEditSheet = false
    @State private var activePauseTimer: Int? = nil
    @State private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment,
        onUpdate: @escaping (ExerciseSet) -> Void,
        isLastSet: Bool = false,
        suppressRestTimer: Bool = false,
        onSetCompleted: (() -> Void)? = nil,
        isLiveWorkout: Bool = true,
        isPendingWorkout: Bool = false,
        weightUnit: WeightUnit = .pounds,
        gymSettings: GymSettingsProviding? = nil
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.isLastSet = isLastSet
        self.suppressRestTimer = suppressRestTimer
        self.onSetCompleted = onSetCompleted
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
        self.weightUnit = weightUnit
        self.gymSettings = gymSettings ?? GymSettings.shared
        _localConfig = State(initialValue: set.restPauseConfig ?? RestPauseConfig())
        _weight = State(initialValue: set.weight.map { formatWeight($0) } ?? "")
    }

    var isCompleted: Bool {
        localConfig.miniSets.allSatisfy { $0.isCompleted }
    }

    var completedMiniSetsCount: Int {
        localConfig.miniSets.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 8) {
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

            HStack {
                Text("Weight:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField(weightUnit.abbreviation, text: $weight)
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

                Text(weightUnit.abbreviation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal)

            ForEach(localConfig.miniSets.indices, id: \.self) { index in
                MiniSetRow(
                    miniSet: localConfig.miniSets[index],
                    isFirstSet: index == 0,
                    pauseDuration: localConfig.pauseDuration,
                    isPauseTimerActive: activePauseTimer == index,
                    isLiveWorkout: isLiveWorkout,
                    isPendingWorkout: isPendingWorkout,
                    onUpdate: { updatedMiniSet in
                        localConfig.miniSets[index] = updatedMiniSet
                        saveConfig()

                        if updatedMiniSet.isCompleted && index < localConfig.miniSets.count - 1 {
                            activePauseTimer = index + 1
                            let pauseDuration = localConfig.pauseDuration
                            Task {
                                try? await Task.sleep(for: .seconds(pauseDuration))
                                await MainActor.run { activePauseTimer = nil }
                            }
                        } else if updatedMiniSet.isCompleted && index == localConfig.miniSets.count - 1 {
                            if !suppressRestTimer && !isLastSet {
                                restTimerManager.startTimer(
                                    duration: set.restPeriod,
                                    exerciseName: exerciseName,
                                    setNumber: set.setNumber
                                )
                            }
                            onSetCompleted?()
                        }
                    }
                )
            }

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
    let isLiveWorkout: Bool
    let isPendingWorkout: Bool
    let onUpdate: (RestPauseMiniSet) -> Void

    @State private var reps: String
    @State private var remainingPauseTime: TimeInterval = 0
    @State private var pauseTimer: Timer?

    init(
        miniSet: RestPauseMiniSet,
        isFirstSet: Bool,
        pauseDuration: TimeInterval,
        isPauseTimerActive: Bool,
        isLiveWorkout: Bool = true,
        isPendingWorkout: Bool = false,
        onUpdate: @escaping (RestPauseMiniSet) -> Void
    ) {
        self.miniSet = miniSet
        self.isFirstSet = isFirstSet
        self.pauseDuration = pauseDuration
        self.isPauseTimerActive = isPauseTimerActive
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
        self.onUpdate = onUpdate

        _reps = State(initialValue: isPendingWorkout ? String(miniSet.targetReps) : (miniSet.actualReps.map { String($0) } ?? String(miniSet.targetReps)))
    }

    var body: some View {
        VStack(spacing: 4) {
            if isPauseTimerActive {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.green)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                    Text("Rest \(Int(remainingPauseTime))s...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
                .onAppear {
                    startPauseCountdown()
                }
                .onDisappear {
                    stopPauseCountdown()
                }
            }

            HStack(spacing: 12) {
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

                Text("Target: \(miniSet.targetReps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("reps", text: $reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .onChange(of: reps) { _, newValue in
                        var updatedMiniSet = miniSet
                        if isPendingWorkout {
                            updatedMiniSet.targetReps = Int(newValue) ?? miniSet.targetReps
                        } else {
                            updatedMiniSet.actualReps = Int(newValue)
                            if !isLiveWorkout && updatedMiniSet.completedAt == nil {
                                updatedMiniSet.completedAt = Date()
                            }
                        }
                        onUpdate(updatedMiniSet)
                    }

                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isLiveWorkout && !isPendingWorkout {
                    Button {
                        markComplete()
                    } label: {
                        Image(systemName: miniSet.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(miniSet.isCompleted ? .green : .gray)
                    }
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

    private func startPauseCountdown() {
        remainingPauseTime = pauseDuration
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingPauseTime > 0 {
                remainingPauseTime -= 1
            } else {
                stopPauseCountdown()
            }
        }
    }

    private func stopPauseCountdown() {
        pauseTimer?.invalidate()
        pauseTimer = nil
    }
}

// MARK: - Rest-Pause Config Editor

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
