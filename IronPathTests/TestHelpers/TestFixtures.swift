import Foundation
@testable import IronPath

/// Test fixtures providing sample data for unit tests
struct TestFixtures {

    // MARK: - Exercise Fixtures

    /// Create a sample exercise with customizable properties
    static func sampleExercise(
        name: String = "Bench Press",
        primaryMuscleGroups: Set<MuscleGroup> = [.chest],
        secondaryMuscleGroups: Set<MuscleGroup> = [.triceps, .shoulders],
        equipment: Equipment = .barbell,
        difficulty: ExerciseDifficulty = .intermediate
    ) -> Exercise {
        Exercise(
            name: name,
            primaryMuscleGroups: primaryMuscleGroups,
            secondaryMuscleGroups: secondaryMuscleGroups,
            equipment: equipment,
            difficulty: difficulty,
            instructions: "Test instructions",
            formTips: "Test form tips"
        )
    }

    /// Common exercises for testing
    static let benchPress = sampleExercise(
        name: "Barbell Bench Press",
        primaryMuscleGroups: [.chest],
        secondaryMuscleGroups: [.triceps, .shoulders],
        equipment: .barbell
    )

    static let squat = sampleExercise(
        name: "Barbell Squat",
        primaryMuscleGroups: [.quads, .glutes],
        secondaryMuscleGroups: [.hamstrings, .lowerBack],
        equipment: .barbell
    )

    static let cablePulldown = sampleExercise(
        name: "Lat Pulldown",
        primaryMuscleGroups: [.back],
        secondaryMuscleGroups: [.biceps],
        equipment: .cables
    )

    static let dumbbellCurl = sampleExercise(
        name: "Dumbbell Curl",
        primaryMuscleGroups: [.biceps],
        equipment: .dumbbells
    )

    // MARK: - ExerciseSet Fixtures

    /// Create a sample standard set
    static func sampleSet(
        setNumber: Int = 1,
        weight: Double = 100,
        targetReps: Int = 10,
        actualReps: Int? = nil,
        restPeriod: TimeInterval = 90,
        isCompleted: Bool = false
    ) -> ExerciseSet {
        ExerciseSet(
            setNumber: setNumber,
            setType: .standard,
            targetReps: targetReps,
            actualReps: isCompleted ? (actualReps ?? targetReps) : actualReps,
            weight: weight,
            restPeriod: restPeriod,
            completedAt: isCompleted ? Date() : nil
        )
    }

    /// Create a completed standard set
    static func completedSet(
        setNumber: Int = 1,
        weight: Double = 100,
        targetReps: Int = 10,
        actualReps: Int = 10
    ) -> ExerciseSet {
        sampleSet(
            setNumber: setNumber,
            weight: weight,
            targetReps: targetReps,
            actualReps: actualReps,
            isCompleted: true
        )
    }

    /// Create a warmup set
    static func warmupSet(
        setNumber: Int = 1,
        weight: Double = 50,
        targetReps: Int = 12,
        isCompleted: Bool = false
    ) -> ExerciseSet {
        ExerciseSet(
            setNumber: setNumber,
            setType: .warmup,
            targetReps: targetReps,
            actualReps: isCompleted ? targetReps : nil,
            weight: weight,
            restPeriod: 60,
            completedAt: isCompleted ? Date() : nil
        )
    }

    /// Create a drop set with configured drops
    static func sampleDropSet(
        setNumber: Int = 1,
        startingWeight: Double = 100,
        targetReps: Int = 8,
        numberOfDrops: Int = 2,
        allCompleted: Bool = false
    ) -> ExerciseSet {
        var dropConfig = DropSetConfig(numberOfDrops: numberOfDrops, dropPercentage: 0.2)

        let weights = [100.0, 80.0, 65.0] // Pre-calculated drop weights
        for i in 0...numberOfDrops {
            let drop = DropSetEntry(
                dropNumber: i,
                targetWeight: weights[safe: i],
                actualWeight: allCompleted ? weights[safe: i] : nil,
                targetReps: targetReps,
                actualReps: allCompleted ? targetReps : nil,
                completedAt: allCompleted ? Date() : nil
            )
            dropConfig.drops.append(drop)
        }

        return ExerciseSet(
            setNumber: setNumber,
            setType: .dropSet,
            targetReps: targetReps,
            weight: startingWeight,
            restPeriod: 90,
            dropSetConfig: dropConfig
        )
    }

    /// Create a rest-pause set
    static func sampleRestPauseSet(
        setNumber: Int = 1,
        weight: Double = 100,
        targetReps: Int = 8,
        numberOfPauses: Int = 2,
        allCompleted: Bool = false
    ) -> ExerciseSet {
        var restPauseConfig = RestPauseConfig(numberOfPauses: numberOfPauses, pauseDuration: 15)

        // Initial set + mini-sets
        restPauseConfig.miniSets.append(RestPauseMiniSet(
            miniSetNumber: 0,
            targetReps: targetReps,
            actualReps: allCompleted ? targetReps : nil,
            completedAt: allCompleted ? Date() : nil
        ))

        for i in 1...numberOfPauses {
            restPauseConfig.miniSets.append(RestPauseMiniSet(
                miniSetNumber: i,
                targetReps: max(targetReps / 2, 2),
                actualReps: allCompleted ? max(targetReps / 2, 2) : nil,
                completedAt: allCompleted ? Date() : nil
            ))
        }

        return ExerciseSet(
            setNumber: setNumber,
            setType: .restPause,
            targetReps: targetReps,
            weight: weight,
            restPeriod: 90,
            restPauseConfig: restPauseConfig
        )
    }

