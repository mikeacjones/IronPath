import Foundation
import HealthKit

/// Manages integration with Apple HealthKit for exporting workout data
class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    private init() {}

    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// The types of data we want to write to HealthKit
    private var typesToWrite: Set<HKSampleType> {
        Set([
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ])
    }

    /// Request authorization to write workout data to HealthKit
    func requestAuthorization() async throws -> Bool {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: typesToWrite, read: nil) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    /// Check if we have authorization to write workouts
    func isAuthorizedToWrite() -> Bool {
        guard isHealthKitAvailable else { return false }

        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        return status == .sharingAuthorized
    }

    /// Save a completed workout to HealthKit
    func saveWorkout(
        workout: Workout,
        activeCalories: Double
    ) async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        guard let startDate = workout.startedAt,
              let endDate = workout.completedAt else {
            throw HealthKitError.invalidWorkoutData
        }

        // Create the workout
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .traditionalStrengthTraining
        workoutConfiguration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: workoutConfiguration, device: nil)

        try await builder.beginCollection(at: startDate)

        // Add active energy burned
        if activeCalories > 0 {
            let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: activeCalories)
            let calorieSample = HKQuantitySample(
                type: calorieType,
                quantity: calorieQuantity,
                start: startDate,
                end: endDate
            )
            try await builder.addSamples([calorieSample])
        }

        try await builder.endCollection(at: endDate)

        // Add metadata before finishing
        var metadata: [String: Any] = [
            HKMetadataKeyWorkoutBrandName: "IronPath",
            "WorkoutName": workout.name,
            "TotalVolume": workout.totalVolume,
            "ExerciseCount": workout.exercises.count
        ]

        if workout.isDeload {
            metadata["IsDeload"] = true
        }

        // Add metadata to the workout
        try await builder.addMetadata(metadata)

        // Finish and save the workout
        let hkWorkout = try await builder.finishWorkout()

        if hkWorkout == nil {
            throw HealthKitError.failedToSave
        }
    }

    /// Create a workout summary string for Claude to estimate calories
    func createWorkoutSummaryForCalorieEstimation(workout: Workout, userProfile: UserProfile?) -> String {
        let weightUnit = workout.weightUnit

        var summary = "Strength training workout summary:\n"
        summary += "- Duration: \(Int((workout.duration ?? 0) / 60)) minutes\n"
        summary += "- Total volume: \(weightUnit.format(workout.totalVolume))\n"
        summary += "- Number of exercises: \(workout.exercises.count)\n"

        if workout.isDeload {
            summary += "- Type: Deload/recovery workout (lighter weights)\n"
        }

        summary += "\nExercises performed:\n"

        for exercise in workout.exercises {
            let completedSets = exercise.sets.filter { $0.isCompleted }
            let avgWeight = completedSets.compactMap { $0.weight }.reduce(0, +) / max(Double(completedSets.count), 1)
            let totalReps = completedSets.compactMap { $0.actualReps }.reduce(0, +)

            summary += "- \(exercise.exercise.name): \(completedSets.count) sets, \(totalReps) total reps"
            if avgWeight > 0 {
                summary += ", avg weight: \(weightUnit.format(avgWeight))"
            }
            summary += "\n"
        }

        if let profile = userProfile {
            summary += "\nUser info:\n"
            summary += "- Fitness level: \(profile.fitnessLevel.rawValue)\n"
        }

        return summary
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case invalidWorkoutData
    case failedToSave

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "Not authorized to write to HealthKit"
        case .invalidWorkoutData:
            return "Invalid workout data - missing start or end time"
        case .failedToSave:
            return "Failed to save workout to HealthKit"
        }
    }
}
