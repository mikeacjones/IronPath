import XCTest
@testable import IronPath

final class ExerciseSetCompletionTests: XCTestCase {
    func testCompleteForHistoricalEntry_CompletesRepBasedSetWithTargetReps() {
        var set = ExerciseSet(
            setNumber: 1,
            setType: .standard,
            targetReps: 10,
            actualReps: nil,
            weight: 135,
            restPeriod: 90
        )
        let completedAt = Date()

        set.completeForHistoricalEntry(at: completedAt)

        XCTAssertEqual(set.actualReps, 10)
        XCTAssertEqual(set.completedAt, completedAt)
        XCTAssertTrue(set.isCompleted)
    }

    func testCompleteForHistoricalEntry_CompletesTimedSetWithActualDuration() {
        var set = ExerciseSet(
            setNumber: 1,
            setType: .timed,
            targetReps: 0,
            actualReps: 12,
            weight: 25,
            restPeriod: 60,
            timedSetConfig: TimedSetConfig(targetDuration: 45, actualDuration: nil, addedWeight: 25)
        )
        let completedAt = Date()

        set.completeForHistoricalEntry(at: completedAt)

        XCTAssertNil(set.actualReps)
        XCTAssertEqual(set.timedSetConfig?.actualDuration, 45)
        XCTAssertEqual(set.completedAt, completedAt)
        XCTAssertTrue(set.isCompleted)
    }

    func testCompleteForHistoricalEntry_CreatesTimedConfigWhenMissing() {
        var set = ExerciseSet(
            setNumber: 1,
            setType: .timed,
            targetReps: 0,
            actualReps: nil,
            weight: nil,
            restPeriod: 60
        )

        set.completeForHistoricalEntry(at: Date())

        XCTAssertEqual(set.timedSetConfig?.targetDuration, 30)
        XCTAssertEqual(set.timedSetConfig?.actualDuration, 30)
        XCTAssertTrue(set.isCompleted)
    }
}
