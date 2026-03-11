import SwiftUI

// MARK: - Workout History Detail View

struct WorkoutHistoryDetailView: View {
    @State private var viewModel: HistoryDetailViewModel
    @Environment(\.dismiss) var dismiss

    init(workout: Workout, onDelete: (() -> Void)? = nil, onUpdate: ((Workout) -> Void)? = nil) {
        _viewModel = State(initialValue: HistoryDetailViewModel(
            workout: workout,
            onDelete: onDelete,
            onUpdate: onUpdate
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Deload banner if applicable
                if viewModel.workout.isDeload {
                    DeloadBanner()
                }

                // Workout summary header
                WorkoutSummaryHeader(workout: viewModel.workout, unit: viewModel.workout.weightUnit)

                // Exercises
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises")
                        .font(.headline)

                    ForEach(viewModel.workout.exercises) { exercise in
                        WorkoutHistoryExerciseCard(exercise: exercise, unit: viewModel.workout.weightUnit)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.workout.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.requestEdit()
                } label: {
                    Text("Edit")
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    viewModel.requestDelete()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingEditSheet) {
            EditHistoricalWorkoutView(workout: viewModel.workout) { updatedWorkout in
                viewModel.updateWorkout(updatedWorkout)
            }
        }
        .alert("Delete Workout?", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteWorkout()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(viewModel.workout.name)\"? This action cannot be undone.")
        }
    }
}

// MARK: - Deload Banner

private struct DeloadBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.heart.fill")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Deload Workout")
                    .font(.headline)
                Text("This workout used lighter weights for recovery and won't affect progressive overload tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.15))
        .foregroundStyle(.green)
        .cornerRadius(12)
    }
}

// MARK: - Workout Summary Header

private struct WorkoutSummaryHeader: View {
    let workout: Workout
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let completedAt = workout.completedAt {
                Text(completedAt.formatted(date: .complete, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                HistoryStatBadge(
                    icon: "figure.strengthtraining.traditional",
                    value: "\(workout.exercises.count)",
                    label: "Exercises"
                )

                if let duration = workout.duration {
                    HistoryStatBadge(
                        icon: "clock",
                        value: "\(Int(duration / 60))",
                        label: "Minutes"
                    )
                }

                HistoryStatBadge(
                    icon: "scalemass",
                    value: formatVolume(workout.totalVolume, unit: unit),
                    label: "Volume"
                )

                if let calories = workout.estimatedCalories {
                    HistoryStatBadge(
                        icon: "flame",
                        value: "\(calories)",
                        label: "Calories"
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatVolume(_ volume: Double, unit: WeightUnit) -> String {
        let unitAbbr = unit.abbreviation
        if volume >= 1000000 {
            return String(format: "%.1fM %@", volume / 1000000, unitAbbr)
        } else if volume >= 1000 {
            return String(format: "%.0fK %@", volume / 1000, unitAbbr)
        }
        return String(format: "%.0f %@", volume, unitAbbr)
    }
}

// MARK: - Workout History Exercise Card

struct WorkoutHistoryExerciseCard: View {
    let exercise: WorkoutExercise
    let unit: WeightUnit

    private var completedSets: [ExerciseSet] {
        exercise.sets.filter { $0.completedAt != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exercise.name)
                        .font(.headline)
                    Text(exercise.exercise.equipment.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Completion status
                Text("\(completedSets.count)/\(exercise.sets.count)")
                    .font(.subheadline)
                    .foregroundStyle(completedSets.count == exercise.sets.count ? .green : .orange)
            }

            // Sets table
            SetsTableView(sets: exercise.sets, unit: unit)

            // Notes if any
            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Sets Table View

private struct SetsTableView: View {
    let sets: [ExerciseSet]
    let unit: WeightUnit

    /// Check if any sets are timed to determine header style
    private var isTimedExercise: Bool {
        sets.first?.setType == .timed
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - different for timed vs standard exercises
            if isTimedExercise {
                HStack {
                    Text("Set")
                        .frame(width: 40, alignment: .leading)
                    Text("Target")
                        .frame(width: 60, alignment: .center)
                    Text("Actual")
                        .frame(width: 60, alignment: .center)
                    Text("Weight")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            } else {
                HStack {
                    Text("Set")
                        .frame(width: 40, alignment: .leading)
                    Text("Target")
                        .frame(width: 60, alignment: .center)
                    Text("Actual")
                        .frame(width: 60, alignment: .center)
                    Text("Weight")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            }

            Divider()

            // Sets
            ForEach(sets) { set in
                HistorySetRow(set: set, unit: unit)

                if set.id != sets.last?.id {
                    Divider()
                }
            }
        }
    }
}

// MARK: - History Set Row (for history table)

private struct HistorySetRow: View {
    let set: ExerciseSet
    let unit: WeightUnit

    var body: some View {
        // Handle timed sets differently
        if set.setType == .timed {
            timedSetRow
        } else {
            standardSetRow
        }
    }

    /// Row display for timed sets (duration-based)
    private var timedSetRow: some View {
        HStack {
            Text("\(set.setNumber)")
                .frame(width: 40, alignment: .leading)
                .foregroundStyle(set.completedAt != nil ? .primary : .secondary)

            // Target duration
            if let config = set.timedSetConfig {
                Text(formatDuration(config.targetDuration))
                    .frame(width: 60, alignment: .center)
                    .foregroundStyle(.secondary)

                // Actual duration
                if let actualDuration = config.actualDuration {
                    Text(formatDuration(actualDuration))
                        .frame(width: 60, alignment: .center)
                        .foregroundStyle(actualDuration >= config.targetDuration ? .green : .orange)
                } else {
                    Text("-")
                        .frame(width: 60, alignment: .center)
                        .foregroundStyle(.secondary)
                }

                // Added weight (for weighted timed exercises like weighted planks)
                if let addedWeight = config.addedWeight, addedWeight > 0 {
                    Text(WeightConverter.format(addedWeight, unit: unit))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fontWeight(.medium)
                } else {
                    Text("-")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Fallback if timedSetConfig is missing
                Text("-")
                    .frame(width: 60, alignment: .center)
                    .foregroundStyle(.secondary)
                Text("-")
                    .frame(width: 60, alignment: .center)
                    .foregroundStyle(.secondary)
                Text("-")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 8)
    }

    /// Row display for standard sets (rep-based)
    private var standardSetRow: some View {
        HStack {
            Text("\(set.setNumber)")
                .frame(width: 40, alignment: .leading)
                .foregroundStyle(set.completedAt != nil ? .primary : .secondary)

            Text("\(set.targetReps)")
                .frame(width: 60, alignment: .center)
                .foregroundStyle(.secondary)

            if let actualReps = set.actualReps {
                Text("\(actualReps)")
                    .frame(width: 60, alignment: .center)
                    .foregroundStyle(actualReps >= set.targetReps ? .green : .orange)
            } else {
                Text("-")
                    .frame(width: 60, alignment: .center)
                    .foregroundStyle(.secondary)
            }

            if let weight = set.weight {
                Text(WeightConverter.format(weight, unit: unit))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .fontWeight(.medium)
            } else {
                Text("-")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 8)
    }

    /// Format duration in seconds to a readable string (e.g., "30s" or "1:30")
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        } else {
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60
            if remainingSeconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes):\(String(format: "%02d", remainingSeconds))"
            }
        }
    }
}

// MARK: - Helper Functions

private func formatHistoryWeight(_ weight: Double) -> String {
    WeightConverter.format(weight, unit: .pounds, includeUnit: false)
}
