import Foundation

// MARK: - Anthropic Provider

/// AI Provider implementation for Anthropic's Claude models
class AnthropicProvider: AIProvider {

    // MARK: - Constants

    private let baseURL = "https://api.anthropic.com/v1"

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

    private var apiKey: String? {
        AIProviderManager.shared.getAPIKey(for: .anthropic)
    }

    private var modelId: String {
        AIProviderManager.shared.currentModelId
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
        techniqueOptions: WorkoutGenerationOptions
    ) async throws -> Workout {
        // Get available equipment
        let availableEquipment: Set<Equipment>
        if let gymProfile = GymProfileManager.shared.activeProfile {
            availableEquipment = gymProfile.availableEquipment
        } else {
            availableEquipment = profile.availableEquipment
        }

        // Determine target muscles
        let targetMuscles: Set<MuscleGroup>
        if let specified = targetMuscleGroups, !specified.isEmpty {
            targetMuscles = specified
        } else if let workoutType = workoutType, let type = WorkoutType(rawValue: workoutType) {
            targetMuscles = type.targetMuscleGroups
        } else {
            targetMuscles = Set(MuscleGroup.allCases)
        }

        // Get available exercises formatted for prompt
        let availableExercises = AIProviderHelpers.getAvailableExercisesPrompt(
            muscleGroups: targetMuscles,
            availableEquipment: availableEquipment,
            workoutHistory: workoutHistory
        )

        let systemPrompt = AIProviderHelpers.buildWorkoutSystemPrompt(
            profile: profile,
            isDeload: isDeload,
            allowDeloadRecommendation: allowDeloadRecommendation,
            techniqueOptions: techniqueOptions
        )

        let userPrompt = AIProviderHelpers.buildWorkoutUserPrompt(
            workoutType: workoutType,
            targetMuscleGroups: targetMuscles,
            userNotes: userNotes,
            workoutHistory: workoutHistory,
            isDeload: isDeload,
            allowDeloadRecommendation: allowDeloadRecommendation,
            availableExercises: availableExercises
        )

        let response = try await sendMessage(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        return try AIProviderHelpers.parseWorkoutResponse(response, prompt: userPrompt)
    }

    func replaceExercise(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout
    ) async throws -> WorkoutExercise {
        // Get available equipment
        let availableEquipment: Set<Equipment>
        if let gymProfile = GymProfileManager.shared.activeProfile {
            availableEquipment = gymProfile.availableEquipment
        } else {
            availableEquipment = profile.availableEquipment
        }

        // Get available exercises for the same muscle groups
        let availableExercises = AIProviderHelpers.getAvailableExercisesPrompt(
            muscleGroups: exercise.exercise.primaryMuscleGroups,
            availableEquipment: availableEquipment,
            workoutHistory: []
        )

        let prompt = AIProviderHelpers.buildExerciseReplacementPrompt(
            exercise: exercise,
            profile: profile,
            reason: reason,
            currentWorkout: currentWorkout,
            availableExercises: availableExercises
        )

        let response = try await sendMessage(
            systemPrompt: "You are a fitness expert. Respond only with valid JSON - no markdown, no explanations.",
            userPrompt: prompt
        )

        return try AIProviderHelpers.parseExerciseReplacementResponse(response, originalExercise: exercise)
    }

    func getFormTips(exercise: Exercise, userLevel: FitnessLevel) async throws -> String {
        let prompt = AIProviderHelpers.buildFormTipsPrompt(exercise: exercise, userLevel: userLevel)

        let response = try await sendMessage(
            systemPrompt: "You are an experienced personal trainer providing form guidance. Be concise and practical.",
            userPrompt: prompt
        )

        return response
    }

    func generateCustomExercise(
        description: String,
        profile: UserProfile
    ) async throws -> Exercise {
        let prompt = AIProviderHelpers.buildCustomExercisePrompt(
            description: description,
            availableEquipment: profile.availableEquipment
        )

        let response = try await sendMessage(
            systemPrompt: "You are a fitness expert. Respond only with valid JSON - no markdown, no explanations.",
            userPrompt: prompt
        )

        return try AIProviderHelpers.parseCustomExerciseResponse(response)
    }

    func estimateCaloriesBurned(workoutSummary: String) async throws -> Int {
        let prompt = AIProviderHelpers.buildCalorieEstimationPrompt(workoutSummary: workoutSummary)

        let response = try await sendMessage(
            systemPrompt: "You are a fitness expert. Respond with only a number.",
            userPrompt: prompt
        )

        return AIProviderHelpers.parseCalorieEstimation(response)
    }

    // MARK: - API Communication

    private func sendMessage(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIProviderError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": modelId,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData

        // Debug logging
        let requestHeaders = [
            "Content-Type": "application/json",
            "x-api-key": "[REDACTED]",
            "anthropic-version": "2023-06-01"
        ]
        let requestBodyString = String(data: requestBodyData, encoding: .utf8) ?? ""

        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)

        guard let httpResponse = response as? HTTPURLResponse else {
            APIDebugManager.shared.log(APILogEntry(
                endpoint: url.absoluteString,
                method: "POST",
                requestHeaders: requestHeaders,
                requestBody: requestBodyString,
                error: "Invalid response type",
                duration: duration
            ))
            throw AIProviderError.invalidResponse
        }

        let responseBodyString = String(data: data, encoding: .utf8) ?? ""

        // Log the request
        APIDebugManager.shared.log(APILogEntry(
            endpoint: url.absoluteString,
            method: "POST",
            requestHeaders: requestHeaders,
            requestBody: requestBodyString,
            responseStatusCode: httpResponse.statusCode,
            responseBody: responseBodyString,
            error: httpResponse.statusCode != 200 ? "HTTP \(httpResponse.statusCode)" : nil,
            duration: duration
        ))

        guard httpResponse.statusCode == 200 else {
            // Try to extract error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIProviderError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
            throw AIProviderError.apiError(statusCode: httpResponse.statusCode, message: nil)
        }

        // Parse Anthropic response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIProviderError.parseError(detail: "Could not extract content from response")
        }

        return text
    }
}
