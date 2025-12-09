import SwiftUI

struct AddHistoricalWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    var onSave: () -> Void

    @State private var workoutName = ""
    @State private var workoutDate = Date()
    @State private var workoutDuration: TimeInterval = 3600 // 1 hour default
    @State private var exercises: [WorkoutExercise] = []
    @State private var notes = ""
    @State private var isDeload = false
    @State private var showingExerciseSelector = false
    @State private var editingExerciseIndex: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $workoutName)

                    DatePicker("Date", selection: $workoutDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("", selection: $workoutDuration) {
                            Text("30 min").tag(TimeInterval(1800))
                            Text("45 min").tag(TimeInterval(2700))
                            Text("1 hour").tag(TimeInterval(3600))
                            Text("1.5 hours").tag(TimeInterval(5400))
                            Text("2 hours").tag(TimeInterval(7200))
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle(isOn: $isDeload) {
                        HStack {
                            Image(systemName: "arrow.down.heart")
                                .foregroundStyle(.green)
                            Text("Deload Workout")
                        }
                    }
                }

                Section {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            editingExerciseIndex = index
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.exercise.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    let completedSets = exercise.sets.filter { $0.actualReps != nil }
                                    if completedSets.isEmpty {
                                        Text("No sets recorded")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(completedSets.map { set in
                                            if let weight = set.weight {
                                                return "\(Int(weight))x\(set.actualReps ?? set.targetReps)"
                                            } else {
                                                return "\(set.actualReps ?? set.targetReps) reps"
                                            }
                                        }.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteExercise)
                    .onMove(perform: moveExercise)

                    Button {
                        showingExerciseSelector = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    if exercises.isEmpty {
                        Text("Add exercises to record your workout")
                    }
                }

                Section("Notes") {
                    TextField("Optional notes about this workout", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .disabled(workoutName.isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingExerciseSelector) {
                ExerciseSelectorView { exercise in
                    let workoutExercise = WorkoutExercise(
                        exercise: exercise,
                        sets: [
                            ExerciseSet(setNumber: 1, targetReps: 10),
                            ExerciseSet(setNumber: 2, targetReps: 10),
                            ExerciseSet(setNumber: 3, targetReps: 10)
                        ],
                        orderIndex: exercises.count
                    )
                    exercises.append(workoutExercise)
                    editingExerciseIndex = exercises.count - 1
                }
            }
            .sheet(item: $editingExerciseIndex) { index in
                EditHistoricalExerciseView(exercise: $exercises[index])
            }
        }
    }

    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        // Update order indices
        for i in 0..<exercises.count {
            exercises[i].orderIndex = i
        }
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
        // Update order indices
        for i in 0..<exercises.count {
            exercises[i].orderIndex = i
        }
    }

    private func saveWorkout() {
        let startTime = workoutDate.addingTimeInterval(-workoutDuration)

        // Mark all sets as completed
        var completedExercises = exercises
        for i in 0..<completedExercises.count {
            for j in 0..<completedExercises[i].sets.count {
                if completedExercises[i].sets[j].actualReps == nil {
                    completedExercises[i].sets[j].actualReps = completedExercises[i].sets[j].targetReps
                }
                completedExercises[i].sets[j].completedAt = workoutDate
            }
        }

        let workout = Workout(
            name: workoutName,
            exercises: completedExercises,
            createdAt: workoutDate,
            startedAt: startTime,
            completedAt: workoutDate,
            notes: notes,
            isDeload: isDeload
        )

        WorkoutDataManager.shared.saveWorkout(workout)
        onSave()
        dismiss()
    }
}

// MARK: - Exercise Selector View

struct ExerciseSelectorView: View {
    @Environment(\.dismiss) var dismiss
    var onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?

    var filteredExercises: [Exercise] {
        var exercises = ExerciseDatabase.shared.exercises

        if let muscleGroup = selectedMuscleGroup {
            exercises = exercises.filter { $0.primaryMuscleGroups.contains(muscleGroup) }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Muscle group filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedMuscleGroup = nil
                        } label: {
                            Text("All")
                                .font(.subheadline)
                                .fontWeight(selectedMuscleGroup == nil ? .semibold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedMuscleGroup == nil ? Color.blue : Color(.systemGray5))
                                .foregroundStyle(selectedMuscleGroup == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }

                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Button {
                                selectedMuscleGroup = group
                            } label: {
                                Text(group.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedMuscleGroup == group ? .semibold : .regular)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedMuscleGroup == group ? Color.blue : Color(.systemGray5))
                                    .foregroundStyle(selectedMuscleGroup == group ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                List(filteredExercises) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            HStack {
                                Text(exercise.equipment.rawValue)
                                Text("•")
                                Text(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Historical Exercise View

struct EditHistoricalExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var exercise: WorkoutExercise

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(exercise.exercise.name)
                            .font(.headline)
                        Spacer()
                        Text(exercise.exercise.equipment.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        HistoricalSetRow(
                            setIndex: index,
                            setNumber: set.setNumber,
                            weight: Binding(
                                get: { exercise.sets[index].weight },
                                set: { exercise.sets[index].weight = $0 }
                            ),
                            reps: Binding(
                                get: { exercise.sets[index].actualReps ?? exercise.sets[index].targetReps },
                                set: { exercise.sets[index].actualReps = $0 }
                            ),
                            onWeightChanged: { changedSetIndex, newWeight in
                                // Propagate weight to all subsequent sets
                                for i in (changedSetIndex + 1)..<exercise.sets.count {
                                    exercise.sets[i].weight = newWeight
                                }
                            },
                            onRepsChanged: { changedSetIndex, newReps in
                                // Propagate reps to all subsequent sets
                                for i in (changedSetIndex + 1)..<exercise.sets.count {
                                    exercise.sets[i].actualReps = newReps
                                }
                            }
                        )
                    }
                    .onDelete(perform: deleteSet)

                    Button {
                        addSet()
                    } label: {
                        Label("Add Set", systemImage: "plus.circle")
                    }
                } header: {
                    HStack {
                        Text("Sets")
                        Spacer()
                        Text("Changes propagate to subsequent sets")
                            .font(.caption2)
                            .textCase(.none)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: Binding(
                        get: { exercise.notes },
                        set: { exercise.notes = $0 }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func deleteSet(at offsets: IndexSet) {
        exercise.sets.remove(atOffsets: offsets)
        // Renumber sets
        for i in 0..<exercise.sets.count {
            exercise.sets[i].setNumber = i + 1
        }
    }

    private func addSet() {
        let newSetNumber = exercise.sets.count + 1
        let lastSet = exercise.sets.last
        let newSet = ExerciseSet(
            setNumber: newSetNumber,
            targetReps: lastSet?.targetReps ?? 10,
            actualReps: lastSet?.actualReps,
            weight: lastSet?.weight
        )
        exercise.sets.append(newSet)
    }
}

struct HistoricalSetRow: View {
    let setIndex: Int  // 0-based index
    let setNumber: Int
    @Binding var weight: Double?
    @Binding var reps: Int
    let onWeightChanged: ((Int, Double?) -> Void)?  // (setIndex, newWeight)
    let onRepsChanged: ((Int, Int) -> Void)?  // (setIndex, newReps)

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    init(
        setIndex: Int,
        setNumber: Int,
        weight: Binding<Double?>,
        reps: Binding<Int>,
        onWeightChanged: ((Int, Double?) -> Void)? = nil,
        onRepsChanged: ((Int, Int) -> Void)? = nil
    ) {
        self.setIndex = setIndex
        self.setNumber = setNumber
        self._weight = weight
        self._reps = reps
        self.onWeightChanged = onWeightChanged
        self.onRepsChanged = onRepsChanged
    }

    var body: some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: weightText) { _, newValue in
                        let newWeight = Double(newValue)
                        weight = newWeight
                        onWeightChanged?(setIndex, newWeight)
                    }
                Text("lbs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("x")
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: repsText) { _, newValue in
                        let newReps = Int(newValue) ?? reps
                        reps = newReps
                        onRepsChanged?(setIndex, newReps)
                    }
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let w = weight {
                weightText = w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
            }
            repsText = "\(reps)"
        }
    }
}

// Extension to make Int? conform to Identifiable for sheet presentation
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
