import Foundation
import UIKit
import UserNotifications
import Combine

// MARK: - Rest Timer Manager

/// Manages a global rest timer that persists when navigating away from exercise detail
class RestTimerManager: ObservableObject {
    static let shared = RestTimerManager()

    @Published var isActive: Bool = false
    @Published var totalDuration: TimeInterval = 0
    @Published var exerciseName: String = ""
    @Published var setNumber: Int = 0
    @Published var showCompletionBanner: Bool = false

    /// The absolute time when the timer should complete
    private var endTime: Date?
    private var timer: Timer?
    private var notificationObserver: NSObjectProtocol?

    private init() {
        requestNotificationPermission()
        setupAppLifecycleObservers()
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

        // Schedule local notification for when timer completes
        scheduleCompletionNotification(in: duration)

        startDisplayTimer()
    }

    func addTime(_ seconds: TimeInterval) {
        guard let currentEndTime = endTime else { return }
        endTime = currentEndTime.addingTimeInterval(seconds)
        totalDuration += seconds

        // Reschedule notification
        cancelScheduledNotification()
        scheduleCompletionNotification(in: remainingTime)
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

        // Auto-hide banner after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.showCompletionBanner = false
        }
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
        content.sound = .default

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
