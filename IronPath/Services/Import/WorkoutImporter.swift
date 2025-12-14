import Foundation

// MARK: - Workout Import Protocol

/// Protocol for importing workouts from various sources (FitBod, Strong, Hevy, etc.)
protocol WorkoutImporter {
    /// The name of the import source (e.g., "FitBod", "Strong", "Hevy")
    var sourceName: String { get }

    /// Supported file extensions (e.g., ["csv"], ["json"])
    var supportedFileExtensions: [String] { get }

    /// Parse imported data into ParsedWorkout objects
    /// - Parameter data: The raw file data (CSV, JSON, etc.)
    /// - Returns: Array of parsed workouts
    /// - Throws: ParseError if the data cannot be parsed
    func parse(_ data: String) async throws -> [ParsedWorkout]

    /// Detect the weight unit used in the source data
    /// - Parameter data: The raw file data
    /// - Returns: The detected weight unit, or nil if cannot be determined
    func detectWeightUnit(_ data: String) -> WeightUnit?
}

// MARK: - Default Implementations

extension WorkoutImporter {
    /// Default implementation returns nil (unit must be specified by user)
    func detectWeightUnit(_ data: String) -> WeightUnit? {
        nil
    }
}

// MARK: - Common Parse Errors

/// Errors that can occur during workout import parsing
enum WorkoutImportError: LocalizedError {
    case invalidFormat(source: String, details: String)
    case missingRequiredData(source: String, field: String)
    case unsupportedFormat(source: String)
    case emptyFile(source: String)
    case invalidDate(source: String, value: String)
    case invalidNumber(source: String, field: String, value: String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let source, let details):
            return "[\(source)] Invalid format: \(details)"
        case .missingRequiredData(let source, let field):
            return "[\(source)] Missing required field: \(field)"
        case .unsupportedFormat(let source):
            return "[\(source)] Unsupported file format"
        case .emptyFile(let source):
            return "[\(source)] File is empty"
        case .invalidDate(let source, let value):
            return "[\(source)] Invalid date format: \(value)"
        case .invalidNumber(let source, let field, let value):
            return "[\(source)] Invalid number in \(field): \(value)"
        }
    }
}

// MARK: - Import Source Registry

/// Registry of available workout import sources
@MainActor
final class WorkoutImportRegistry {
    static let shared = WorkoutImportRegistry()

    private var importers: [WorkoutImporter] = []

    private init() {
        // Register default importers
        registerImporter(FitBodCSVImporter())
    }

    /// Register a new importer
    func registerImporter(_ importer: WorkoutImporter) {
        importers.append(importer)
    }

    /// Get all registered importers
    func availableImporters() -> [WorkoutImporter] {
        importers
    }

    /// Find importer by source name
    func importer(for sourceName: String) -> WorkoutImporter? {
        importers.first { $0.sourceName == sourceName }
    }

    /// Find importer that supports a file extension
    func importer(forFileExtension ext: String) -> WorkoutImporter? {
        importers.first { $0.supportedFileExtensions.contains(ext.lowercased()) }
    }
}