    // MARK: - WorkoutExercise Fixtures

    /// Create a sample workout exercise with configurable sets
    static func sampleWorkoutExercise(
        exercise: Exercise? = nil,
        setCount: Int = 3,
        weight: Double = 100,
        targetReps: Int = 10,
        allCompleted: Bool = false
    ) -> WorkoutExercise {
        let sets = (1...setCount).map { setNumber in
            sampleSet(
                setNumber: setNumber,
                weight: weight,
                targetReps: targetReps,
                isCompleted: allCompleted
            )
        }

        return WorkoutExercise(
            exercise: exercise ?? benchPress,
            sets: sets,
            orderIndex: 0
        )
    }

    /// Create a workout exercise with mixed set types
    static func workoutExerciseWithMixedSets() -> WorkoutExercise {
        let sets: [ExerciseSet] = [
            warmupSet(setNumber: 1, weight: 50, isCompleted: true),
            completedSet(setNumber: 2, weight: 100),
            completedSet(setNumber: 3, weight: 100),
            sampleDropSet(setNumber: 4, startingWeight: 100, allCompleted: true)
        ]

        return WorkoutExercise(
            exercise: benchPress,
            sets: sets,
            orderIndex: 0
        )
    }

    // MARK: - Workout Fixtures

    /// Create a sample workout with customizable properties
    static func sampleWorkout(
        name: String = "Test Workout",
        exerciseCount: Int = 3,
        setsPerExercise: Int = 3,
        completed: Bool = false,
        isDeload: Bool = false
    ) -> Workout {
        let exercises: [Exercise] = [benchPress, squat, cablePulldown, dumbbellCurl]

        let workoutExercises = (0..<min(exerciseCount, exercises.count)).map { index in
            var exercise = sampleWorkoutExercise(
                exercise: exercises[index],
                setCount: setsPerExercise,
                weight: Double((index + 1) * 50),
                allCompleted: completed
            )
            exercise.orderIndex = index
            return exercise
        }

        let startTime = Date().addingTimeInterval(-3600) // 1 hour ago

        return Workout(
            name: name,
            exercises: workoutExercises,
            createdAt: startTime,
            startedAt: completed ? startTime : nil,
            completedAt: completed ? Date() : nil,
            isDeload: isDeload
        )
    }

    /// Create a completed workout
    static func completedWorkout(
        name: String = "Completed Workout",
        exerciseCount: Int = 3
    ) -> Workout {
        sampleWorkout(
            name: name,
            exerciseCount: exerciseCount,
            completed: true
        )
    }

    /// Create a deload workout
    static func deloadWorkout() -> Workout {
        sampleWorkout(
            name: "Deload Workout",
            exerciseCount: 2,
            completed: true,
            isDeload: true
        )
    }

    /// Create an incomplete workout (in progress)
    static func inProgressWorkout() -> Workout {
        var workout = sampleWorkout(name: "In Progress", exerciseCount: 3, completed: false)
        // Start the workout but don't complete it
        return Workout(
            id: workout.id,
            name: workout.name,
            exercises: workout.exercises,
            createdAt: workout.createdAt,
            startedAt: Date().addingTimeInterval(-1800), // Started 30 min ago
            completedAt: nil
        )
    }

    // MARK: - Cable Machine Config Fixtures

    /// Default cable machine config with simple 5lb increments
    static func simpleCableMachine() -> CableMachineConfig {
        CableMachineConfig(
            name: "Simple Cable",
            plateTiers: [CableMachineConfig.PlateTier(plateWeight: 5.0, plateCount: 40)]
        )
    }

    /// Cable machine with tiered weight stack
    static func tieredCableMachine() -> CableMachineConfig {
        CableMachineConfig(
            name: "Tiered Cable",
            plateTiers: [
                CableMachineConfig.PlateTier(plateWeight: 9.0, plateCount: 6),
                CableMachineConfig.PlateTier(plateWeight: 12.5, plateCount: 12)
            ]
        )
    }

    /// Cable machine with free weights (single of each)
    static func cableMachineWithFreeWeights() -> CableMachineConfig {
        var config = simpleCableMachine()
        config.freeWeights = [
            CableMachineConfig.FreeWeight(weight: 2.5, count: 1),
            CableMachineConfig.FreeWeight(weight: 5.0, count: 1)
        ]
        return config
    }

    /// Cable machine with multiple free weights of same type (e.g., 3x 5lb)
    static func cableMachineWithMultipleFreeWeights() -> CableMachineConfig {
        var config = simpleCableMachine()
        config.freeWeights = [
            CableMachineConfig.FreeWeight(weight: 5.0, count: 3)
        ]
        return config
    }

    // Legacy alias for backwards compatibility with existing tests
    static func cableMachineWithIntegratedWeights() -> CableMachineConfig {
        cableMachineWithFreeWeights()
    }

    // MARK: - Date Helpers

    /// Get a date in the past
    static func pastDate(daysAgo: Int = 1) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    /// Get a date relative to now
    static func date(minutesAgo: Int) -> Date {
        Date().addingTimeInterval(TimeInterval(-minutesAgo * 60))
    }
}

// MARK: - Array Extension (safe subscript if not already defined)

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
