import SwiftUI

struct ActiveWorkoutView: View {
    let workout: Workout
    let userProfile: UserProfile?
    let onComplete: (Workout) -> Void
    let onCancel: () -> Void

    @Environment(DependencyContainer.self) private var dependencies
    @State private var viewModel: ActiveWorkoutViewModel
    @State private var editorViewModel: WorkoutEditorViewModel
    @State private var replacementViewModel = ExerciseReplacementViewModel()

    // Add exercise state (UI-only, stays in View)
    @State private var showAddExerciseSheet = false
    @State private var showCreateGroupSheet = false

    /// Convenience accessor for the current workout state
    private var currentWorkout: Workout {
        get { viewModel.workout }
        nonmutating set { viewModel.workout = newValue }
    }

    init(workout: Workout, userProfile: UserProfile?, onComplete: @escaping (Workout) -> Void, onCancel: @escaping () -> Void) {
        self.workout = workout
        self.userProfile = userProfile
        self.onComplete = onComplete
        self.onCancel = onCancel

        // Initialize the active workout ViewModel
        let activeVM = ActiveWorkoutViewModel(workout: workout, userProfile: userProfile)
        activeVM.onComplete = onComplete
        activeVM.onCancel = onCancel
        _viewModel = State(initialValue: activeVM)

        // Initialize the editor ViewModel (for add/remove/replace operations)
        let editorVM = WorkoutEditorViewModel(workout: workout, userProfile: userProfile)
        editorVM.preventRemovingLastExercise = true
        _editorViewModel = State(initialValue: editorVM)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Timer header
                WorkoutTimerHeader(
                    startTime: viewModel.workoutStartTime,
                    completedCount: viewModel.completedExercisesCount,
                    totalCount: viewModel.totalExercisesCount
                )

                // Global rest timer (visible when timer is active)
                // Isolated in its own view to prevent re-renders from affecting exercise list
                RestTimerBarContainer()

                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        DraggableExerciseList(
                            workout: $viewModel.workout,
                            isLiveWorkout: true,
                            exercisePreferenceManager: dependencies.exercisePreferenceManager,
                            onExerciseTap: { exercise in
                                viewModel.selectExercise(exercise)
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
                        .onChange(of: viewModel.workout) { _, _ in
                            viewModel.persistWorkoutState()
                            // Keep editorViewModel in sync
                            editorViewModel.workout = viewModel.workout
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
                    .padding()
                }

                // Finish button
                VStack {
                    Button {
                        viewModel.finishWorkout()
                    } label: {
                        HStack {
                            Image(systemName: viewModel.allExercisesCompleted ? "checkmark.circle.fill" : "flag.checkered")
                            Text(viewModel.allExercisesCompleted ? "Complete Workout" : "Finish Early")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(viewModel.allExercisesCompleted ? .green : .blue)
                    .disabled(viewModel.isFinishing)
                    .accessibilityIdentifier("finish_workout_button")
                }
                .padding()
                .background(Color(.systemBackground))
            }

            // Rest complete banner overlay (isolated to prevent re-renders)
            RestCompleteBannerContainer()
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    viewModel.showCancelConfirmation = true
                }
                .foregroundStyle(.red)
                .confirmationDialog("Cancel Workout?", isPresented: $viewModel.showCancelConfirmation, titleVisibility: .visible) {
                    Button("Cancel Workout", role: .destructive) {
                        viewModel.cancelWorkout()
                    }
                    Button("Keep Going", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to cancel this workout? Your progress will be lost.")
                }
            }
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
            Text("Remove \(exercise.exercise.name) from this workout? Any logged sets will be lost.")
        }
        .sheet(item: $viewModel.selectedExercise) { exercise in
            // Get current version of exercise from workout (in case it was updated)
            let currentExercise = viewModel.getCurrentExercise(exercise)
            let groupInfo = viewModel.getGroupInfo(for: currentExercise)
            let nextExercise = viewModel.getNextExerciseInGroup(for: currentExercise)

            ExerciseDetailSheet(
                exercise: currentExercise,
                onUpdate: { updatedExercise in
                    viewModel.handleExerciseUpdateFromSheet(updatedExercise)
                },
                onUpdateWithoutDismiss: { updatedExercise in
                    // Update without dismissing - used for superset navigation
                    // Also navigate to next exercise in group
                    viewModel.updateExerciseAndNavigateToNext(updatedExercise)
                },
                groupInfo: groupInfo,
                onNavigateToNextInGroup: nil, // Navigation now handled by onUpdateWithoutDismiss
                nextExerciseInGroup: nextExercise
            )
            .id(currentExercise.id) // Force SwiftUI to recreate view when exercise changes
        }
        .sheet(item: $replacementViewModel.exerciseToReplace) { exercise in
            ExerciseReplacementSheet(
                viewModel: replacementViewModel,
                exercise: exercise
            )
        }
        .sheet(isPresented: $showAddExerciseSheet) {
            AddExerciseSheet(
                existingExercises: editorViewModel.existingExerciseNames,
                userProfile: userProfile
            ) { exercise in
                editorViewModel.addExerciseFromLibrary(exercise)
            }
        }
        .sheet(item: $editorViewModel.groupToAddExerciseTo) { group in
            AddExerciseSheet(
                existingExercises: editorViewModel.existingExerciseNames,
                userProfile: userProfile
            ) { exercise in
                editorViewModel.addExerciseToGroup(exercise, group: group)
            }
        }
        .sheet(isPresented: $showCreateGroupSheet) {
            CreateExerciseGroupSheet(
                workout: $editorViewModel.workout,
                onGroupCreated: {
                    viewModel.workout = editorViewModel.workout
                    viewModel.persistWorkoutState()
                }
            )
        }
        .sheet(isPresented: $viewModel.showCompletionSummary, onDismiss: {
            // Reset finishing state when sheet is dismissed
            // This handles edge cases where the sheet might be dismissed unexpectedly
            viewModel.resetFinishingState()
        }) {
            if let completedWorkout = viewModel.completedWorkoutForSummary {
                WorkoutCompletionSummaryView(
                    workout: completedWorkout,
                    userProfile: userProfile,
                    onDismiss: {
                        viewModel.dismissCompletionSummary()
                    }
                )
                .interactiveDismissDisabled()
            } else {
                // Fallback view - should not normally appear
                // If this shows, there's a state synchronization issue
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading summary...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // If workout data isn't ready, dismiss and retry
                    if viewModel.completedWorkoutForSummary == nil {
                        viewModel.showCompletionSummary = false
                        viewModel.resetFinishingState()
                    }
                }
            }
        }
        .onAppear {
            // Sync editorViewModel with viewModel's workout
            editorViewModel.workout = viewModel.workout
            editorViewModel.onWorkoutChanged = { updatedWorkout in
                viewModel.workout = updatedWorkout
                viewModel.persistWorkoutState()
            }

            // Configure replacement ViewModel
            replacementViewModel.configure(
                userProfile: userProfile,
                currentWorkout: viewModel.workout,
                currentWorkoutExercises: viewModel.workout.exercises.map { $0.exercise.name }
            )
            replacementViewModel.onReplacement = { oldExercise, newExercise in
                // Update the workout with the replacement, maintaining group membership
                viewModel.workout.replaceExercise(oldExerciseId: oldExercise.id, with: newExercise)
                viewModel.persistWorkoutState()
            }
        }
        .onChange(of: viewModel.workout) { _, newWorkout in
            // Keep replacement ViewModel context up to date
            replacementViewModel.currentWorkout = newWorkout
            replacementViewModel.currentWorkoutExercises = newWorkout.exercises.map { $0.exercise.name }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

}
