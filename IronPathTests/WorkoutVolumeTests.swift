import Foundation
import Testing
@testable import IronPath

struct WorkoutVolumeTests {
    @Test
    func workoutTotalVolumeDoesNotDoubleApplyExerciseMultiplier() {
        let exercise = Exercise(
            name: "Dumbbell Bench Press",
            primaryMuscleGroups: [.chest],
            equipment: .dumbbells,
            multiplier: 2.0
        )

        let set = ExerciseSet(
            setNumber: 1,
            targetReps: 10,
            actualReps: 10,
            weight: 50,
            completedAt: Date()
        )

        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: [set],
            orderIndex: 0
        )

        let workout = Workout(
            name: "Push Day",
            exercises: [workoutExercise],
            completedAt: Date()
        )

        #expect(workoutExercise.totalVolume == 1000)
        #expect(workout.totalVolume == 1000)
    }
}
