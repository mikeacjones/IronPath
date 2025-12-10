import XCTest
@testable import IronPath

final class CableMachineConfigTests: XCTestCase {

    // MARK: - Base Stack Weight Tests

    func testBaseStackWeightsCalculation() {
        // Given a simple cable machine with 5lb plates
        let config = TestFixtures.simpleCableMachine()

        // Then base stack should include 0 and all cumulative weights
        let weights = config.baseStackWeights
        XCTAssertTrue(weights.contains(0))
        XCTAssertTrue(weights.contains(5))
        XCTAssertTrue(weights.contains(10))
        XCTAssertTrue(weights.contains(200)) // 40 plates x 5lb
    }

    func testBaseStackWeightsAreSorted() {
        // Given any cable machine config
        let config = TestFixtures.tieredCableMachine()

        // Then base stack weights should be sorted ascending
        let weights = config.baseStackWeights
        XCTAssertEqual(weights, weights.sorted())
    }

    func testTieredStackWeightsCalculation() {
        // Given a tiered cable machine
        let config = TestFixtures.tieredCableMachine()

        // Then stack should include weights from both tiers
        let weights = config.baseStackWeights

        // Tier 1: 6 x 9lb = 54 max (9, 18, 27, 36, 45, 54)
        XCTAssertTrue(weights.contains(9))
        XCTAssertTrue(weights.contains(54))

        // Tier 2: adds 12 x 12.5lb = 150 more
        // Total max = 54 + 150 = 204
        XCTAssertTrue(weights.contains(66.5)) // 54 + 12.5
        XCTAssertTrue(weights.contains(204))
    }

    // MARK: - Available Weights Tests

    func testAvailableWeightsWithNoFreeWeights() {
        // Given a cable machine without free weights
        let config = TestFixtures.simpleCableMachine()

        // Then available weights should equal base stack weights
        XCTAssertEqual(config.availableWeights, config.baseStackWeights)
    }

    func testAvailableWeightsWithIntegratedFreeWeights() {
        // Given a cable machine with integrated free weights
        let config = TestFixtures.cableMachineWithIntegratedWeights()

        // Then available weights should include free weight combinations
        let weights = config.availableWeights

        // Should include base weight + free weights
        XCTAssertTrue(weights.contains(5)) // Base stack
        XCTAssertTrue(weights.contains(7.5)) // 5 + 2.5
        XCTAssertTrue(weights.contains(10)) // 5 + 5 or base
        XCTAssertTrue(weights.contains(12.5)) // 10 + 2.5
    }

    func testAvailableWeightsAreSorted() {
        // Given a cable machine with free weights
        let config = TestFixtures.cableMachineWithIntegratedWeights()

        // Then available weights should be sorted
        let weights = config.availableWeights
        XCTAssertEqual(weights, weights.sorted())
    }

    func testAvailableWeightsHaveNoDuplicates() {
        // Given a cable machine config
        let config = TestFixtures.cableMachineWithIntegratedWeights()

        // Then available weights should have no duplicates
        let weights = config.availableWeights
        XCTAssertEqual(weights.count, Set(weights).count)
    }

    func testAvailableWeightsWithMultipleFreeWeightsOfSameType() {
        // Given a cable machine with 3x 5lb free weights
        let config = TestFixtures.cableMachineWithMultipleFreeWeights()

        // Then available weights should include all combinations:
        // Stack only, stack + 5, stack + 10, stack + 15
        let weights = config.availableWeights

        // Base stack weight of 5lbs should have combinations:
        XCTAssertTrue(weights.contains(5))   // Base stack only (pin at 5)
        XCTAssertTrue(weights.contains(10))  // 5 + 5 (one free weight) OR base 10
        XCTAssertTrue(weights.contains(15))  // 5 + 10 (two free weights) OR base 15
        XCTAssertTrue(weights.contains(20))  // 5 + 15 (all three free weights) OR base 20

        // Also verify we can get odd combinations
        XCTAssertTrue(weights.contains(25))  // 10 + 15 (three free weights)
    }

    func testFreeWeightCombinationsWithMixedWeights() {
        // Given a cable machine with 2x 2.5lb and 1x 5lb free weights
        var config = TestFixtures.simpleCableMachine()
        config.freeWeights = [
            CableMachineConfig.FreeWeight(weight: 2.5, count: 2),
            CableMachineConfig.FreeWeight(weight: 5.0, count: 1)
        ]

        let weights = config.availableWeights

        // Should be able to add various combinations to pin at 10:
        XCTAssertTrue(weights.contains(10))    // Pin only
        XCTAssertTrue(weights.contains(12.5))  // 10 + 2.5
        XCTAssertTrue(weights.contains(15))    // 10 + 5 or 10 + 2.5 + 2.5
        XCTAssertTrue(weights.contains(17.5))  // 10 + 5 + 2.5
        XCTAssertTrue(weights.contains(20))    // 10 + 5 + 2.5 + 2.5
    }

