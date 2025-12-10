import XCTest
@testable import IronPath

final class ExerciseSetTests: XCTestCase {

    // MARK: - Standard Set Tests

    func testStandardSetIsCompletedWhenBothFieldsSet() {
        // Given a standard set with actualReps and completedAt
        let set = TestFixtures.completedSet(weight: 100, actualReps: 10)

        // Then isCompleted should be true
        XCTAssertTrue(set.isCompleted)
    }

    func testStandardSetIsNotCompletedWithoutActualReps() {
        // Given a standard set without actualReps
        let set = ExerciseSet(
            setNumber: 1,
            setType: .standard,
            targetReps: 10,
            actualReps: nil,
            weight: 100,
            completedAt: Date()
        )

        // Then isCompleted should be false
        XCTAssertFalse(set.isCompleted)
    }

    func testStandardSetIsNotCompletedWithoutCompletedAt() {
        // Given a standard set without completedAt
        let set = ExerciseSet(
            setNumber: 1,
            setType: .standard,
            targetReps: 10,
            actualReps: 10,
            weight: 100,
            completedAt: nil
        )

        // Then isCompleted should be false
        XCTAssertFalse(set.isCompleted)
    }

    func testStandardSetTotalActualReps() {
        // Given a completed standard set
        let set = TestFixtures.completedSet(actualReps: 12)

        // Then totalActualReps should match actualReps
        XCTAssertEqual(set.totalActualReps, 12)
    }

    func testStandardSetTotalVolume() {
        // Given a completed standard set
        let set = TestFixtures.completedSet(weight: 135, actualReps: 8)

        // Then totalVolume should be weight x reps
        XCTAssertEqual(set.totalVolume, 1080, accuracy: 0.001)
    }

    // MARK: - Warmup Set Tests

    func testWarmupSetIsCompletedWhenBothFieldsSet() {
        // Given a completed warmup set
        let set = TestFixtures.warmupSet(weight: 50, isCompleted: true)

        // Then isCompleted should be true
        XCTAssertTrue(set.isCompleted)
    }

    func testWarmupSetIsNotCompletedWithoutCompletedAt() {
        // Given an incomplete warmup set
        let set = TestFixtures.warmupSet(weight: 50, isCompleted: false)

        // Then isCompleted should be false
        XCTAssertFalse(set.isCompleted)
    }

    func testWarmupSetType() {
        // Given a warmup set
        let set = TestFixtures.warmupSet()

        // Then setType should be warmup
        XCTAssertEqual(set.setType, .warmup)
    }

    // MARK: - Drop Set Tests

    func testDropSetIsNotCompletedWhenNoDropsComplete() {
        // Given a drop set with no completed drops
        let set = TestFixtures.sampleDropSet(allCompleted: false)

        // Then isCompleted should be false
        XCTAssertFalse(set.isCompleted)
    }

    func testDropSetIsCompletedWhenAllDropsComplete() {
        // Given a drop set with all drops completed
        let set = TestFixtures.sampleDropSet(allCompleted: true)

        // Then isCompleted should be true
        XCTAssertTrue(set.isCompleted)
    }

    func testDropSetTotalActualReps() {
        // Given a completed drop set (3 drops x 8 reps each)
        let set = TestFixtures.sampleDropSet(
            targetReps: 8,
            numberOfDrops: 2, // Initial + 2 drops = 3 total
            allCompleted: true
        )

        // Then totalActualReps should sum all drops
        // 3 drops x 8 reps = 24 reps
        XCTAssertEqual(set.totalActualReps, 24)
    }

    func testDropSetTotalVolumeCalculation() {
        // Given a completed drop set
        let set = TestFixtures.sampleDropSet(
            startingWeight: 100,
            targetReps: 8,
            numberOfDrops: 2,
            allCompleted: true
        )

        // Then totalVolume should sum volume from all drops
        // Drop 0: 100 x 8 = 800
        // Drop 1: 80 x 8 = 640
        // Drop 2: 65 x 8 = 520
        // Total = 1960
        let expectedVolume = (100.0 * 8) + (80.0 * 8) + (65.0 * 8)
        XCTAssertEqual(set.totalVolume, expectedVolume, accuracy: 0.001)
    }

