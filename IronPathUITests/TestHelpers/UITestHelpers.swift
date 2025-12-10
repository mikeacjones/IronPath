import XCTest

// MARK: - UI Test Extensions

extension XCUIElement {

    /// Wait for element to exist with timeout
    @discardableResult
    func waitForExistence(timeout: TimeInterval = 5) -> Bool {
        waitForExistence(timeout: timeout)
    }

    /// Tap element after waiting for it to exist
    func tapWhenReady(timeout: TimeInterval = 5) {
        XCTAssertTrue(waitForExistence(timeout: timeout), "Element \(self) did not appear in time")
        tap()
    }

    /// Type text after clearing existing text
    func clearAndType(_ text: String) {
        guard let stringValue = self.value as? String else {
            tap()
            typeText(text)
            return
        }

        tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
        typeText(text)
    }
}

extension XCUIApplication {

    /// Launch app with specific test arguments
    func launchForTesting(resetState: Bool = true) {
        launchArguments = ["--uitesting"]

        if resetState {
            launchArguments.append("--reset-state")
        }

        launch()
    }

    /// Wait for app to become idle
    func waitForAppToLoad(timeout: TimeInterval = 10) {
        // Wait for main navigation to appear
        let tabBar = tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: timeout), "App did not load in time")
    }
}

// MARK: - Test Assertions

extension XCTestCase {

    /// Assert element exists with custom message
    func assertExists(_ element: XCUIElement, message: String = "", timeout: TimeInterval = 5) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, message.isEmpty ? "Element \(element) should exist" : message)
    }

    /// Assert element does not exist
    func assertNotExists(_ element: XCUIElement, message: String = "") {
        XCTAssertFalse(element.exists, message.isEmpty ? "Element \(element) should not exist" : message)
    }

    /// Assert element contains text
    func assertContainsText(_ element: XCUIElement, text: String) {
        let label = element.label
        XCTAssertTrue(label.contains(text), "Element should contain '\(text)' but has '\(label)'")
    }
}

// MARK: - Navigation Helpers

extension XCUIApplication {

    /// Navigate to workout tab
    func navigateToWorkoutTab() {
        let workoutTab = tabBars.buttons["Workout"]
        if workoutTab.exists {
            workoutTab.tap()
        }
    }

    /// Navigate to history tab
    func navigateToHistoryTab() {
        let historyTab = tabBars.buttons["History"]
        if historyTab.exists {
            historyTab.tap()
        }
    }

    /// Navigate to progress tab
    func navigateToProgressTab() {
        let progressTab = tabBars.buttons["Progress"]
        if progressTab.exists {
            progressTab.tap()
        }
    }

    /// Navigate to profile tab
    func navigateToProfileTab() {
        let profileTab = tabBars.buttons["Profile"]
        if profileTab.exists {
            profileTab.tap()
        }
    }
}

// MARK: - Wait Helpers

extension XCTestCase {

    /// Wait for condition to become true
    func waitFor(
        condition: @escaping () -> Bool,
        timeout: TimeInterval = 10,
        pollInterval: TimeInterval = 0.5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }

        return condition()
    }
}
