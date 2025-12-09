import Foundation

/// Manages storage and retrieval of workout history
class WorkoutDataManager {
    static let shared = WorkoutDataManager()

    private let workoutHistoryKey = "workout_history"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        // Listen for iCloud sync changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudSync),
            name: .cloudDataDidSync,
            object: nil
        )
    }

    @objc private func handleCloudSync() {
        // Cache is automatically updated when getWorkoutHistory is called
        // No action needed here, but we could notify observers if needed
    }

    /// Save a completed workout to history
    func saveWorkout(_ workout: Workout) {
        var history = getWorkoutHistory()

        // Prevent duplicate saves - check if workout with same ID already exists
        guard !history.contains(where: { $0.id == workout.id }) else {
            return
        }

        history.append(workout)

        // Keep only the last 100 workouts
        if history.count > 100 {
            history = Array(history.suffix(100))
        }

        // Save to both local and iCloud
        CloudSyncManager.shared.saveWorkoutHistory(history)
    }

    /// Get all workout history
    func getWorkoutHistory() -> [Workout] {
        return CloudSyncManager.shared.loadWorkoutHistory()
    }

    /// Get the most recent workout containing a specific exercise
    /// - Parameter excludeDeload: If true, skips deload workouts (default: true for progressive overload tracking)
    func getLastWorkoutWith(exerciseName: String, excludeDeload: Bool = true) -> WorkoutExercise? {
        let history = getWorkoutHistory()

        // Search from most recent to oldest
        for workout in history.reversed() {
            // Skip deload workouts when tracking progressive overload
            if excludeDeload && workout.isDeload {
                continue
            }
            if let exercise = workout.exercises.first(where: { $0.exercise.name == exerciseName }) {
                return exercise
            }
        }

        return nil
    }

    /// Get suggested weight for progressive overload
    func getSuggestedWeight(for exerciseName: String, targetReps: Int) -> Double? {
        guard let lastExercise = getLastWorkoutWith(exerciseName: exerciseName) else {
            return nil
        }

        // Find the average weight used in completed sets
        let completedSets = lastExercise.sets.filter { $0.isCompleted }
        guard !completedSets.isEmpty else { return nil }

        let totalWeight = completedSets.compactMap { $0.weight }.reduce(0, +)
        let avgWeight = totalWeight / Double(completedSets.count)

        // Suggest 2.5-5% increase for progressive overload
        let increase = avgWeight * 0.025 // 2.5% increase
        let suggestedWeight = avgWeight + increase

        // Round to valid weight for the equipment type
        let equipment = lastExercise.exercise.equipment
        return GymSettings.shared.roundToValidWeight(suggestedWeight, for: equipment)
    }

    /// Get suggested weight with equipment type specified (for when we know the equipment)
    func getSuggestedWeight(for exerciseName: String, targetReps: Int, equipment: Equipment) -> Double? {
        guard let lastExercise = getLastWorkoutWith(exerciseName: exerciseName) else {
            return nil
        }

        // Find the average weight used in completed sets
        let completedSets = lastExercise.sets.filter { $0.isCompleted }
        guard !completedSets.isEmpty else { return nil }

        let totalWeight = completedSets.compactMap { $0.weight }.reduce(0, +)
        let avgWeight = totalWeight / Double(completedSets.count)

        // Suggest 2.5-5% increase for progressive overload
        let increase = avgWeight * 0.025 // 2.5% increase
        let suggestedWeight = avgWeight + increase

        // Round to valid weight for the equipment type
        return GymSettings.shared.roundToValidWeight(suggestedWeight, for: equipment)
    }

    /// Get workout statistics
    func getWorkoutStats() -> WorkoutStats {
        let history = getWorkoutHistory()
        let completed = history.filter { $0.isCompleted }

        let totalWorkouts = completed.count
        let totalVolume = completed.reduce(0) { $0 + $1.totalVolume }

        // Calculate this week's workouts
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let thisWeek = completed.filter { $0.completedAt ?? Date.distantPast >= weekStart }

        return WorkoutStats(
            totalWorkouts: totalWorkouts,
            totalVolume: totalVolume,
            workoutsThisWeek: thisWeek.count,
            averageWorkoutDuration: calculateAverageDuration(completed)
        )
    }

    private func calculateAverageDuration(_ workouts: [Workout]) -> TimeInterval {
        let durations = workouts.compactMap { $0.duration }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }

    /// Clear all workout history (for testing/reset)
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: workoutHistoryKey)
    }

    /// Export all workout history as JSON
    func exportHistoryAsJSON() -> Data? {
        let history = getWorkoutHistory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(history)
    }

    /// Export all workout history as CSV
    func exportHistoryAsCSV() -> String {
        let history = getWorkoutHistory()
        var csv = "Workout Name,Date,Exercise,Set,Target Reps,Actual Reps,Weight (lbs),Completed\n"

        for workout in history {
            let dateStr = workout.completedAt?.ISO8601Format() ?? "N/A"

            for exercise in workout.exercises {
                for set in exercise.sets {
                    let completed = set.completedAt != nil ? "Yes" : "No"
                    let weight = set.weight.map { String(Int($0)) } ?? "N/A"
                    let actualReps = set.actualReps.map { String($0) } ?? "N/A"

                    csv += "\"\(workout.name)\",\(dateStr),\"\(exercise.exercise.name)\",\(set.setNumber),\(set.targetReps),\(actualReps),\(weight),\(completed)\n"
                }
            }
        }

        return csv
    }

    /// Get workout by ID
    func getWorkout(byId id: UUID) -> Workout? {
        return getWorkoutHistory().first { $0.id == id }
    }

    /// Delete a workout by ID
    func deleteWorkout(byId id: UUID) {
        var history = getWorkoutHistory()
        history.removeAll { $0.id == id }
        CloudSyncManager.shared.saveWorkoutHistory(history)
    }

    /// Delete multiple workouts by IDs
    func deleteWorkouts(byIds ids: Set<UUID>) {
        var history = getWorkoutHistory()
        history.removeAll { ids.contains($0.id) }
        CloudSyncManager.shared.saveWorkoutHistory(history)
    }
}

