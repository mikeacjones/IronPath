import XCTest
@testable import IronPath

final class WorkoutDataManagerTests: XCTestCase {

    var mockManager: MockWorkoutDataManager!

    override func setUp() {
        super.setUp()
        mockManager = MockWorkoutDataManager()
    }

    override func tearDown() {
        mockManager.reset()
        mockManager = nil
        super.tearDown()
    }

    // MARK: - Save Workout Tests

    func testSaveWorkoutAddsToHistory() {
        // Given a workout
        let workout = TestFixtures.completedWorkout()

        // When saving the workout
        mockManager.saveWorkout(workout)

        // Then workout should be in history
        XCTAssertTrue(mockManager.saveWorkoutCalled)
        XCTAssertEqual(mockManager.lastSavedWorkout?.id, workout.id)
        XCTAssertEqual(mockManager.workouts.count, 1)
    }

    func testSaveWorkoutPreventsDuplicates() {
        // Given a workout already saved
        let workout = TestFixtures.completedWorkout()
        mockManager.saveWorkout(workout)

        // When saving the same workout again
        mockManager.saveWorkout(workout)

        // Then history should only have one copy
        XCTAssertEqual(mockManager.workouts.count, 1)
    }

    func testSaveMultipleWorkouts() {
        // Given multiple workouts
        let workout1 = TestFixtures.completedWorkout(name: "Workout 1")
        let workout2 = TestFixtures.completedWorkout(name: "Workout 2")

        // When saving both
        mockManager.saveWorkout(workout1)
        mockManager.saveWorkout(workout2)

        // Then both should be in history
        XCTAssertEqual(mockManager.workouts.count, 2)
    }

    // MARK: - Get Workout History Tests

    func testGetWorkoutHistoryReturnsAllWorkouts() {
        // Given workouts in history
        mockManager.workouts = [
            TestFixtures.completedWorkout(name: "Workout 1"),
            TestFixtures.completedWorkout(name: "Workout 2")
        ]

        // When getting history
        let history = mockManager.getWorkoutHistory()

        // Then all workouts returned
        XCTAssertEqual(history.count, 2)
    }

    func testGetWorkoutHistoryReturnsEmptyWhenNoHistory() {
        // Given no workouts
        mockManager.workouts = []

        // When getting history
        let history = mockManager.getWorkoutHistory()

        // Then empty array returned
        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - Get Last Workout With Exercise Tests

    func testGetLastWorkoutWithExercise() {
        // Given workouts with specific exercises
        let workout1 = TestFixtures.sampleWorkout(name: "Old Workout", exerciseCount: 3, completed: true)
        let workout2 = TestFixtures.sampleWorkout(name: "Recent Workout", exerciseCount: 3, completed: true)

        mockManager.workouts = [workout1, workout2]

        // When finding last workout with Bench Press
        let result = mockManager.getLastWorkoutWith(exerciseName: "Barbell Bench Press", excludeDeload: true)

        // Then should find the exercise
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.exercise.name, "Barbell Bench Press")
    }

    func testGetLastWorkoutExcludesDeload() {
        // Given a regular workout and a deload workout
        let regularWorkout = TestFixtures.sampleWorkout(name: "Regular", completed: true)
        let deloadWorkout = TestFixtures.deloadWorkout()

        mockManager.workouts = [regularWorkout, deloadWorkout]

        // When finding last workout excluding deload
        let result = mockManager.getLastWorkoutWith(exerciseName: "Barbell Bench Press", excludeDeload: true)

        // Then should find from regular workout, not deload
        XCTAssertNotNil(result)
    }

    func testGetLastWorkoutIncludesDeload() {
        // Given workouts
        let regularWorkout = TestFixtures.sampleWorkout(name: "Regular", completed: true)
        let deloadWorkout = TestFixtures.deloadWorkout()

        mockManager.workouts = [regularWorkout, deloadWorkout]

        // When finding last workout including deload
        let result = mockManager.getLastWorkoutWith(exerciseName: "Barbell Bench Press", excludeDeload: false)

        // Then should find from most recent (deload or regular)
        XCTAssertNotNil(result)
    }

