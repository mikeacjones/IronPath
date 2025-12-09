import Foundation

// MARK: - Anthropic Provider

/// AI Provider implementation for Anthropic's Claude models
class AnthropicProvider: AIProvider {

    // MARK: - AIProvider Properties

    var id: String { AIProviderType.anthropic.rawValue }

    var displayName: String { "Anthropic" }

    var iconName: String { "brain.head.profile" }

    var availableModels: [AIModel] {
        [
            AIModel(
                id: "claude-haiku-4-5-20251001",
                displayName: "Claude 4.5 Haiku",
                description: "Fastest & cheapest - Good for most workouts",
                costTier: .low,
                providerId: id
            ),
            AIModel(
                id: "claude-sonnet-4-20250514",
                displayName: "Claude 4 Sonnet",
                description: "Balanced - Better reasoning",
                costTier: .medium,
                providerId: id
            ),
            AIModel(
                id: "claude-opus-4-20250514",
                displayName: "Claude 4 Opus",
                description: "Most capable - Best for complex requests",
                costTier: .high,
                providerId: id
            )
        ]
    }

    var selectedModel: AIModel {
        get {
            let selectedId = AIProviderManager.shared.selectedModelId
            return availableModels.first { $0.id == selectedId } ?? availableModels[0]
        }
        set {
            AIProviderManager.shared.selectModel(newValue)
        }
    }

    var isConfigured: Bool {
        AIProviderManager.shared.hasAPIKey(for: .anthropic)
    }

    var apiKeyURL: URL? {
        URL(string: "https://console.anthropic.com")
    }

    var setupInstructions: String {
        "Get your API key from console.anthropic.com. Claude is excellent at understanding workout context and creating personalized training programs."
    }

    // MARK: - API Key Access

    var apiKey: String? {
        AIProviderManager.shared.getAPIKey(for: .anthropic)
    }

    // MARK: - AIProvider Methods

    func generateWorkout(
        profile: UserProfile,
        targetMuscleGroups: Set<MuscleGroup>?,
        workoutHistory: [Workout],
        workoutType: String?,
        userNotes: String?,
        isDeload: Bool,
        allowDeloadRecommendation: Bool,
        availableExercises: [Exercise]
    ) async throws -> Workout {
        // Delegate to existing AnthropicService
        return try await AnthropicService.shared.generateWorkout(
            profile: profile,
            targetMuscleGroups: targetMuscleGroups,
            workoutHistory: workoutHistory,
            workoutType: workoutType,
            userNotes: userNotes,
            isDeload: isDeload,
            allowDeloadRecommendation: allowDeloadRecommendation
        )
    }

    func replaceExercise(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout,
        availableExercises: [Exercise]
    ) async throws -> WorkoutExercise {
        return try await AnthropicService.shared.replaceExercise(
            exercise: exercise,
            profile: profile,
            reason: reason,
            currentWorkout: currentWorkout
        )
    }

    func getFormTips(exercise: Exercise, userLevel: FitnessLevel) async throws -> String {
        return try await AnthropicService.shared.getFormTips(
            exercise: exercise,
            userLevel: userLevel
        )
    }

    func generateCustomExercise(
        description: String,
        profile: UserProfile
    ) async throws -> Exercise {
        return try await AnthropicService.shared.generateCustomExercise(
            prompt: description,
            availableEquipment: profile.availableEquipment
        )
    }

    func estimateCaloriesBurned(workoutSummary: String) async throws -> Int {
        return try await AnthropicService.shared.estimateCaloriesBurned(
            workoutSummary: workoutSummary
        )
    }
}
