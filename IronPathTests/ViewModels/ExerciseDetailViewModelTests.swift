import XCTest
@testable import IronPath

@MainActor
final class ExerciseDetailViewModelTests: XCTestCase {
    func testExerciseHistory_PreservesSessionWeightUnitsInReverseChronologicalOrder() {
        let mockWorkoutDataManager = MockWorkoutDataManager()
        let exercise = TestData.benchPress

        let poundsWorkout = Workout(
            name: "Bench Day Lbs",
            exercises: [
                WorkoutExercise(
                    exercise: exercise,
                    sets: [
                        ExerciseSet(
                            setNumber: 1,
                            targetReps: 8,
                            actualReps: 8,
                            weight: 135,
                            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
                        )
                    ],
                    orderIndex: 0
                )
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            weightUnit: .pounds
        )

        let kilogramsWorkout = Workout(
            name: "Bench Day Kg",
            exercises: [
                WorkoutExercise(
                    exercise: exercise,
                    sets: [
                        ExerciseSet(
                            setNumber: 1,
                            targetReps: 8,
                            actualReps: 8,
                            weight: 60,
                            completedAt: Date(timeIntervalSince1970: 1_700_100_000)
                        )
                    ],
                    orderIndex: 0
                )
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_100_000),
            weightUnit: .kilograms
        )

        mockWorkoutDataManager.workoutHistory = [poundsWorkout, kilogramsWorkout]

        let sut = ExerciseDetailViewModel(
            exercise: WorkoutExercise(
                exercise: exercise,
                sets: [TestData.standardSet(number: 1, weight: 135)],
                orderIndex: 0
            ),
            workoutDataManager: mockWorkoutDataManager
        )

        XCTAssertEqual(sut.exerciseHistory.count, 2)
        XCTAssertEqual(sut.exerciseHistory[0].weightUnit, .kilograms)
        XCTAssertEqual(sut.exerciseHistory[0].sets.first?.weight, 60)
        XCTAssertEqual(sut.exerciseHistory[1].weightUnit, .pounds)
        XCTAssertEqual(sut.exerciseHistory[1].sets.first?.weight, 135)
    }
}