    func testGetLastWorkoutReturnsNilForUnknownExercise() {
        // Given workouts
        mockManager.workouts = [TestFixtures.completedWorkout()]

        // When finding unknown exercise
        let result = mockManager.getLastWorkoutWith(exerciseName: "Unknown Exercise", excludeDeload: true)

        // Then should return nil
        XCTAssertNil(result)
    }

    // MARK: - Get Suggested Weight Tests

    func testGetSuggestedWeightProgressiveOverload() {
        // Given a workout with completed sets
        let workout = TestFixtures.sampleWorkout(exerciseCount: 1, completed: true)
        mockManager.workouts = [workout]

        // When getting suggested weight
        let suggested = mockManager.getSuggestedWeight(for: "Barbell Bench Press", targetReps: 10)

        // Then should return weight with increase
        XCTAssertNotNil(suggested)
        XCTAssertGreaterThan(suggested!, 0)
    }

    func testGetSuggestedWeightReturnsNilForNewExercise() {
        // Given no workout history
        mockManager.workouts = []

        // When getting suggested weight for unknown exercise
        let suggested = mockManager.getSuggestedWeight(for: "New Exercise", targetReps: 10)

        // Then should return nil
        XCTAssertNil(suggested)
    }

    // MARK: - Get Workout Stats Tests

    func testGetWorkoutStats() {
        // Given completed workouts
        mockManager.workouts = [
            TestFixtures.completedWorkout(name: "Workout 1"),
            TestFixtures.completedWorkout(name: "Workout 2")
        ]

        // When getting stats
        let stats = mockManager.getWorkoutStats()

        // Then should return correct counts
        XCTAssertEqual(stats.totalWorkouts, 2)
        XCTAssertGreaterThan(stats.totalVolume, 0)
    }

    func testGetWorkoutStatsWithNoWorkouts() {
        // Given no workouts
        mockManager.workouts = []

        // When getting stats
        let stats = mockManager.getWorkoutStats()

        // Then should return zeros
        XCTAssertEqual(stats.totalWorkouts, 0)
        XCTAssertEqual(stats.totalVolume, 0)
    }

    // MARK: - Delete Workout Tests

    func testDeleteWorkout() {
        // Given a workout in history
        let workout = TestFixtures.completedWorkout()
        mockManager.workouts = [workout]

        // When deleting the workout
        mockManager.deleteWorkout(byId: workout.id)

        // Then workout should be removed
        XCTAssertTrue(mockManager.deleteWorkoutCalled)
        XCTAssertEqual(mockManager.lastDeletedWorkoutId, workout.id)
        XCTAssertTrue(mockManager.workouts.isEmpty)
    }

    func testDeleteMultipleWorkouts() {
        // Given workouts in history
        let workout1 = TestFixtures.completedWorkout(name: "Workout 1")
        let workout2 = TestFixtures.completedWorkout(name: "Workout 2")
        let workout3 = TestFixtures.completedWorkout(name: "Workout 3")

        mockManager.workouts = [workout1, workout2, workout3]

        // When deleting multiple workouts
        mockManager.deleteWorkouts(byIds: [workout1.id, workout3.id])

        // Then only workout2 should remain
        XCTAssertEqual(mockManager.workouts.count, 1)
        XCTAssertEqual(mockManager.workouts.first?.id, workout2.id)
    }

    // MARK: - Update Workout Tests

    func testUpdateWorkout() {
        // Given a workout in history
        var workout = TestFixtures.completedWorkout(name: "Original Name")
        mockManager.workouts = [workout]

        // When updating the workout
        workout = Workout(
            id: workout.id,
            name: "Updated Name",
            exercises: workout.exercises,
            createdAt: workout.createdAt,
            startedAt: workout.startedAt,
            completedAt: workout.completedAt
        )
        mockManager.updateWorkout(workout)

        // Then workout should be updated
        XCTAssertTrue(mockManager.updateWorkoutCalled)
        XCTAssertEqual(mockManager.workouts.first?.name, "Updated Name")
    }

