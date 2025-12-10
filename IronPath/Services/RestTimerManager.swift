import Foundation
import UIKit
import UserNotifications
import Combine
import AudioToolbox

// MARK: - Rest Timer Manager

/// Manages a global rest timer that persists when navigating away from exercise detail
/// Timer state is persisted to UserDefaults so it survives app restarts
class RestTimerManager: ObservableObject {
    static let shared = RestTimerManager()

    // UserDefaults keys for persistence
    private let endTimeKey = "rest_timer_end_time"
    private let totalDurationKey = "rest_timer_total_duration"
    private let exerciseNameKey = "rest_timer_exercise_name"
    private let setNumberKey = "rest_timer_set_number"
    private let isGroupTimerKey = "rest_timer_is_group"
    private let groupTypeKey = "rest_timer_group_type"
    private let nextExerciseNameKey = "rest_timer_next_exercise"

    @Published var isActive: Bool = false
    @Published var totalDuration: TimeInterval = 0
    @Published var exerciseName: String = ""
    @Published var setNumber: Int = 0
    @Published var showCompletionBanner: Bool = false

    // Superset/Circuit tracking
    @Published var isGroupTimer: Bool = false
    @Published var groupType: ExerciseGroupType?
    @Published var nextExerciseName: String?  // Next exercise in superset to do

    /// The absolute time when the timer should complete
    private var endTime: Date?
    private var timer: Timer?
    private var notificationObserver: NSObjectProtocol?

