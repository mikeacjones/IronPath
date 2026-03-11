import SwiftUI

// MARK: - Workout Detail View

struct WorkoutDetailView: View {
    @Environment(AppState.self) var appState
    @Environment(DependencyContainer.self) private var dependencies
    @State private var editorViewModel: WorkoutEditorViewModel
    @State private var replacementViewModel = ExerciseReplacementViewModel()

    let onStartWorkout: (Workout) -> Void
    let onRegenerate: () -> Void
    let onConvertToNormal: ((Workout) -> Void)?
    let onWorkoutUpdated: ((Workout) -> Void)?

    // Editing state
    @State private var selectedExercise: WorkoutExercise?

    // Add exercise state
    @State private var showAddExerciseSheet = false

    // Superset/circuit creation state
    @State private var showCreateGroupSheet = false

    init(workout: Workout, onStartWorkout: @escaping () -> Void, onRegenerate: @escaping () -> Void) {
        _editorViewModel = State(initialValue: WorkoutEditorViewModel(workout: workout))
        self.onStartWorkout = { _ in onStartWorkout() }
        self.onRegenerate = onRegenerate
        self.onConvertToNormal = nil
        self.onWorkoutUpdated = nil
    }

    init(workout: Workout, onStartWorkout: @escaping (Workout) -> Void, onRegenerate: @escaping () -> Void, onConvertToNormal: ((Workout) -> Void)? = nil, onWorkoutUpdated: ((Workout) -> Void)? = nil) {
        _editorViewModel = State(initialValue: WorkoutEditorViewModel(workout: workout))
        self.onStartWorkout = onStartWorkout
        self.onRegenerate = onRegenerate
        self.onConvertToNormal = onConvertToNormal
        self.onWorkoutUpdated = onWorkoutUpdated
    }

