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
                WorkoutSummaryHeader(workout: viewModel.workout)

                // Exercises
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises")
                        .font(.headline)

                    ForEach(viewModel.workout.exercises) { exercise in
                        WorkoutHistoryExerciseCard(exercise: exercise)
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
                    value: formatVolume(workout.totalVolume),
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

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000000 {
            return String(format: "%.1fM", volume / 1000000)
        } else if volume >= 1000 {
            return String(format: "%.0fK", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }
}

// MARK: - Workout History Exercise Card

struct WorkoutHistoryExerciseCard: View {
    let exercise: WorkoutExercise

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
            SetsTableView(sets: exercise.sets)

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

    var body: some View {
        VStack(spacing: 0) {
            // Header
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

            Divider()

            // Sets
            ForEach(sets) { set in
                HistorySetRow(set: set)

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

    var body: some View {
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
                Text("\(formatHistoryWeight(weight)) lbs")
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
}

// MARK: - Helper Functions

private func formatHistoryWeight(_ weight: Double) -> String {
    if weight.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", weight)
    }
    return String(format: "%.1f", weight)
}
