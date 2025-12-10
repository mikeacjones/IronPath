import XCTest

final class HistoryUITests: XCTestCase {

    var app: XCUIApplication!
    var historyPage: HistoryPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchForTesting()

        historyPage = HistoryPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        historyPage = nil
    }

    // MARK: - Navigation Tests

    func testCanNavigateToHistory() throws {
        // When navigating to history
        app.navigateToHistoryTab()

        // Then history screen should be visible
        XCTAssertTrue(historyPage.isOnHistoryTab())
    }

    // MARK: - Add Historical Workout Tests

    func testCanOpenAddWorkoutSheet() throws {
        // Given on history tab
        app.navigateToHistoryTab()

        // When tapping add button
        historyPage.tapAddWorkout()

        // Then add workout sheet should appear
        let addWorkoutTitle = app.navigationBars["Add Workout"]
        XCTAssertTrue(addWorkoutTitle.waitForExistence(timeout: 3))
    }

    // MARK: - Workout List Tests

    func testHistoryShowsCalendarView() throws {
        // Given on history tab
        app.navigateToHistoryTab()

        // Then calendar view should be visible by default
        let calendarText = app.staticTexts["Calendar View"]
        XCTAssertTrue(calendarText.waitForExistence(timeout: 3))
    }

    func testCanToggleCalendarView() throws {
        // Given on history tab
        app.navigateToHistoryTab()

        // When toggling calendar
        historyPage.toggleCalendarView()

        // Then view should update (this is a basic check - just verify no crash)
        XCTAssertTrue(historyPage.isOnHistoryTab())
    }

    // MARK: - Workout Detail Tests
    // Note: These tests require existing workout data in history

    func testTappingWorkoutShowsDetail() throws {
        // Given on history tab with workouts
        app.navigateToHistoryTab()

        // Skip test if no workouts exist
        guard historyPage.hasWorkouts() else {
            throw XCTSkip("No workouts in history to test detail view")
        }

        // When tapping first workout
        historyPage.tapFirstWorkout()

        // Then should show detail view with edit button
        XCTAssertTrue(historyPage.isShowingWorkoutDetail())
    }

    func testCanAccessEditFromDetail() throws {
        // Given viewing workout detail
        app.navigateToHistoryTab()

        guard historyPage.hasWorkouts() else {
            throw XCTSkip("No workouts in history to test edit")
        }

        historyPage.tapFirstWorkout()
        XCTAssertTrue(historyPage.isShowingWorkoutDetail())

        // When tapping edit
        historyPage.tapEditWorkout()

        // Then edit sheet should appear
        let editWorkoutTitle = app.navigationBars["Edit Workout"]
        XCTAssertTrue(editWorkoutTitle.waitForExistence(timeout: 3))
    }
}
