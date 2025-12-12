import Foundation

/// Represents the similarity score between two exercises
struct ExerciseSimilarity: Codable, Identifiable, Hashable {
    var id: String { exerciseName }
    let exerciseName: String
    let score: Double  // 0.0 to 1.0

    /// Formatted percentage string for display
    var percentageString: String {
        return "\(Int(score * 100))%"
    }
}

/// Container for pre-calculated similarity data loaded from JSON
struct ExerciseSimilarityData: Codable {
    let version: String
    let generatedAt: Date
    let similarities: [String: [ExerciseSimilarity]]  // exerciseName -> sorted similarities

    static let currentVersion = "1.0"
}

/// Equipment categories for similarity grouping
enum EquipmentCategory: String, CaseIterable {
    case freeWeights = "Free Weights"
    case machines = "Machines"
    case bodyweight = "Bodyweight"
    case accessories = "Accessories"

    /// Get the category for a given equipment type
    static func category(for equipment: Equipment) -> EquipmentCategory {
        switch equipment {
        case .barbell, .dumbbells, .kettlebells, .trapBar:
            return .freeWeights
        case .cables, .legPress, .smithMachine:
            return .machines
        case .bodyweightOnly, .pullUpBar:
            return .bodyweight
        case .resistanceBands, .bench, .squat:
            return .accessories
        }
    }

    /// Get the category for a specific machine (always machines)
    static func category(for machine: SpecificMachine) -> EquipmentCategory {
        return .machines
    }

    /// Calculate similarity between two equipment setups
    /// - Returns: 1.0 for same equipment, 0.75 for same category, 0.25 for different category
    static func similarity(
        equipment1: Equipment,
        machine1: SpecificMachine?,
        equipment2: Equipment,
        machine2: SpecificMachine?
    ) -> Double {
        // Exact equipment match
        if equipment1 == equipment2 {
            // If both have specific machines, check those too
            if let m1 = machine1, let m2 = machine2 {
                return m1 == m2 ? 1.0 : 0.75
            }
            return 1.0
        }

        // Same category
        let cat1 = category(for: equipment1)
        let cat2 = category(for: equipment2)

        if cat1 == cat2 {
            return 0.5
        }

        // Different category - but some relationships are closer
        // Free weights and bodyweight are both "functional"
        if (cat1 == .freeWeights && cat2 == .bodyweight) ||
           (cat1 == .bodyweight && cat2 == .freeWeights) {
            return 0.35
        }

        return 0.25
    }
}
