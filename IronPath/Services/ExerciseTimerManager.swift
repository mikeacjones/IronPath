import Foundation
import SwiftUI
import AVFoundation

// MARK: - Exercise Timer Manager

/// Manages countdown and timer state for timed exercises (e.g., planks, timed ball slams)
@Observable
@MainActor
final class ExerciseTimerManager {
    static let shared = ExerciseTimerManager()

    // MARK: - State

    /// Whether a timer is active (countdown or main timer)
    private(set) var isActive: Bool = false

    /// Whether we're in countdown phase (3-2-1)
    private(set) var isCountdown: Bool = false

    /// Countdown value (3, 2, 1)
    private(set) var countdownRemaining: Int = 3

    /// Total target duration for the timed exercise
    private(set) var totalDuration: TimeInterval = 0

    /// Exercise being timed
    private(set) var exerciseName: String = ""

    /// Set number being timed
    private(set) var setNumber: Int = 0

    /// Heartbeat counter for forcing SwiftUI updates
    private(set) var timerTick: UInt64 = 0

    // MARK: - Private State

    /// Start time of the main timer (not countdown)
    private var startTime: Date?

    /// Timer for both countdown and main timer
    private var timer: Timer?

    /// Completion callback for countdown
    private var countdownCompleteCallback: (() -> Void)?

    /// Completion callback for timer reaching target
    private var timerCompleteCallback: ((TimeInterval) -> Void)?

    /// Haptic feedback generator
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Computed Properties

    /// Elapsed time since timer started (excluding countdown)
    var elapsedTime: TimeInterval {
        _ = timerTick
        guard let startTime = startTime, !isCountdown else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    /// Formatted remaining time (MM:SS) - counts down from target to 0
    var formattedElapsedTime: String {
        _ = timerTick
        let time = max(remainingTime, 0)  // Show countdown, never negative
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Remaining time until target (can be negative if user exceeds target)
    var remainingTime: TimeInterval {
        _ = timerTick
        return totalDuration - elapsedTime
    }

    /// Progress (1.0 to 0.0) - represents time remaining as fraction
    var progress: Double {
        _ = timerTick
        guard totalDuration > 0 else { return 1.0 }
        return max(1.0 - (elapsedTime / totalDuration), 0.0)
    }

    // MARK: - Initialization

    private init() {
        impactFeedback.prepare()
    }

    // MARK: - Public Methods

    /// Start a 3-2-1 countdown, then call the completion handler to start the main timer
    func startCountdown(exerciseName: String, setNumber: Int, onComplete: @escaping () -> Void) {
        guard !isActive else { return }

        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.isActive = true
        self.isCountdown = true
        self.countdownRemaining = 3
        self.countdownCompleteCallback = onComplete

        // Start countdown timer
        timer?.invalidate()
        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.countdownTick()
            }
        }
        timer = newTimer
        RunLoop.current.add(newTimer, forMode: .common)

        // Haptic for initial countdown start
        impactFeedback.impactOccurred(intensity: 0.5)
    }

    /// Skip countdown and start timer immediately
    func skipCountdown() {
        guard isCountdown else { return }

        timer?.invalidate()
        isCountdown = false
        countdownCompleteCallback?()
        countdownCompleteCallback = nil
    }

    /// Start the main exercise timer (called after countdown completes)
    func startExerciseTimer(targetDuration: TimeInterval, onComplete: ((TimeInterval) -> Void)? = nil) {
        guard isActive, !isCountdown else { return }

        self.totalDuration = targetDuration
        self.startTime = Date()
        self.timerCompleteCallback = onComplete

        // Start main timer (update every 0.1 seconds for smooth UI)
        timer?.invalidate()
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.mainTimerTick()
            }
        }
        timer = newTimer
        RunLoop.current.add(newTimer, forMode: .common)
    }

    /// Stop the timer and return the final duration
    func stopTimer() -> TimeInterval? {
        guard isActive, !isCountdown else { return nil }

        let finalDuration = elapsedTime

        timer?.invalidate()
        timer = nil
        isActive = false
        startTime = nil

        // Play completion sound (same as rest timer)
        playCompletionSound()

        // Reset state
        timerTick = 0
        exerciseName = ""
        setNumber = 0
        totalDuration = 0

        return finalDuration
    }

    /// Pause the timer (preserves current elapsed time)
    func pauseTimer() {
        guard isActive, !isCountdown else { return }
        timer?.invalidate()
        timer = nil
    }

    /// Resume the timer from paused state
    func resumeTimer() {
        guard isActive, !isCountdown, timer == nil else { return }

        // Recalculate start time to account for paused duration
        if let startTime = startTime {
            let pausedElapsed = Date().timeIntervalSince(startTime)
            self.startTime = Date().addingTimeInterval(-pausedElapsed)
        }

        // Restart timer
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.mainTimerTick()
            }
        }
        timer = newTimer
        RunLoop.current.add(newTimer, forMode: .common)
    }

    /// Cancel the timer without returning a duration
    func cancelTimer() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isCountdown = false
        startTime = nil
        timerTick = 0
        exerciseName = ""
        setNumber = 0
        totalDuration = 0
        countdownCompleteCallback = nil
    }

    // MARK: - Private Methods

    /// Called every second during countdown
    private func countdownTick() {
        guard isCountdown else { return }

        countdownRemaining -= 1
        timerTick &+= 1

        // Haptic feedback for each tick
        impactFeedback.impactOccurred(intensity: 0.3)

        if countdownRemaining <= 0 {
            // Countdown complete - switch to main timer
            timer?.invalidate()
            isCountdown = false

            // Stronger haptic for start
            impactFeedback.impactOccurred(intensity: 0.7)

            // Call completion handler
            countdownCompleteCallback?()
            countdownCompleteCallback = nil
        }
    }

    /// Called every 0.1 seconds during main timer
    private func mainTimerTick() {
        timerTick &+= 1

        // Check if target duration reached - auto-stop timer
        let elapsed = elapsedTime
        if elapsed >= totalDuration {
            // Stop timer at target duration - use actual elapsed time for accuracy
            let finalDuration = elapsed  // Use actual elapsed, not target (may be slightly over due to timer precision)

            timer?.invalidate()
            timer = nil
            isActive = false
            startTime = nil

            // Play completion sound
            playCompletionSound()

            // Haptic feedback
            impactFeedback.impactOccurred(intensity: 0.7)

            // Call completion callback before resetting state
            let callback = timerCompleteCallback

            // Reset state
            timerTick = 0
            exerciseName = ""
            setNumber = 0
            totalDuration = 0
            timerCompleteCallback = nil

            // Notify completion
            callback?(finalDuration)
        }
    }

    /// Play completion sound (reuses rest timer sound)
    private func playCompletionSound() {
        let sound = AppSettings.shared.restNotificationSound
        sound.playSound()
    }
}
