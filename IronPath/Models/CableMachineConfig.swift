import Foundation
import SwiftUI

// MARK: - Cable Machine Configuration

/// Represents a cable machine's weight stack configuration
struct CableMachineConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String  // e.g., "Lat Pulldown", "Cable Crossover"
    var plateTiers: [PlateTier]  // Different plate tiers with their own weights

    /// Integrated free weights that are part of this specific machine
    /// (e.g., built-in 2.5lb or 5lb add-on plates that can't be moved)
    var integratedFreeWeights: [Double] = []

    /// Whether this machine uses floating free weights from the gym's global pool
    /// (mutually exclusive with integrated free weights)
    var usesFloatingFreeWeights: Bool = false

    struct PlateTier: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var plateWeight: Double  // Weight per plate in this tier
        var plateCount: Int      // Number of plates in this tier
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

    /// Get the effective free weights for this machine
    /// Returns integrated free weights if set, or floating free weights from GymSettings if enabled
    var effectiveFreeWeights: [Double] {
        if !integratedFreeWeights.isEmpty {
            return integratedFreeWeights
        } else if usesFloatingFreeWeights {
            return GymSettings.shared.floatingCableFreeWeights
        }
        return []
    }

    /// Calculate all available weights including free weight combinations
    var availableWeights: [Double] {
        let stackWeights = baseStackWeights
        var allWeights = Set(stackWeights)

        // Add free weight combinations
        let freeWeights = effectiveFreeWeights
        for freeWeight in freeWeights {
            for stackWeight in stackWeights {
                allWeights.insert(stackWeight + freeWeight)
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
        let freeWeights = effectiveFreeWeights
        if !freeWeights.isEmpty {
            let freeWeightStr = freeWeights.map { formatWeight($0) }.joined(separator: ", ")
            desc += " + free weights: \(freeWeightStr)lb"
        }
        return desc
    }

    /// Check if a specific weight is achievable with this configuration
    func isValidWeight(_ weight: Double) -> Bool {
        availableWeights.contains { abs($0 - weight) < 0.01 }
    }

    /// Get the breakdown of a weight into pin position and free weight
    /// Returns nil if the weight is not achievable
    func weightBreakdown(for weight: Double) -> (pin: Int, pinWeight: Double, freeWeight: Double)? {
        guard weight > 0 else { return nil }

        // First try to find exact stack match (no free weight needed)
        if let pin = pinLocationForStackWeight(weight) {
            return (pin, weight, 0)
        }

        // Try free weight combinations
        for freeWeight in effectiveFreeWeights {
            let stackWeight = weight - freeWeight
            if stackWeight >= 0, let pin = pinLocationForStackWeight(stackWeight) {
                return (pin, stackWeight, freeWeight)
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
}
