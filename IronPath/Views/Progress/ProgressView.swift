import SwiftUI

// MARK: - Progress Tab View

struct ProgressTabView: View {
    @State private var workouts: [Workout] = []
    @State private var personalRecords: [PersonalRecord] = []
    @State private var selectedExercise: String?

    private var weightUnit: WeightUnit {
        GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds
    }

    var exerciseNames: [String] {
        var names = Set<String>()
        for workout in workouts {
            for exercise in workout.exercises {
                names.insert(exercise.exercise.name)
            }
        }
        return names.sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if workouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("Track your progress")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("Complete workouts to see your progress charts and analytics")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 100)
                } else {
                    VStack(spacing: 20) {
                        // Volume chart
                        VolumeChartView(workouts: workouts)
                            .padding(.horizontal)

                        // Personal Records
                        PRSectionView(records: personalRecords, weightUnit: weightUnit)
                            .padding(.horizontal)

                        // Exercise picker for specific progress
                        if !exerciseNames.isEmpty {
                            ExerciseProgressSection(
                                exerciseNames: exerciseNames,
                                selectedExercise: $selectedExercise,
                                workouts: workouts,
                                weightUnit: weightUnit
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        workouts = WorkoutDataManager.shared.getWorkoutHistory()
        personalRecords = calculatePRs()
    }

    private func calculatePRs() -> [PersonalRecord] {
        var prs: [String: PersonalRecord] = [:]

        for workout in workouts {
            for workoutExercise in workout.exercises {
                let exerciseName = workoutExercise.exercise.name

                for set in workoutExercise.sets {
                    guard let weight = set.weight,
                          let reps = set.actualReps,
                          set.isCompleted else { continue }

                    let currentPR = prs[exerciseName]

                    // Check if this is a new max weight
                    if currentPR == nil || weight > currentPR!.weight {
                        prs[exerciseName] = PersonalRecord(
                            exerciseName: exerciseName,
                            weight: weight,
                            reps: reps,
                            date: set.completedAt ?? workout.completedAt ?? Date()
                        )
                    }
                }
            }
        }

        return prs.values.sorted { $0.weight > $1.weight }
    }
}

// MARK: - Personal Record

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
}

// MARK: - Volume Chart View

struct VolumeChartView: View {
    let workouts: [Workout]

    var weeklyVolume: [(week: String, volume: Double)] {
        let calendar = Calendar.current
        var volumeByWeek: [Date: Double] = [:]

        for workout in workouts {
            guard let completedAt = workout.completedAt else { continue }
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: completedAt))!
            volumeByWeek[weekStart, default: 0] += workout.totalVolume
        }

        let sorted = volumeByWeek.sorted { $0.key < $1.key }.suffix(8)
        return sorted.map { (week: formatWeek($0.key), volume: $0.value) }
    }

    var maxVolume: Double {
        weeklyVolume.map { $0.volume }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume")
                .font(.headline)

            if weeklyVolume.isEmpty {
                Text("Complete workouts to see your volume trend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weeklyVolume, id: \.week) { data in
                        VStack(spacing: 4) {
                            Text(formatVolume(data.volume))
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.gradient)
                                .frame(height: max(20, CGFloat(data.volume / maxVolume) * 120))

                            Text(data.week)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 160)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0fK", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }
}

// MARK: - PR Section View

struct PRSectionView: View {
    let records: [PersonalRecord]
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Personal Records", systemImage: "trophy.fill")
                    .font(.headline)
                Spacer()
                Text("\(records.count) PRs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if records.isEmpty {
                Text("Complete workouts to set personal records")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(records.prefix(5)) { record in
                    PRRowView(record: record, weightUnit: weightUnit)
                }

                if records.count > 5 {
                    Text("+ \(records.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - PR Row View

struct PRRowView: View {
    let record: PersonalRecord
    let weightUnit: WeightUnit

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
                .font(.caption)

            Text(record.exerciseName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formatWeight(record.weight)) \(weightUnit.abbreviation) × \(record.reps)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Exercise Progress Section

struct ExerciseProgressSection: View {
    let exerciseNames: [String]
    @Binding var selectedExercise: String?
    let workouts: [Workout]
    let weightUnit: WeightUnit

    var exerciseHistory: [(date: Date, weight: Double, reps: Int)] {
        guard let exerciseName = selectedExercise else { return [] }

        var history: [(date: Date, weight: Double, reps: Int)] = []

        for workout in workouts.sorted(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }) {
            for workoutExercise in workout.exercises where workoutExercise.exercise.name == exerciseName {
                for set in workoutExercise.sets {
                    guard let weight = set.weight,
                          let reps = set.actualReps,
                          set.isCompleted,
                          let date = set.completedAt ?? workout.completedAt else { continue }

                    history.append((date: date, weight: weight, reps: reps))
                }
            }
        }

        return history
    }

    var maxWeight: Double {
        exerciseHistory.map { $0.weight }.max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Progress")
                .font(.headline)

            // Exercise picker
            Menu {
                Button("Select Exercise") {
                    selectedExercise = nil
                }
                Divider()
                ForEach(exerciseNames, id: \.self) { name in
                    Button(name) {
                        selectedExercise = name
                    }
                }
            } label: {
                HStack {
                    Text(selectedExercise ?? "Select an exercise")
                        .foregroundStyle(selectedExercise == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }

            if let exerciseName = selectedExercise {
                if exerciseHistory.isEmpty {
                    Text("No data for \(exerciseName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    // Simple progress visualization
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Weight:")
                                .foregroundStyle(.secondary)
                            Text("\(formatWeight(maxWeight)) \(weightUnit.abbreviation)")
                                .fontWeight(.bold)
                        }
                        .font(.subheadline)

                        Text("Recent Sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(exerciseHistory.suffix(5).reversed(), id: \.date) { entry in
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(formatWeight(entry.weight)) \(weightUnit.abbreviation) × \(entry.reps)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
