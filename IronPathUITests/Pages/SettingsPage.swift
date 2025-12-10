import XCTest

/// Page object for the Profile/Settings tab
class SettingsPage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var profileTitle: XCUIElement {
        app.navigationBars["Profile"]
    }

    var notificationSoundPicker: XCUIElement {
        app.buttons["Rest Timer Sound"]
    }

    var dumbbellConfigButton: XCUIElement {
        app.buttons["Configure Dumbbells"]
    }

    var showYouTubeVideosToggle: XCUIElement {
        app.switches["Show YouTube Videos"]
    }

    var showFormTipsToggle: XCUIElement {
        app.switches["Show Form Tips"]
    }

    /// Settings section headers
    var notificationsSection: XCUIElement {
        app.staticTexts["Notifications"]
    }

    var equipmentSection: XCUIElement {
        app.staticTexts["Equipment"]
    }

    // MARK: - Actions

    func tapNotificationSoundPicker() {
        notificationSoundPicker.tapWhenReady()
    }

    func selectSound(_ soundName: String) {
        let soundButton = app.buttons[soundName]
        if soundButton.waitForExistence(timeout: 2) {
            soundButton.tap()
        }
    }

    func tapDumbbellConfig() {
        dumbbellConfigButton.tapWhenReady()
    }

    func toggleYouTubeVideos() {
        showYouTubeVideosToggle.tap()
    }

    func toggleFormTips() {
        showFormTipsToggle.tap()
    }

    // MARK: - Verifications

    func isOnProfileTab() -> Bool {
        profileTitle.waitForExistence(timeout: 3)
    }

    func hasNotificationSettings() -> Bool {
        notificationsSection.waitForExistence(timeout: 3)
    }

    func hasEquipmentSettings() -> Bool {
        equipmentSection.waitForExistence(timeout: 3)
    }

    func isYouTubeVideosEnabled() -> Bool {
        // Check toggle state
        guard showYouTubeVideosToggle.exists else { return false }
        return showYouTubeVideosToggle.value as? String == "1"
    }

    func isFormTipsEnabled() -> Bool {
        guard showFormTipsToggle.exists else { return false }
        return showFormTipsToggle.value as? String == "1"
    }
}
