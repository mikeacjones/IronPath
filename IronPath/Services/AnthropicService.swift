import Foundation

/// Service for interacting with Anthropic's Claude API
class AnthropicService {
    static let shared = AnthropicService()

    private let baseURL = "https://api.anthropic.com/v1"

    /// Get the currently configured model from user settings
    private var model: String {
        // Use AIProviderManager if Anthropic is selected, otherwise fall back to default
        if AIProviderManager.shared.selectedProviderType == .anthropic {
            return AIProviderManager.shared.currentModelId
        }
        // Fallback for backwards compatibility
        return ModelConfigManager.shared.modelId
    }

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
        // Try new AIProviderManager first
        if let key = AIProviderManager.shared.getAPIKey(for: .anthropic), !key.isEmpty {
            return key
        }
        // Fallback to legacy APIKeyManager for backwards compatibility
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
        allowDeloadRecommendation: Bool = false,
        techniqueOptions: WorkoutGenerationOptions = WorkoutGenerationOptions()
    ) async throws -> Workout {
        // Get available equipment from gym profile
        let availableEquipment: Set<Equipment>
        if let gymProfile = GymProfileManager.shared.activeProfile {
            availableEquipment = gymProfile.availableEquipment
        } else {
            availableEquipment = profile.availableEquipment
        }

        // Build the initial prompt for the agentic flow
        let systemPrompt = buildAgenticSystemPrompt(
            profile: profile,
            isDeload: isDeload,
            allowDeloadRecommendation: allowDeloadRecommendation,
            techniqueOptions: techniqueOptions
        )
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
        let preferenceManager = ExercisePreferenceManager.shared

        // Build the exercise list with history
        var result = "AVAILABLE EXERCISES (only use exercises from this list):\n\n"

        for exercise in matchingExercises {
            // Check if exercise should be excluded
            let pref = preferenceManager.getPreference(for: exercise.name)
            if pref == .doNotSuggest {
                continue
            }

            let prefNote: String
            switch pref {
            case .preferMore: prefNote = " [USER PREFERS]"
            case .preferLess: prefNote = " [USER DISLIKES - use sparingly]"
            default: prefNote = ""
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
    private func buildAgenticSystemPrompt(
        profile: UserProfile,
        isDeload: Bool = false,
        allowDeloadRecommendation: Bool = false,
        techniqueOptions: WorkoutGenerationOptions = WorkoutGenerationOptions()
    ) -> String {
        var prompt = """
        You are a personal fitness trainer creating workout plans. You MUST use the get_available_exercises tool to see what exercises are available before creating a workout.

        CRITICAL CONSTRAINTS:
        - Only include exercises that appear in the tool results. The user's gym has LIMITED EQUIPMENT - do not assume any exercise is available.
        - You are running in a HEADLESS AGENTIC LOOP - you CANNOT ask questions or request clarification. You must make reasonable decisions based on the information provided.
        - DO NOT include conversational text, questions, or suggestions in your response. Your final response MUST be ONLY the JSON workout object.
        - If the user requests a workout type they recently did, create the workout anyway - they may be following a specific program or schedule.

        User Profile:
        - Fitness Level: \(profile.fitnessLevel.rawValue)
        - Goals: \(profile.goals.map { $0.rawValue }.joined(separator: ", "))
        - Preferred Duration: \(profile.workoutPreferences.preferredWorkoutDuration) minutes
        - Preferred Rest Time: \(profile.workoutPreferences.preferredRestTime) seconds between sets
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
        3. Select exercises from the list as appropriate for the workout type and user profile
        4. Use the exercise history to suggest appropriate weights\(isDeload ? " (reduced to 50-70% for deload)" : " (progressive overload)")
        5. Return the workout in JSON format
        """

        // Build advanced techniques section based on options
        prompt += buildAdvancedTechniquesPrompt(techniqueOptions: techniqueOptions, fitnessLevel: profile.fitnessLevel)

        return prompt
    }

    /// Build the advanced techniques prompt section based on user options
    private func buildAdvancedTechniquesPrompt(techniqueOptions: WorkoutGenerationOptions, fitnessLevel: FitnessLevel) -> String {
        var prompt = ""

        // Check if any techniques are enabled
        let warmupEnabled = techniqueOptions.warmupSetMode != .disabled
        let dropSetEnabled = techniqueOptions.dropSetMode != .disabled
        let restPauseEnabled = techniqueOptions.restPauseMode != .disabled

        guard warmupEnabled || dropSetEnabled || restPauseEnabled else {
            return "\n\nADVANCED TRAINING TECHNIQUES: Do NOT include any advanced set types (warmup, dropSet, restPause). Use only standard sets."
        }

        prompt += "\n\nADVANCED TRAINING TECHNIQUES:\n"

        // Build requirements list
        var required: [String] = []
        var allowed: [String] = []

        if warmupEnabled {
            if techniqueOptions.warmupSetMode == .required {
                required.append("warmup sets (lighter weight to prepare muscles)")
            } else {
                allowed.append("warmup sets")
            }
        }

        if dropSetEnabled {
            if techniqueOptions.dropSetMode == .required {
                required.append("drop sets (reduce weight immediately after failure)")
            } else {
                allowed.append("drop sets")
            }
        }

        if restPauseEnabled {
            if techniqueOptions.restPauseMode == .required {
                required.append("rest-pause sets (brief 10-20s rest then continue)")
            } else {
                allowed.append("rest-pause sets")
            }
        }

        // Add requirements to prompt
        if !required.isEmpty {
            prompt += "⚠️ REQUIRED: You MUST include the following techniques in this workout:\n"
            for technique in required {
                prompt += "- \(technique)\n"
            }
            prompt += "\n"
        }

        if !allowed.isEmpty {
            prompt += "ALLOWED (use if appropriate for the user): \(allowed.joined(separator: ", "))\n\n"
        }

        // Add the JSON format explanation
        prompt += """
        To use advanced sets, add an "advancedSets" array to the exercise:
        "advancedSets": [
          {"setNumber": 1, "type": "warmup", "reps": "10", "weight": 50},
          {"setNumber": 2, "type": "standard", "reps": "8", "weight": 100},
          {"setNumber": 3, "type": "dropSet", "reps": "8", "weight": 100, "numberOfDrops": 2, "dropPercentage": 0.2},
          {"setNumber": 4, "type": "restPause", "reps": "8", "weight": 100, "numberOfPauses": 2, "pauseDuration": 15}
        ]
        """

        // Add fitness level guidance
        if fitnessLevel == .beginner && required.isEmpty {
            prompt += "\nNote: User is a beginner - only use advanced techniques sparingly unless specifically required."
        }

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
        // Add current date for context
        let todayStr = Date().formatted(date: .complete, time: .omitted)
        var prompt = "Today's Date: \(todayStr)\n\nPlease create a workout for me.\n\n"

        if isDeload {
            prompt += "⚠️ THIS IS A DELOAD WORKOUT - Use lighter weights (50-70% of normal) for recovery.\n\n"
        }

        if let workoutType = workoutType {
            prompt += "Workout Type: \(workoutType)\n"
            prompt += "Based on this workout type, decide which muscle groups to target and use the get_available_exercises tool to find appropriate exercises.\n\n"
        }

        if let notes = userNotes, !notes.isEmpty {
            prompt += "My Notes: \(notes)\n\n"
        }

        // Add comprehensive workout history with full set breakdown
        if !workoutHistory.isEmpty {
            prompt += "RECENT WORKOUT HISTORY:\n"

            // Show detailed history for last 5 workouts
            let relevantHistory = workoutHistory.filter { !$0.isDeload }.prefix(5)
            for workout in relevantHistory {
                let dateStr = workout.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? "recent"
                prompt += "\n[\(dateStr)] \(workout.name)\n"

                for exercise in workout.exercises {
                    let completedSets = exercise.sets.filter { $0.completedAt != nil }
                    if !completedSets.isEmpty {
                        prompt += "  - \(exercise.exercise.name):\n"
                        for (index, set) in completedSets.enumerated() {
                            let weight = set.weight.map { "\(Int($0))lbs" } ?? "bodyweight"
                            let reps = set.actualReps.map { "\($0) reps" } ?? "\(set.targetReps) reps (target)"
                            prompt += "      Set \(index + 1): \(weight) x \(reps)\n"
                        }
                    }
                }
            }

            // For auto-generate, provide more history context so Claude can recommend deload
            if allowDeloadRecommendation {
                prompt += "\nDELOAD CONTEXT:\n"
                let lastDeload = workoutHistory.last { $0.isDeload }
                if let lastDeload = lastDeload, let completedAt = lastDeload.completedAt {
                    let daysSinceDeload = Calendar.current.dateComponents([.day], from: completedAt, to: Date()).day ?? 0
                    prompt += "- Last deload workout: \(daysSinceDeload) days ago\n"
                } else {
                    prompt += "- No recent deload workouts in history\n"
                }
                let nonDeloadCount = workoutHistory.filter { !$0.isDeload }.count
                prompt += "- Total non-deload workouts in recent history: \(nonDeloadCount)\n"
            }

            prompt += "\nUse this history to:\n"
            prompt += "1. Suggest appropriate weights based on past performance (progressive overload)\n"
            prompt += "2. Vary exercise selection to ensure balanced training\n"
            prompt += "3. Avoid overtraining muscle groups that were recently worked hard\n\n"
        }

        // Add exercise preferences if any
        if let preferencePrompt = ExercisePreferenceManager.shared.generatePreferencePrompt() {
            prompt += preferencePrompt
            prompt += "\n"
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
              "sets": number,
              "reps": "rep range or target",
              "weight": \(isDeload ? "reduced weight (50-70% of history)" : "suggested weight based on history or appropriate starting weight"),
              "restSeconds": number,
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

            let sets: [ExerciseSet]

            // Check if Claude provided advanced set configurations
            if let advancedSets = exerciseJSON.advancedSets, !advancedSets.isEmpty {
                sets = advancedSets.enumerated().map { idx, advSet in
                    let setReps = advSet.reps.flatMap { Int($0.components(separatedBy: "-").first ?? "8") } ?? targetReps
                    let setWeight = advSet.weight ?? exerciseJSON.weight

                    switch advSet.setType {
                    case .standard:
                        return ExerciseSet(
                            setNumber: advSet.setNumber,
                            setType: .standard,
                            targetReps: setReps,
                            weight: setWeight,
                            restPeriod: TimeInterval(exerciseJSON.restSeconds)
                        )
                    case .warmup:
                        return ExerciseSet.createWarmupSet(
                            setNumber: advSet.setNumber,
                            targetReps: setReps,
                            weight: setWeight,
                            restPeriod: 60
                        )
                    case .dropSet:
                        return ExerciseSet.createDropSet(
                            setNumber: advSet.setNumber,
                            targetReps: setReps,
                            weight: setWeight,
                            restPeriod: TimeInterval(exerciseJSON.restSeconds),
                            numberOfDrops: advSet.numberOfDrops ?? 2,
                            dropPercentage: advSet.dropPercentage ?? 0.2
                        )
                    case .restPause:
                        return ExerciseSet.createRestPauseSet(
                            setNumber: advSet.setNumber,
                            targetReps: setReps,
                            weight: setWeight,
                            restPeriod: TimeInterval(exerciseJSON.restSeconds),
                            numberOfPauses: advSet.numberOfPauses ?? 2,
                            pauseDuration: TimeInterval(advSet.pauseDuration ?? 15)
                        )
                    }
                }
            } else {
                // Standard sets (backwards compatible)
                sets = (1...exerciseJSON.sets).map { setNum in
                    ExerciseSet(
                        setNumber: setNum,
                        setType: .standard,
                        targetReps: targetReps,
                        weight: exerciseJSON.weight,
                        restPeriod: TimeInterval(exerciseJSON.restSeconds)
                    )
                }
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
            "model": model,
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
