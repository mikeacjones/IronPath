import SwiftUI

struct AddHistoricalWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
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
                AddExerciseSheet(
                    existingExercises: exercises.map { $0.exercise.name },
                    userProfile: appState.userProfile
                ) { exercise in
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
                ExerciseDetailSheet(
                    exercise: exercises[index],
                    onUpdate: { updatedExercise in
                        exercises[index] = updatedExercise
                    },
                    isLiveWorkout: false,
                    showVideosOverride: false,
                    showFormTipsOverride: false
                )
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


// Extension to make Int? conform to Identifiable for sheet presentation
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
