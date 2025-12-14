import Foundation

// MARK: - Weight Converter

/// Utility for formatting and converting weight values
struct WeightConverter {

    // MARK: - Formatting

    /// Format a weight value with its unit
    /// - Parameters:
    ///   - weight: The weight value to format
    ///   - unit: The unit of the weight
    ///   - includeUnit: Whether to include the unit symbol (default: true)
    ///   - decimalPlaces: Number of decimal places to show (default: auto-detect)
    /// - Returns: Formatted weight string (e.g., "100 lbs", "45.5 kg")
    static func format(
        _ weight: Double,
        unit: WeightUnit,
        includeUnit: Bool = true,
        decimalPlaces: Int? = nil
    ) -> String {
        // Auto-detect decimal places if not specified
        let places: Int
        if let decimalPlaces = decimalPlaces {
            places = decimalPlaces
        } else {
            // Show decimals only if needed
            places = weight.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = places
        formatter.maximumFractionDigits = places

        let formattedNumber = formatter.string(from: NSNumber(value: weight)) ?? "\(weight)"

        if includeUnit {
            return "\(formattedNumber) \(unit.abbreviation)"
        } else {
            return formattedNumber
        }
    }

    /// Format a weight with multiplier hint (e.g., "20 lbs per arm")
    /// - Parameters:
    ///   - weight: The weight value
    ///   - unit: The unit of the weight
    ///   - multiplier: The exercise multiplier
    /// - Returns: Formatted string with multiplier hint if applicable
    static func formatWithMultiplier(
        _ weight: Double,
        unit: WeightUnit,
        multiplier: Double
    ) -> String {
        let baseFormat = format(weight, unit: unit)

        if multiplier > 1.0 {
            return "\(baseFormat) per arm"
        } else {
            return baseFormat
        }
    }

    // MARK: - Conversion

    /// Convert a weight value from one unit to another
    /// - Parameters:
    ///   - weight: The weight to convert
    ///   - from: The source unit
    ///   - to: The target unit
    /// - Returns: The converted weight value
    static func convert(_ weight: Double, from: WeightUnit, to: WeightUnit) -> Double {
        WeightUnit.convert(weight, from: from, to: to)
    }

    // MARK: - Rounding

    /// Round a weight to the nearest common increment for its unit
    /// - Parameters:
    ///   - weight: The weight to round
    ///   - unit: The unit of the weight
    /// - Returns: Rounded weight value
    static func roundToNearestIncrement(_ weight: Double, unit: WeightUnit) -> Double {
        let increment: Double
        switch unit {
        case .pounds:
            // Round to nearest 2.5 lbs for < 50, 5 lbs for >= 50
            increment = weight < 50 ? 2.5 : 5.0
        case .kilograms:
            // Round to nearest 1.25 kg for < 20, 2.5 kg for >= 20
            increment = weight < 20 ? 1.25 : 2.5
        }

        return (weight / increment).rounded() * increment
    }

    /// Round a weight to a specific increment
    /// - Parameters:
    ///   - weight: The weight to round
    ///   - increment: The increment to round to (e.g., 2.5, 5.0)
    /// - Returns: Rounded weight value
    static func round(_ weight: Double, to increment: Double) -> Double {
        guard increment > 0 else { return weight }
        return (weight / increment).rounded() * increment
    }

    // MARK: - Validation

    /// Check if a weight value is valid
    /// - Parameter weight: The weight to validate
    /// - Returns: True if weight is valid (positive, finite)
    static func isValid(_ weight: Double) -> Bool {
        weight > 0 && weight.isFinite
    }

    /// Clamp a weight value to a reasonable range
    /// - Parameters:
    ///   - weight: The weight to clamp
    ///   - min: Minimum weight (default: 0)
    ///   - max: Maximum weight (default: 1000 for lbs, 500 for kg)
    ///   - unit: The unit (for determining reasonable max)
    /// - Returns: Clamped weight value
    static func clamp(
        _ weight: Double,
        min: Double = 0,
        max: Double? = nil,
        unit: WeightUnit
    ) -> Double {
        let maxValue = max ?? (unit == .pounds ? 1000 : 500)
        return Swift.max(min, Swift.min(weight, maxValue))
    }
}

// MARK: - Helper for Formatting Weights

/// Global helper function for formatting weights (convenience wrapper)
/// - Parameters:
///   - weight: The weight value
///   - unit: The unit to use (default: pounds)
/// - Returns: Formatted weight string
func formatWeight(_ weight: Double, unit: WeightUnit = .pounds) -> String {
    WeightConverter.format(weight, unit: unit)
}
