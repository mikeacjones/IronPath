import SwiftUI

// MARK: - Workout Detail View

struct WorkoutDetailView: View {
    @State var workout: Workout
    @EnvironmentObject var appState: AppState
    @ObservedObject private var preferenceManager = ExercisePreferenceManager.shared

    let onStartWorkout: (Workout) -> Void
    let onRegenerate: () -> Void
    let onConvertToNormal: ((Workout) -> Void)?
    let onWorkoutUpdated: ((Workout) -> Void)?

    // Editing state
    @State private var selectedExercise: WorkoutExercise?

    // Add exercise state
    @State private var showAddExerciseSheet = false

    // Remove exercise state
    @State private var exerciseToRemove: WorkoutExercise?
    @State private var showRemoveConfirmation = false

    // Replace exercise state
    @State private var exerciseToReplace: WorkoutExercise?
    @State private var replacementNotes: String = ""
    @State private var isReplacingExercise = false
    @State private var replacementError: String?
    @State private var showReplacementError = false

    // Superset/circuit creation state
    @State private var showCreateGroupSheet = false
    @State private var groupToAddExerciseTo: ExerciseGroup?

    init(workout: Workout, onStartWorkout: @escaping () -> Void, onRegenerate: @escaping () -> Void) {
        self._workout = State(initialValue: workout)
        self.onStartWorkout = { _ in onStartWorkout() }
        self.onRegenerate = onRegenerate
        self.onConvertToNormal = nil
        self.onWorkoutUpdated = nil
    }

    init(workout: Workout, onStartWorkout: @escaping (Workout) -> Void, onRegenerate: @escaping () -> Void, onConvertToNormal: ((Workout) -> Void)? = nil, onWorkoutUpdated: ((Workout) -> Void)? = nil) {
        self._workout = State(initialValue: workout)
        self.onStartWorkout = onStartWorkout
        self.onRegenerate = onRegenerate
        self.onConvertToNormal = onConvertToNormal
        self.onWorkoutUpdated = onWorkoutUpdated
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

                Text("Tap an exercise to edit. Long press to drag and reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Exercise list with drag-to-reorder
                VStack(spacing: 12) {
                    DraggableExerciseList(
                        workout: $workout,
                        isLiveWorkout: false,
                        preferenceManager: preferenceManager,
                        onExerciseTap: { exercise in
                            selectedExercise = exercise
                        },
                        onExerciseReplace: { exercise in
                            replacementNotes = ""
                            exerciseToReplace = exercise
                        },
                        onExerciseRemove: { exercise in
                            exerciseToRemove = exercise
                            showRemoveConfirmation = true
                        },
                        onSetPreference: { exercise, preference in
                            preferenceManager.setPreference(
                                preference,
                                for: exercise.exercise.name
                            )
                        },
                        onAddExerciseToGroup: { group in
                            groupToAddExerciseTo = group
                        }
                    )
                    .onChange(of: workout) { _, newWorkout in
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
                    if ungroupedExercises.count >= 2 {
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
            let currentExercise = workout.exercises.first { $0.id == exercise.id } ?? exercise

            ExerciseDetailSheet(
                exercise: currentExercise,
                onUpdate: { updatedExercise in
                    updateExercise(updatedExercise)
                },
                isLiveWorkout: false,
                isPendingWorkout: true,
                showVideosOverride: false,
                showFormTipsOverride: false
            )
        }
        .sheet(isPresented: $showAddExerciseSheet) {
            AddExerciseSheet(
                existingExercises: workout.exercises.map { $0.exercise.name },
                userProfile: appState.userProfile
            ) { exercise in
                addExerciseFromLibrary(exercise)
            }
        }
        .sheet(item: $exerciseToReplace) { exercise in
            ExerciseReplacementSheet(
                exercise: exercise,
                currentWorkoutExercises: workout.exercises.map { $0.exercise.name },
                notes: $replacementNotes,
                isLoading: $isReplacingExercise,
                onReplace: {
                    replaceExercise()
                },
                onQuickReplace: { newExercise in
                    quickReplaceExercise(with: newExercise)
                },
                onCancel: {
                    exerciseToReplace = nil
                }
            )
        }
        .alert(
            "Remove Exercise?",
            isPresented: $showRemoveConfirmation,
            presenting: exerciseToRemove
        ) { exercise in
            Button("Remove", role: .destructive) {
                removeExercise(exercise)
            }
            Button("Cancel", role: .cancel) {
                exerciseToRemove = nil
            }
        } message: { exercise in
            Text("Remove \(exercise.exercise.name) from this workout?")
        }
        .alert("Replacement Error", isPresented: $showReplacementError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(replacementError ?? "Failed to replace exercise")
        }
        .sheet(isPresented: $showCreateGroupSheet) {
            CreateExerciseGroupSheet(
                workout: $workout,
                onGroupCreated: {
                    onWorkoutUpdated?(workout)
                }
            )
        }
        .sheet(item: $groupToAddExerciseTo) { group in
            AddExerciseSheet(
                existingExercises: workout.exercises.map { $0.exercise.name },
                userProfile: appState.userProfile
            ) { exercise in
                addExerciseToGroup(exercise, group: group)
            }
        }
    }

    // MARK: - Computed Properties

    /// Exercises that are not part of any group
    private var ungroupedExercises: [WorkoutExercise] {
        workout.exercises.filter { exercise in
            !workout.isGrouped(exercise.id)
        }
    }

    // MARK: - Exercise Management

    private func addExerciseFromLibrary(_ exercise: Exercise) {
        let sets = (1...3).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                targetReps: 10,
                restPeriod: 90
            )
        }

        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: sets,
            orderIndex: workout.exercises.count,
            notes: ""
        )

        workout.exercises.append(workoutExercise)
        onWorkoutUpdated?(workout)
    }

