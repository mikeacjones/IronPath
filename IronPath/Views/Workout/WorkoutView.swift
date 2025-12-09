import SwiftUI

// MARK: - Workout View

struct WorkoutView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var pendingWorkoutManager = PendingWorkoutManager.shared
    @ObservedObject private var activeWorkoutManager = ActiveWorkoutManager.shared
    @State private var isGeneratingWorkout = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showWorkoutSetup = false

    /// Computed binding for active workout navigation
    private var activeWorkout: Binding<Workout?> {
        Binding(
            get: { activeWorkoutManager.activeWorkout },
            set: { _ in } // Navigation dismissal handled by onComplete/onCancel
        )
    }

    /// Convenience accessor for the pending workout
    private var generatedWorkout: Workout? {
        get { pendingWorkoutManager.pendingWorkout }
    }

    /// Determines what workout to do today based on split and recent history
    private var recommendedWorkoutDay: WorkoutSplitDay? {
        guard let profile = appState.userProfile else { return nil }
        let split = profile.workoutPreferences.workoutSplit
        let rotation = split.workoutRotation
        guard !rotation.isEmpty else { return nil }

        let history = WorkoutDataManager.shared.getWorkoutHistory()

        // Find the most recent workout that matches a split day
        if let lastWorkout = history.first {
            // Try to determine what type of workout was last done
            let lastWorkoutDay = determineWorkoutDay(from: lastWorkout, split: split)

            if let lastDay = lastWorkoutDay,
               let lastIndex = rotation.firstIndex(of: lastDay) {
                // Return the next workout in rotation
                let nextIndex = (lastIndex + 1) % rotation.count
                return rotation[nextIndex]
            }
        }

        // No history or couldn't determine, start from beginning
        return rotation.first
    }

    /// Try to determine what split day a workout was based on the exercises
    private func determineWorkoutDay(from workout: Workout, split: WorkoutSplit) -> WorkoutSplitDay? {
        // Get all primary muscle groups from the workout
        var workoutMuscles = Set<MuscleGroup>()
        for exercise in workout.exercises {
            workoutMuscles.formUnion(exercise.exercise.primaryMuscleGroups)
        }

        // Find the best matching split day
        var bestMatch: WorkoutSplitDay?
        var bestScore = 0

        for day in split.workoutRotation {
            let targetMuscles = day.targetMuscleGroups
            let overlap = workoutMuscles.intersection(targetMuscles).count
            if overlap > bestScore {
                bestScore = overlap
                bestMatch = day
            }
        }

        return bestMatch
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isGeneratingWorkout {
                    WorkoutGenerationLoadingView()
                } else if let workout = generatedWorkout {
                    WorkoutDetailView(
                        workout: workout,
                        onStartWorkout: { updatedWorkout in
                            startWorkout(updatedWorkout)
                        },
                        onRegenerate: {
                            pendingWorkoutManager.clearPendingWorkout()
                        },
                        onConvertToNormal: { updatedWorkout in
                            pendingWorkoutManager.pendingWorkout = updatedWorkout
                        }
                    )
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)

                        Text("Ready to workout?")
                            .font(.title)
                            .fontWeight(.bold)

                        if let recommended = recommendedWorkoutDay,
                           let profile = appState.userProfile {
                            VStack(spacing: 8) {
                                Text("Recommended: \(recommended.rawValue)")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                Text("Based on your \(profile.workoutPreferences.workoutSplit.rawValue) split")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Let Claude generate a personalized workout based on your profile and goals")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            // Auto-generate button (uses split recommendation)
                            if let recommended = recommendedWorkoutDay {
                                Button {
                                    autoGenerateWorkout(for: recommended)
                                } label: {
                                    HStack {
                                        Image(systemName: "sparkles")
                                        Text("Auto Generate \(recommended.rawValue)")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }

                            // Manual selection button
                            Button {
                                showWorkoutSetup = true
                            } label: {
                                Text("Choose Workout Type")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(item: activeWorkout) { workout in
                ActiveWorkoutView(workout: workout, userProfile: appState.userProfile, onComplete: { _ in
                    _ = activeWorkoutManager.completeWorkout()
                    pendingWorkoutManager.clearPendingWorkout()
                }, onCancel: {
                    activeWorkoutManager.cancelWorkout()
                })
            }
            .sheet(isPresented: $showWorkoutSetup) {
                WorkoutSetupView(
                    isGenerating: $isGeneratingWorkout,
                    onGenerate: { workoutType, notes, isDeload in
                        generateWorkout(workoutType: workoutType, notes: notes, isDeload: isDeload)
                    }
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func startWorkout(_ workout: Workout) {
        activeWorkoutManager.startWorkout(workout)
    }

    /// Auto-generate a workout based on the recommended split day
    private func autoGenerateWorkout(for splitDay: WorkoutSplitDay) {
        guard let profile = appState.userProfile else {
            errorMessage = "Please complete onboarding first"
            showError = true
            return
        }

        guard APIKeyManager.shared.hasAPIKey else {
            errorMessage = "Please add your Anthropic API key in the Profile tab before generating workouts"
            showError = true
            return
        }

        isGeneratingWorkout = true

        // Build context notes based on training style
        let trainingStyle = profile.workoutPreferences.trainingStyle
        let styleNotes = "Training style: \(trainingStyle.rawValue)"

        Task {
            do {
                let recentWorkouts = Array(WorkoutDataManager.shared.getWorkoutHistory().suffix(10))

                let workout = try await AnthropicService.shared.generateWorkout(
                    profile: profile,
                    targetMuscleGroups: splitDay.targetMuscleGroups,
                    workoutHistory: recentWorkouts,
                    workoutType: splitDay.rawValue,
                    userNotes: styleNotes,
                    allowDeloadRecommendation: true  // Let Claude recommend deload if needed
                )
                await MainActor.run {
                    pendingWorkoutManager.pendingWorkout = workout
                    isGeneratingWorkout = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGeneratingWorkout = false
                }
            }
        }
    }

    private func generateWorkout(workoutType: WorkoutType, notes: String, isDeload: Bool = false) {
        guard let profile = appState.userProfile else {
            errorMessage = "Please complete onboarding first"
            showError = true
            return
        }

        guard APIKeyManager.shared.hasAPIKey else {
            errorMessage = "Please add your Anthropic API key in the Profile tab before generating workouts"
            showError = true
            return
        }

        isGeneratingWorkout = true

        Task {
            do {
                let recentWorkouts = Array(WorkoutDataManager.shared.getWorkoutHistory().suffix(5))

                var workout = try await AnthropicService.shared.generateWorkout(
                    profile: profile,
                    targetMuscleGroups: workoutType.targetMuscleGroups,
                    workoutHistory: recentWorkouts,
                    workoutType: workoutType.rawValue,
                    userNotes: notes.isEmpty ? nil : notes,
                    isDeload: isDeload
                )
                workout.isDeload = isDeload
                await MainActor.run {
                    pendingWorkoutManager.pendingWorkout = workout
                    isGeneratingWorkout = false
                    showWorkoutSetup = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGeneratingWorkout = false
                }
            }
        }
    }
}
