import SwiftUI

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

// MARK: - Success Header

/// Success header with checkmark and workout name
struct SummarySuccessHeader: View {
    let workoutName: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Workout Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text(workoutName)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.top)
    }
}

// MARK: - Stats Grid

/// Grid of workout statistics cards
struct SummaryStatsGrid: View {
    let workout: Workout
    let estimatedCalories: Int?
    let isEstimatingCalories: Bool

    var body: some View {
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
}

// MARK: - AI Summary Section

/// AI-generated workout summary section
struct AISummarySection: View {
    let aiSummary: String?
    let isGeneratingAISummary: Bool

    var body: some View {
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
}

// MARK: - Personal Records Section

/// Section displaying personal records achieved
struct PersonalRecordsSection: View {
    let workoutPRs: [WorkoutPR]
    let weightUnit: WeightUnit

    var body: some View {
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
                PRCard(pr: pr, weightUnit: weightUnit)
            }
        }
    }
}

// MARK: - Apple Health Export Section

/// Apple Health export section with button or success message
struct AppleHealthExportSection: View {
    let exportSuccess: Bool
    let isExportingToHealth: Bool
    let isEstimatingCalories: Bool
    let onExport: () -> Void

    var body: some View {
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
                            onExport()
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
    }
}
