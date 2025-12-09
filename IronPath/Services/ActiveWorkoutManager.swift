import Foundation
import Combine

/// Manages an active workout in progress
/// Persists workout state so it survives app restarts with correct elapsed time
class ActiveWorkoutManager: ObservableObject {
    static let shared = ActiveWorkoutManager()

    private let workoutKey = "active_workout_data"
    private let startTimeKey = "active_workout_start_time"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Published var activeWorkout: Workout? {
        didSet {
            saveActiveWorkout()
        }
    }

    /// The time when the workout was started (persisted for accurate elapsed time)
    @Published var workoutStartTime: Date? {
        didSet {
            if let startTime = workoutStartTime {
                UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: startTimeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: startTimeKey)
            }
        }
    }

    private init() {
        loadActiveWorkout()
    }

    /// Save the active workout to UserDefaults
    private func saveActiveWorkout() {
        if let workout = activeWorkout,
           let data = try? encoder.encode(workout) {
            UserDefaults.standard.set(data, forKey: workoutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: workoutKey)
            UserDefaults.standard.removeObject(forKey: startTimeKey)
        }
    }

    /// Load the active workout from UserDefaults
    private func loadActiveWorkout() {
        if let data = UserDefaults.standard.data(forKey: workoutKey),
           let workout = try? decoder.decode(Workout.self, from: data) {
            self.activeWorkout = workout

            // Restore start time
            let startTimeInterval = UserDefaults.standard.double(forKey: startTimeKey)
            if startTimeInterval > 0 {
                self.workoutStartTime = Date(timeIntervalSince1970: startTimeInterval)
            } else {
                // Fallback to workout's startedAt if available
                self.workoutStartTime = workout.startedAt
            }
        }
    }

    /// Start a new workout
    func startWorkout(_ workout: Workout) {
        var startedWorkout = workout
        let now = Date()
        startedWorkout.startedAt = now
        workoutStartTime = now
        activeWorkout = startedWorkout
    }

    /// Update the current workout state (e.g., after completing a set)
    func updateWorkout(_ workout: Workout) {
        activeWorkout = workout
    }

    /// Complete the workout and clear the active state
    func completeWorkout() -> Workout? {
        let completed = activeWorkout
        activeWorkout = nil
        workoutStartTime = nil
        return completed
    }

    /// Cancel the workout and clear the active state
    func cancelWorkout() {
        activeWorkout = nil
        workoutStartTime = nil
    }

    /// Check if there's an active workout in progress
    var hasActiveWorkout: Bool {
        activeWorkout != nil
    }

    /// Get elapsed time since workout started
    var elapsedTime: TimeInterval {
        guard let startTime = workoutStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
}
