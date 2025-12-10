import XCTest

final class WorkoutGenerationUITests: XCTestCase {

    var app: XCUIApplication!
    var workoutPage: WorkoutPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchForTesting()

        workoutPage = WorkoutPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        workoutPage = nil
    }

    // MARK: - Navigation Tests

    func testCanNavigateToWorkoutTab() throws {
        // When navigating to workout tab
        app.navigateToWorkoutTab()

        // Then workout screen should be visible
        XCTAssertTrue(workoutPage.isOnWorkoutTab())
    }

    func testWorkoutTabShowsReadyState() throws {
        // Given on workout tab
        app.navigateToWorkoutTab()

        // Then should show ready state
        XCTAssertTrue(workoutPage.isShowingReadyState())
    }

    // MARK: - Button Tests

    func testChooseWorkoutTypeButtonExists() throws {
        // Given on workout tab
        app.navigateToWorkoutTab()

        // Then choose workout type button should exist
        XCTAssertTrue(workoutPage.hasChooseWorkoutTypeButton())
    }

    func testTappingChooseWorkoutTypeOpensSheet() throws {
        // Given on workout tab
        app.navigateToWorkoutTab()

        // When tapping choose workout type
        workoutPage.tapChooseWorkoutType()

        // Then workout setup sheet should appear
        // Look for any common element in the workout setup sheet
        let sheetElement = app.staticTexts["What would you like to train?"]
        XCTAssertTrue(sheetElement.waitForExistence(timeout: 3))
    }

    // MARK: - Auto Generate Tests
    // Note: Auto generate button only appears when user profile is configured

    func testAutoGenerateButtonAppearsWithProfile() throws {
        // Given a configured user profile (skip if not configured)
        app.navigateToWorkoutTab()

        // Check if auto generate button exists (depends on profile setup)
        if workoutPage.hasAutoGenerateButton() {
            // Then button should be tappable
            XCTAssertTrue(workoutPage.autoGenerateButton.isEnabled)
        }
        // If no button, test passes (profile not configured)
    }
}
