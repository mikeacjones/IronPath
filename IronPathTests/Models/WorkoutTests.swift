import XCTest
@testable import IronPath

final class WorkoutTests: XCTestCase {

    // MARK: - Workout Tests

    func testWorkoutDurationCalculation() {
        // Given a workout with start and completion times
        let startTime = Date()
        let completedTime = startTime.addingTimeInterval(3600) // 1 hour later

        let workout = Workout(
            name: "Test Workout",
            exercises: [],
            startedAt: startTime,
            completedAt: completedTime
        )

        // Then duration should be 1 hour
        XCTAssertNotNil(workout.duration)
        XCTAssertEqual(workout.duration!, 3600, accuracy: 0.001)
    }

    func testWorkoutDurationIsNilWhenNotStarted() {
        // Given a workout that hasn't been started
        let workout = Workout(
            name: "Test Workout",
            exercises: [],
            startedAt: nil,
            completedAt: nil
        )

        // Then duration should be nil
        XCTAssertNil(workout.duration)
    }

    func testWorkoutDurationIsNilWhenNotCompleted() {
        // Given a workout that was started but not completed
        let workout = Workout(
            name: "Test Workout",
            exercises: [],
            startedAt: Date(),
            completedAt: nil
        )

        // Then duration should be nil
        XCTAssertNil(workout.duration)
    }

    func testWorkoutIsCompletedWhenCompletedAtIsSet() {
        // Given a completed workout
        let workout = TestFixtures.completedWorkout()

        // Then isCompleted should be true
        XCTAssertTrue(workout.isCompleted)
    }

    func testWorkoutIsNotCompletedWhenCompletedAtIsNil() {
        // Given a workout without completedAt
        let workout = Workout(
            name: "Test Workout",
            exercises: [],
            completedAt: nil
        )

        // Then isCompleted should be false
        XCTAssertFalse(workout.isCompleted)
    }

    func testWorkoutTotalVolumeCalculation() {
        // Given a workout with exercises
        let exercise1 = TestFixtures.sampleWorkoutExercise(
            setCount: 3,
            weight: 100,
            targetReps: 10,
            allCompleted: true
        )

        let workout = Workout(
            name: "Test Workout",
            exercises: [exercise1]
        )

        // Then total volume should be calculated correctly
        // 3 sets x 100 lbs x 10 reps = 3000 lbs
        XCTAssertEqual(workout.totalVolume, 3000, accuracy: 0.001)
    }

    func testWorkoutTotalVolumeWithMultipleExercises() {
        // Given a workout with multiple exercises
        let workout = TestFixtures.completedWorkout(exerciseCount: 3)

        // Then total volume should sum all exercises
        XCTAssertGreaterThan(workout.totalVolume, 0)
    }

    func testWorkoutHasGroupsIsFalseWhenNoGroups() {
        // Given a workout without exercise groups
        let workout = Workout(
            name: "Test Workout",
            exercises: [],
            exerciseGroups: nil
        )

        // Then hasGroups should be false
        XCTAssertFalse(workout.hasGroups)
    }

    func testWorkoutHasGroupsIsFalseWhenEmptyGroups() {
        // Given a workout with empty groups array
        let workout = Workout(
            name: "Test Workout",
            exercises: [],
            exerciseGroups: []
        )

        // Then hasGroups should be false
        XCTAssertFalse(workout.hasGroups)
    }

    func testWorkoutHasGroupsIsTrueWhenGroupsExist() {
        // Given a workout with exercise groups
        let group = ExerciseGroup(
            groupType: .superset,
            name: "Superset",
            exerciseIds: [UUID(), UUID()],
            restAfterGroup: 90
        )

        let workout = Workout(
            name: "Test Workout",
            exercises: [],
            exerciseGroups: [group]
        )

        // Then hasGroups should be true
        XCTAssertTrue(workout.hasGroups)
    }

    func testDeloadWorkoutFlag() {
        // Given a deload workout
        let workout = TestFixtures.deloadWorkout()

        // Then isDeload should be true
        XCTAssertTrue(workout.isDeload)
    }

    func testNonDeloadWorkoutFlag() {
        // Given a regular workout
        let workout = TestFixtures.completedWorkout()

        // Then isDeload should be false
        XCTAssertFalse(workout.isDeload)
    }

    // MARK: - WorkoutExercise Tests

    func testWorkoutExerciseTotalVolume() {
        // Given a workout exercise with completed sets
        let exercise = TestFixtures.sampleWorkoutExercise(
            setCount: 4,
            weight: 150,
            targetReps: 8,
            allCompleted: true
        )

        // Then volume should be weight x reps x sets
        // 4 sets x 150 lbs x 8 reps = 4800 lbs
        XCTAssertEqual(exercise.totalVolume, 4800, accuracy: 0.001)
    }

    func testWorkoutExerciseTotalVolumeWithIncompleteSets() {
        // Given a workout exercise with incomplete sets
        let exercise = TestFixtures.sampleWorkoutExercise(
            setCount: 3,
            weight: 100,
            targetReps: 10,
            allCompleted: false
        )

        // Note: WorkoutExercise.totalVolume uses targetReps when actualReps is nil
        // This allows showing expected volume before sets are completed
        // 3 sets x 100 lbs x 10 target reps = 3000 lbs
        XCTAssertEqual(exercise.totalVolume, 3000, accuracy: 0.001)
    }

    func testWorkoutExerciseIsCompletedWhenAllSetsComplete() {
        // Given an exercise with all sets completed
        let exercise = TestFixtures.sampleWorkoutExercise(
            setCount: 3,
            allCompleted: true
        )

        // Then isCompleted should be true
        XCTAssertTrue(exercise.isCompleted)
    }

    func testWorkoutExerciseIsNotCompletedWhenSomeSetsPending() {
        // Given an exercise with incomplete sets
        let exercise = TestFixtures.sampleWorkoutExercise(
            setCount: 3,
            allCompleted: false
        )

        // Then isCompleted should be false
        XCTAssertFalse(exercise.isCompleted)
    }

    func testWorkoutExerciseVolumeWithPartialCompletion() {
        // Given an exercise with some completed sets
        var exercise = TestFixtures.sampleWorkoutExercise(setCount: 3, weight: 100, targetReps: 10, allCompleted: false)

        // Complete only the first set with actual reps
        exercise.sets[0] = TestFixtures.completedSet(setNumber: 1, weight: 100, targetReps: 10, actualReps: 8)

        // Note: WorkoutExercise.totalVolume uses (actualReps ?? targetReps) for each set
        // Set 1: 100 * 8 (actual) = 800
        // Set 2: 100 * 10 (target, no actual) = 1000
        // Set 3: 100 * 10 (target, no actual) = 1000
        // Total: 2800
        XCTAssertEqual(exercise.totalVolume, 2800, accuracy: 0.001)
    }
}
