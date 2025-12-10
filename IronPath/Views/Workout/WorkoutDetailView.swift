import SwiftUI

// MARK: - Workout Detail View

struct WorkoutDetailView: View {
    @State var workout: Workout
    let onStartWorkout: (Workout) -> Void
    let onRegenerate: () -> Void
    let onConvertToNormal: ((Workout) -> Void)?

    init(workout: Workout, onStartWorkout: @escaping () -> Void, onRegenerate: @escaping () -> Void) {
        self._workout = State(initialValue: workout)
        self.onStartWorkout = { _ in onStartWorkout() }
        self.onRegenerate = onRegenerate
        self.onConvertToNormal = nil
    }

    init(workout: Workout, onStartWorkout: @escaping (Workout) -> Void, onRegenerate: @escaping () -> Void, onConvertToNormal: ((Workout) -> Void)? = nil) {
        self._workout = State(initialValue: workout)
        self.onStartWorkout = onStartWorkout
        self.onRegenerate = onRegenerate
        self.onConvertToNormal = onConvertToNormal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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

                ForEach(workout.exercises) { workoutExercise in
                    ExerciseCard(workoutExercise: workoutExercise)
                }

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
                        Text("Generate Different Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
        }
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

// MARK: - Exercise Card

struct ExerciseCard: View {
    let workoutExercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(workoutExercise.exercise.name)
                .font(.headline)

            HStack {
                Label("\(workoutExercise.sets.count) sets", systemImage: "repeat")
                Spacer()
                Label("\(workoutExercise.sets.first?.targetReps ?? 0) reps", systemImage: "number")
                Spacer()
                Label("\(Int(workoutExercise.sets.first?.restPeriod ?? 0))s rest", systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !workoutExercise.notes.isEmpty {
                Text(workoutExercise.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
