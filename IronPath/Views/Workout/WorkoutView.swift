import SwiftUI

// MARK: - Workout View

struct WorkoutView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var dependencies: DependencyContainer
    @State private var isGeneratingWorkout = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showWorkoutSetup = false

    /// Computed binding for active workout navigation
    private var activeWorkout: Binding<Workout?> {
        Binding(
            get: { (dependencies.activeWorkoutManager as? ActiveWorkoutManager)?.activeWorkout },
            set: { _ in } // Navigation dismissal handled by onComplete/onCancel
        )
    }

    /// Convenience accessor for the pending workout
    private var generatedWorkout: Workout? {
        get { (dependencies.pendingWorkoutManager as? PendingWorkoutManager)?.pendingWorkout }
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
                            dependencies.pendingWorkoutManager.clearPendingWorkout()
                        },
                        onConvertToNormal: { updatedWorkout in
                            (dependencies.pendingWorkoutManager as? PendingWorkoutManager)?.pendingWorkout = updatedWorkout
                        },
                        onWorkoutUpdated: { updatedWorkout in
                            (dependencies.pendingWorkoutManager as? PendingWorkoutManager)?.pendingWorkout = updatedWorkout
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

                        Text("Let your AI generate a personalized workout based on your profile, goals, and recent training")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            // Auto-generate button - LLM decides workout type
                            Button {
                                autoGenerateWorkout()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Auto Generate")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("auto_generate_workout_button")

                            // Manual selection button - still AI generated but with options
                            Button {
                                showWorkoutSetup = true
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Generate with Options")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityIdentifier("choose_workout_type_button")

                            // Build your own - no AI, empty workout
                            Button {
                                createEmptyWorkout()
                            } label: {
                                HStack {
                                    Image(systemName: "hammer")
                                    Text("Build Your Own")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityIdentifier("build_your_own_button")
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Workout")
            .fullScreenCover(item: activeWorkout) { workout in
                NavigationStack {
                    ActiveWorkoutView(workout: workout, userProfile: appState.userProfile, onComplete: { _ in
                        _ = dependencies.activeWorkoutManager.completeWorkout()
                        dependencies.pendingWorkoutManager.clearPendingWorkout()
                    }, onCancel: {
                        dependencies.activeWorkoutManager.cancelWorkout()
                    })
                }
            }
            .sheet(isPresented: $showWorkoutSetup) {
                WorkoutSetupView(
                    isGenerating: $isGeneratingWorkout,
                    onGenerate: { workoutType, notes, isDeload, options in
                        generateWorkout(workoutType: workoutType, notes: notes, isDeload: isDeload, options: options)
                    }
                )
                .environmentObject(appState)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func startWorkout(_ workout: Workout) {
        dependencies.activeWorkoutManager.startWorkout(workout)
    }

    /// Auto-generate a workout - LLM decides the type based on split and history
    private func autoGenerateWorkout() {
        guard let profile = appState.userProfile else {
            errorMessage = "Please complete onboarding first"
            showError = true
            return
        }

        guard dependencies.aiProviderManager.isConfigured else {
            errorMessage = "Please configure your AI provider in the Profile tab before generating workouts"
            showError = true
            return
        }

        isGeneratingWorkout = true

        // Build context notes based on training style
        let trainingStyle = profile.workoutPreferences.trainingStyle
        let styleNotes = "Training style: \(trainingStyle.rawValue)"

        // Apply global technique settings from profile
        let effectiveOptions = WorkoutGenerationOptions().applying(globalSettings: profile.workoutPreferences.advancedTechniqueSettings)

        let aiProvider = dependencies.aiProviderManager.currentProvider
        let pendingManager = dependencies.pendingWorkoutManager

        Task {
            do {
                // Create agentic builder - no specific workout type, LLM decides
                let builder = AgentWorkoutBuilder(
                    workoutType: nil,
                    targetMuscleGroups: nil,
                    userNotes: styleNotes,
                    techniqueOptions: effectiveOptions,
                    profile: profile
                )

                let workout = try await aiProvider.generateWorkoutAgentic(
                    builder: builder,
                    progressCallback: nil  // Could add progress UI later
                )

                await MainActor.run {
                    (pendingManager as? PendingWorkoutManager)?.pendingWorkout = workout
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

    private func generateWorkout(workoutType: WorkoutType, notes: String, isDeload: Bool = false, options: WorkoutGenerationOptions = WorkoutGenerationOptions()) {
        guard let profile = appState.userProfile else {
            errorMessage = "Please complete onboarding first"
            showError = true
            return
        }

        guard dependencies.aiProviderManager.isConfigured else {
            errorMessage = "Please configure your AI provider in the Profile tab before generating workouts"
            showError = true
            return
        }

        isGeneratingWorkout = true

        let aiProvider = dependencies.aiProviderManager.currentProvider
        let pendingManager = dependencies.pendingWorkoutManager

        Task {
            do {
                // Create agentic builder
                let builder = AgentWorkoutBuilder(
                    workoutType: workoutType.rawValue,
                    targetMuscleGroups: workoutType.targetMuscleGroups,
                    userNotes: notes.isEmpty ? nil : notes,
                    techniqueOptions: options,
                    profile: profile
                )

                var workout = try await aiProvider.generateWorkoutAgentic(
                    builder: builder,
                    progressCallback: nil  // Could add progress UI later
                )
                workout.isDeload = isDeload

                await MainActor.run {
                    (pendingManager as? PendingWorkoutManager)?.pendingWorkout = workout
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

    private func createEmptyWorkout() {
        let workout = Workout(
            name: "Custom Workout",
            exercises: [],
            notes: ""
        )
        (dependencies.pendingWorkoutManager as? PendingWorkoutManager)?.pendingWorkout = workout
    }
}
