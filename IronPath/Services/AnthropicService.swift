import Foundation

/// Service for interacting with Anthropic's Claude API
class AnthropicService {
    static let shared = AnthropicService()

    private let baseURL = "https://api.anthropic.com/v1"
    private let model = "claude-haiku-4-5-20251001" // Cheapest Claude 4.x model ($1/$5 per M tokens)

    private init() {}

    // MARK: - Exercise Database Lookup

    /// Find a matching exercise from the database by name
    /// Returns the database exercise (with video URL) if found, otherwise creates a new one
    private func findOrCreateExercise(
        name: String,
        primaryMuscleGroups: Set<MuscleGroup>,
        equipment: Equipment
    ) -> Exercise {
        // Try to find a matching exercise in the database (case-insensitive)
        let lowercasedName = name.lowercased()
        if let dbExercise = ExerciseDatabase.shared.exercises.first(where: {
            $0.name.lowercased() == lowercasedName
        }) {
            return dbExercise
        }

        // Try fuzzy match - check if database exercise name contains the generated name or vice versa
        if let dbExercise = ExerciseDatabase.shared.exercises.first(where: {
            $0.name.lowercased().contains(lowercasedName) ||
            lowercasedName.contains($0.name.lowercased())
        }) {
            return dbExercise
        }

        // No match found, create a new exercise without video
        return Exercise(
            name: name,
            primaryMuscleGroups: primaryMuscleGroups,
            equipment: equipment
        )
    }

    /// Get the current API key from storage
    private var apiKey: String? {
        return APIKeyManager.shared.getAPIKey()
    }

    // MARK: - Workout Generation

    // FUTURE ENHANCEMENT: Interactive workout generation with tool use
    // To enable Claude to ask clarifying questions during workout generation:
    // 1. Add tools array to the API request with tools like:
    //    - ask_clarification(question: String, options: [String]) - ask user a question
    //    - check_equipment(equipment: String) - verify equipment availability
    //    - get_exercise_history(exerciseName: String) - get past performance data
    // 2. Create a multi-turn conversation loop that:
    //    - Sends initial prompt with tools
    //    - Checks response for tool_use content blocks
    //    - Presents tool calls to user (e.g., "Claude asks: Do you have access to a bench?")
    //    - Sends tool_result back to continue the conversation
    //    - Continues until Claude returns the final workout JSON
    // 3. Update UI to show an interactive chat during generation
    // This would enable smarter workouts that adapt to real-time user input.

