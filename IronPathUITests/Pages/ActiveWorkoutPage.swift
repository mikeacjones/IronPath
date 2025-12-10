import XCTest

/// Page object for the Active Workout screen
class ActiveWorkoutPage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var finishWorkoutButton: XCUIElement {
        app.buttons["finish_workout_button"]
    }

    var cancelButton: XCUIElement {
        app.buttons["Cancel"]
    }

    var completeSetButtons: XCUIElementQuery {
        app.buttons.matching(identifier: "complete_set_button")
    }

    var restTimerSkipButton: XCUIElement {
        app.buttons["Skip"]
    }

    var workoutCompleteBanner: XCUIElement {
        app.staticTexts["Workout Complete!"]
    }

    /// Get exercise cards
    var exerciseCards: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'exercise_card'"))
    }

    // MARK: - Actions

    func completeSet(at index: Int) {
        let buttons = completeSetButtons.allElementsBoundByIndex
        if index < buttons.count {
            buttons[index].tap()
        }
    }

    func tapFinishWorkout() {
        finishWorkoutButton.tapWhenReady()
    }

    func tapCancel() {
        cancelButton.tapWhenReady()
    }

    func skipRestTimer() {
        if restTimerSkipButton.waitForExistence(timeout: 2) {
            restTimerSkipButton.tap()
        }
    }

    func confirmCancel() {
        let confirmButton = app.buttons["Yes, Cancel"]
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
        }
    }

    // MARK: - Verifications

    func isActive() -> Bool {
        finishWorkoutButton.waitForExistence(timeout: 3)
    }

    func isRestTimerVisible() -> Bool {
        restTimerSkipButton.waitForExistence(timeout: 2)
    }

    func isWorkoutCompleted() -> Bool {
        workoutCompleteBanner.waitForExistence(timeout: 5)
    }

    func setCount() -> Int {
        completeSetButtons.count
    }
}