    func testDropSetConfigSuggestedWeights() {
        // Given a drop set config
        let config = DropSetConfig(numberOfDrops: 2, dropPercentage: 0.2)

        // When calculating suggested weights
        let weights = config.suggestedWeights(startingWeight: 100)

        // Then weights should decrease by 20% each drop
        XCTAssertEqual(weights.count, 3)
        XCTAssertEqual(weights[0], 100, accuracy: 0.001)
        XCTAssertEqual(weights[1], 80, accuracy: 0.1) // Rounded
        XCTAssertLessThan(weights[2], weights[1])
    }

    func testDropSetConfigWithDifferentPercentage() {
        // Given a drop set config with 25% reduction
        let config = DropSetConfig(numberOfDrops: 2, dropPercentage: 0.25)

        // When calculating suggested weights
        let weights = config.suggestedWeights(startingWeight: 100)

        // Then first drop should be ~75
        XCTAssertEqual(weights[1], 75, accuracy: 1.0) // Allow rounding
    }

    // MARK: - Rest-Pause Set Tests

    func testRestPauseSetIsNotCompletedWhenNoMiniSetsComplete() {
        // Given a rest-pause set with no completed mini-sets
        let set = TestFixtures.sampleRestPauseSet(allCompleted: false)

        // Then isCompleted should be false
        XCTAssertFalse(set.isCompleted)
    }

    func testRestPauseSetIsCompletedWhenAllMiniSetsComplete() {
        // Given a rest-pause set with all mini-sets completed
        let set = TestFixtures.sampleRestPauseSet(allCompleted: true)

        // Then isCompleted should be true
        XCTAssertTrue(set.isCompleted)
    }

    func testRestPauseSetTotalActualReps() {
        // Given a completed rest-pause set
        let set = TestFixtures.sampleRestPauseSet(
            targetReps: 8,
            numberOfPauses: 2,
            allCompleted: true
        )

        // Then totalActualReps should sum all mini-sets
        // Initial: 8 reps + 2 pauses x 4 reps each = 16 reps
        XCTAssertEqual(set.totalActualReps, 16)
    }

    func testRestPauseSetTotalVolume() {
        // Given a completed rest-pause set
        let set = TestFixtures.sampleRestPauseSet(
            weight: 100,
            targetReps: 8,
            numberOfPauses: 2,
            allCompleted: true
        )

        // Then totalVolume should be weight x total reps
        // 100 lbs x 16 total reps = 1600 lbs
        XCTAssertEqual(set.totalVolume, 1600, accuracy: 0.001)
    }

    func testRestPauseConfigTotalActualReps() {
        // Given a rest-pause config with completed mini-sets
        var config = RestPauseConfig(numberOfPauses: 2, pauseDuration: 15)
        config.miniSets = [
            RestPauseMiniSet(miniSetNumber: 0, targetReps: 8, actualReps: 8, completedAt: Date()),
            RestPauseMiniSet(miniSetNumber: 1, targetReps: 4, actualReps: 5, completedAt: Date()),
            RestPauseMiniSet(miniSetNumber: 2, targetReps: 4, actualReps: 3, completedAt: Date())
        ]

        // Then totalActualReps should sum all mini-sets
        XCTAssertEqual(config.totalActualReps, 16) // 8 + 5 + 3
    }

    // MARK: - Set Type Properties Tests

    func testSetTypeDisplayNames() {
        XCTAssertEqual(SetType.standard.displayName, "Standard")
        XCTAssertEqual(SetType.warmup.displayName, "Warmup")
        XCTAssertEqual(SetType.dropSet.displayName, "Drop Set")
        XCTAssertEqual(SetType.restPause.displayName, "Rest-Pause")
    }

    func testSetTypeShortNames() {
        XCTAssertEqual(SetType.standard.shortName, "STD")
        XCTAssertEqual(SetType.warmup.shortName, "W")
        XCTAssertEqual(SetType.dropSet.shortName, "DROP")
        XCTAssertEqual(SetType.restPause.shortName, "RP")
    }

    func testSetTypeIconNames() {
        XCTAssertFalse(SetType.standard.iconName.isEmpty)
        XCTAssertFalse(SetType.warmup.iconName.isEmpty)
        XCTAssertFalse(SetType.dropSet.iconName.isEmpty)
        XCTAssertFalse(SetType.restPause.iconName.isEmpty)
    }

