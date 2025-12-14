import Foundation

// MARK: - Import Result

/// Result of importing workouts
struct ImportResult {
    var successCount: Int
    var failedWorkouts: [(ParsedWorkout, Error)]

    var hasFailures: Bool {
        !failedWorkouts.isEmpty
    }

    var totalCount: Int {
        successCount + failedWorkouts.count
    }
}

// MARK: - Import Manager Protocol

protocol ImportManaging {
    /// Import parsed workouts into the data store
    func importWorkouts(_ session: ImportSession) async throws -> ImportResult
}

// MARK: - Import Manager

/// Manages the import process from ParsedWorkout to persisted Workout
@MainActor
final class ImportManager: ImportManaging {
    // MARK: - Dependencies

    private let workoutDataManager: WorkoutDataManaging
    private let exerciseMatcher: ExerciseMatching

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case unmappedExercise(String)
        case invalidData(String)
        case persistenceFailed(Error)

        var errorDescription: String? {
            switch self {
            case .unmappedExercise(let name):
                return "Exercise '\(name)' has not been mapped to a database exercise"
            case .invalidData(let details):
                return "Invalid workout data: \(details)"
            case .persistenceFailed(let error):
                return "Failed to save workout: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization

    init(
        workoutDataManager: WorkoutDataManaging? = nil,
        exerciseMatcher: ExerciseMatching? = nil
    ) {
        self.workoutDataManager = workoutDataManager ?? WorkoutDataManager.shared
        self.exerciseMatcher = exerciseMatcher ?? ExerciseMatcher()
    }

    // MARK: - Public Methods

    func importWorkouts(_ session: ImportSession) async throws -> ImportResult {
        var successCount = 0
        var failedWorkouts: [(ParsedWorkout, Error)] = []

        // Import each selected workout
        for parsedWorkout in session.workoutsToImport {
            do {
                let workout = try convertToWorkout(parsedWorkout, session: session)
                workoutDataManager.saveWorkout(workout)
                successCount += 1
            } catch {
                failedWorkouts.append((parsedWorkout, error))
            }
        }

        return ImportResult(successCount: successCount, failedWorkouts: failedWorkouts)
    }

    // MARK: - Private Methods

    private func convertToWorkout(_ parsed: ParsedWorkout, session: ImportSession) throws -> Workout {
        var workoutExercises: [WorkoutExercise] = []

        // Convert each parsed exercise
        for (exerciseIndex, parsedExercise) in parsed.exercises.enumerated() {
            // Get the mapped exercise
            guard let exercise = parsedExercise.matchedExercise ?? session.exerciseMappings[parsedExercise.name] else {
                throw ImportError.unmappedExercise(parsedExercise.name)
            }

            // Convert sets
            let sets = parsedExercise.sets.enumerated().map { setIndex, parsedSet in
                ExerciseSet(
                    setNumber: setIndex + 1,
                    setType: parsedSet.isWarmup ? .warmup : .standard,
                    targetReps: parsedSet.reps,
                    actualReps: parsedSet.reps,
                    weight: parsedSet.weight,
                    restPeriod: 60,  // Default 60 seconds rest
                    completedAt: parsed.date
                )
            }

            guard !sets.isEmpty else {
                throw ImportError.invalidData("Exercise '\(parsedExercise.name)' has no sets")
            }

            let workoutExercise = WorkoutExercise(
                exercise: exercise,
                sets: sets,
                orderIndex: exerciseIndex,
                notes: parsedExercise.sets.compactMap { $0.note.isEmpty ? nil : $0.note }.joined(separator: "; "),
                isTimedMode: false
            )

            workoutExercises.append(workoutExercise)
        }

        guard !workoutExercises.isEmpty else {
            throw ImportError.invalidData("Workout has no exercises")
        }

        // Create the workout
        let workout = Workout(
            name: parsed.name,
            exercises: workoutExercises,
            createdAt: parsed.date,
            startedAt: parsed.date,
            completedAt: parsed.date,
            notes: "Imported from FitBod",
            weightUnit: session.sourceUnit
        )

        return workout
    }
}
