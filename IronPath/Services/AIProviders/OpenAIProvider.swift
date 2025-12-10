import Foundation

// MARK: - OpenAI Provider

/// AI Provider implementation for OpenAI's GPT models
class OpenAIProvider: AIProvider {

    // MARK: - Constants

    private let baseURL = "https://api.openai.com/v1"

    // MARK: - AIProvider Properties

    var id: String { AIProviderType.openai.rawValue }

    var displayName: String { "OpenAI" }

    var iconName: String { "sparkles" }

    var availableModels: [AIModel] {
        [
            AIModel(
                id: "gpt-4o-mini",
                displayName: "GPT-4o Mini",
                description: "Fast & affordable - Good for most workouts",
                costTier: .low,
                providerId: id
            ),
            AIModel(
                id: "gpt-4o",
                displayName: "GPT-4o",
                description: "Balanced - Great reasoning and speed",
                costTier: .medium,
                providerId: id
            ),
            AIModel(
                id: "gpt-4-turbo",
                displayName: "GPT-4 Turbo",
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
        AIProviderManager.shared.hasAPIKey(for: .openai)
    }

    var apiKeyURL: URL? {
        URL(string: "https://platform.openai.com/api-keys")
    }

    var setupInstructions: String {
        "Get your API key from platform.openai.com. GPT models offer strong general reasoning and are widely trusted."
    }

    // MARK: - API Key Access

    private var apiKey: String? {
        AIProviderManager.shared.getAPIKey(for: .openai)
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
            availableExercises: availableExercises,
            techniqueOptions: techniqueOptions
        )

        let response = try await sendChatRequest(
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

        let response = try await sendChatRequest(
            systemPrompt: "You are a fitness expert. Respond only with valid JSON - no markdown, no explanations.",
            userPrompt: prompt
        )

        return try AIProviderHelpers.parseExerciseReplacementResponse(response, originalExercise: exercise)
    }

    func getFormTips(exercise: Exercise, userLevel: FitnessLevel) async throws -> String {
        let prompt = AIProviderHelpers.buildFormTipsPrompt(exercise: exercise, userLevel: userLevel)

        let response = try await sendChatRequest(
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

        let response = try await sendChatRequest(
            systemPrompt: "You are a fitness expert. Respond only with valid JSON - no markdown, no explanations.",
            userPrompt: prompt
        )

        return try AIProviderHelpers.parseCustomExerciseResponse(response)
    }

    func estimateCaloriesBurned(workoutSummary: String) async throws -> Int {
        let prompt = AIProviderHelpers.buildCalorieEstimationPrompt(workoutSummary: workoutSummary)

        let response = try await sendChatRequest(
            systemPrompt: "You are a fitness expert. Respond with only a number.",
            userPrompt: prompt
        )

        return AIProviderHelpers.parseCalorieEstimation(response)
    }

    func generateEquipmentExercises(
        equipmentName: String,
        equipmentType: CustomEquipment.CustomEquipmentType,
        existingExerciseNames: [String]
    ) async throws -> [ExerciseDraft] {
        let systemPrompt = AITools.buildEquipmentExercisesSystemPrompt()
        let userPrompt = AITools.buildEquipmentExercisesUserPrompt(
            equipmentName: equipmentName,
            equipmentType: equipmentType,
            existingExerciseNames: existingExerciseNames
        )

        let response = try await sendChatRequestWithTools(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            tools: AITools.equipmentExerciseTools,
            toolChoice: "generate_equipment_exercises"
        )

        let toolInput = try AIToolParser.extractToolInputFromOpenAI(from: response)
        let result = try AIToolParser.parseEquipmentExercises(from: toolInput)
        return result.exercises
    }

    // MARK: - API Communication

    private func sendChatRequest(systemPrompt: String, userPrompt: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIProviderError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 4096,
            "temperature": 0.7
        ]

        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData

        // Debug logging
        let requestHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer [REDACTED]"
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

        // Parse OpenAI response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIProviderError.parseError(detail: "Could not extract content from response")
        }

        return content
    }

    /// Send a chat request with tool calling support
    private func sendChatRequestWithTools(
        systemPrompt: String,
        userPrompt: String,
        tools: [[String: Any]],
        toolChoice: String
    ) async throws -> [String: Any] {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIProviderError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Convert tools to OpenAI function format
        let functions = tools.map { tool -> [String: Any] in
            [
                "type": "function",
                "function": [
                    "name": tool["name"] as? String ?? "",
                    "description": tool["description"] as? String ?? "",
                    "parameters": tool["input_schema"] as? [String: Any] ?? [:]
                ]
            ]
        }

        let requestBody: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 8192,
            "temperature": 0.7,
            "tools": functions,
            "tool_choice": ["type": "function", "function": ["name": toolChoice]]
        ]

        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData

        // Debug logging
        let requestHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer [REDACTED]"
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
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIProviderError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
            throw AIProviderError.apiError(statusCode: httpResponse.statusCode, message: nil)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.parseError(detail: "Could not parse response JSON")
        }

        return json
    }
}
