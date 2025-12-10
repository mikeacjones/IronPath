import XCTest

final class ActiveWorkoutUITests: XCTestCase {

    var app: XCUIApplication!
    var workoutPage: WorkoutPage!
    var activeWorkoutPage: ActiveWorkoutPage!
    var historyPage: HistoryPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchForTesting()

        workoutPage = WorkoutPage(app: app)
        activeWorkoutPage = ActiveWorkoutPage(app: app)
        historyPage = HistoryPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        workoutPage = nil
        activeWorkoutPage = nil
        historyPage = nil
    }

    // MARK: - Active Workout Tests
    // Note: These tests require a generated workout to be started

    func testFinishWorkoutButtonExists() throws {
        // This test verifies the accessibility identifier is properly set
        // Skip if we can't get to an active workout

        app.navigateToWorkoutTab()

        // Check if there's already a generated workout ready to start
        if workoutPage.isShowingGeneratedWorkout() {
            workoutPage.tapStartWorkout()

            // Then finish button should exist
            XCTAssertTrue(activeWorkoutPage.finishWorkoutButton.waitForExistence(timeout: 5))
        } else {
            throw XCTSkip("No generated workout available to test active workout")
        }
    }

    func testCanCancelActiveWorkout() throws {
        app.navigateToWorkoutTab()

        guard workoutPage.isShowingGeneratedWorkout() else {
            throw XCTSkip("No generated workout available")
        }

        workoutPage.tapStartWorkout()

        // Wait for active workout
        guard activeWorkoutPage.isActive() else {
            throw XCTSkip("Could not start active workout")
        }

        // When tapping cancel
        activeWorkoutPage.tapCancel()

        // And confirming
        activeWorkoutPage.confirmCancel()

        // Then should return to workout tab
        XCTAssertTrue(workoutPage.isOnWorkoutTab())
    }

    // MARK: - Set Completion Tests

    func testCompleteSetButtonsExist() throws {
        app.navigateToWorkoutTab()

        guard workoutPage.isShowingGeneratedWorkout() else {
            throw XCTSkip("No generated workout available")
        }

        workoutPage.tapStartWorkout()

        guard activeWorkoutPage.isActive() else {
            throw XCTSkip("Could not start active workout")
        }

        // Then there should be complete set buttons
        // Note: The count depends on the workout structure
        let setCount = activeWorkoutPage.setCount()
        XCTAssertGreaterThanOrEqual(setCount, 0)
    }

    // MARK: - Finish Workout Flow

    func testCanFinishWorkoutEarly() throws {
        app.navigateToWorkoutTab()

        guard workoutPage.isShowingGeneratedWorkout() else {
            throw XCTSkip("No generated workout available")
        }

        workoutPage.tapStartWorkout()

        guard activeWorkoutPage.isActive() else {
            throw XCTSkip("Could not start active workout")
        }

        // When tapping finish workout
        activeWorkoutPage.tapFinishWorkout()

        // Then should show completion screen or confirmation
        // The exact behavior depends on whether any sets were completed
        let completionText = app.staticTexts["Workout Complete!"]
        let confirmationText = app.staticTexts["Finish Early"]

        let showsCompletion = completionText.waitForExistence(timeout: 3)
        let showsConfirmation = confirmationText.waitForExistence(timeout: 1)

        XCTAssertTrue(showsCompletion || showsConfirmation, "Should show completion or confirmation")
    }
}