    private init() {
        requestNotificationPermission()
        setupAppLifecycleObservers()
        restoreTimerState()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Remaining time calculated from endTime - ensures accuracy even after app backgrounding
    var remainingTime: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remainingTime / totalDuration)
    }

    var formattedTime: String {
        let time = remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func startTimer(duration: TimeInterval, exerciseName: String, setNumber: Int) {
        stopTimer()

        self.totalDuration = duration
        self.endTime = Date().addingTimeInterval(duration)
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.isActive = true
        self.showCompletionBanner = false
        self.isGroupTimer = false
        self.groupType = nil
        self.nextExerciseName = nil

        // Persist state for app restart recovery
        persistTimerState()

        // Schedule local notification for when timer completes
        scheduleCompletionNotification(in: duration)

        startDisplayTimer()
    }

    /// Start a rest timer after completing all exercises in a superset/circuit round
    func startGroupTimer(
        duration: TimeInterval,
        groupType: ExerciseGroupType,
        exerciseNames: [String],
        completedRound: Int
    ) {
        stopTimer()

        self.totalDuration = duration
        self.endTime = Date().addingTimeInterval(duration)
        self.exerciseName = exerciseNames.joined(separator: " → ")
        self.setNumber = completedRound
        self.isActive = true
        self.showCompletionBanner = false
        self.isGroupTimer = true
        self.groupType = groupType
        self.nextExerciseName = exerciseNames.first

        // Persist state for app restart recovery
        persistTimerState()

        scheduleGroupCompletionNotification(in: duration, groupType: groupType)
        startDisplayTimer()
    }

    func addTime(_ seconds: TimeInterval) {
        guard let currentEndTime = endTime else { return }
        endTime = currentEndTime.addingTimeInterval(seconds)
        totalDuration += seconds

        // Persist updated state
        persistTimerState()

        // Reschedule notification
        cancelScheduledNotification()
        scheduleCompletionNotification(in: remainingTime)
    }

    /// Set the rest time to a specific duration
    /// Adjusts the current timer if active
    func setRestTime(_ newDuration: TimeInterval) {
        guard isActive, endTime != nil else { return }

        // Calculate how much time has already elapsed
        let elapsedTime = totalDuration - remainingTime

        // Set new total duration
        totalDuration = newDuration

        // If we've already rested longer than the new duration, keep at least 5 seconds
        let newRemainingTime = max(5, newDuration - elapsedTime)

        // Update end time based on new remaining time
        endTime = Date().addingTimeInterval(newRemainingTime)

        // Persist updated state
        persistTimerState()

        // Reschedule notification
        cancelScheduledNotification()
        scheduleCompletionNotification(in: newRemainingTime)
    }

    func skipTimer() {
        cancelScheduledNotification()
        stopTimer()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        endTime = nil
        isActive = false
        isGroupTimer = false
        groupType = nil
        nextExerciseName = nil
        clearPersistedState()
    }

    // MARK: - Persistence

    /// Save timer state to UserDefaults for restoration after app restart
    private func persistTimerState() {
        let defaults = UserDefaults.standard

        if let endTime = endTime {
            defaults.set(endTime.timeIntervalSince1970, forKey: endTimeKey)
            defaults.set(totalDuration, forKey: totalDurationKey)
            defaults.set(exerciseName, forKey: exerciseNameKey)
            defaults.set(setNumber, forKey: setNumberKey)
            defaults.set(isGroupTimer, forKey: isGroupTimerKey)
            if let groupType = groupType {
                defaults.set(groupType.rawValue, forKey: groupTypeKey)
            }
            if let nextExercise = nextExerciseName {
                defaults.set(nextExercise, forKey: nextExerciseNameKey)
            }
        }
    }

    /// Clear persisted timer state
    private func clearPersistedState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: endTimeKey)
        defaults.removeObject(forKey: totalDurationKey)
        defaults.removeObject(forKey: exerciseNameKey)
        defaults.removeObject(forKey: setNumberKey)
        defaults.removeObject(forKey: isGroupTimerKey)
        defaults.removeObject(forKey: groupTypeKey)
        defaults.removeObject(forKey: nextExerciseNameKey)
    }

    /// Restore timer state from UserDefaults after app restart
    private func restoreTimerState() {
        let defaults = UserDefaults.standard

        let endTimeInterval = defaults.double(forKey: endTimeKey)
        guard endTimeInterval > 0 else { return }

        let restoredEndTime = Date(timeIntervalSince1970: endTimeInterval)

        // Check if timer has already expired
        if restoredEndTime.timeIntervalSinceNow <= 0 {
            // Timer expired while app was closed - show completion banner briefly
            clearPersistedState()
            showCompletionBanner = true
            // Play sound for expired timer
            playCompletionSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.showCompletionBanner = false
            }
            return
        }

        // Restore timer state
        self.endTime = restoredEndTime
        self.totalDuration = defaults.double(forKey: totalDurationKey)
        self.exerciseName = defaults.string(forKey: exerciseNameKey) ?? ""
        self.setNumber = defaults.integer(forKey: setNumberKey)
        self.isGroupTimer = defaults.bool(forKey: isGroupTimerKey)

        if let groupTypeRaw = defaults.string(forKey: groupTypeKey) {
            self.groupType = ExerciseGroupType(rawValue: groupTypeRaw)
        }
        self.nextExerciseName = defaults.string(forKey: nextExerciseNameKey)

        self.isActive = true
        startDisplayTimer()
    }

    /// Start the display timer that updates the UI
    private func startDisplayTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Force UI update
            self.objectWillChange.send()

            // Check if timer completed
            if self.remainingTime <= 0 {
                self.timerCompleted()
            }
        }
    }

    private func timerCompleted() {
        stopTimer()
        showCompletionBanner = true

        // Play sound even when app is in foreground
        playCompletionSound()

        // Auto-hide banner after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.showCompletionBanner = false
        }
    }

    /// Play the configured completion sound
    private func playCompletionSound() {
        let sound = AppSettings.shared.restNotificationSound
        sound.playSound()
    }

    // MARK: - App Lifecycle

    private func setupAppLifecycleObservers() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppForeground()
        }
    }

    private func handleAppForeground() {
        guard isActive else { return }

        // Check if timer already completed while backgrounded
        if remainingTime <= 0 {
            timerCompleted()
        } else {
            // Restart display timer to continue updating UI
            startDisplayTimer()
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleCompletionNotification(in seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Time for your next set of \(exerciseName)!"

        // Use configured notification sound
        let soundSetting = AppSettings.shared.restNotificationSound
        if let notificationSound = soundSetting.notificationSound {
            content.sound = notificationSound
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "rest_timer_completion",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleGroupCompletionNotification(in seconds: TimeInterval, groupType: ExerciseGroupType) {
        let content = UNMutableNotificationContent()
        content.title = "\(groupType.displayName) Rest Complete"
        if let nextExercise = nextExerciseName {
            content.body = "Time for round \(setNumber + 1)! Start with \(nextExercise)"
        } else {
            content.body = "Time for your next round!"
        }

        // Use configured notification sound
        let soundSetting = AppSettings.shared.restNotificationSound
        if let notificationSound = soundSetting.notificationSound {
            content.sound = notificationSound
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "rest_timer_completion",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelScheduledNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest_timer_completion"])
    }
}
