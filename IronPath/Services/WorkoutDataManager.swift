import Foundation

/// Manages storage and retrieval of workout history
class WorkoutDataManager {
    static let shared = WorkoutDataManager()

    private let workoutHistoryKey = "workout_history"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    /// Save a completed workout to history
    func saveWorkout(_ workout: Workout) {
        var history = getWorkoutHistory()
        history.append(workout)

        // Keep only the last 100 workouts
        if history.count > 100 {
            history = Array(history.suffix(100))
        }

        if let encoded = try? encoder.encode(history) {
            UserDefaults.standard.set(encoded, forKey: workoutHistoryKey)
        }
    }

    /// Get all workout history
    func getWorkoutHistory() -> [Workout] {
        guard let data = UserDefaults.standard.data(forKey: workoutHistoryKey),
              let workouts = try? decoder.decode([Workout].self, from: data) else {
            return []
        }
        return workouts
    }

    /// Get the most recent workout containing a specific exercise
    func getLastWorkoutWith(exerciseName: String) -> WorkoutExercise? {
        let history = getWorkoutHistory()

        // Search from most recent to oldest
        for workout in history.reversed() {
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
}

struct WorkoutStats {
    let totalWorkouts: Int
    let totalVolume: Double
    let workoutsThisWeek: Int
    let averageWorkoutDuration: TimeInterval
}