    // MARK: - Export Tests

    func testExportHistoryAsJSON() {
        // Given workouts in history
        mockManager.workouts = [TestFixtures.completedWorkout()]

        // When exporting as JSON
        let jsonData = mockManager.exportHistoryAsJSON()

        // Then should return valid JSON data
        XCTAssertNotNil(jsonData)
    }

    func testExportHistoryAsCSV() {
        // Given workouts in history
        mockManager.workouts = [TestFixtures.completedWorkout()]

        // When exporting as CSV
        let csv = mockManager.exportHistoryAsCSV()

        // Then should contain CSV header and data
        XCTAssertTrue(csv.contains("Workout Name"))
        XCTAssertTrue(csv.contains("Exercise"))
    }

    // MARK: - Get Workout By ID Tests

    func testGetWorkoutById() {
        // Given a workout in history
        let workout = TestFixtures.completedWorkout()
        mockManager.workouts = [workout]

        // When finding by ID
        let found = mockManager.getWorkout(byId: workout.id)

        // Then should return the workout
        XCTAssertEqual(found?.id, workout.id)
    }

    func testGetWorkoutByIdReturnsNilForUnknownId() {
        // Given workouts in history
        mockManager.workouts = [TestFixtures.completedWorkout()]

        // When finding by unknown ID
        let found = mockManager.getWorkout(byId: UUID())

        // Then should return nil
        XCTAssertNil(found)
    }

    // MARK: - PR Detection Tests

    func testDetectWorkoutPRsForWeight() {
        // Given existing workout with 100lb bench
        var existingWorkout = TestFixtures.sampleWorkout(exerciseCount: 1, completed: true)
        existingWorkout.exercises[0].sets = [
            TestFixtures.completedSet(weight: 100, actualReps: 10)
        ]

        // And new workout with 110lb bench
        var newWorkout = TestFixtures.sampleWorkout(exerciseCount: 1, completed: true)
        newWorkout.exercises[0].sets = [
            TestFixtures.completedSet(weight: 110, actualReps: 10)
        ]

        mockManager.workouts = [existingWorkout]

        // When detecting PRs
        let prs = mockManager.detectWorkoutPRs(in: newWorkout)

        // Then should detect weight PR
        XCTAssertFalse(prs.isEmpty)
        XCTAssertTrue(prs.contains { $0.type == .weight })
    }

    func testDetectWorkoutPRsSkipsDeload() {
        // Given a deload workout
        let deloadWorkout = TestFixtures.deloadWorkout()
        mockManager.workouts = []

        // When detecting PRs
        let prs = mockManager.detectWorkoutPRs(in: deloadWorkout)

        // Then should return empty (deloads don't count for PRs)
        XCTAssertTrue(prs.isEmpty)
    }

    func testDetectFirstTimePR() {
        // Given no history
        mockManager.workouts = []

        // And a new workout
        let newWorkout = TestFixtures.sampleWorkout(exerciseCount: 1, completed: true)

        // When detecting PRs
        let prs = mockManager.detectWorkoutPRs(in: newWorkout)

        // Then should detect first-time PR
        XCTAssertFalse(prs.isEmpty)
        XCTAssertNil(prs.first?.previousValue)
    }

    // MARK: - Clear History Tests

    func testClearHistory() {
        // Given workouts in history
        mockManager.workouts = [
            TestFixtures.completedWorkout(),
            TestFixtures.completedWorkout()
        ]

        // When clearing history
        mockManager.clearHistory()

        // Then history should be empty
        XCTAssertTrue(mockManager.clearHistoryCalled)
        XCTAssertTrue(mockManager.workouts.isEmpty)
    }
}
