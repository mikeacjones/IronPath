import SwiftUI

struct AddHistoricalWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState
    @Environment(DependencyContainer.self) private var dependencies
    var onSave: () -> Void

    @State private var workoutName = ""
    @State private var workoutDate = Date()
    @State private var workoutDuration: TimeInterval = 3600 // 1 hour default
    @State private var editorViewModel: WorkoutEditorViewModel
    @State private var notes = ""
    @State private var isDeload = false
    @State private var showingExerciseSelector = false
    @State private var selectedExercise: WorkoutExercise?

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
        // Initialize with empty workout
        let emptyWorkout = Workout(
            name: "",
            exercises: [],
            createdAt: Date(),
            startedAt: Date(),
            completedAt: Date(),
            notes: "",
            isDeload: false
        )
        _editorViewModel = State(initialValue: WorkoutEditorViewModel(workout: emptyWorkout))
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

        // Mark all sets as completed
        var completedExercises = editorViewModel.workout.exercises
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
            isDeload: isDeload,
            weightUnit: GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds
        )

        WorkoutDataManager.shared.saveWorkout(workout)
        onSave()
        dismiss()
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
