import Foundation

// MARK: - Import Session

/// Observable state for the import wizard flow
@Observable @MainActor
final class ImportSession {
    // MARK: - Parsed Data
    var parsedWorkouts: [ParsedWorkout] = []
    var unmappedExercises: [UnmappedExercise] = []

    // MARK: - User Mappings
    /// User-selected mappings from CSV exercise name to database Exercise
    var exerciseMappings: [String: Exercise] = [:]

    // MARK: - Selection State
    /// Set of workout IDs selected for import (all selected by default)
    var selectedWorkouts: Set<UUID> = []

    // MARK: - Import Settings
    /// Weight unit of the source data (detected or user-specified)
    var sourceUnit: WeightUnit = .pounds

    // MARK: - Wizard State
    var currentStep: Int = 0

    // MARK: - Computed Properties

    /// All unique exercise names that need mapping
    var exercisesNeedingMapping: [UnmappedExercise] {
        unmappedExercises.filter { unmapped in
            exerciseMappings[unmapped.name] == nil
        }
    }

    /// Whether all exercises have been mapped
    var allExercisesMapped: Bool {
        exercisesNeedingMapping.isEmpty
    }

    /// Workouts selected for import
    var workoutsToImport: [ParsedWorkout] {
        parsedWorkouts.filter { selectedWorkouts.contains($0.id) }
    }

    /// Total number of exercises across all selected workouts
    var totalExerciseCount: Int {
        workoutsToImport.reduce(0) { $0 + $1.exercises.count }
    }

    /// Total number of sets across all selected workouts
    var totalSetCount: Int {
        workoutsToImport.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { $0 + $1.sets.count }
        }
    }

    /// Date range of selected workouts
    var dateRange: (start: Date, end: Date)? {
        let dates = workoutsToImport.map { $0.date }
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }
        return (earliest, latest)
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Methods

    /// Select all workouts for import
    func selectAllWorkouts() {
        selectedWorkouts = Set(parsedWorkouts.map { $0.id })
    }

    /// Deselect all workouts
    func deselectAllWorkouts() {
        selectedWorkouts.removeAll()
    }

    /// Toggle workout selection
    func toggleWorkout(_ id: UUID) {
        if selectedWorkouts.contains(id) {
            selectedWorkouts.remove(id)
        } else {
            selectedWorkouts.insert(id)
        }
    }

    /// Add a mapping from CSV exercise name to database exercise
    func addMapping(from csvName: String, to exercise: Exercise) {
        exerciseMappings[csvName] = exercise

        // Update all parsed exercises with this name to have the matched exercise
        for workoutIndex in parsedWorkouts.indices {
            for exerciseIndex in parsedWorkouts[workoutIndex].exercises.indices {
                if parsedWorkouts[workoutIndex].exercises[exerciseIndex].name == csvName {
                    parsedWorkouts[workoutIndex].exercises[exerciseIndex].matchedExercise = exercise
                }
            }
        }

        // Remove from unmapped list
        unmappedExercises.removeAll { $0.name == csvName }
    }

    /// Remove a mapping
    func removeMapping(for csvName: String) {
        exerciseMappings.removeValue(forKey: csvName)

        // Update all parsed exercises to remove the match
        for workoutIndex in parsedWorkouts.indices {
            for exerciseIndex in parsedWorkouts[workoutIndex].exercises.indices {
                if parsedWorkouts[workoutIndex].exercises[exerciseIndex].name == csvName {
                    parsedWorkouts[workoutIndex].exercises[exerciseIndex].matchedExercise = nil
                }
            }
        }

        // Add back to unmapped list if needed
        let count = parsedWorkouts.reduce(0) { total, workout in
            total + workout.exercises.filter { $0.name == csvName }.count
        }
        if count > 0 {
            unmappedExercises.append(UnmappedExercise(name: csvName, count: count))
        }
    }

    /// Reset the session
    func reset() {
        parsedWorkouts.removeAll()
        unmappedExercises.removeAll()
        exerciseMappings.removeAll()
        selectedWorkouts.removeAll()
        sourceUnit = .pounds
        currentStep = 0
    }
}