    /// Generate a personalized workout using Claude with agentic tool use
    /// This approach ensures Claude can only select from exercises that match available equipment
    func generateWorkout(
        profile: UserProfile,
        targetMuscleGroups: Set<MuscleGroup>? = nil,
        workoutHistory: [Workout] = [],
        workoutType: String? = nil,
        userNotes: String? = nil,
        isDeload: Bool = false,
        allowDeloadRecommendation: Bool = false
    ) async throws -> Workout {
        // Get available equipment from gym profile
        let availableEquipment: Set<Equipment>
        if let gymProfile = GymProfileManager.shared.activeProfile {
            availableEquipment = gymProfile.availableEquipment
        } else {
            availableEquipment = profile.availableEquipment
        }

        // Build the initial prompt for the agentic flow
        let systemPrompt = buildAgenticSystemPrompt(profile: profile, isDeload: isDeload, allowDeloadRecommendation: allowDeloadRecommendation)
        let userPrompt = buildAgenticUserPrompt(
            workoutType: workoutType,
            targetMuscleGroups: targetMuscleGroups,
            userNotes: userNotes,
            workoutHistory: workoutHistory,
            isDeload: isDeload,
            allowDeloadRecommendation: allowDeloadRecommendation
        )

        // Start the agentic conversation
        var messages: [[String: Any]] = [
            ["role": "user", "content": userPrompt]
        ]

        // Tool definition for querying available exercises
        // Use enum to constrain muscle group values
        let muscleGroupValues = MuscleGroup.allCases.map { $0.rawValue }
        let tools: [[String: Any]] = [
            [
                "name": "get_available_exercises",
                "description": "Get a list of exercises available at the user's gym that target specific muscle groups. This returns ONLY exercises that can be performed with the user's available equipment. You MUST use this tool to see what exercises are available before building a workout.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "muscle_groups": [
                            "type": "array",
                            "items": [
                                "type": "string",
                                "enum": muscleGroupValues
                            ],
                            "description": "List of muscle groups to find exercises for"
                        ]
                    ],
                    "required": ["muscle_groups"]
                ]
            ]
        ]

        // Agentic loop - continue until Claude returns a final response (not a tool call)
        var maxIterations = 5
        while maxIterations > 0 {
            maxIterations -= 1

            let response = try await sendMessageWithTools(
                messages: messages,
                systemPrompt: systemPrompt,
                tools: tools
            )

            // Check if Claude wants to use a tool
            if response.stopReason == "tool_use" {
                // Find the tool use block
                guard let toolUse = response.content.first(where: { $0.type == "tool_use" }),
                      let toolId = toolUse.id,
                      let toolName = toolUse.name else {
                    throw AnthropicError.invalidResponse
                }

                // Add assistant's response to messages
                let assistantContent = response.content.map { block -> [String: Any] in
                    if block.type == "tool_use" {
                        return [
                            "type": "tool_use",
                            "id": block.id ?? "",
                            "name": block.name ?? "",
                            "input": block.input.map { ["muscle_groups": $0.muscleGroups ?? []] } ?? [:]
                        ]
                    } else {
                        return ["type": "text", "text": block.text ?? ""]
                    }
                }
                messages.append(["role": "assistant", "content": assistantContent])

                // Handle the tool call
                if toolName == "get_available_exercises" {
                    let muscleGroups = toolUse.input?.muscleGroups ?? []
                    print("DEBUG: Claude requested muscle groups: \(muscleGroups)")
                    // Values are guaranteed to match enum rawValues due to schema constraint
                    let targetMuscles = Set(muscleGroups.compactMap { MuscleGroup(rawValue: $0) })
                    print("DEBUG: Parsed to MuscleGroup enums: \(targetMuscles.map { $0.rawValue })")

                    // Get filtered exercises
                    let exerciseList = getAvailableExercisesForClaude(
                        muscleGroups: targetMuscles,
                        availableEquipment: availableEquipment,
                        workoutHistory: workoutHistory
                    )

                    // Add tool result to messages
                    messages.append([
                        "role": "user",
                        "content": [
                            [
                                "type": "tool_result",
                                "tool_use_id": toolId,
                                "content": exerciseList
                            ]
                        ]
                    ])
                }
            } else {
                // Claude returned a final response - parse the workout
                return try parseWorkoutFromResponse(response, prompt: userPrompt)
            }
        }

        throw AnthropicError.invalidResponse
    }

    /// Parse muscle group string to enum (case-insensitive)
    private func parseMuscleGroup(_ string: String) -> MuscleGroup? {
        let lowercased = string.lowercased().trimmingCharacters(in: .whitespaces)
        switch lowercased {
        case "chest": return .chest
        case "back": return .back
        case "shoulders": return .shoulders
        case "biceps": return .biceps
        case "triceps": return .triceps
        case "forearms": return .forearms
        case "abs", "core", "abdominals": return .abs
        case "obliques": return .obliques
        case "quads", "quadriceps", "legs": return .quads
        case "hamstrings": return .hamstrings
        case "glutes": return .glutes
        case "calves": return .calves
        case "lower back", "lowerback": return .lowerBack
        case "traps", "trapezius": return .traps
        default:
            print("DEBUG: Unknown muscle group: \(string)")
            return nil
        }
    }

    /// Get available exercises filtered by equipment and muscle groups, formatted for Claude
    private func getAvailableExercisesForClaude(
        muscleGroups: Set<MuscleGroup>,
        availableEquipment: Set<Equipment>,
        workoutHistory: [Workout]
    ) -> String {
        // Get available specific machines from active gym profile
        let availableMachines = GymProfileManager.shared.activeProfile?.availableMachines ?? []

        print("DEBUG: getAvailableExercisesForClaude called")
        print("DEBUG: Requested muscle groups: \(muscleGroups.map { $0.rawValue })")
        print("DEBUG: Available equipment: \(availableEquipment.map { $0.rawValue })")
        print("DEBUG: Available machines: \(availableMachines.map { $0.rawValue })")
        print("DEBUG: Total exercises in database: \(ExerciseDatabase.shared.exercises.count)")

        // Filter exercises by equipment and specific machines
        let equipmentFilteredExercises = ExerciseDatabase.shared.exercises.filter { exercise in
            // If exercise requires a specific machine, check if that machine is available
            if let requiredMachine = exercise.specificMachine {
                return availableMachines.contains(requiredMachine)
            }
            // Otherwise check regular equipment
            return availableEquipment.contains(exercise.equipment)
        }
        print("DEBUG: Exercises matching equipment: \(equipmentFilteredExercises.count)")

        // Then filter by muscle groups (primary or secondary)
        let matchingExercises = equipmentFilteredExercises.filter { exercise in
            !muscleGroups.isDisjoint(with: exercise.primaryMuscleGroups) ||
            !muscleGroups.isDisjoint(with: exercise.secondaryMuscleGroups)
        }
        print("DEBUG: Exercises matching equipment AND muscles: \(matchingExercises.count)")

        // Check exercise preferences
        let preferences = GymSettings.shared.exercisePreferences

        // Build the exercise list with history
        var result = "AVAILABLE EXERCISES (only use exercises from this list):\n\n"

        for exercise in matchingExercises {
            // Check if exercise should be excluded
            if let pref = preferences[exercise.name], pref == .never {
                continue
            }

            let prefNote: String
            if let pref = preferences[exercise.name] {
                switch pref {
                case .suggestMore: prefNote = " [USER PREFERS]"
                case .suggestLess: prefNote = " [USER DISLIKES - use sparingly]"
                default: prefNote = ""
                }
            } else {
                prefNote = ""
            }

            result += "- \(exercise.name)\(prefNote)\n"
            result += "  Equipment: \(exercise.equipment.rawValue)\n"
            result += "  Primary: \(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))\n"
            if !exercise.secondaryMuscleGroups.isEmpty {
                result += "  Secondary: \(exercise.secondaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))\n"
            }
            result += "  Difficulty: \(exercise.difficulty.rawValue)\n"

            // Add history for this exercise
            let exerciseHistory = getExerciseHistory(exerciseName: exercise.name, from: workoutHistory)
            if !exerciseHistory.isEmpty {
                result += "  Recent History: \(exerciseHistory)\n"
            }

            result += "\n"
        }

        if matchingExercises.isEmpty {
            result += "No exercises available for the requested muscle groups with the user's equipment.\n"
            result += "Consider bodyweight alternatives or asking the user about their equipment.\n"
        }

        return result
    }

    /// Get recent history for an exercise
    private func getExerciseHistory(exerciseName: String, from workouts: [Workout]) -> String {
        var history: [String] = []

        for workout in workouts.prefix(5) {
            if let exercise = workout.exercises.first(where: { $0.exercise.name == exerciseName }) {
                let completedSets = exercise.sets.filter { $0.completedAt != nil }
                if !completedSets.isEmpty {
                    let maxWeight = completedSets.compactMap { $0.weight }.max() ?? 0
                    let avgReps = completedSets.compactMap { $0.actualReps }.reduce(0, +) / max(completedSets.count, 1)
                    let dateStr = workout.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? "recent"
                    history.append("\(dateStr): \(Int(maxWeight))lbs x \(avgReps) reps")
                }
            }
        }

        return history.joined(separator: "; ")
    }

    /// Build system prompt for agentic workout generation
    private func buildAgenticSystemPrompt(profile: UserProfile, isDeload: Bool = false, allowDeloadRecommendation: Bool = false) -> String {
        var prompt = """
        You are a personal fitness trainer creating workout plans. You MUST use the get_available_exercises tool to see what exercises are available before creating a workout.

        CRITICAL: Only include exercises that appear in the tool results. The user's gym has LIMITED EQUIPMENT - do not assume any exercise is available.

        User Profile:
        - Fitness Level: \(profile.fitnessLevel.rawValue)
        - Goals: \(profile.goals.map { $0.rawValue }.joined(separator: ", "))
        - Preferred Duration: \(profile.workoutPreferences.preferredWorkoutDuration) minutes
        - Rest Time: \(profile.workoutPreferences.preferredRestTime) seconds between sets
        """

        if isDeload {
            prompt += """


        ⚠️ DELOAD WORKOUT: This is a DELOAD/RECOVERY workout. You MUST:
        - Use weights at 50-70% of what the user normally lifts (based on history)
        - Focus on form and muscle activation rather than intensity
        - Reduce volume slightly (fewer total sets)
        - Keep rest periods the same or slightly longer
        - Include "DELOAD" in the workout name
        - Set "isDeload": true in the JSON response
        - The purpose is active recovery, not progressive overload
        """
        } else if allowDeloadRecommendation {
            prompt += """


        DELOAD RECOMMENDATION:
        You may recommend a deload workout by setting "isDeload": true in the JSON if you observe ANY of these signs in the workout history:
        - User has been training the same muscle groups intensely for 4+ consecutive workouts without a break
        - Recent workout weights/volume have plateaued or decreased (signs of fatigue)
        - User has been training for 3-4 weeks straight without a deload
        - The workout history shows very high frequency (5+ workouts per week for multiple weeks)

        If you recommend a deload:
        - Include "DELOAD" or "Recovery" in the workout name
        - Set "isDeload": true in the JSON
        - Use 50-70% of normal weights
        - Explain in exercise notes why you're recommending lighter weights
        """
        }

        prompt += """


        When creating the workout:
        1. First call get_available_exercises with the muscle groups you want to target
        2. Review the returned exercise list - these are the ONLY exercises you can use
        3. Select 4-7 exercises from the list
        4. Use the exercise history to suggest appropriate weights\(isDeload ? " (reduced to 50-70% for deload)" : " (progressive overload)")
        5. Return the workout in JSON format
        """

        return prompt
    }

    /// Build user prompt for agentic workout generation
    private func buildAgenticUserPrompt(
        workoutType: String?,
        targetMuscleGroups: Set<MuscleGroup>?,
        userNotes: String?,
        workoutHistory: [Workout],
        isDeload: Bool = false,
        allowDeloadRecommendation: Bool = false
    ) -> String {
        var prompt = "Please create a workout for me.\n\n"

        if isDeload {
            prompt += "⚠️ THIS IS A DELOAD WORKOUT - Use lighter weights (50-70% of normal) for recovery.\n\n"
        }

        if let workoutType = workoutType {
            prompt += "Workout Type: \(workoutType)\n"
        }

        if let muscles = targetMuscleGroups, !muscles.isEmpty {
            prompt += "Target Muscles: \(muscles.map { $0.rawValue }.joined(separator: ", "))\n"
        }

        if let notes = userNotes, !notes.isEmpty {
            prompt += "My Notes: \(notes)\n"
        }

        if !workoutHistory.isEmpty {
            // Filter out deload workouts from history when showing recent workouts for context
            let relevantHistory = workoutHistory.filter { !$0.isDeload }.prefix(3)
            prompt += "\nRecent workouts: \(relevantHistory.map { $0.name }.joined(separator: ", "))\n"

            // For auto-generate, provide more history context so Claude can recommend deload
            if allowDeloadRecommendation {
                let lastDeload = workoutHistory.last { $0.isDeload }
                if let lastDeload = lastDeload, let completedAt = lastDeload.completedAt {
                    let daysSinceDeload = Calendar.current.dateComponents([.day], from: completedAt, to: Date()).day ?? 0
                    prompt += "Last deload workout: \(daysSinceDeload) days ago\n"
                } else {
                    prompt += "No recent deload workouts in history\n"
                }
                let nonDeloadCount = workoutHistory.filter { !$0.isDeload }.count
                prompt += "Total non-deload workouts in recent history: \(nonDeloadCount)\n"
            }
        }

        prompt += """

        Please use the get_available_exercises tool to see what exercises I can do at my gym, then create a workout plan.

        Return the final workout as JSON:
        {
          "name": "\(isDeload ? "Deload - " : "")Workout name",
          "isDeload": \(isDeload ? "true" : "false")\(allowDeloadRecommendation ? " // Set to true if you recommend a deload based on training history" : ""),
          "exercises": [
            {
              "name": "Exercise name (must match exactly from the list)",
              "sets": 3,
              "reps": "8-12",
              "weight": \(isDeload ? "reduced weight (50-70% of history)" : "135"),
              "restSeconds": 90,
              "equipment": "equipment type",
              "primaryMuscles": ["muscle1"],
              "notes": "Optional coaching notes"
            }
          ]
        }
        """

        return prompt
    }

    /// Send a message with tools to Claude API
    private func sendMessageWithTools(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]]
    ) async throws -> ClaudeResponse {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": messages,
            "tools": tools
        ]

        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData

        // Capture request info for debug logging
        let requestHeaders = [
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01"
        ]
        let requestBodyString = String(data: requestBodyData, encoding: .utf8) ?? ""

        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)

        guard let httpResponse = response as? HTTPURLResponse else {
            // Log failed request
            APIDebugManager.shared.log(APILogEntry(
                endpoint: url.absoluteString,
                method: "POST",
                requestHeaders: requestHeaders,
                requestBody: requestBodyString,
                error: "Invalid response type",
                duration: duration
            ))
            throw AnthropicError.invalidResponse
        }

        let responseBodyString = String(data: data, encoding: .utf8) ?? ""

        guard httpResponse.statusCode == 200 else {
            // Log error response
            var errorMessage: String? = nil
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorInfo = errorJson["error"] as? [String: Any],
               let message = errorInfo["message"] as? String {
                errorMessage = message
            }

            APIDebugManager.shared.log(APILogEntry(
                endpoint: url.absoluteString,
                method: "POST",
                requestHeaders: requestHeaders,
                requestBody: requestBodyString,
                responseStatusCode: httpResponse.statusCode,
                responseBody: responseBodyString,
                error: errorMessage,
                duration: duration
            ))

            if let message = errorMessage {
                throw AnthropicError.apiErrorWithMessage(statusCode: httpResponse.statusCode, message: message)
            }
            throw AnthropicError.apiError(statusCode: httpResponse.statusCode)
        }

        // Log successful response
        APIDebugManager.shared.log(APILogEntry(
            endpoint: url.absoluteString,
            method: "POST",
            requestHeaders: requestHeaders,
            requestBody: requestBodyString,
            responseStatusCode: httpResponse.statusCode,
            responseBody: responseBodyString,
            duration: duration
        ))

        let decoder = JSONDecoder()
        return try decoder.decode(ClaudeResponse.self, from: data)
    }

    /// Replace an exercise with an alternative
    func replaceExercise(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout
    ) async throws -> WorkoutExercise {
        let prompt = buildExerciseReplacementPrompt(
            exercise: exercise,
            profile: profile,
            reason: reason,
            currentWorkout: currentWorkout
        )

        let response = try await sendMessage(prompt: prompt)
        return try parseExerciseReplacementFromResponse(response, originalExercise: exercise)
    }

    // MARK: - AI Coaching

    /// Get form tips and coaching advice for an exercise
    func getFormTips(exercise: Exercise, userLevel: FitnessLevel) async throws -> String {
        let prompt = """
        Provide concise form tips and safety advice for the following exercise:

        Exercise: \(exercise.name)
        User Level: \(userLevel.rawValue)
        Primary Muscles: \(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))

        Give 3-5 key form cues and 1-2 safety tips. Be specific and actionable.
        """

        let response = try await sendMessage(prompt: prompt)
        return response.content.first?.text ?? ""
    }

    /// Analyze workout performance and provide progression recommendations
    func analyzeProgress(workouts: [Workout], profile: UserProfile) async throws -> String {
        let workoutSummary = workouts.prefix(10).map { workout in
            """
            - \(workout.name): \(workout.exercises.count) exercises, \
            \(Int(workout.totalVolume)) lbs total volume, \
            \(workout.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? "not completed")
            """
        }.joined(separator: "\n")

        let prompt = """
        Analyze this user's recent workout history and provide progression recommendations:

        User Profile:
        - Fitness Level: \(profile.fitnessLevel.rawValue)
        - Goals: \(profile.goals.map { $0.rawValue }.joined(separator: ", "))

        Recent Workouts:
        \(workoutSummary)

        Provide:
        1. Progress assessment (1-2 sentences)
        2. What's going well (2-3 points)
        3. Areas for improvement (2-3 points)
        4. Specific recommendations for next workouts (2-3 points)
        """

        let response = try await sendMessage(prompt: prompt)
        return response.content.first?.text ?? ""
    }

    // MARK: - Custom Exercise Generation

    /// Generate a custom exercise based on user's description
    func generateCustomExercise(
        prompt: String,
        availableEquipment: Set<Equipment>
    ) async throws -> Exercise {
        let systemPrompt = """
        Generate a custom exercise based on the user's description in JSON format.

        User's Description: \(prompt)

        Available Equipment: \(availableEquipment.map { $0.rawValue }.joined(separator: ", "))

        Return ONLY valid JSON with this structure:
        {
          "name": "Exercise name (be specific and descriptive)",
          "primaryMuscles": ["muscle1", "muscle2"],
          "secondaryMuscles": ["muscle1"],
          "equipment": "equipment type from available list",
          "difficulty": "beginner" or "intermediate" or "advanced",
          "instructions": "Step by step instructions for performing the exercise",
          "formTips": "Key form cues and tips for proper execution"
        }

        Valid muscle groups: chest, back, shoulders, biceps, triceps, forearms, core, quadriceps, hamstrings, glutes, calves
        Valid equipment types: barbell, dumbbell, cables, machine, bodyweightOnly, resistanceBands, kettlebell, medicineBall, pullUpBar, dip, squat, bench, legPress, smithMachine

        Requirements:
        - Use only equipment from the available list
        - Be specific with the exercise name
        - Provide clear, actionable instructions
        - Include important form tips for safety
        """

        let response = try await sendMessage(prompt: systemPrompt)
        return try parseCustomExerciseFromResponse(response)
    }

    private func parseCustomExerciseFromResponse(_ response: ClaudeResponse) throws -> Exercise {
        guard let text = response.content.first?.text else {
            throw AnthropicError.invalidResponse
        }

        // Extract JSON from response using safe substring extraction
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}"),
              jsonStart <= jsonEnd else {
            throw AnthropicError.parseError
        }

        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.parseError
        }

        let decoder = JSONDecoder()
        let exerciseJSON = try decoder.decode(CustomExerciseJSON.self, from: jsonData)

        // Convert to Exercise model
        let equipment = Equipment.fromString(exerciseJSON.equipment)
        let primaryMuscles = Set(exerciseJSON.primaryMuscles.compactMap { MuscleGroup(rawValue: $0) })
        let secondaryMuscles = Set(exerciseJSON.secondaryMuscles.compactMap { MuscleGroup(rawValue: $0) })
        let difficulty = ExerciseDifficulty(rawValue: exerciseJSON.difficulty) ?? .intermediate

        return Exercise(
            name: exerciseJSON.name,
            primaryMuscleGroups: primaryMuscles,
            secondaryMuscleGroups: secondaryMuscles,
            equipment: equipment,
            difficulty: difficulty,
            instructions: exerciseJSON.instructions,
            formTips: exerciseJSON.formTips,
            isCustom: true
        )
    }

    // MARK: - API Communication

    private func sendMessage(prompt: String) async throws -> ClaudeResponse {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestBodyData

        // Capture request info for debug logging
        let requestHeaders = [
            "Content-Type": "application/json",
            "x-api-key": apiKey,
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
            throw AnthropicError.invalidResponse
        }

        let responseBodyString = String(data: data, encoding: .utf8) ?? ""

        guard httpResponse.statusCode == 200 else {
            APIDebugManager.shared.log(APILogEntry(
                endpoint: url.absoluteString,
                method: "POST",
                requestHeaders: requestHeaders,
                requestBody: requestBodyString,
                responseStatusCode: httpResponse.statusCode,
                responseBody: responseBodyString,
                error: "HTTP \(httpResponse.statusCode)",
                duration: duration
            ))
            throw AnthropicError.apiError(statusCode: httpResponse.statusCode)
        }

        // Log successful response
        APIDebugManager.shared.log(APILogEntry(
            endpoint: url.absoluteString,
            method: "POST",
            requestHeaders: requestHeaders,
            requestBody: requestBodyString,
            responseStatusCode: httpResponse.statusCode,
            responseBody: responseBodyString,
            duration: duration
        ))

        let decoder = JSONDecoder()
        return try decoder.decode(ClaudeResponse.self, from: data)
    }

    // MARK: - Prompt Building

    private func buildWorkoutGenerationPrompt(
        profile: UserProfile,
        targetMuscleGroups: Set<MuscleGroup>?,
        workoutHistory: [Workout],
        workoutType: String? = nil,
        userNotes: String? = nil
    ) -> String {
        // Use active gym profile's equipment if available, otherwise fall back to user profile
        let availableEquipment: Set<Equipment>
        if let gymProfile = GymProfileManager.shared.activeProfile {
            availableEquipment = gymProfile.availableEquipment
        } else {
            availableEquipment = profile.availableEquipment
        }

        // Calculate equipment that is NOT available
        let allEquipment = Set(Equipment.allCases)
        let unavailableEquipment = allEquipment.subtracting(availableEquipment)

        var prompt = """
        Generate a personalized workout plan in JSON format.

        User Profile:
        - Fitness Level: \(profile.fitnessLevel.rawValue)
        - Goals: \(profile.goals.map { $0.rawValue }.joined(separator: ", "))
        - Available Equipment: \(availableEquipment.map { $0.rawValue }.joined(separator: ", "))
        - Preferred Duration: \(profile.workoutPreferences.preferredWorkoutDuration) minutes
        - Rest Time: \(profile.workoutPreferences.preferredRestTime) seconds between sets
        """

        // Add explicit unavailable equipment warning
        if !unavailableEquipment.isEmpty {
            prompt += "\n\n⚠️ EQUIPMENT NOT AVAILABLE - DO NOT USE: \(unavailableEquipment.map { $0.rawValue }.joined(separator: ", "))"
            prompt += "\nThe user does NOT have access to: \(unavailableEquipment.map { $0.rawValue }.joined(separator: ", ")). Do not suggest any exercises that require this equipment."
        }

        if let workoutType = workoutType {
            prompt += "\n- Workout Type: \(workoutType)"
        }

        if let targetMuscles = targetMuscleGroups, !targetMuscles.isEmpty {
            prompt += "\n- Target Muscle Groups: \(targetMuscles.map { $0.rawValue }.joined(separator: ", "))"
        }

        if !profile.workoutPreferences.avoidInjuries.isEmpty {
            prompt += "\n- Avoid due to injuries: \(profile.workoutPreferences.avoidInjuries.joined(separator: ", "))"
        }

        // Add gym equipment constraints
        let gymEquipmentSummary = GymSettings.shared.equipmentSummaryForClaude()
        if !gymEquipmentSummary.isEmpty {
            prompt += "\n\n\(gymEquipmentSummary)"
            prompt += "\nIMPORTANT: When suggesting weights for cable exercises, only use weights that are achievable with the available plate stacks described above."
        }

        // Add exercise preferences
        let exercisePreferences = GymSettings.shared.exercisePreferencesForClaude()
        if !exercisePreferences.isEmpty {
            prompt += "\n\n\(exercisePreferences)"
        }

        if let userNotes = userNotes, !userNotes.isEmpty {
            prompt += "\n\nIMPORTANT USER NOTES: \(userNotes)"
        }

        if !workoutHistory.isEmpty {
            let recentWorkouts = workoutHistory.prefix(3).map { $0.name }.joined(separator: ", ")
            prompt += "\n\nRecent Workouts: \(recentWorkouts)"
        }

        prompt += """


        Return ONLY valid JSON with this structure:
        {
          "name": "Workout name",
          "exercises": [
            {
              "name": "Exercise name",
              "sets": 3,
              "reps": "8-12",
              "restSeconds": 90,
              "equipment": "equipment type",
              "primaryMuscles": ["muscle1", "muscle2"],
              "notes": "Optional coaching notes"
            }
          ]
        }

        Requirements:
        - 4-7 exercises total
        - ⚠️ CRITICAL EQUIPMENT CONSTRAINT: You MUST only suggest exercises using the Available Equipment listed above. If the user only has Dumbbells and Bodyweight, you CANNOT suggest barbell exercises, cable exercises, machine exercises, etc. This is a HARD requirement.
        - For example: If "Barbell" is NOT in available equipment, do NOT suggest Barbell Back Squat, Bench Press with barbell, Deadlifts, etc.
        - Match user's fitness level
        - Progressive overload principles
        - Balanced muscle group targeting
        - STRICTLY follow any user notes about injuries, equipment availability, or preferences
        """

        return prompt
    }

    private func buildExerciseReplacementPrompt(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout
    ) -> String {
        let otherExercises = currentWorkout.exercises
            .filter { $0.id != exercise.id }
            .map { $0.exercise.name }
            .joined(separator: ", ")

        // Use active gym profile's equipment if available, otherwise fall back to user profile
        let availableEquipment: Set<Equipment>
        if let gymProfile = GymProfileManager.shared.activeProfile {
            availableEquipment = gymProfile.availableEquipment
        } else {
            availableEquipment = profile.availableEquipment
        }

        var prompt = """
        Suggest a replacement exercise in JSON format.

        Current Exercise to Replace: \(exercise.exercise.name)
        - Sets: \(exercise.sets.count)
        - Target Reps: \(exercise.sets.first?.targetReps ?? 10)
        - Primary Muscles: \(exercise.exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))

        User Profile:
        - Fitness Level: \(profile.fitnessLevel.rawValue)
        - Available Equipment: \(availableEquipment.map { $0.rawValue }.joined(separator: ", "))

        Other Exercises in Workout (avoid duplicates): \(otherExercises)
        """

        if let reason = reason, !reason.isEmpty {
            prompt += "\n\nREASON FOR REPLACEMENT: \(reason)"
        }

        prompt += """


        Return ONLY valid JSON with this structure:
        {
          "name": "New exercise name",
          "sets": \(exercise.sets.count),
          "reps": "\(exercise.sets.first?.targetReps ?? 10)",
          "restSeconds": \(Int(exercise.sets.first?.restPeriod ?? 90)),
          "equipment": "equipment type",
          "primaryMuscles": ["muscle1", "muscle2"],
          "notes": "Brief explanation of why this is a good replacement"
        }

        Requirements:
        - Target similar muscle groups as the original exercise
        - Use only equipment the user has available
        - Consider the reason for replacement if provided
        - Don't duplicate exercises already in the workout
        """

        return prompt
    }

    private func parseExerciseReplacementFromResponse(_ response: ClaudeResponse, originalExercise: WorkoutExercise) throws -> WorkoutExercise {
        guard let text = response.content.first?.text else {
            throw AnthropicError.invalidResponse
        }

        // Extract JSON from response using safe substring extraction
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}"),
              jsonStart <= jsonEnd else {
            throw AnthropicError.parseError
        }

        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AnthropicError.parseError
        }

        let decoder = JSONDecoder()
        let exerciseJSON = try decoder.decode(ExerciseJSON.self, from: jsonData)

        // Convert to WorkoutExercise
        let equipment = Equipment.fromString(exerciseJSON.equipment)
        let primaryMuscles = Set(exerciseJSON.primaryMuscles.compactMap { MuscleGroup(rawValue: $0) })

        // Try to match with database exercise (for video URLs and other metadata)
        let exercise = findOrCreateExercise(
            name: exerciseJSON.name,
            primaryMuscleGroups: primaryMuscles,
            equipment: equipment
        )

        // Parse reps
        let targetReps = Int(exerciseJSON.reps.components(separatedBy: "-").first ?? "10") ?? 10

        let sets = (1...exerciseJSON.sets).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                targetReps: targetReps,
                restPeriod: TimeInterval(exerciseJSON.restSeconds)
            )
        }

        return WorkoutExercise(
            exercise: exercise,
            sets: sets,
            orderIndex: originalExercise.orderIndex,
            notes: exerciseJSON.notes ?? ""
        )
    }

    private func parseWorkoutFromResponse(_ response: ClaudeResponse, prompt: String) throws -> Workout {
        // Find the text content block (might not be first if there are other block types)
        guard let textBlock = response.content.first(where: { $0.type == "text" }),
              let text = textBlock.text else {
            print("DEBUG: No text block found in response. Content types: \(response.content.map { $0.type })")
            throw AnthropicError.parseError
        }

        print("DEBUG: Claude response text: \(text.prefix(500))...")

        // Extract JSON from response using safe substring extraction
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}"),
              jsonStart <= jsonEnd else {
            print("DEBUG: No JSON found in response")
            throw AnthropicError.parseError
        }

        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("DEBUG: Failed to convert JSON string to data")
            throw AnthropicError.parseError
        }

        let decoder = JSONDecoder()
        do {
            let workoutJSON = try decoder.decode(WorkoutJSON.self, from: jsonData)
            print("DEBUG: Successfully parsed workout: \(workoutJSON.name) with \(workoutJSON.exercises.count) exercises")
            return try buildWorkout(from: workoutJSON, prompt: prompt)
        } catch {
            print("DEBUG: JSON decode error: \(error)")
            print("DEBUG: JSON string was: \(jsonString.prefix(1000))")
            throw AnthropicError.parseError
        }
    }

    private func buildWorkout(from workoutJSON: WorkoutJSON, prompt: String) throws -> Workout {

        // Convert JSON to Workout model
        let exercises = workoutJSON.exercises.enumerated().map { index, exerciseJSON in
            let equipment = Equipment.fromString(exerciseJSON.equipment)
            let primaryMuscles = Set(exerciseJSON.primaryMuscles.compactMap { MuscleGroup(rawValue: $0) })

            // Try to match with database exercise (for video URLs and other metadata)
            let exercise = self.findOrCreateExercise(
                name: exerciseJSON.name,
                primaryMuscleGroups: primaryMuscles,
                equipment: equipment
            )

            // Parse reps (could be "10" or "8-12")
            let targetReps = Int(exerciseJSON.reps.components(separatedBy: "-").first ?? "10") ?? 10

            let sets = (1...exerciseJSON.sets).map { setNum in
                ExerciseSet(
                    setNumber: setNum,
                    targetReps: targetReps,
                    weight: exerciseJSON.weight,  // Use suggested weight from Claude
                    restPeriod: TimeInterval(exerciseJSON.restSeconds)
                )
            }

            return WorkoutExercise(
                exercise: exercise,
                sets: sets,
                orderIndex: index,
                notes: exerciseJSON.notes ?? ""
            )
        }

        return Workout(
            name: workoutJSON.name,
            exercises: exercises,
            claudeGenerationPrompt: prompt,
            isDeload: workoutJSON.isDeload ?? false
        )
    }

    // MARK: - Calorie Estimation

    /// Estimate active calories burned during a strength training workout
    /// Uses Claude to provide a conservative estimate based on workout data
    func estimateCaloriesBurned(workoutSummary: String) async throws -> Int {
        guard let apiKey = APIKeyManager.shared.getAPIKey() else {
            throw AnthropicError.missingAPIKey
        }

        let systemPrompt = """
        You are a fitness expert estimating calories burned during strength training.

        IMPORTANT: Be CONSERVATIVE in your estimates. It's better to underestimate than overestimate.

        Typical calorie burn rates for strength training:
        - Light intensity: 3-4 calories per minute
        - Moderate intensity: 5-7 calories per minute
        - High intensity: 8-10 calories per minute

        Factors to consider:
        - Workout duration (most important)
        - Total volume (weight × reps)
        - Number of compound vs isolation exercises
        - Rest periods (longer rest = fewer calories)
        - Deload workouts burn fewer calories due to lighter weights

        Respond with ONLY a single integer representing your conservative estimate of active calories burned.
        No explanation, no units, just the number.
        """

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 50,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "Estimate the active calories burned for this workout:\n\n\(workoutSummary)"]
            ]
        ]

        let requestBodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = requestBodyData

        // Capture request info for debug logging
        let requestHeaders = [
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01"
        ]
        let requestBodyString = String(data: requestBodyData, encoding: .utf8) ?? ""

        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)

        let responseBodyString = String(data: data, encoding: .utf8) ?? ""

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            APIDebugManager.shared.log(APILogEntry(
                endpoint: url.absoluteString,
                method: "POST",
                requestHeaders: requestHeaders,
                requestBody: requestBodyString,
                responseStatusCode: statusCode,
                responseBody: responseBodyString,
                error: "HTTP \(statusCode)",
                duration: duration
            ))
            throw AnthropicError.apiError(statusCode: statusCode)
        }

        // Log successful response
        APIDebugManager.shared.log(APILogEntry(
            endpoint: url.absoluteString,
            method: "POST",
            requestHeaders: requestHeaders,
            requestBody: requestBodyString,
            responseStatusCode: httpResponse.statusCode,
            responseBody: responseBodyString,
            duration: duration
        ))

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let textContent = claudeResponse.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            // Default to a conservative estimate if no text content
            return 150
        }

        // Extract just the number from the response (Claude might include extra text)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to parse directly first
        if let calories = Int(trimmedText), calories > 0 {
            return calories
        }

        // If that fails, try to extract a number from the text
        let numbers = trimmedText.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 }

        if let firstNumber = numbers.first {
            return firstNumber
        }

        // Default fallback
        return 150
    }
}

