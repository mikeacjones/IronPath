import Foundation
import OSLog

// MARK: - App Logger

/// Centralized logging using OSLog for structured, performant logging.
/// Use these loggers instead of print() throughout the app.
///
/// Usage:
/// ```swift
/// AppLogger.cloud.info("Sync completed")
/// AppLogger.cloud.error("Sync failed: \(error)")
/// AppLogger.workout.debug("Starting workout: \(workout.name)")
/// ```
///
/// Benefits over print():
/// - Structured categories (subsystem/category)
/// - Log levels (debug, info, error, fault)
/// - Visible in Console.app with filtering
/// - Compiled out in release for debug-level logs
/// - No performance impact when logging is disabled

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kotrs.IronPath"

    /// Cloud sync operations (iCloud, CloudKit)
    static let cloud = Logger(subsystem: subsystem, category: "CloudSync")

    /// Workout generation and management
    static let workout = Logger(subsystem: subsystem, category: "Workout")

    /// AI provider interactions (API calls, responses)
    static let ai = Logger(subsystem: subsystem, category: "AI")

    /// Exercise database and similarity calculations
    static let exercise = Logger(subsystem: subsystem, category: "Exercise")

    /// Timer and notification operations
    static let timer = Logger(subsystem: subsystem, category: "Timer")

    /// Settings and profile management
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// HealthKit integration
    static let health = Logger(subsystem: subsystem, category: "HealthKit")

    /// General app lifecycle and navigation
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Data persistence (UserDefaults, local storage)
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
}

// MARK: - Logger Extensions

extension Logger {
    /// Log an error with the error's localized description
    func error(_ message: String, error: Error) {
        self.error("\(message): \(error.localizedDescription)")
    }

    /// Log a network response status
    func networkResponse(endpoint: String, statusCode: Int) {
        if (200..<300).contains(statusCode) {
            self.debug("[\(statusCode)] \(endpoint)")
        } else {
            self.warning("[\(statusCode)] \(endpoint)")
        }
    }
}
