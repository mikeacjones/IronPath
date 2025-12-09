import Foundation
import Combine

/// Manages a generated workout that hasn't been started yet
/// Persists across app launches so users don't lose their generated workout
class PendingWorkoutManager: ObservableObject {
    static let shared = PendingWorkoutManager()

    private let storageKey = "pending_generated_workout"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Published var pendingWorkout: Workout? {
        didSet {
            savePendingWorkout()
        }
    }

    private init() {
        loadPendingWorkout()
    }

    /// Save the pending workout to UserDefaults
    private func savePendingWorkout() {
        if let workout = pendingWorkout,
           let data = try? encoder.encode(workout) {
            UserDefaults.standard.set(data, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    /// Load the pending workout from UserDefaults
    private func loadPendingWorkout() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let workout = try? decoder.decode(Workout.self, from: data) {
            self.pendingWorkout = workout
        }
    }

    /// Clear the pending workout (e.g., when starting or discarding)
    func clearPendingWorkout() {
        pendingWorkout = nil
    }

    /// Check if there's a pending workout available
    var hasPendingWorkout: Bool {
        pendingWorkout != nil
    }
}