// MARK: - Models

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
    // For tool_use blocks
    let id: String?
    let name: String?
    let input: ToolInput?
}

struct ToolInput: Codable {
    let muscleGroups: [String]?

    enum CodingKeys: String, CodingKey {
        case muscleGroups = "muscle_groups"
    }
}

struct WorkoutJSON: Codable {
    let name: String
    let exercises: [ExerciseJSON]
    let isDeload: Bool?  // Claude can recommend a deload workout

    enum CodingKeys: String, CodingKey {
        case name, exercises, isDeload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        exercises = try container.decode([ExerciseJSON].self, forKey: .exercises)
        // Handle isDeload as optional bool or string
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .isDeload) {
            isDeload = boolValue
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .isDeload) {
            isDeload = stringValue.lowercased() == "true"
        } else {
            isDeload = nil
        }
    }
}

struct ExerciseJSON: Codable {
    let name: String
    let sets: Int
    let reps: String
    let restSeconds: Int
    let equipment: String
    let primaryMuscles: [String]
    let notes: String?
    let weight: Double?  // Suggested weight from Claude

    enum CodingKeys: String, CodingKey {
        case name, sets, reps, restSeconds, equipment, primaryMuscles, notes, weight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        equipment = try container.decode(String.self, forKey: .equipment)
        primaryMuscles = try container.decode([String].self, forKey: .primaryMuscles)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // Handle sets as either Int or String
        if let intSets = try? container.decode(Int.self, forKey: .sets) {
            sets = intSets
        } else if let stringSets = try? container.decode(String.self, forKey: .sets),
                  let parsedSets = Int(stringSets) {
            sets = parsedSets
        } else {
            sets = 3  // Default
        }

