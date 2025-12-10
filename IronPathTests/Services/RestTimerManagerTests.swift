import XCTest
@testable import IronPath

final class RestTimerManagerTests: XCTestCase {

    var mockTimer: MockRestTimerManager!

    override func setUp() {
        super.setUp()
        mockTimer = MockRestTimerManager()
    }

    override func tearDown() {
        mockTimer.reset()
        mockTimer = nil
        super.tearDown()
    }

    // MARK: - Start Timer Tests

    func testStartTimerSetsState() {
        // When starting a timer
        mockTimer.startTimer(duration: 90, exerciseName: "Bench Press", setNumber: 1)

        // Then state should be properly set
        XCTAssertTrue(mockTimer.startTimerCalled)
        XCTAssertTrue(mockTimer.isActive)
        XCTAssertEqual(mockTimer.totalDuration, 90)
        XCTAssertEqual(mockTimer.exerciseName, "Bench Press")
        XCTAssertEqual(mockTimer.setNumber, 1)
    }

    func testStartTimerClearsPreviousTimer() {
        // Given an existing timer
        mockTimer.startTimer(duration: 60, exerciseName: "Old Exercise", setNumber: 1)

        // When starting a new timer
        mockTimer.startTimer(duration: 90, exerciseName: "New Exercise", setNumber: 2)

        // Then new timer should replace old
        XCTAssertEqual(mockTimer.exerciseName, "New Exercise")
        XCTAssertEqual(mockTimer.setNumber, 2)
        XCTAssertEqual(mockTimer.totalDuration, 90)
    }

    // MARK: - Remaining Time Tests

    func testRemainingTimeCalculation() {
        // Given a timer with known remaining time
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(45)

        // Then remaining time should be correct
        XCTAssertEqual(mockTimer.remainingTime, 45, accuracy: 1.0)
    }

    func testRemainingTimeIsZeroWhenInactive() {
        // Given no active timer
        mockTimer.isActive = false

        // Then remaining time should be 0
        XCTAssertEqual(mockTimer.remainingTime, 0)
    }

    func testRemainingTimeNeverNegative() {
        // Given a timer that has "expired"
        mockTimer.startTimer(duration: 1, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(-10)

        // Then remaining time should be 0, not negative
        XCTAssertGreaterThanOrEqual(mockTimer.remainingTime, 0)
    }

    // MARK: - Progress Tests

    func testProgressCalculation() {
        // Given a timer halfway through
        mockTimer.totalDuration = 100
        mockTimer.startTimer(duration: 100, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(50)

        // Then progress should be 0.5
        XCTAssertEqual(mockTimer.progress, 0.5, accuracy: 0.01)
    }

    func testProgressIsZeroWhenStarting() {
        // Given a freshly started timer
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(90)

        // Then progress should be near 0
        XCTAssertEqual(mockTimer.progress, 0, accuracy: 0.01)
    }

    func testProgressIsOneWhenComplete() {
        // Given a completed timer
        mockTimer.totalDuration = 90
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(0)

        // Then progress should be 1
        XCTAssertEqual(mockTimer.progress, 1, accuracy: 0.01)
    }

    func testProgressHandlesZeroDuration() {
        // Given a timer with zero duration
        mockTimer.totalDuration = 0

        // Then progress should be 0 (not crash)
        XCTAssertEqual(mockTimer.progress, 0)
    }

    // MARK: - Formatted Time Tests

    func testFormattedTimeFormat() {
        // Given a timer with 90 seconds remaining
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(90)

        // Then formatted time should be "1:30"
        XCTAssertEqual(mockTimer.formattedTime, "1:30")
    }

    func testFormattedTimeWithZeroMinutes() {
        // Given a timer with 45 seconds remaining
        mockTimer.startTimer(duration: 45, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(45)

        // Then formatted time should be "0:45"
        XCTAssertEqual(mockTimer.formattedTime, "0:45")
    }

    func testFormattedTimeWithSingleDigitSeconds() {
        // Given a timer with 5 seconds remaining
        mockTimer.startTimer(duration: 5, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(5)

        // Then seconds should be zero-padded
        XCTAssertEqual(mockTimer.formattedTime, "0:05")
    }

    func testFormattedTimeWithLargerDuration() {
        // Given a timer with 3 minutes 15 seconds
        mockTimer.startTimer(duration: 195, exerciseName: "Test", setNumber: 1)
        mockTimer.setRemainingTime(195)

        // Then formatted time should be "3:15"
        XCTAssertEqual(mockTimer.formattedTime, "3:15")
    }

    // MARK: - Add Time Tests

    func testAddTimeExtendsTimer() {
        // Given an active timer
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)
        let initialDuration = mockTimer.totalDuration

        // When adding time
        mockTimer.addTime(30)

        // Then timer should be extended
        XCTAssertTrue(mockTimer.addTimeCalled)
        XCTAssertEqual(mockTimer.lastAddedTime, 30)
        XCTAssertEqual(mockTimer.totalDuration, initialDuration + 30)
    }

    func testAddNegativeTimeReducesTimer() {
        // Given an active timer
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)

        // When adding negative time
        mockTimer.addTime(-15)

        // Then timer should be reduced
        XCTAssertEqual(mockTimer.totalDuration, 75)
    }

    // MARK: - Skip Timer Tests

    func testSkipTimerStops() {
        // Given an active timer
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)

        // When skipping
        mockTimer.skipTimer()

        // Then timer should be stopped
        XCTAssertTrue(mockTimer.skipTimerCalled)
        XCTAssertFalse(mockTimer.isActive)
    }

    // MARK: - Stop Timer Tests

    func testStopTimer() {
        // Given an active timer
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)

        // When stopping
        mockTimer.stopTimer()

        // Then timer should be inactive
        XCTAssertTrue(mockTimer.stopTimerCalled)
        XCTAssertFalse(mockTimer.isActive)
    }

