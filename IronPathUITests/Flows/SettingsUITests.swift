import XCTest

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!
    var settingsPage: SettingsPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchForTesting()

        settingsPage = SettingsPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        settingsPage = nil
    }

    // MARK: - Navigation Tests

    func testCanNavigateToProfile() throws {
        // When navigating to profile tab
        app.navigateToProfileTab()

        // Then profile screen should be visible
        XCTAssertTrue(settingsPage.isOnProfileTab())
    }

    // MARK: - Settings Sections Tests

    func testProfileShowsNotificationSettings() throws {
        // Given on profile tab
        app.navigateToProfileTab()

        // Then notification settings should be visible
        // Scroll down if needed
        app.swipeUp()

        XCTAssertTrue(settingsPage.notificationsSection.waitForExistence(timeout: 3))
    }

    func testProfileShowsEquipmentSettings() throws {
        // Given on profile tab
        app.navigateToProfileTab()

        // Then equipment settings should be visible
        // May need to scroll
        app.swipeUp()

        XCTAssertTrue(settingsPage.equipmentSection.waitForExistence(timeout: 3))
    }

    // MARK: - Toggle Tests

    func testYouTubeVideoToggleExists() throws {
        // Given on profile tab
        app.navigateToProfileTab()

        // Then YouTube video toggle should exist
        XCTAssertTrue(settingsPage.showYouTubeVideosToggle.waitForExistence(timeout: 3))
    }

    func testFormTipsToggleExists() throws {
        // Given on profile tab
        app.navigateToProfileTab()

        // Then form tips toggle should exist
        XCTAssertTrue(settingsPage.showFormTipsToggle.waitForExistence(timeout: 3))
    }

    // MARK: - Interaction Tests

    func testCanToggleYouTubeVideos() throws {
        // Given on profile tab
        app.navigateToProfileTab()

        guard settingsPage.showYouTubeVideosToggle.waitForExistence(timeout: 3) else {
            throw XCTSkip("YouTube videos toggle not found")
        }

        // Get initial state
        let initialState = settingsPage.isYouTubeVideosEnabled()

        // When toggling
        settingsPage.toggleYouTubeVideos()

        // Then state should change
        let newState = settingsPage.isYouTubeVideosEnabled()
        XCTAssertNotEqual(initialState, newState, "Toggle state should change")

        // Toggle back to restore state
        settingsPage.toggleYouTubeVideos()
    }

    func testCanToggleFormTips() throws {
        // Given on profile tab
        app.navigateToProfileTab()

        guard settingsPage.showFormTipsToggle.waitForExistence(timeout: 3) else {
            throw XCTSkip("Form tips toggle not found")
        }

        // Get initial state
        let initialState = settingsPage.isFormTipsEnabled()

        // When toggling
        settingsPage.toggleFormTips()

        // Then state should change
        let newState = settingsPage.isFormTipsEnabled()
        XCTAssertNotEqual(initialState, newState, "Toggle state should change")

        // Toggle back to restore state
        settingsPage.toggleFormTips()
    }
}
