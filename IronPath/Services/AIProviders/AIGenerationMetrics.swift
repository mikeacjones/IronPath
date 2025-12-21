import Foundation
import OSLog

/// Tracks quality metrics for AI workout generation
/// Used to measure parse errors, generation success rate, and refinement impact
@MainActor
final class AIGenerationMetrics {
    static let shared = AIGenerationMetrics()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kotrs.IronPath", category: "AIMetrics")

    // MARK: - Metrics Counters

    private(set) var totalGenerations: Int = 0
    private(set) var successfulGenerations: Int = 0
    private(set) var parseErrors: Int = 0
    private(set) var refinementPasses: Int = 0
    private(set) var refinementImprovements: Int = 0

    private init() {}

    // MARK: - Recording Methods

    func recordGenerationStart() {
        totalGenerations += 1
        logger.info("Generation started. Total: \(self.totalGenerations)")
    }

    func recordGenerationSuccess() {
        successfulGenerations += 1
        logger.info("Generation succeeded. Success rate: \(self.successRate)%")
    }

    func recordParseError(context: String) {
        parseErrors += 1
        logger.error("Parse error: \(context). Total errors: \(self.parseErrors)")
    }

    func recordRefinementPass(hadImprovements: Bool) {
        refinementPasses += 1
        if hadImprovements {
            refinementImprovements += 1
        }
        logger.info("Refinement pass. Improvement rate: \(self.refinementImprovementRate)%")
    }

    // MARK: - Computed Metrics

    var successRate: Double {
        guard totalGenerations > 0 else { return 0 }
        return Double(successfulGenerations) / Double(totalGenerations) * 100
    }

    var parseErrorRate: Double {
        guard totalGenerations > 0 else { return 0 }
        return Double(parseErrors) / Double(totalGenerations) * 100
    }

    var refinementImprovementRate: Double {
        guard refinementPasses > 0 else { return 0 }
        return Double(refinementImprovements) / Double(refinementPasses) * 100
    }

    // MARK: - Summary

    func logSummary() {
        logger.info("""
        AI Generation Metrics Summary:
        - Total generations: \(self.totalGenerations)
        - Success rate: \(self.successRate)%
        - Parse error rate: \(self.parseErrorRate)%
        - Refinement passes: \(self.refinementPasses)
        - Refinement improvement rate: \(self.refinementImprovementRate)%
        """)
    }

    func reset() {
        totalGenerations = 0
        successfulGenerations = 0
        parseErrors = 0
        refinementPasses = 0
        refinementImprovements = 0
    }
}
