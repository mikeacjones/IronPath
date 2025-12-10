import Foundation
import SwiftUI

// MARK: - Cable Machine Configuration

/// Represents a cable machine's weight stack configuration
struct CableMachineConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String  // e.g., "Lat Pulldown", "Cable Crossover"
    var plateTiers: [PlateTier]  // Different plate tiers with their own weights

    struct PlateTier: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var plateWeight: Double  // Weight per plate in this tier
        var plateCount: Int      // Number of plates in this tier
    }

    /// Calculate all available weights for this machine
    var availableWeights: [Double] {
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
        plateTiers.map { "\($0.plateCount)×\(formatWeight($0.plateWeight))lb" }.joined(separator: " + ")
    }

    /// Check if a specific weight is achievable with this configuration
    func isValidWeight(_ weight: Double) -> Bool {
        availableWeights.contains(weight)
    }

    /// Get the pin location (plate number) for a given weight
    /// Returns nil if the weight is not achievable
    func pinLocation(for weight: Double) -> Int? {
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

    /// Get detailed pin info including which tier
    func pinInfo(for weight: Double) -> (pinNumber: Int, tierDescription: String)? {
        guard weight > 0 else { return nil }

        var currentWeight: Double = 0
        var plateNumber = 0
        var tierIndex = 0
        var platesInCurrentTier = 0

        for tier in plateTiers {
            for plateInTier in 0..<tier.plateCount {
                plateNumber += 1
                platesInCurrentTier = plateInTier + 1
                currentWeight += tier.plateWeight
                if abs(currentWeight - weight) < 0.01 {
                    let tierDesc = "Plate \(platesInCurrentTier) of \(tier.plateCount) @ \(formatWeight(tier.plateWeight))lb"
                    return (plateNumber, tierDesc)
                }
            }
            tierIndex += 1
            platesInCurrentTier = 0
        }

        return nil
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