struct WorkoutStats {
    let totalWorkouts: Int
    let totalVolume: Double
    let workoutsThisWeek: Int
    let averageWorkoutDuration: TimeInterval
}

// MARK: - Workout Personal Records

/// Represents a personal record achieved in a workout
struct WorkoutPR: Identifiable {
    let id = UUID()
    let exerciseName: String
    let type: PRType
    let newValue: Double
    let previousValue: Double?

    enum PRType {
        case weight      // Heaviest weight lifted
        case volume      // Highest total volume for exercise
        case reps        // Most reps at a given weight

        var displayName: String {
            switch self {
            case .weight: return "Weight PR"
            case .volume: return "Volume PR"
            case .reps: return "Rep PR"
            }
        }

        var icon: String {
            switch self {
            case .weight: return "scalemass.fill"
            case .volume: return "chart.bar.fill"
            case .reps: return "repeat"
            }
        }
    }
}

extension WorkoutDataManager {
    /// Detect personal records achieved in a workout
    /// Only compares against non-deload workouts
    func detectWorkoutPRs(in workout: Workout) -> [WorkoutPR] {
        // Don't detect PRs for deload workouts
        guard !workout.isDeload else { return [] }

        var prs: [WorkoutPR] = []
        let history = getWorkoutHistory().filter { !$0.isDeload && $0.id != workout.id }

        for workoutExercise in workout.exercises {
            let exerciseName = workoutExercise.exercise.name
            let completedSets = workoutExercise.sets.filter { $0.isCompleted }

            guard !completedSets.isEmpty else { continue }

            // Get historical data for this exercise
            let historicalExercises = history.flatMap { $0.exercises }
                .filter { $0.exercise.name == exerciseName }

            // Check for weight PR (heaviest single set)
            if let maxWeight = completedSets.compactMap({ $0.weight }).max() {
                let previousMaxWeight = historicalExercises.flatMap { $0.sets }
                    .filter { $0.isCompleted }
                    .compactMap { $0.weight }
                    .max()

                if let prev = previousMaxWeight {
                    if maxWeight > prev {
                        prs.append(WorkoutPR(
                            exerciseName: exerciseName,
                            type: .weight,
                            newValue: maxWeight,
                            previousValue: prev
                        ))
                    }
                } else if maxWeight > 0 {
                    // First time doing this exercise with weight
                    prs.append(WorkoutPR(
                        exerciseName: exerciseName,
                        type: .weight,
                        newValue: maxWeight,
                        previousValue: nil
                    ))
                }
            }

            // Check for volume PR (total volume for this exercise)
            let exerciseVolume = workoutExercise.totalVolume
            if exerciseVolume > 0 {
                let previousMaxVolume = historicalExercises.map { $0.totalVolume }.max()

                if let prev = previousMaxVolume {
                    if exerciseVolume > prev {
                        prs.append(WorkoutPR(
                            exerciseName: exerciseName,
                            type: .volume,
                            newValue: exerciseVolume,
                            previousValue: prev
                        ))
                    }
                }
                // Don't add volume PR for first-time exercises (weight PR is enough)
            }
        }

        return prs
    }
}