        // Handle reps as either String or Int
        if let stringReps = try? container.decode(String.self, forKey: .reps) {
            reps = stringReps
        } else if let intReps = try? container.decode(Int.self, forKey: .reps) {
            reps = String(intReps)
        } else {
            reps = "10"  // Default
        }

        // Handle restSeconds as either Int or String
        if let intRest = try? container.decode(Int.self, forKey: .restSeconds) {
            restSeconds = intRest
        } else if let stringRest = try? container.decode(String.self, forKey: .restSeconds),
                  let parsedRest = Int(stringRest) {
            restSeconds = parsedRest
        } else {
            restSeconds = 90  // Default
        }

        // Handle weight as either Double, Int, or String
        if let doubleWeight = try? container.decodeIfPresent(Double.self, forKey: .weight) {
            weight = doubleWeight
        } else if let intWeight = try? container.decodeIfPresent(Int.self, forKey: .weight) {
            weight = Double(intWeight)
        } else if let stringWeight = try? container.decodeIfPresent(String.self, forKey: .weight),
                  let parsedWeight = Double(stringWeight) {
            weight = parsedWeight
        } else {
            weight = nil
        }
    }
}

struct CustomExerciseJSON: Codable {
    let name: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let equipment: String
    let difficulty: String
    let instructions: String
    let formTips: String
}

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int)
    case apiErrorWithMessage(statusCode: Int, message: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key is missing. Please set ANTHROPIC_API_KEY environment variable."
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let code):
            return "API error with status code: \(code)"
        case .apiErrorWithMessage(let code, let message):
            return "API error (\(code)): \(message)"
        case .parseError:
            return "Failed to parse Claude's response"
        }
    }
}
