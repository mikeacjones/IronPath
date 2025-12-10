import Foundation
import SwiftUI

// MARK: - Cable Machine Configuration

/// Represents a cable machine's weight stack configuration
struct CableMachineConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String  // e.g., "Lat Pulldown", "Cable Crossover"
    var plateTiers: [PlateTier]  // Different plate tiers with their own weights

    /// Free weights available on this machine (e.g., add-on plates)
    /// Each entry tracks a weight value and how many of that weight are available
    var freeWeights: [FreeWeight] = []

    struct PlateTier: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var plateWeight: Double  // Weight per plate in this tier
        var plateCount: Int      // Number of plates in this tier
    }

    /// Represents a free weight add-on for a cable machine
    struct FreeWeight: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var weight: Double  // Weight in lbs (e.g., 5.0)
        var count: Int      // How many of this weight are available (e.g., 3)

        /// Total weight if all of this type are used
        var totalWeight: Double {
            weight * Double(count)
        }
    }

    /// Calculate the base stack weights (without free weights)
    var baseStackWeights: [Double] {
        var weights: [Double] = [0]
        var currentWeight: Double = 0

        for tier in plateTiers {
            for _ in 0..<tier.plateCount {
                currentWeight += tier.plateWeight
                weights.append(currentWeight)
            }
        }

        return weights.sorted()
    }

    /// Calculate all possible free weight combinations
    /// Returns array of total add-on weights possible (e.g., [0, 5, 10, 15] for 3x5lb)
    private var freeWeightCombinations: [Double] {
        guard !freeWeights.isEmpty else { return [0] }

        var combinations: Set<Double> = [0]

        // Generate all combinations of free weights
        // For each free weight type, we can use 0, 1, 2, ... count of them
        func generateCombinations(index: Int, currentTotal: Double) {
            if index >= freeWeights.count {
                combinations.insert(currentTotal)
                return
            }

            let fw = freeWeights[index]
            for numUsed in 0...fw.count {
                let addedWeight = Double(numUsed) * fw.weight
                generateCombinations(index: index + 1, currentTotal: currentTotal + addedWeight)
            }
        }

        generateCombinations(index: 0, currentTotal: 0)
        return Array(combinations).sorted()
    }

    /// Calculate all available weights including free weight combinations
    var availableWeights: [Double] {
        let stackWeights = baseStackWeights
        var allWeights = Set<Double>()

        // For each stack weight, add all possible free weight combinations
        let freeWeightOptions = freeWeightCombinations
        for stackWeight in stackWeights {
            for freeWeightTotal in freeWeightOptions {
                allWeights.insert(stackWeight + freeWeightTotal)
            }
        }

        return Array(allWeights).sorted()
    }

    /// Find the nearest available weight
    func nearestWeight(to target: Double) -> Double {
        let weights = availableWeights
        guard !weights.isEmpty else { return target }
        return weights.min(by: { abs($0 - target) < abs($1 - target) }) ?? target
    }

    /// Get weights near target for selection UI
    func weightsNear(_ target: Double, count: Int = 5) -> [Double] {
        let weights = availableWeights
        guard let nearestIndex = weights.firstIndex(where: { $0 >= target }) else {
            return Array(weights.suffix(count))
        }

        let startIndex = max(0, nearestIndex - count/2)
        let endIndex = min(weights.count, startIndex + count)
        return Array(weights[startIndex..<endIndex])
    }

    /// Default cable machine config (simple 5lb increments)
    static var defaultConfig: CableMachineConfig {
        CableMachineConfig(
            name: "Default Cable Machine",
            plateTiers: [PlateTier(plateWeight: 5.0, plateCount: 40)]
        )
    }

    /// Example: Lat pulldown with 6x9lb then 12.5lb plates
    static var latPulldownExample: CableMachineConfig {
        CableMachineConfig(
            name: "Lat Pulldown",
            plateTiers: [
                PlateTier(plateWeight: 9.0, plateCount: 6),
                PlateTier(plateWeight: 12.5, plateCount: 12)
            ]
        )
    }

    /// Human-readable description of the weight stack
    var stackDescription: String {
        var desc = plateTiers.map { "\($0.plateCount)×\(formatWeight($0.plateWeight))lb" }.joined(separator: " + ")
        if !freeWeights.isEmpty {
            let freeWeightStr = freeWeights.map { "\($0.count)×\(formatWeight($0.weight))lb" }.joined(separator: ", ")
            desc += " + free: \(freeWeightStr)"
        }
        return desc
    }

    /// Check if a specific weight is achievable with this configuration
    func isValidWeight(_ weight: Double) -> Bool {
        availableWeights.contains { abs($0 - weight) < 0.01 }
    }

    /// Get the breakdown of a weight into pin position and free weight total
    /// Returns nil if the weight is not achievable
    func weightBreakdown(for weight: Double) -> (pin: Int, pinWeight: Double, freeWeight: Double)? {
        guard weight > 0 else { return nil }

        // Try each possible free weight combination
        for freeWeightTotal in freeWeightCombinations {
            let stackWeight = weight - freeWeightTotal
            if stackWeight >= 0, let pin = pinLocationForStackWeight(stackWeight) {
                return (pin, stackWeight, freeWeightTotal)
            }
        }

        return nil
    }

    /// Get the pin location (plate number) for a given stack weight (without free weights)
    private func pinLocationForStackWeight(_ weight: Double) -> Int? {
        guard weight > 0 else { return nil }

        var currentWeight: Double = 0
        var plateNumber = 0

        for tier in plateTiers {
            for _ in 0..<tier.plateCount {
                plateNumber += 1
                currentWeight += tier.plateWeight
                if abs(currentWeight - weight) < 0.01 {
                    return plateNumber
                }
            }
        }

        return nil
    }

    /// Get the pin location (plate number) for a given weight
    /// Returns nil if the weight is not achievable
    func pinLocation(for weight: Double) -> Int? {
        // First check if it's an exact stack weight
        if let pin = pinLocationForStackWeight(weight) {
            return pin
        }

        // Check if it's achievable with free weights
        if let breakdown = weightBreakdown(for: weight) {
            return breakdown.pin
        }

        return nil
    }

    /// Get detailed pin info including which tier and any free weight
    func pinInfo(for weight: Double) -> (pinNumber: Int, tierDescription: String, freeWeight: Double)? {
        guard weight > 0 else { return nil }

        // Get the weight breakdown
        guard let breakdown = weightBreakdown(for: weight) else {
            return nil
        }

        // Handle case where pin weight is 0 (only free weights used)
        if breakdown.pinWeight == 0 {
            return (0, "No pin (free weights only)", breakdown.freeWeight)
        }

        // Now find the tier info for the stack weight
        var currentWeight: Double = 0
        var plateNumber = 0
        var platesInCurrentTier = 0

        for tier in plateTiers {
            for plateInTier in 0..<tier.plateCount {
                plateNumber += 1
                platesInCurrentTier = plateInTier + 1
                currentWeight += tier.plateWeight
                if abs(currentWeight - breakdown.pinWeight) < 0.01 {
                    let tierDesc = "Plate \(platesInCurrentTier) of \(tier.plateCount) @ \(formatWeight(tier.plateWeight))lb"
                    return (plateNumber, tierDesc, breakdown.freeWeight)
                }
            }
            platesInCurrentTier = 0
        }

        return nil
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }

    // MARK: - Migration from old format

    /// Migrate from old integratedFreeWeights array format
    mutating func migrateFromLegacyFormat(integratedFreeWeights: [Double]) {
        // Count occurrences of each weight
        var weightCounts: [Double: Int] = [:]
        for weight in integratedFreeWeights {
            weightCounts[weight, default: 0] += 1
        }

        // Convert to new FreeWeight format
        freeWeights = weightCounts.map { FreeWeight(weight: $0.key, count: $0.value) }
            .sorted { $0.weight < $1.weight }
    }
}
