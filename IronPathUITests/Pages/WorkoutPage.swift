import XCTest

/// Page object for the Workout tab
class WorkoutPage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var autoGenerateButton: XCUIElement {
        app.buttons["auto_generate_workout_button"]
    }

    var chooseWorkoutTypeButton: XCUIElement {
        app.buttons["choose_workout_type_button"]
    }

    var workoutTitle: XCUIElement {
        app.navigationBars["Workout"]
    }

    var readyToWorkoutText: XCUIElement {
        app.staticTexts["Ready to workout?"]
    }

    /// Generated workout elements
    var startWorkoutButton: XCUIElement {
        app.buttons["Start Workout"]
    }

    var regenerateButton: XCUIElement {
        app.buttons["Regenerate"]
    }

    // MARK: - Workout Setup Sheet Elements

    var muscleGroupPickers: XCUIElementQuery {
        app.buttons.matching(identifier: "muscle_group")
    }

    // MARK: - Actions

    func tapAutoGenerate() {
        autoGenerateButton.tapWhenReady()
    }

    func tapChooseWorkoutType() {
        chooseWorkoutTypeButton.tapWhenReady()
    }

    func tapStartWorkout() {
        startWorkoutButton.tapWhenReady()
    }

    func tapRegenerate() {
        regenerateButton.tapWhenReady()
    }

    // MARK: - Verifications

    func isOnWorkoutTab() -> Bool {
        workoutTitle.waitForExistence(timeout: 3)
    }

    func isShowingReadyState() -> Bool {
        readyToWorkoutText.waitForExistence(timeout: 3)
    }

    func isShowingGeneratedWorkout() -> Bool {
        startWorkoutButton.waitForExistence(timeout: 3)
    }

    func hasAutoGenerateButton() -> Bool {
        autoGenerateButton.waitForExistence(timeout: 3)
    }

    func hasChooseWorkoutTypeButton() -> Bool {
        chooseWorkoutTypeButton.waitForExistence(timeout: 3)
    }
}
