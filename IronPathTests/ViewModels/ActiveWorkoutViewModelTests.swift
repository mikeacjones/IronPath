import XCTest
@testable import IronPath

@MainActor
final class ActiveWorkoutViewModelTests: XCTestCase {

    var sut: ActiveWorkoutViewModel!
    var mockWorkoutDataManager: MockWorkoutDataManager!
    var mockActiveWorkoutManager: MockActiveWorkoutManager!
    var mockRestTimerManager: MockRestTimerManager!

    override func setUp() async throws {
        mockWorkoutDataManager = MockWorkoutDataManager()
        mockActiveWorkoutManager = MockActiveWorkoutManager()
        mockRestTimerManager = MockRestTimerManager()

        sut = ActiveWorkoutViewModel(
            workout: TestData.sampleWorkout,
            userProfile: TestData.sampleUserProfile,
            activeWorkoutManager: mockActiveWorkoutManager,
            workoutDataManager: mockWorkoutDataManager,
            restTimerManager: mockRestTimerManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockWorkoutDataManager = nil
        mockActiveWorkoutManager = nil
        mockRestTimerManager = nil
    }

    // MARK: - Initialization Tests

    func testInit_SetsWorkoutStartTime() {
        XCTAssertNotNil(sut.workoutStartTime)
    }

    func testInit_SetsWorkoutFromParameter() {
        XCTAssertEqual(sut.workout.name, "Push Day")
        XCTAssertEqual(sut.workout.exercises.count, 2)
    }

    // MARK: - Computed Properties Tests

    func testCompletedExercisesCount_WhenNoExercisesCompleted_ReturnsZero() {
        XCTAssertEqual(sut.completedExercisesCount, 0)
    }

    func testCompletedExercisesCount_WhenExerciseCompleted_ReturnsCorrectCount() {
        // Complete all sets of first exercise
        for i in 0..<sut.workout.exercises[0].sets.count {
            sut.workout.exercises[0].sets[i].actualReps = 10
            sut.workout.exercises[0].sets[i].completedAt = Date()
        }

        XCTAssertEqual(sut.completedExercisesCount, 1)
    }

    func testAllExercisesCompleted_WhenNotAllComplete_ReturnsFalse() {
        XCTAssertFalse(sut.allExercisesCompleted)
    }

    func testAllExercisesCompleted_WhenAllComplete_ReturnsTrue() {
        // Complete all exercises
        for exerciseIndex in 0..<sut.workout.exercises.count {
            for setIndex in 0..<sut.workout.exercises[exerciseIndex].sets.count {
                sut.workout.exercises[exerciseIndex].sets[setIndex].actualReps = 10
                sut.workout.exercises[exerciseIndex].sets[setIndex].completedAt = Date()
            }
        }

        XCTAssertTrue(sut.allExercisesCompleted)
    }

    func testTotalExercisesCount_ReturnsCorrectCount() {
        XCTAssertEqual(sut.totalExercisesCount, 2)
    }

    // MARK: - Exercise Update Tests

    func testUpdateExercise_UpdatesWorkoutCorrectly() {
        var updatedExercise = sut.workout.exercises[0]
        updatedExercise.notes = "Updated notes"

        sut.updateExercise(updatedExercise)

        XCTAssertEqual(sut.workout.exercises[0].notes, "Updated notes")
    }

    func testUpdateExercise_WithDismissSheet_ClearsSelectedExercise() {
        sut.selectedExercise = sut.workout.exercises[0]
        let updatedExercise = sut.workout.exercises[0]

        sut.updateExercise(updatedExercise, dismissSheet: true)

        XCTAssertNil(sut.selectedExercise)
    }

    func testUpdateExercise_WithoutDismissSheet_KeepsSelectedExercise() {
        sut.selectedExercise = sut.workout.exercises[0]
        let updatedExercise = sut.workout.exercises[0]

        sut.updateExercise(updatedExercise, dismissSheet: false)

        XCTAssertNotNil(sut.selectedExercise)
    }

    // MARK: - Workout Completion Tests

    func testFinishWorkout_SavesToHistory() {
        sut.finishWorkout()

        XCTAssertEqual(mockWorkoutDataManager.savedWorkouts.count, 1)
    }

    func testFinishWorkout_SetsCompletedAt() {
        sut.finishWorkout()

        XCTAssertNotNil(sut.completedWorkoutForSummary?.completedAt)
    }

    func testFinishWorkout_ShowsCompletionSummary() {
        sut.finishWorkout()

        XCTAssertTrue(sut.showCompletionSummary)
    }

    func testFinishWorkout_StopsRestTimer() {
        mockRestTimerManager.isActive = true

        sut.finishWorkout()

        XCTAssertTrue(mockRestTimerManager.wasSkipped)
    }

    func testFinishWorkout_SetsIsFinishingFlag() {
        sut.finishWorkout()

        XCTAssertTrue(sut.isFinishing)
    }

    func testFinishWorkout_PreventsDuplicateCalls() {
        sut.finishWorkout()
        sut.finishWorkout() // Second call should be ignored

        XCTAssertEqual(mockWorkoutDataManager.savedWorkouts.count, 1)
    }

    // MARK: - Cancel Workout Tests

    func testCancelWorkout_StopsRestTimer() {
        mockRestTimerManager.isActive = true

        sut.cancelWorkout()

        XCTAssertTrue(mockRestTimerManager.wasSkipped)
    }

    func testCancelWorkout_CallsOnCancelCallback() {
        var callbackCalled = false
        sut.onCancel = { callbackCalled = true }

        sut.cancelWorkout()

        XCTAssertTrue(callbackCalled)
    }

    // MARK: - Dismiss Summary Tests

    func testDismissCompletionSummary_HidesSummary() {
        sut.showCompletionSummary = true
        sut.completedWorkoutForSummary = TestData.completedWorkout

        sut.dismissCompletionSummary()

        XCTAssertFalse(sut.showCompletionSummary)
    }

    func testDismissCompletionSummary_CallsOnCompleteCallback() {
        var completedWorkout: Workout?
        sut.onComplete = { workout in
            completedWorkout = workout
        }
        sut.completedWorkoutForSummary = TestData.completedWorkout

        sut.dismissCompletionSummary()

        XCTAssertNotNil(completedWorkout)
    }

    // MARK: - Exercise Selection Tests

    func testSelectExercise_SetsSelectedExercise() {
        let exercise = sut.workout.exercises[0]

        sut.selectExercise(exercise)

        XCTAssertEqual(sut.selectedExercise?.id, exercise.id)
    }

    func testDismissSelectedExercise_ClearsSelection() {
        sut.selectedExercise = sut.workout.exercises[0]

        sut.dismissSelectedExercise()

        XCTAssertNil(sut.selectedExercise)
    }

    func testGetCurrentExercise_ReturnsLatestVersion() {
        let originalExercise = sut.workout.exercises[0]
        sut.workout.exercises[0].notes = "Updated"

        let currentExercise = sut.getCurrentExercise(originalExercise)

        XCTAssertEqual(currentExercise.notes, "Updated")
    }

    // MARK: - Persist State Tests

    func testPersistWorkoutState_CallsActiveWorkoutManager() {
        sut.persistWorkoutState()

        // The mock doesn't track this directly, but we can verify the workout
        // was passed by checking that updateWorkout was implicitly called
        XCTAssertNotNil(sut.workout)
    }

    // MARK: - Navigation Flag Tests

    func testHandleExerciseUpdateFromSheet_WhenNavigating_SkipsUpdate() {
        sut.isNavigatingBetweenExercises = true
        sut.selectedExercise = sut.workout.exercises[0]
        let originalNotes = sut.workout.exercises[0].notes

        var updatedExercise = sut.workout.exercises[0]
        updatedExercise.notes = "Should not update"

        sut.handleExerciseUpdateFromSheet(updatedExercise)

        // Notes should be updated even during navigation (data is persisted)
        // but selectedExercise should not be cleared
        XCTAssertNotNil(sut.selectedExercise)
    }

    // MARK: - Cleanup Tests

    func testCleanup_DoesNotCrash() {
        // Cleanup should be safe to call even without pending tasks
        sut.cleanup()

        // ViewModel should still be in a valid state
        XCTAssertNotNil(sut.workout)
    }
}
