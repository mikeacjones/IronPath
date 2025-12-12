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
                        },
                        onWorkoutUpdated: { updatedWorkout in
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

                        Text("Let Claude generate a personalized workout based on your profile, goals, and recent training")
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

                            // Manual selection button
                            Button {
                                showWorkoutSetup = true
                            } label: {
                                Text("Choose Workout Type")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityIdentifier("choose_workout_type_button")
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Workout")
            .fullScreenCover(item: activeWorkout) { workout in
                NavigationStack {
                    ActiveWorkoutView(workout: workout, userProfile: appState.userProfile, onComplete: { _ in
                        _ = activeWorkoutManager.completeWorkout()
                        pendingWorkoutManager.clearPendingWorkout()
                    }, onCancel: {
                        activeWorkoutManager.cancelWorkout()
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
        activeWorkoutManager.startWorkout(workout)
    }

    /// Auto-generate a workout - LLM decides the type based on split and history
    private func autoGenerateWorkout() {
        guard let profile = appState.userProfile else {
            errorMessage = "Please complete onboarding first"
            showError = true
            return
        }

        guard AIProviderManager.shared.isConfigured else {
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

        Task {
            do {
                let provider = AIProviderManager.shared.currentProvider

                // Create agentic builder - no specific workout type, LLM decides
                let builder = AgentWorkoutBuilder(
                    workoutType: nil,
                    targetMuscleGroups: nil,
                    userNotes: styleNotes,
                    techniqueOptions: effectiveOptions,
                    profile: profile
                )

                let workout = try await provider.generateWorkoutAgentic(
                    builder: builder,
                    progressCallback: nil  // Could add progress UI later
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

    private func generateWorkout(workoutType: WorkoutType, notes: String, isDeload: Bool = false, options: WorkoutGenerationOptions = WorkoutGenerationOptions()) {
        guard let profile = appState.userProfile else {
            errorMessage = "Please complete onboarding first"
            showError = true
            return
        }

        guard AIProviderManager.shared.isConfigured else {
            errorMessage = "Please configure your AI provider in the Profile tab before generating workouts"
            showError = true
            return
        }

        isGeneratingWorkout = true

        Task {
            do {
                let provider = AIProviderManager.shared.currentProvider

                // Create agentic builder
                let builder = AgentWorkoutBuilder(
                    workoutType: workoutType.rawValue,
                    targetMuscleGroups: workoutType.targetMuscleGroups,
                    userNotes: notes.isEmpty ? nil : notes,
                    techniqueOptions: options,
                    profile: profile
                )

                var workout = try await provider.generateWorkoutAgentic(
                    builder: builder,
                    progressCallback: nil  // Could add progress UI later
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
