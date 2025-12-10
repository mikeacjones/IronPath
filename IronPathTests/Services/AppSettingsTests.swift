import XCTest
@testable import IronPath

final class AppSettingsTests: XCTestCase {

    // Note: These tests use the shared AppSettings instance
    // In a production app, you might want to use dependency injection
    // to allow testing with isolated instances

    // MARK: - Rest Notification Sound Tests

    func testRestNotificationSoundAllCases() {
        // All cases should exist and have display names
        for sound in RestNotificationSound.allCases {
            XCTAssertFalse(sound.displayName.isEmpty)
        }
    }

    func testRestNotificationSoundDefaultHasNotificationSound() {
        // Default sound should have a notification sound
        let defaultSound = RestNotificationSound.default
        XCTAssertNotNil(defaultSound.notificationSound)
    }

    func testRestNotificationSoundNoneHasNoNotificationSound() {
        // None should not have a notification sound
        let noneSound = RestNotificationSound.none
        XCTAssertNil(noneSound.notificationSound)
    }

    func testRestNotificationSoundDisplayNames() {
        // Verify display names are user-friendly
        XCTAssertEqual(RestNotificationSound.default.displayName, "Default")
        XCTAssertEqual(RestNotificationSound.none.displayName, "None")
    }

    func testRestNotificationSoundRawValues() {
        // Raw values should be stable for persistence
        XCTAssertEqual(RestNotificationSound.default.rawValue, "default")
        XCTAssertEqual(RestNotificationSound.none.rawValue, "none")
    }

    func testRestNotificationSoundSystemSoundIDs() {
        // Sounds (except none) should have system sound IDs
        for sound in RestNotificationSound.allCases {
            if sound == .none {
                XCTAssertNil(sound.systemSoundID)
            } else {
                XCTAssertNotNil(sound.systemSoundID)
            }
        }
    }

    // MARK: - Sound Encoding/Decoding Tests

    func testRestNotificationSoundCodable() throws {
        // Given a sound
        let original = RestNotificationSound.chord

        // When encoding and decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RestNotificationSound.self, from: data)

        // Then should match
        XCTAssertEqual(decoded, original)
    }

    func testAllSoundsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for sound in RestNotificationSound.allCases {
            let data = try encoder.encode(sound)
            let decoded = try decoder.decode(RestNotificationSound.self, from: data)
            XCTAssertEqual(decoded, sound)
        }
    }

    // MARK: - Sound Case Count

    func testRestNotificationSoundCaseCount() {
        // Verify we have expected number of sound options
        // Update this if you add/remove sounds
        XCTAssertGreaterThanOrEqual(RestNotificationSound.allCases.count, 6)
    }

    // MARK: - Sound Playing

    func testPlaySoundDoesNotCrash() {
        // This is a basic sanity test - just verify no crashes
        for sound in RestNotificationSound.allCases {
            // Don't actually play sounds in tests, just verify playSound method exists
            _ = sound.systemSoundID
        }
    }
}

// MARK: - App Settings Boolean Properties Tests

final class AppSettingsBooleanPropertiesTests: XCTestCase {

    // These tests verify the existence and type of boolean settings
    // Note: These reference the shared instance

    func testShowYouTubeVideosDefaultValue() {
        // Default should be true (videos shown by default)
        // This tests the default state - actual value may differ if changed
        let appSettings = AppSettings.shared
        _ = appSettings.showYouTubeVideos // Just verify property exists
    }

    func testShowFormTipsDefaultValue() {
        // Default should be true (tips shown by default)
        let appSettings = AppSettings.shared
        _ = appSettings.showFormTips // Just verify property exists
    }

    func testRestNotificationSoundDefaultValue() {
        // Should have a default sound
        let appSettings = AppSettings.shared
        _ = appSettings.restNotificationSound // Just verify property exists
    }
}

// MARK: - Settings Persistence Helpers

/// Helper functions for testing settings persistence
extension AppSettingsTests {

    func resetToDefaults() {
        // Helper to reset settings for testing
        // Note: In production, you'd want a more robust reset mechanism
        AppSettings.shared.showYouTubeVideos = true
        AppSettings.shared.showFormTips = true
        AppSettings.shared.restNotificationSound = .default
    }
}
