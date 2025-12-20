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
                    // Success header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("Workout Complete!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(workout.name)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Stats cards
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            CompletionStatCard(
                                icon: "clock.fill",
                                value: formatDuration(workout.duration ?? 0),
                                label: "Duration",
                                color: .blue
                            )

                            CompletionStatCard(
                                icon: "scalemass.fill",
                                value: formatVolume(workout.totalVolume),
                                label: "Volume",
                                color: .purple
                            )
                        }

                        HStack(spacing: 16) {
                            CompletionStatCard(
                                icon: "figure.strengthtraining.traditional",
                                value: "\(workout.exercises.count)",
                                label: "Exercises",
                                color: .orange
                            )

                            CompletionStatCard(
                                icon: "flame.fill",
                                value: estimatedCalories.map { "\($0)" } ?? "...",
                                label: "Est. Calories",
                                color: .red,
                                isLoading: isEstimatingCalories
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Deload badge if applicable
                    if workout.isDeload {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.heart.fill")
                            Text("Deload workout - using lighter weights for recovery")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // AI Summary section
                    if dependencies.appSettings.showAIWorkoutSummary {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "text.bubble")
                                    .foregroundStyle(.blue)
                                Text("AI Summary")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            if isGeneratingAISummary {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Generating summary...")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else if let summary = aiSummary {
                                Text(summary)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Personal Records section
                    if !workoutPRs.isEmpty {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                Text("Personal Records!")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            ForEach(workoutPRs) { pr in
                                PRCard(pr: pr, weightUnit: workout.weightUnit)
                            }
                        }
                    }

                    // Apple Health export section
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.horizontal)

                        if HealthKitManager.shared.isHealthKitAvailable {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                    Text("Apple Health")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(.horizontal)

                                if exportSuccess {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Workout saved to Apple Health")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                } else {
                                    Button {
                                        exportToHealth()
                                    } label: {
                                        HStack {
                                            if isExportingToHealth {
                                                ProgressView()
                                                    .tint(.white)
                                            } else {
                                                Image(systemName: "square.and.arrow.up")
                                            }
                                            Text(isExportingToHealth ? "Exporting..." : "Export to Apple Health")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundStyle(.white)
                                        .cornerRadius(12)
                                    }
                                    .disabled(isExportingToHealth || isEstimatingCalories)
                                    .padding(.horizontal)

                                    Text("Saves workout duration and estimated calories burned")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

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
                // Run calorie estimation and AI summary generation concurrently
                async let caloriesTask: () = estimateCalories()
                async let summaryTask: () = generateAISummary()
                _ = await (caloriesTask, summaryTask)
            }
        }
    }

    private func detectPRs() {
        workoutPRs = dependencies.workoutDataManager.detectWorkoutPRs(in: workout)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK", volume / 1000)
        }
        return "\(Int(volume))"
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

// MARK: - Completion Stat Card

/// A card displaying a single statistic in the workout completion summary
struct CompletionStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            if isLoading {
                ProgressView()
                    .frame(height: 28)
            } else {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - PR Card

/// A card displaying a personal record achievement
struct PRCard: View {
    let pr: WorkoutPR
    let weightUnit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pr.type.icon)
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(pr.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(pr.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatValue(pr.newValue, for: pr.type))
                    .font(.headline)
                    .foregroundStyle(.green)

                if let prev = pr.previousValue {
                    Text("was \(formatValue(prev, for: pr.type))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("First time!")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatValue(_ value: Double, for type: WorkoutPR.PRType) -> String {
        let unit = weightUnit.abbreviation
        switch type {
        case .weight:
            return "\(formatWeight(value)) \(unit)"
        case .volume:
            if value >= 1000 {
                return String(format: "%.1fK %@", value / 1000, unit)
            }
            return "\(formatWeight(value)) \(unit)"
        case .reps:
            return "\(Int(value)) reps"
        }
    }
}