    private func addExerciseToGroup(_ exercise: Exercise, group: ExerciseGroup) {
        // Create the workout exercise
        let sets = (1...3).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                targetReps: 10,
                restPeriod: 90
            )
        }

        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: sets,
            orderIndex: workout.exercises.count,
            notes: ""
        )

        // Add to workout
        workout.exercises.append(workoutExercise)

        // Add to the group
        if var groups = workout.exerciseGroups,
           let groupIndex = groups.firstIndex(where: { $0.id == group.id }) {
            groups[groupIndex].exerciseIds.append(workoutExercise.id)
            groups[groupIndex].groupType = ExerciseGroupType.suggestedType(for: groups[groupIndex].exerciseIds.count)
            workout.exerciseGroups = groups
        }

        // Rebuild exercise order to keep grouped exercises together
        workout.rebuildExercisesOrder()
        onWorkoutUpdated?(workout)
    }

    private func removeExercise(_ exercise: WorkoutExercise) {
        // Remove exercise from any group it belongs to
        if var groups = workout.exerciseGroups {
            for i in groups.indices {
                if groups[i].exerciseIds.contains(exercise.id) {
                    // Remove the exercise from this group
                    groups[i].exerciseIds.removeAll { $0 == exercise.id }
                }
            }

            // Remove any groups that now have only 1 or 0 exercises
            // (a group with 1 exercise is no longer a valid superset/circuit)
            groups.removeAll { $0.exerciseIds.count <= 1 }

            // Update group types based on new exercise counts
            for i in groups.indices {
                groups[i].groupType = ExerciseGroupType.suggestedType(for: groups[i].exerciseIds.count)
            }

            workout.exerciseGroups = groups.isEmpty ? nil : groups
        }

        workout.exercises.removeAll { $0.id == exercise.id }

        // Reindex remaining exercises
        for i in workout.exercises.indices {
            workout.exercises[i].orderIndex = i
        }

        exerciseToRemove = nil
        onWorkoutUpdated?(workout)
    }

    private func updateExercise(_ updatedExercise: WorkoutExercise) {
        if let index = workout.exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            workout.exercises[index] = updatedExercise
        }
        selectedExercise = nil
        onWorkoutUpdated?(workout)
    }

    private func replaceExercise() {
        guard let exerciseToReplace = exerciseToReplace,
              let profile = appState.userProfile else { return }

        isReplacingExercise = true

        Task {
            do {
                let provider = AIProviderManager.shared.currentProvider
                let replacement = try await provider.replaceExercise(
                    exercise: exerciseToReplace,
                    profile: profile,
                    reason: replacementNotes.isEmpty ? nil : replacementNotes,
                    currentWorkout: workout
                )

                await MainActor.run {
                    if let index = workout.exercises.firstIndex(where: { $0.id == exerciseToReplace.id }) {
                        workout.exercises[index] = replacement
                    }
                    onWorkoutUpdated?(workout)
                    isReplacingExercise = false
                    self.exerciseToReplace = nil
                }
            } catch {
                await MainActor.run {
                    replacementError = error.localizedDescription
                    showReplacementError = true
                    isReplacingExercise = false
                }
            }
        }
    }

    private func quickReplaceExercise(with newExercise: Exercise) {
        guard let exerciseToReplace = exerciseToReplace else { return }

        // Create a new WorkoutExercise with the same sets structure but new exercise
        let newSets = exerciseToReplace.sets.map { oldSet in
            ExerciseSet(
                setNumber: oldSet.setNumber,
                targetReps: oldSet.targetReps,
                weight: oldSet.weight,
                restPeriod: oldSet.restPeriod
            )
        }

        let replacement = WorkoutExercise(
            exercise: newExercise,
            sets: newSets,
            orderIndex: exerciseToReplace.orderIndex,
            notes: ""
        )

        if let index = workout.exercises.firstIndex(where: { $0.id == exerciseToReplace.id }) {
            workout.exercises[index] = replacement
        }
        onWorkoutUpdated?(workout)

        self.exerciseToReplace = nil
    }

    private func convertToNormalWorkout() {
        var updatedWorkout = workout
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

            if let suggestedWeight = WorkoutDataManager.shared.getSuggestedWeight(
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
                let roundedWeight = GymSettings.shared.roundToValidWeight(estimatedNormalWeight, for: equipment)
                for j in 0..<updatedWorkout.exercises[i].sets.count {
                    updatedWorkout.exercises[i].sets[j].weight = roundedWeight
                }
            }
        }

        workout = updatedWorkout
        onConvertToNormal?(updatedWorkout)
    }
}