    // MARK: - Nearest Weight Tests

    func testNearestWeightExactMatch() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // When finding nearest weight for an exact match
        let nearest = config.nearestWeight(to: 50)

        // Then should return exact weight
        XCTAssertEqual(nearest, 50)
    }

    func testNearestWeightRoundsUp() {
        // Given a cable machine with 5lb increments
        let config = TestFixtures.simpleCableMachine()

        // When finding nearest weight for 52
        let nearest = config.nearestWeight(to: 52)

        // Then should return nearest (either 50 or 55)
        XCTAssertTrue(nearest == 50 || nearest == 55)
    }

    func testNearestWeightRoundsDown() {
        // Given a cable machine with 5lb increments
        let config = TestFixtures.simpleCableMachine()

        // When finding nearest weight for 48
        let nearest = config.nearestWeight(to: 48)

        // Then should return nearest (either 45 or 50)
        XCTAssertTrue(nearest == 45 || nearest == 50)
    }

    func testNearestWeightAtMaximum() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()
        let maxWeight = config.availableWeights.max()!

        // When finding nearest weight above maximum
        let nearest = config.nearestWeight(to: maxWeight + 100)

        // Then should return maximum
        XCTAssertEqual(nearest, maxWeight)
    }

    func testNearestWeightAtMinimum() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // When finding nearest weight for 0
        let nearest = config.nearestWeight(to: 0)

        // Then should return 0 (first available)
        XCTAssertEqual(nearest, 0)
    }

    // MARK: - Weights Near Target Tests

    func testWeightsNearTargetReturnsCorrectCount() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // When getting weights near a target
        let nearby = config.weightsNear(50, count: 5)

        // Then should return requested count (or less if not enough weights)
        XCTAssertLessThanOrEqual(nearby.count, 5)
    }

    func testWeightsNearTargetCentersOnTarget() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // When getting weights near 50
        let nearby = config.weightsNear(50, count: 5)

        // Then 50 should be included
        XCTAssertTrue(nearby.contains(50))
    }

    func testWeightsNearTargetAreSorted() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // When getting weights near any target
        let nearby = config.weightsNear(100, count: 5)

        // Then should be sorted
        XCTAssertEqual(nearby, nearby.sorted())
    }

    // MARK: - Valid Weight Tests

    func testIsValidWeightForExactMatch() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // Then exact stack weights should be valid
        XCTAssertTrue(config.isValidWeight(50))
        XCTAssertTrue(config.isValidWeight(100))
    }

    func testIsValidWeightForNonStackWeight() {
        // Given a simple cable machine (5lb increments)
        let config = TestFixtures.simpleCableMachine()

        // Then non-stack weights should be invalid
        XCTAssertFalse(config.isValidWeight(52))
        XCTAssertFalse(config.isValidWeight(47))
    }

    func testIsValidWeightWithFreeWeights() {
        // Given a cable machine with 2.5lb free weight
        let config = TestFixtures.cableMachineWithIntegratedWeights()

        // Then stack + free weight combinations should be valid
        XCTAssertTrue(config.isValidWeight(52.5)) // 50 + 2.5
        XCTAssertTrue(config.isValidWeight(55)) // 50 + 5
    }

    // MARK: - Weight Breakdown Tests

    func testWeightBreakdownForStackOnly() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // When getting breakdown for a stack-only weight
        let breakdown = config.weightBreakdown(for: 50)

        // Then should return pin position with no free weight
        XCTAssertNotNil(breakdown)
        XCTAssertEqual(breakdown?.pinWeight, 50)
        XCTAssertEqual(breakdown?.freeWeight, 0)
        XCTAssertEqual(breakdown?.pin, 10) // 10th plate for 50lbs at 5lb/plate
    }

    func testWeightBreakdownWithFreeWeight() {
        // Given a cable machine with free weights
        let config = TestFixtures.cableMachineWithIntegratedWeights()

        // When getting breakdown for a weight requiring free weight
        let breakdown = config.weightBreakdown(for: 52.5)

        // Then should return pin position + free weight
        XCTAssertNotNil(breakdown)
        XCTAssertEqual(breakdown!.pinWeight, 50, accuracy: 0.01)
        XCTAssertEqual(breakdown!.freeWeight ?? 0, 2.5, accuracy: 0.01)
    }

    func testWeightBreakdownForInvalidWeight() {
        // Given a simple cable machine (no free weights)
        let config = TestFixtures.simpleCableMachine()

        // When getting breakdown for an invalid weight
        let breakdown = config.weightBreakdown(for: 52)

        // Then should return nil
        XCTAssertNil(breakdown)
    }

    func testWeightBreakdownForZero() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // When getting breakdown for 0
        let breakdown = config.weightBreakdown(for: 0)

        // Then should return nil (0 is not a valid workout weight)
        XCTAssertNil(breakdown)
    }

    // MARK: - Pin Location Tests

    func testPinLocationCalculation() {
        // Given a simple cable machine
        let config = TestFixtures.simpleCableMachine()

        // Then pin locations should be correct
        XCTAssertEqual(config.pinLocation(for: 5), 1)   // First plate
        XCTAssertEqual(config.pinLocation(for: 10), 2)  // Second plate
        XCTAssertEqual(config.pinLocation(for: 50), 10) // Tenth plate
    }

    func testPinLocationForTieredStack() {
        // Given a tiered cable machine
        let config = TestFixtures.tieredCableMachine()

        // Then pin locations should account for tiers
        XCTAssertEqual(config.pinLocation(for: 9), 1)   // First 9lb plate
        XCTAssertEqual(config.pinLocation(for: 54), 6)  // Last of first tier
        XCTAssertEqual(config.pinLocation(for: 66.5), 7) // First of second tier
    }

    func testPinLocationForInvalidWeight() {
        // Given a cable machine
        let config = TestFixtures.simpleCableMachine()

        // When getting pin location for invalid weight
        let pinLocation = config.pinLocation(for: 52)

        // Then should return nil
        XCTAssertNil(pinLocation)
    }

    // MARK: - Pin Info Tests

    func testPinInfoForWeight() {
        // Given a tiered cable machine
        let config = TestFixtures.tieredCableMachine()

        // When getting pin info for a first-tier weight
        let info = config.pinInfo(for: 27)

        // Then should return detailed tier info
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.pinNumber, 3)
        XCTAssertTrue(info?.tierDescription.contains("9") ?? false) // 9lb plates
    }

    func testPinInfoWithFreeWeight() {
        // Given a cable machine with free weights
        let config = TestFixtures.cableMachineWithIntegratedWeights()

        // When getting pin info for a weight requiring free weight
        let info = config.pinInfo(for: 52.5)

        // Then should include free weight amount
        XCTAssertNotNil(info)
        XCTAssertEqual(info!.freeWeight ?? 0, 2.5, accuracy: 0.01)
    }

    // MARK: - Default Config Tests

    func testDefaultConfig() {
        // When creating default config
        let config = CableMachineConfig.defaultConfig

        // Then should have reasonable defaults
        XCTAssertEqual(config.name, "Default Cable Machine")
        XCTAssertFalse(config.plateTiers.isEmpty)
        XCTAssertGreaterThan(config.availableWeights.count, 0)
    }

    func testLatPulldownExample() {
        // When creating lat pulldown example
        let config = CableMachineConfig.latPulldownExample

        // Then should have tiered configuration
        XCTAssertEqual(config.name, "Lat Pulldown")
        XCTAssertEqual(config.plateTiers.count, 2)
    }

    // MARK: - Stack Description Tests

    func testStackDescriptionFormat() {
        // Given a simple cable machine
        let config = TestFixtures.simpleCableMachine()

        // Then description should include plate info
        let description = config.stackDescription
        XCTAssertTrue(description.contains("40"))
        XCTAssertTrue(description.contains("5"))
    }

    func testStackDescriptionWithFreeWeights() {
        // Given a cable machine with free weights
        let config = TestFixtures.cableMachineWithIntegratedWeights()

        // Then description should include free weights info
        let description = config.stackDescription
        XCTAssertTrue(description.contains("free"))
        XCTAssertTrue(description.contains("2.5") || description.contains("5"))
    }

    // MARK: - Edge Cases

    func testEmptyPlateTiers() {
        // Given a cable machine with no plates
        let config = CableMachineConfig(name: "Empty", plateTiers: [])

        // Then should still have 0 in weights
        XCTAssertEqual(config.baseStackWeights, [0])
    }

    func testSinglePlate() {
        // Given a cable machine with single plate
        let config = CableMachineConfig(
            name: "Single",
            plateTiers: [CableMachineConfig.PlateTier(plateWeight: 10, plateCount: 1)]
        )

        // Then should have 0 and 10
        XCTAssertEqual(config.baseStackWeights, [0, 10])
    }

    func testFreeWeightsWithConfig() {
        // Given a cable machine with free weights
        let config = TestFixtures.cableMachineWithFreeWeights()

        // Then free weights should return configured weights
        XCTAssertEqual(config.freeWeights.count, 2)
        XCTAssertTrue(config.freeWeights.contains { $0.weight == 2.5 && $0.count == 1 })
        XCTAssertTrue(config.freeWeights.contains { $0.weight == 5.0 && $0.count == 1 })
    }

    func testFreeWeightsEmpty() {
        // Given a simple cable machine with no free weights
        let config = TestFixtures.simpleCableMachine()

        // Then free weights should be empty
        XCTAssertTrue(config.freeWeights.isEmpty)
    }
}
