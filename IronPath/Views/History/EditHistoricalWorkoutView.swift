import SwiftUI

struct EditHistoricalWorkoutView: View {
    let originalWorkout: Workout
    var onSave: (Workout) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState
    @Environment(DependencyContainer.self) private var dependencies

    @State private var workoutName: String
    @State private var workoutDate: Date
    @State private var workoutDuration: TimeInterval
    @State private var editorViewModel: WorkoutEditorViewModel
    @State private var notes: String
    @State private var isDeload: Bool
    @State private var showingExerciseSelector = false
    @State private var selectedExercise: WorkoutExercise?

    init(workout: Workout, onSave: @escaping (Workout) -> Void) {
        self.originalWorkout = workout
        self.onSave = onSave

        _workoutName = State(initialValue: workout.name)
        _workoutDate = State(initialValue: workout.completedAt ?? Date())
        _workoutDuration = State(initialValue: workout.duration ?? 3600)
        _editorViewModel = State(initialValue: WorkoutEditorViewModel(workout: workout))
        _notes = State(initialValue: workout.notes)
        _isDeload = State(initialValue: workout.isDeload)
    }

    private var exercises: [WorkoutExercise] {
        editorViewModel.workout.exercises
    }

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
                    DraggableExerciseList(
                        workout: $editorViewModel.workout,
                        isLiveWorkout: false,
                        exercisePreferenceManager: dependencies.exercisePreferenceManager,
                        onExerciseTap: { exercise in
                            selectedExercise = exercise
                        },
                        onExerciseReplace: { _ in },
                        onExerciseRemove: { exercise in
                            editorViewModel.initiateRemoval(for: exercise)
                        },
                        onSetPreference: { _, _ in },
                        onAddExerciseToGroup: { _ in }
                    )

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
            .navigationTitle("Edit Workout")
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
                    existingExercises: editorViewModel.existingExerciseNames,
                    userProfile: appState.userProfile
                ) { exercise in
                    editorViewModel.addExerciseFromLibrary(exercise)
                    // Automatically open the newly added exercise for editing
                    if let lastExercise = editorViewModel.workout.exercises.last {
                        selectedExercise = lastExercise
                    }
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                // Get current version of exercise from workout (in case it was updated)
                let currentExercise = editorViewModel.workout.exercises.first { $0.id == exercise.id } ?? exercise

                ExerciseDetailSheet(
                    exercise: currentExercise,
                    onUpdate: { updatedExercise in
                        editorViewModel.updateExercise(updatedExercise)
                        selectedExercise = nil
                    },
                    workoutWeightUnit: editorViewModel.workout.weightUnit,
                    isLiveWorkout: false,
                    isPendingWorkout: true,
                    showVideosOverride: false,
                    showFormTipsOverride: false
                )
            }
            .alert(
                "Remove Exercise?",
                isPresented: $editorViewModel.showRemoveConfirmation,
                presenting: editorViewModel.exerciseToRemove
            ) { exercise in
                Button("Remove", role: .destructive) {
                    editorViewModel.removeExercise(exercise)
                }
                Button("Cancel", role: .cancel) {
                    editorViewModel.cancelRemoval()
                }
            } message: { exercise in
                Text("Remove \(exercise.exercise.name) from this workout?")
            }
        }
    }

    private func saveWorkout() {
        let startTime = workoutDate.addingTimeInterval(-workoutDuration)

        // Mark all sets as completed if they have actual reps
        var completedExercises = editorViewModel.workout.exercises
        for i in 0..<completedExercises.count {
            for j in 0..<completedExercises[i].sets.count {
                completedExercises[i].sets[j].completeForHistoricalEntry(at: workoutDate)
            }
        }

        // Create updated workout preserving the original ID and weight unit
        let updatedWorkout = Workout(
            id: originalWorkout.id,
            name: workoutName,
            exercises: completedExercises,
            createdAt: originalWorkout.createdAt,
            startedAt: startTime,
            completedAt: workoutDate,
            notes: notes,
            isDeload: isDeload,
            weightUnit: originalWorkout.weightUnit // Preserve original unit
        )

        onSave(updatedWorkout)
        dismiss()
    }
}

#Preview {
    EditHistoricalWorkoutView(
        workout: Workout(
            name: "Test Workout",
            exercises: [],
            createdAt: Date(),
            startedAt: Date(),
            completedAt: Date(),
            notes: "",
            isDeload: false
        ),
        onSave: { _ in }
    )
    .environment(AppState())
}