    // MARK: - Factory Method Tests

    func testCreateDropSetFactory() {
        // Given parameters for a drop set
        let set = ExerciseSet.createDropSet(
            setNumber: 1,
            targetReps: 8,
            weight: 100,
            numberOfDrops: 2
        )

        // Then set should be properly configured
        XCTAssertEqual(set.setType, .dropSet)
        XCTAssertNotNil(set.dropSetConfig)
        XCTAssertEqual(set.dropSetConfig?.numberOfDrops, 2)
        XCTAssertEqual(set.dropSetConfig?.drops.count, 3) // Initial + 2 drops
    }

    func testCreateRestPauseSetFactory() {
        // Given parameters for a rest-pause set
        let set = ExerciseSet.createRestPauseSet(
            setNumber: 1,
            targetReps: 8,
            weight: 100,
            numberOfPauses: 2,
            pauseDuration: 20
        )

        // Then set should be properly configured
        XCTAssertEqual(set.setType, .restPause)
        XCTAssertNotNil(set.restPauseConfig)
        XCTAssertEqual(set.restPauseConfig?.numberOfPauses, 2)
        XCTAssertEqual(set.restPauseConfig?.pauseDuration, 20)
        XCTAssertEqual(set.restPauseConfig?.miniSets.count, 3) // Initial + 2 pauses
    }

    func testCreateWarmupSetFactory() {
        // Given parameters for a warmup set
        let set = ExerciseSet.createWarmupSet(
            setNumber: 1,
            targetReps: 12,
            weight: 45,
            restPeriod: 45
        )

        // Then set should be properly configured
        XCTAssertEqual(set.setType, .warmup)
        XCTAssertEqual(set.targetReps, 12)
        XCTAssertEqual(set.weight, 45)
        XCTAssertEqual(set.restPeriod, 45)
    }

    // MARK: - Edge Cases

    func testSetWithNoWeight() {
        // Given a bodyweight set with no weight
        let set = ExerciseSet(
            setNumber: 1,
            setType: .standard,
            targetReps: 15,
            actualReps: 15,
            weight: nil,
            completedAt: Date()
        )

        // Then volume should be 0 (no weight tracked)
        XCTAssertEqual(set.totalVolume, 0)
    }

    func testDropSetWithPartialCompletion() {
        // Given a drop set with only some drops completed
        var config = DropSetConfig(numberOfDrops: 2, dropPercentage: 0.2)
        config.drops = [
            DropSetEntry(dropNumber: 0, targetWeight: 100, actualWeight: 100, targetReps: 8, actualReps: 8, completedAt: Date()),
            DropSetEntry(dropNumber: 1, targetWeight: 80, targetReps: 8), // Not completed
            DropSetEntry(dropNumber: 2, targetWeight: 65, targetReps: 8)  // Not completed
        ]

        let set = ExerciseSet(
            setNumber: 1,
            setType: .dropSet,
            targetReps: 8,
            weight: 100,
            dropSetConfig: config
        )

        // Then isCompleted should be false
        XCTAssertFalse(set.isCompleted)

        // And totalActualReps should only count completed drops
        XCTAssertEqual(set.totalActualReps, 8)
    }

    func testRestPauseSetWithPartialCompletion() {
        // Given a rest-pause set with partial completion
        var config = RestPauseConfig(numberOfPauses: 2, pauseDuration: 15)
        config.miniSets = [
            RestPauseMiniSet(miniSetNumber: 0, targetReps: 8, actualReps: 8, completedAt: Date()),
            RestPauseMiniSet(miniSetNumber: 1, targetReps: 4, actualReps: 4, completedAt: Date()),
            RestPauseMiniSet(miniSetNumber: 2, targetReps: 4) // Not completed
        ]

        let set = ExerciseSet(
            setNumber: 1,
            setType: .restPause,
            targetReps: 8,
            weight: 100,
            restPauseConfig: config
        )

        // Then isCompleted should be false
        XCTAssertFalse(set.isCompleted)

        // And totalActualReps should only count completed mini-sets
        XCTAssertEqual(set.totalActualReps, 12) // 8 + 4
    }
}
