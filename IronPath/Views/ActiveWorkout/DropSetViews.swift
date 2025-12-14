import SwiftUI

// MARK: - Drop Set Row

struct DropSetRow: View {
    let set: ExerciseSet
    let setIndex: Int
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let suppressRestTimer: Bool
    let isLastSet: Bool
    let onSetCompleted: (() -> Void)?
    let isLiveWorkout: Bool
    let isPendingWorkout: Bool

    @State private var localConfig: DropSetConfig
    @State private var showEditSheet = false
    @State private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment,
        onUpdate: @escaping (ExerciseSet) -> Void,
        suppressRestTimer: Bool = false,
        isLastSet: Bool = false,
        onSetCompleted: (() -> Void)? = nil,
        isLiveWorkout: Bool = true,
        isPendingWorkout: Bool = false
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.suppressRestTimer = suppressRestTimer
        self.isLastSet = isLastSet
        self.onSetCompleted = onSetCompleted
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
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

            ForEach(localConfig.drops.indices, id: \.self) { index in
                DropEntryRow(
                    drop: localConfig.drops[index],
                    isFirstDrop: index == 0,
                    isLiveWorkout: isLiveWorkout,
                    isPendingWorkout: isPendingWorkout,
                    onUpdate: { updatedDrop in
                        localConfig.drops[index] = updatedDrop
                        saveConfig()

                        if updatedDrop.isCompleted && index == localConfig.drops.count - 1 {
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
    let isLiveWorkout: Bool
    let isPendingWorkout: Bool
    let onUpdate: (DropSetEntry) -> Void

    @State private var weight: String
    @State private var reps: String

    init(drop: DropSetEntry, isFirstDrop: Bool, isLiveWorkout: Bool = true, isPendingWorkout: Bool = false, onUpdate: @escaping (DropSetEntry) -> Void) {
        self.drop = drop
        self.isFirstDrop = isFirstDrop
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
        self.onUpdate = onUpdate

        _weight = State(initialValue: (drop.actualWeight ?? drop.targetWeight).map { formatWeight($0) } ?? "")
        _reps = State(initialValue: isPendingWorkout ? String(drop.targetReps) : (drop.actualReps.map { String($0) } ?? String(drop.targetReps)))
    }

    var body: some View {
        HStack(spacing: 12) {
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

            TextField("lbs", text: $weight)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .onChange(of: weight) { _, newValue in
                    var updatedDrop = drop
                    updatedDrop.actualWeight = Double(newValue)
                    if !isLiveWorkout && updatedDrop.completedAt == nil {
                        updatedDrop.completedAt = Date()
                    }
                    onUpdate(updatedDrop)
                }

            Text("×")
                .foregroundStyle(.secondary)

            TextField("reps", text: $reps)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .onChange(of: reps) { _, newValue in
                    var updatedDrop = drop
                    if isPendingWorkout {
                        updatedDrop.targetReps = Int(newValue) ?? drop.targetReps
                    } else {
                        updatedDrop.actualReps = Int(newValue)
                        if !isLiveWorkout && updatedDrop.completedAt == nil {
                            updatedDrop.completedAt = Date()
                        }
                    }
                    onUpdate(updatedDrop)
                }

            Spacer()

            if isLiveWorkout && !isPendingWorkout {
                Button {
                    markComplete()
                } label: {
                    Image(systemName: drop.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(drop.isCompleted ? .green : .gray)
                }
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

// MARK: - Drop Set Config Editor

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
