import Foundation
import SwiftUI

// MARK: - AI Provider Protocol

/// Protocol that all AI providers must implement to generate workouts
/// This abstraction allows easy addition of new providers (OpenAI, local models, etc.)
protocol AIProvider {
    /// Unique identifier for this provider
    var id: String { get }

    /// Display name for the UI
    var displayName: String { get }

    /// Icon name (SF Symbol)
    var iconName: String { get }

    /// Available models for this provider
    var availableModels: [AIModel] { get }

    /// Currently selected model
    var selectedModel: AIModel { get set }

    /// Check if the provider is configured (has API key, etc.)
    var isConfigured: Bool { get }

    /// URL for getting an API key
    var apiKeyURL: URL? { get }

    /// Instructions for setting up this provider
    var setupInstructions: String { get }

    /// Generate a workout using this provider
    func generateWorkout(
        profile: UserProfile,
        targetMuscleGroups: Set<MuscleGroup>?,
        workoutHistory: [Workout],
        workoutType: String?,
        userNotes: String?,
        isDeload: Bool,
        allowDeloadRecommendation: Bool,
        techniqueOptions: WorkoutGenerationOptions
    ) async throws -> Workout

    /// Replace an exercise in a workout
    func replaceExercise(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout
    ) async throws -> WorkoutExercise

    /// Get form tips for an exercise
    func getFormTips(exercise: Exercise, userLevel: FitnessLevel) async throws -> String

    /// Generate a custom exercise from a description
    func generateCustomExercise(
        description: String,
        profile: UserProfile
    ) async throws -> Exercise

    /// Estimate calories burned for a workout
    func estimateCaloriesBurned(workoutSummary: String) async throws -> Int
}

// MARK: - AI Model

/// Represents a specific model within an AI provider
struct AIModel: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let description: String
    let costTier: CostTier
    let providerId: String

    enum CostTier: String, Codable {
        case low = "$"
        case medium = "$$"
        case high = "$$$"
        case veryHigh = "$$$$"
    }
}

// MARK: - AI Provider Type

/// Enum of supported AI providers for persistence and identification
enum AIProviderType: String, CaseIterable, Codable {
    case anthropic = "anthropic"
    case openai = "openai"

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI (GPT)"
        }
    }

    var iconName: String {
        switch self {
        case .anthropic: return "brain.head.profile"
        case .openai: return "sparkles"
        }
    }
}

// MARK: - AI Provider Errors

enum AIProviderError: LocalizedError {
    case notConfigured
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String?)
    case parseError(detail: String?)
    case unsupportedOperation
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI provider is not configured. Please add your API key in settings."
        case .missingAPIKey:
            return "API key is missing. Please add your API key in settings."
        case .invalidResponse:
            return "Received an invalid response from the AI provider."
        case .apiError(let code, let message):
            if let msg = message {
                return "API error (\(code)): \(msg)"
            }
            return "API error with status code: \(code)"
        case .parseError(let detail):
            if let d = detail {
                return "Failed to parse response: \(d)"
            }
            return "Failed to parse the AI response."
        case .unsupportedOperation:
            return "This operation is not supported by the current AI provider."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
