import Foundation

// MARK: - Weight Unit

/// Represents the unit of measurement for weights
enum WeightUnit: String, Codable, CaseIterable, Sendable {
    case pounds = "lbs"
    case kilograms = "kg"

    // MARK: - Display Properties

    /// Full name of the unit
    var displayName: String {
        switch self {
        case .pounds: return "Pounds"
        case .kilograms: return "Kilograms"
        }
    }

    /// Short abbreviation
    var abbreviation: String {
        self.rawValue
    }

    /// Symbol for display (same as abbreviation)
    var symbol: String {
        self.rawValue
    }

    // MARK: - Conversion Constants

    /// Conversion factor: 1 kg = 2.20462 lbs
    static let lbsPerKg: Double = 2.20462

    /// Conversion factor: 1 lb = 0.453592 kg
    static let kgPerLb: Double = 0.453592

    // MARK: - Conversion Methods

    /// Convert a weight value from one unit to another
    /// - Parameters:
    ///   - weight: The weight value to convert
    ///   - from: The source unit
    ///   - to: The target unit
    /// - Returns: The converted weight value
    static func convert(_ weight: Double, from: WeightUnit, to: WeightUnit) -> Double {
        // If same unit, no conversion needed
        guard from != to else { return weight }

        switch (from, to) {
        case (.pounds, .kilograms):
            return weight * kgPerLb
        case (.kilograms, .pounds):
            return weight * lbsPerKg
        default:
            return weight
        }
    }

    /// Convert a weight from this unit to another unit
    /// - Parameters:
    ///   - weight: The weight value
    ///   - to: The target unit
    /// - Returns: The converted weight
    func convert(_ weight: Double, to: WeightUnit) -> Double {
        WeightUnit.convert(weight, from: self, to: to)
    }

    // MARK: - Formatting

    /// Format a weight value with this unit's abbreviation
    /// Shows decimals only when they exist (e.g., 245.5 -> "245.5kg", 245.0 -> "245kg")
    /// - Parameter weight: The weight value to format
    /// - Returns: Formatted string with weight and unit
    func format(_ weight: Double) -> String {
        "\(WeightConverter.format(weight, unit: self, includeUnit: false))\(rawValue)"
    }

    /// Format a weight value with a space before the unit
    /// Shows decimals only when they exist (e.g., 245.5 -> "245.5 kg", 245.0 -> "245 kg")
    /// - Parameter weight: The weight value to format
    /// - Returns: Formatted string with weight and unit separated by space
    func formatWithSpace(_ weight: Double) -> String {
        WeightConverter.format(weight, unit: self)
    }
}
