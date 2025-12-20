import SwiftUI
import OSLog

// MARK: - Workout Completion Summary View

/// Displays a summary of the completed workout with stats, PRs, and Apple Health export
struct WorkoutCompletionSummaryView: View {
    let workout: Workout
    let userProfile: UserProfile?
    let onDismiss: () -> Void

    @Environment(DependencyContainer.self) private var dependencies

    @State private var estimatedCalories: Int?
    @State private var isEstimatingCalories = false
    @State private var isExportingToHealth = false
    @State private var exportSuccess = false
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var healthKitAuthorized = false
    @State private var workoutPRs: [WorkoutPR] = []
    @State private var aiSummary: String?
    @State private var isGeneratingAISummary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    SummarySuccessHeader(workoutName: workout.name)

                    SummaryStatsGrid(
                        workout: workout,
                        estimatedCalories: estimatedCalories,
                        isEstimatingCalories: isEstimatingCalories
                    )

                    if workout.isDeload {
                        DeloadBadge()
                    }

                    if dependencies.appSettings.showAIWorkoutSummary {
                        AISummarySection(
                            aiSummary: aiSummary,
                            isGeneratingAISummary: isGeneratingAISummary
                        )
                    }

                    if !workoutPRs.isEmpty {
                        PersonalRecordsSection(
                            workoutPRs: workoutPRs,
                            weightUnit: workout.weightUnit
                        )
                    }

                    AppleHealthExportSection(
                        exportSuccess: exportSuccess,
                        isExportingToHealth: isExportingToHealth,
                        isEstimatingCalories: isEstimatingCalories,
                        onExport: exportToHealth
                    )

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .alert("Export Failed", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportError ?? "Failed to export workout to Apple Health")
            }
            .task {
                detectPRs()
                async let caloriesTask: () = estimateCalories()
                async let summaryTask: () = generateAISummary()
                _ = await (caloriesTask, summaryTask)
            }
        }
    }

    private func detectPRs() {
        workoutPRs = dependencies.workoutDataManager.detectWorkoutPRs(in: workout)
    }

    private func estimateCalories() async {
        isEstimatingCalories = true

        let summary = HealthKitManager.shared.createWorkoutSummaryForCalorieEstimation(
            workout: workout,
            userProfile: userProfile
        )

        let aiProvider = dependencies.aiProviderManager.currentProvider
        let workoutManager = dependencies.workoutDataManager

        do {
            let calories = try await aiProvider.estimateCaloriesBurned(workoutSummary: summary)
            await MainActor.run {
                // Ensure we never show 0 calories
                let finalCalories = max(calories, 50)
                estimatedCalories = finalCalories
                isEstimatingCalories = false

                // Save calories to the workout for history display
                saveCaloriesToWorkout(finalCalories, using: workoutManager)
            }
        } catch {
            // Fallback to a simple estimate based on duration
            let durationMinutes = (workout.duration ?? 0) / 60
            let fallbackCalories = Int(durationMinutes * 5) // ~5 cal/min conservative estimate
            await MainActor.run {
                let finalCalories = max(fallbackCalories, 50)
                estimatedCalories = finalCalories
                isEstimatingCalories = false

                // Save calories to the workout for history display
                saveCaloriesToWorkout(finalCalories, using: workoutManager)
            }
        }
    }

    private func saveCaloriesToWorkout(_ calories: Int, using workoutManager: WorkoutDataManaging) {
        var updatedWorkout = workout
        updatedWorkout.estimatedCalories = calories
        workoutManager.updateWorkout(updatedWorkout)
    }

    private func generateAISummary() async {
        guard dependencies.appSettings.showAIWorkoutSummary else { return }

        await MainActor.run {
            isGeneratingAISummary = true
        }

        let aiProvider = dependencies.aiProviderManager.currentProvider
        let workoutManager = dependencies.workoutDataManager

        do {
            // Get recent workouts for context (excluding current workout)
            let allWorkouts: [Workout] = workoutManager.getWorkoutHistory()
            let completedWorkouts = allWorkouts.filter { (w: Workout) -> Bool in
                w.id != workout.id && w.completedAt != nil
            }
            let sortedWorkouts = completedWorkouts.sorted { (w1: Workout, w2: Workout) -> Bool in
                let date1 = w1.completedAt ?? Date.distantPast
                let date2 = w2.completedAt ?? Date.distantPast
                return date1 > date2
            }
            let recentWorkouts: [Workout] = Array(sortedWorkouts.prefix(3))

            let summary = try await aiProvider.generateWorkoutSummary(
                workout: workout,
                recentWorkouts: recentWorkouts,
                personalRecords: workoutPRs
            )

            await MainActor.run {
                aiSummary = summary
                isGeneratingAISummary = false
            }
        } catch {
            AppLogger.ai.error("Failed to generate AI summary", error: error)
            await MainActor.run {
                isGeneratingAISummary = false
            }
        }
    }

    private func exportToHealth() {
        isExportingToHealth = true

        Task {
            do {
                // Request authorization first
                let authorized = try await HealthKitManager.shared.requestAuthorization()

                guard authorized else {
                    throw HealthKitError.notAuthorized
                }

                // Use estimated calories or fallback
                let calories = Double(estimatedCalories ?? 150)

                try await HealthKitManager.shared.saveWorkout(
                    workout: workout,
                    activeCalories: calories
                )

                await MainActor.run {
                    exportSuccess = true
                    isExportingToHealth = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    showExportError = true
                    isExportingToHealth = false
                }
            }
        }
    }
}