    // MARK: - Timer Completion Tests

    func testTimerCompletedShowsBanner() {
        // Given an active timer
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)

        // When timer completes
        mockTimer.simulateCompletion()

        // Then banner should be shown
        XCTAssertTrue(mockTimer.showCompletionBanner)
        XCTAssertFalse(mockTimer.isActive)
    }

    func testCompletionBannerNotShownWhenSkipped() {
        // Given an active timer
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)

        // When skipping (not completing)
        mockTimer.skipTimer()

        // Then banner should not be shown
        XCTAssertFalse(mockTimer.showCompletionBanner)
    }

    // MARK: - State Management Tests

    func testInitialState() {
        // When first created
        let freshTimer = MockRestTimerManager()

        // Then should be inactive
        XCTAssertFalse(freshTimer.isActive)
        XCTAssertEqual(freshTimer.totalDuration, 0)
        XCTAssertEqual(freshTimer.exerciseName, "")
        XCTAssertEqual(freshTimer.setNumber, 0)
        XCTAssertFalse(freshTimer.showCompletionBanner)
    }

    func testResetClearsAllState() {
        // Given a timer with state
        mockTimer.startTimer(duration: 90, exerciseName: "Test", setNumber: 1)
        mockTimer.addTime(30)
        mockTimer.simulateCompletion()

        // When resetting
        mockTimer.reset()

        // Then all state should be cleared
        XCTAssertFalse(mockTimer.isActive)
        XCTAssertEqual(mockTimer.totalDuration, 0)
        XCTAssertEqual(mockTimer.exerciseName, "")
        XCTAssertFalse(mockTimer.startTimerCalled)
        XCTAssertFalse(mockTimer.addTimeCalled)
        XCTAssertFalse(mockTimer.showCompletionBanner)
    }

    // MARK: - Concurrent Timer Tests

    func testOnlyOneTimerCanBeActive() {
        // Given starting multiple timers in sequence
        mockTimer.startTimer(duration: 60, exerciseName: "Exercise 1", setNumber: 1)
        mockTimer.startTimer(duration: 90, exerciseName: "Exercise 2", setNumber: 2)
        mockTimer.startTimer(duration: 120, exerciseName: "Exercise 3", setNumber: 3)

        // Then only the last timer should be active
        XCTAssertEqual(mockTimer.exerciseName, "Exercise 3")
        XCTAssertEqual(mockTimer.totalDuration, 120)
    }

    // MARK: - Edge Cases

    func testAddTimeWhenInactive() {
        // Given inactive timer
        mockTimer.isActive = false

        // When adding time
        mockTimer.addTime(30)

        // Then should handle gracefully (no crash)
        XCTAssertTrue(mockTimer.addTimeCalled)
    }

    func testVeryShortDuration() {
        // Given a very short timer
        mockTimer.startTimer(duration: 1, exerciseName: "Quick", setNumber: 1)

        // Then should handle properly
        XCTAssertTrue(mockTimer.isActive)
        XCTAssertEqual(mockTimer.totalDuration, 1)
    }

    func testVeryLongDuration() {
        // Given a very long timer (10 minutes)
        mockTimer.startTimer(duration: 600, exerciseName: "Long Rest", setNumber: 1)
        mockTimer.setRemainingTime(600)

        // Then should handle properly
        XCTAssertEqual(mockTimer.formattedTime, "10:00")
    }
}