    /// Convenience accessor for the workout
    private var workout: Workout {
        get { editorViewModel.workout }
        nonmutating set { editorViewModel.workout = newValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Deload banner with option to switch to normal
                if workout.isDeload {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down.heart.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Deload Workout")
                                    .font(.headline)
                                Text("Using lighter weights for recovery. This won't affect your progressive overload tracking.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                        }

                        Button {
                            convertToNormalWorkout()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.circle")
                                Text("Switch to Normal Weights")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Text(workout.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                // Exercise list with drag-to-reorder
                VStack(spacing: 12) {
                    DraggableExerciseList(
                        workout: $editorViewModel.workout,
                        isLiveWorkout: false,
                        exercisePreferenceManager: dependencies.exercisePreferenceManager,
                        onExerciseTap: { exercise in
                            selectedExercise = exercise
                        },
                        onExerciseReplace: { exercise in
                            replacementViewModel.initiateReplacement(for: exercise)
                        },
                        onExerciseRemove: { exercise in
                            editorViewModel.initiateRemoval(for: exercise)
                        },
                        onSetPreference: { exercise, preference in
                            dependencies.exercisePreferenceManager.setPreference(
                                preference,
                                for: exercise.exercise.name
                            )
                        },
                        onAddExerciseToGroup: { group in
                            editorViewModel.groupToAddExerciseTo = group
                        }
                    )
                    .onChange(of: editorViewModel.workout) { _, newWorkout in
                        onWorkoutUpdated?(newWorkout)
                    }

                    // Add Exercise button
                    Button {
                        showAddExerciseSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Add Exercise")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundStyle(.blue)
                        .cornerRadius(12)
                    }

                    // Create Superset button (only show if there are 2+ ungrouped exercises)
                    if editorViewModel.ungroupedExercises.count >= 2 {
                        Button {
                            showCreateGroupSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title2)
                                Text("Create Superset")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundStyle(.purple)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Button {
                        onStartWorkout(workout)
                    } label: {
                        Text("Start Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        onRegenerate()
                    } label: {
                        Text("Discard Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
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
        .sheet(isPresented: $showAddExerciseSheet) {
            AddExerciseSheet(
                existingExercises: editorViewModel.existingExerciseNames,
                userProfile: appState.userProfile
            ) { exercise in
                editorViewModel.addExerciseFromLibrary(exercise)
            }
        }
        .sheet(item: $replacementViewModel.exerciseToReplace) { exercise in
            ExerciseReplacementSheet(
                viewModel: replacementViewModel,
                exercise: exercise
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
        .sheet(isPresented: $showCreateGroupSheet) {
            CreateExerciseGroupSheet(
                workout: $editorViewModel.workout,
                onGroupCreated: {
                    onWorkoutUpdated?(editorViewModel.workout)
                }
            )
        }
        .sheet(item: $editorViewModel.groupToAddExerciseTo) { group in
            AddExerciseSheet(
                existingExercises: editorViewModel.existingExerciseNames,
                userProfile: appState.userProfile
            ) { exercise in
                editorViewModel.addExerciseToGroup(exercise, group: group)
            }
        }
        .onAppear {
            // Configure the ViewModel with user profile and callbacks
            editorViewModel.updateUserProfile(appState.userProfile)
            editorViewModel.onWorkoutChanged = { workout in
                onWorkoutUpdated?(workout)
            }

            // Configure replacement ViewModel
            replacementViewModel.configure(
                userProfile: appState.userProfile,
                currentWorkout: editorViewModel.workout,
                currentWorkoutExercises: editorViewModel.existingExerciseNames
            )
            replacementViewModel.onReplacement = { oldExercise, newExercise in
                // Update the workout with the replacement, maintaining group membership
                editorViewModel.workout.replaceExercise(oldExerciseId: oldExercise.id, with: newExercise)
                onWorkoutUpdated?(editorViewModel.workout)
            }
        }
        .onChange(of: editorViewModel.workout) { _, newWorkout in
            // Keep replacement ViewModel context up to date
            replacementViewModel.currentWorkout = newWorkout
            replacementViewModel.currentWorkoutExercises = newWorkout.exercises.map { $0.exercise.name }
        }
    }

    // MARK: - Deload Conversion

    private func convertToNormalWorkout() {
        var updatedWorkout = editorViewModel.workout
        updatedWorkout.isDeload = false

        // Update workout name if it contains deload
        if updatedWorkout.name.lowercased().contains("deload") {
            updatedWorkout.name = updatedWorkout.name
                .replacingOccurrences(of: "Deload - ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Deload ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " Deload", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "DELOAD - ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "DELOAD ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " DELOAD", with: "", options: .caseInsensitive)
        }

        // Recalculate weights using progressive overload
        for i in 0..<updatedWorkout.exercises.count {
            let exerciseName = updatedWorkout.exercises[i].exercise.name
            let equipment = updatedWorkout.exercises[i].exercise.equipment

            if let suggestedWeight = dependencies.workoutDataManager.getSuggestedWeight(
                for: exerciseName,
                targetReps: updatedWorkout.exercises[i].sets.first?.targetReps ?? 10,
                equipment: equipment
            ) {
                // Update all sets with the progressive overload weight
                for j in 0..<updatedWorkout.exercises[i].sets.count {
                    updatedWorkout.exercises[i].sets[j].weight = suggestedWeight
                }
            } else if let currentWeight = updatedWorkout.exercises[i].sets.first?.weight {
                // No history, estimate normal weight as ~1.5x the deload weight
                let estimatedNormalWeight = currentWeight * 1.5
                let roundedWeight = dependencies.gymSettings.roundToValidWeight(estimatedNormalWeight, for: equipment, exerciseName: exerciseName)
                for j in 0..<updatedWorkout.exercises[i].sets.count {
                    updatedWorkout.exercises[i].sets[j].weight = roundedWeight
                }
            }
        }

        editorViewModel.workout = updatedWorkout
        onConvertToNormal?(updatedWorkout)
    }
}
