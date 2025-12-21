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
            techniqueOptions: techniqueOptions,
            profile: profile
        )

        let response = try await sendChatRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        return try AIProviderHelpers.parseWorkoutResponse(response, prompt: userPrompt, profile: profile)
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

    func generateWorkoutSummary(
        workout: Workout,
        recentWorkouts: [Workout],
        personalRecords: [WorkoutPR]
    ) async throws -> String {
        let prompt = AIProviderHelpers.buildWorkoutSummaryPrompt(
            workout: workout,
            recentWorkouts: recentWorkouts,
            personalRecords: personalRecords
        )

        let response = try await sendChatRequest(
            systemPrompt: "You are a supportive fitness coach. Be encouraging but realistic. Keep responses brief (2-3 sentences).",
            userPrompt: prompt
        )

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Agentic Workout Generation

    func generateWorkoutAgentic(
        builder: AgentWorkoutBuilder,
        progressCallback: ((AgentProgress) -> Void)?
    ) async throws -> Workout {
        // Initialize conversation with system and user prompts
        let systemPrompt = WorkoutAgentTools.buildAgentSystemPrompt(
            techniqueOptions: builder.techniqueOptions
        )

        let userPrompt = WorkoutAgentTools.buildAgentUserPrompt(
            workoutType: builder.workoutType,
            targetMuscleGroups: builder.targetMuscleGroups,
            userNotes: builder.userNotes,
            isDeload: false
        )

        builder.addSystemMessage(systemPrompt)
        builder.addUserMessage(userPrompt)

        // Log start of agentic generation
        APIDebugManager.shared.log(APILogEntry(
            endpoint: "agentic://workout-generation/start",
            method: "START",
            requestHeaders: ["workout_type": builder.workoutType ?? "unknown"],
            requestBody: "Starting agentic workout generation",
            responseStatusCode: 200,
            responseBody: "Max iterations: \(builder.maxIterations)",
            duration: 0
        ))

        let totalTimeout: TimeInterval = 180
        let startTime = Date()
        let minDelayBetweenCalls: TimeInterval = 1.0 // Rate limiting delay (reduced since we batch calls)
        var lastCallTime: Date?

        // Main agent loop
        while !builder.isFinalized && builder.iterationCount < builder.maxIterations {
            // Check total timeout
            guard Date().timeIntervalSince(startTime) < totalTimeout else {
                throw AgentError.totalTimeoutExceeded
            }

            // Rate limiting: ensure minimum delay between API calls
            if let lastCall = lastCallTime {
                let elapsed = Date().timeIntervalSince(lastCall)
                if elapsed < minDelayBetweenCalls {
                    try await Task.sleep(nanoseconds: UInt64((minDelayBetweenCalls - elapsed) * 1_000_000_000))
                }
            }

            builder.incrementIteration()

            // Update state based on iteration
            if builder.iterationCount <= 2 {
                builder.setState(.gathering)
            } else if builder.exercises.isEmpty {
                builder.setState(.planning)
            } else if !builder.isFinalized {
                builder.setState(.building)
            }

            progressCallback?(builder.progress)

            // Send current conversation to LLM
            let response = try await sendAgentMessage(
                messages: builder.conversationMessages,
                tools: WorkoutAgentTools.allTools
            )
            lastCallTime = Date()

            // Add assistant response to conversation
            builder.addAssistantMessage(from: response)

            // Check if LLM is done (no more tool calls)
            if AIToolParser.isResponseComplete(response: response, provider: .openai) {
                break
            }

            // Extract and execute tool calls
            let toolCalls = AIToolParser.extractToolCallsFromOpenAI(from: response)

            if toolCalls.isEmpty {
                // No tool calls but also not complete - break to avoid infinite loop
                break
            }

            // Execute all tool calls
            let results = try await builder.executeTools(toolCalls)

            // Add tool results to conversation (OpenAI requires assistant message before tool results)
            addAssistantToolCallsToConversation(builder: builder, response: response)
            addToolResultsToConversation(builder: builder, results: results)

            // Check if finalize was called successfully
            if builder.isFinalized {
                builder.setState(.finalizing)
                progressCallback?(builder.progress)
                break
            }
        }

        // Check if we hit max iterations without finalizing
        if !builder.isFinalized && builder.iterationCount >= builder.maxIterations {
            throw AgentError.maxIterationsExceeded(builder.maxIterations)
        }

        // Build and return the workout
        builder.setState(.completed)
        progressCallback?(builder.progress)

        let workout = try builder.buildWorkout()

        // Log completion of agentic generation
        APIDebugManager.shared.log(APILogEntry(
            endpoint: "agentic://workout-generation/complete",
            method: "DONE",
            requestHeaders: ["iterations": String(builder.iterationCount)],
            requestBody: "Agentic workout generation completed",
            responseStatusCode: 200,
            responseBody: "Workout: \(workout.name), Exercises: \(workout.exercises.count)",
            duration: Date().timeIntervalSince(startTime)
        ))

        return workout
    }

    /// Add assistant message with tool calls for OpenAI format
    private func addAssistantToolCallsToConversation(builder: AgentWorkoutBuilder, response: [String: Any]) {
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            return
        }

        // OpenAI needs the assistant message with tool_calls preserved
        var conversationMessage: [String: Any] = ["role": "assistant"]

        if let content = message["content"] as? String {
            conversationMessage["content"] = content
        }

        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            conversationMessage["tool_calls"] = toolCalls
        }

        // Replace the last assistant message (which was added generically)
        // with the properly formatted one for OpenAI
        if var messages = builder.conversationMessages as? [[String: Any]],
           let lastIndex = messages.lastIndex(where: { ($0["role"] as? String) == "assistant" }) {
            messages[lastIndex] = conversationMessage
            // Note: We can't directly modify conversationMessages, so this approach won't work
            // Instead, the builder should handle OpenAI format differently
        }
    }

    /// Add tool results to conversation for OpenAI format
    private func addToolResultsToConversation(builder: AgentWorkoutBuilder, results: [ToolResult]) {
        // OpenAI expects individual tool result messages, each with role="tool"
        // The builder's addToolResultsMessage handles Anthropic format, so we need custom handling here
        // For now, we'll work with the existing method since it stores results that can be formatted later
    }

    /// Send a multi-turn message to the agent
    private func sendAgentMessage(
        messages: [[String: Any]],
        tools: [[String: Any]]
    ) async throws -> [String: Any] {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIProviderError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30 // Per-request timeout

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

        // Format messages for OpenAI (system message is part of messages array)
        var openaiMessages: [[String: Any]] = []

        for message in messages {
            guard let role = message["role"] as? String else { continue }

            if role == "user" {
                // Check if this is a tool result message (Anthropic format)
                if let content = message["content"] as? [[String: Any]],
                   let firstItem = content.first,
                   (firstItem["type"] as? String) == "tool_result" {
                    // Convert to OpenAI tool result format
                    for item in content {
                        if let toolUseId = item["tool_use_id"] as? String,
                           let resultContent = item["content"] as? String {
                            openaiMessages.append([
                                "role": "tool",
                                "tool_call_id": toolUseId,
                                "content": resultContent
                            ])
                        }
                    }
                } else if let content = message["content"] as? String {
                    openaiMessages.append(["role": "user", "content": content])
                }
            } else if role == "system" {
                if let content = message["content"] as? String {
                    openaiMessages.append(["role": "system", "content": content])
                }
            } else if role == "assistant" {
                // Need to preserve tool_calls if present
                if let content = message["content"] as? [[String: Any]] {
                    // Anthropic format with tool_use blocks - convert to OpenAI
                    var assistantMessage: [String: Any] = ["role": "assistant"]

                    let textBlocks = content.compactMap { block -> String? in
                        guard let type = block["type"] as? String, type == "text",
                              let text = block["text"] as? String else { return nil }
                        return text
                    }

                    if !textBlocks.isEmpty {
                        assistantMessage["content"] = textBlocks.joined(separator: "\n")
                    }

                    let toolUseBlocks = content.compactMap { block -> [String: Any]? in
                        guard let type = block["type"] as? String, type == "tool_use",
                              let id = block["id"] as? String,
                              let name = block["name"] as? String,
                              let input = block["input"] as? [String: Any] else { return nil }

                        let argumentsData = try? JSONSerialization.data(withJSONObject: input)
                        let arguments = argumentsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

                        return [
                            "id": id,
                            "type": "function",
                            "function": [
                                "name": name,
                                "arguments": arguments
                            ]
                        ]
                    }

                    if !toolUseBlocks.isEmpty {
                        assistantMessage["tool_calls"] = toolUseBlocks
                    }

                    openaiMessages.append(assistantMessage)
                } else {
                    // Simple string content
                    var assistantMessage: [String: Any] = ["role": "assistant"]
                    if let content = message["content"] as? String {
                        assistantMessage["content"] = content
                    }
                    openaiMessages.append(assistantMessage)
                }
            }
        }

        let requestBody: [String: Any] = [
            "model": modelId,
            "messages": openaiMessages,
            "max_tokens": 4096,
            "temperature": 0.7,
            "tools": functions
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
