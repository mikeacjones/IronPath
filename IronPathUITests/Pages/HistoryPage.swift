import XCTest

/// Page object for the History tab
class HistoryPage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var historyTitle: XCUIElement {
        app.navigationBars["History"]
    }

    var addWorkoutButton: XCUIElement {
        app.buttons["add_historical_workout_button"]
    }

    var calendarToggle: XCUIElement {
        app.switches.firstMatch
    }

    var noWorkoutsText: XCUIElement {
        app.staticTexts["No workouts this month"]
    }

    /// Get workout history rows
    var workoutRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'workout_history_row'"))
    }

    /// Edit workout button (in detail view)
    var editButton: XCUIElement {
        app.buttons["Edit"]
    }

    /// Delete workout button (in context menu)
    var deleteButton: XCUIElement {
        app.buttons["Delete Workout"]
    }

    // MARK: - Actions

    func tapAddWorkout() {
        addWorkoutButton.tapWhenReady()
    }

    func tapFirstWorkout() {
        let rows = workoutRows.allElementsBoundByIndex
        if !rows.isEmpty {
            rows[0].tap()
        }
    }

    func tapWorkout(at index: Int) {
        let rows = workoutRows.allElementsBoundByIndex
        if index < rows.count {
            rows[index].tap()
        }
    }

    func tapEditWorkout() {
        editButton.tapWhenReady()
    }

    func toggleCalendarView() {
        calendarToggle.tap()
    }

    func longPressFirstWorkout() {
        let rows = workoutRows.allElementsBoundByIndex
        if !rows.isEmpty {
            rows[0].press(forDuration: 1.0)
        }
    }

    func confirmDelete() {
        let confirmButton = app.buttons["Delete"]
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
        }
    }

    // MARK: - Verifications

    func isOnHistoryTab() -> Bool {
        historyTitle.waitForExistence(timeout: 3)
    }

    func hasWorkouts() -> Bool {
        workoutRows.count > 0
    }

    func workoutCount() -> Int {
        workoutRows.count
    }

    func isShowingNoWorkoutsMessage() -> Bool {
        noWorkoutsText.waitForExistence(timeout: 2)
    }

    func isShowingWorkoutDetail() -> Bool {
        editButton.waitForExistence(timeout: 3)
    }
}
