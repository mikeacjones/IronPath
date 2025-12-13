import Foundation
@testable import IronPath

// MARK: - Test Data Factory

enum TestData {

    // MARK: - Users

    static var sampleUserProfile: UserProfile {
        UserProfile(
            name: "Test User",
            fitnessLevel: .intermediate,
            goals: [.hypertrophy],
            availableEquipment: [.barbell, .dumbbells, .cables, .bench]
        )
    }

    // MARK: - Exercises

    static var benchPress: Exercise {
        Exercise(
            name: "Bench Press",
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders],
            equipment: .barbell,
            instructions: "Lie on bench, grip bar, lower to chest, press up",
            formTips: "Keep shoulder blades pinched"
        )
    }

    static var squat: Exercise {
        Exercise(
            name: "Barbell Squat",
            primaryMuscleGroups: [.quads],
            secondaryMuscleGroups: [.glutes, .hamstrings],
            equipment: .barbell,
            instructions: "Stand with bar on back, squat down, stand up",
            formTips: "Keep knees tracking over toes"
        )
    }

    static var latPulldown: Exercise {
        Exercise(
            name: "Lat Pulldown",
            primaryMuscleGroups: [.back],
            secondaryMuscleGroups: [.biceps],
            equipment: .cables,
            instructions: "Pull bar down to chest",
            formTips: "Lead with elbows"
        )
    }

    static var dumbbellCurl: Exercise {
        Exercise(
            name: "Dumbbell Curl",
            primaryMuscleGroups: [.biceps],
            secondaryMuscleGroups: [],
            equipment: .dumbbells,
            instructions: "Curl dumbbells up",
            formTips: "Keep elbows stationary"
        )
    }

    // MARK: - Sets

    static func standardSet(number: Int, targetReps: Int = 10, weight: Double? = nil) -> ExerciseSet {
        ExerciseSet(
            setNumber: number,
            setType: .standard,
            targetReps: targetReps,
            weight: weight,
            restPeriod: 90
        )
    }

    static func completedSet(number: Int, targetReps: Int = 10, actualReps: Int = 10, weight: Double = 135) -> ExerciseSet {
        ExerciseSet(
            setNumber: number,
            setType: .standard,
            targetReps: targetReps,
            actualReps: actualReps,
            weight: weight,
            restPeriod: 90,
            completedAt: Date()
        )
    }

    // MARK: - Workout Exercises

    static func workoutExercise(
        exercise: Exercise,
        orderIndex: Int,
        sets: [ExerciseSet]? = nil
    ) -> WorkoutExercise {
        let defaultSets = (1...3).map { standardSet(number: $0, weight: 135) }
        return WorkoutExercise(
            exercise: exercise,
            sets: sets ?? defaultSets,
            orderIndex: orderIndex
        )
    }

    // MARK: - Workouts

    static var sampleWorkout: Workout {
        Workout(
            name: "Push Day",
            exercises: [
                workoutExercise(exercise: benchPress, orderIndex: 0),
                workoutExercise(exercise: dumbbellCurl, orderIndex: 1)
            ]
        )
    }

    static var completedWorkout: Workout {
        let completedSets = (1...3).map { completedSet(number: $0) }
        return Workout(
            name: "Completed Push Day",
            exercises: [
                WorkoutExercise(
                    exercise: benchPress,
                    sets: completedSets,
                    orderIndex: 0
                )
            ],
            startedAt: Date().addingTimeInterval(-3600),
            completedAt: Date()
        )
    }

    static func workoutWithExercises(_ exercises: [WorkoutExercise]) -> Workout {
        Workout(name: "Test Workout", exercises: exercises)
    }

    // MARK: - Gym Profiles

    static var sampleGymProfile: GymProfile {
        GymProfile(
            name: "My Gym",
            availableEquipment: [.barbell, .dumbbells, .cables],
            availableMachines: [.pecDeck, .chestPress],
            defaultCableConfig: .defaultConfig
        )
    }
}
