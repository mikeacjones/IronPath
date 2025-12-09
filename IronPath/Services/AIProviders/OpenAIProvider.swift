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
        availableExercises: [Exercise]
    ) async throws -> Workout {
        let systemPrompt = buildWorkoutSystemPrompt(
            profile: profile,
            isDeload: isDeload,
            allowDeloadRecommendation: allowDeloadRecommendation
        )

        let userPrompt = buildWorkoutUserPrompt(
            profile: profile,
            targetMuscleGroups: targetMuscleGroups,
            workoutHistory: workoutHistory,
            workoutType: workoutType,
            userNotes: userNotes,
            isDeload: isDeload,
            availableExercises: availableExercises
        )

        let response = try await sendChatRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        return try parseWorkoutResponse(response, prompt: userPrompt)
    }

    func replaceExercise(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout,
        availableExercises: [Exercise]
    ) async throws -> WorkoutExercise {
        let prompt = buildExerciseReplacementPrompt(
            exercise: exercise,
            profile: profile,
            reason: reason,
            currentWorkout: currentWorkout,
            availableExercises: availableExercises
        )

        let response = try await sendChatRequest(
            systemPrompt: "You are a fitness expert. Respond only with valid JSON.",
            userPrompt: prompt
        )

        return try parseExerciseReplacementResponse(response, originalExercise: exercise)
    }

    func getFormTips(exercise: Exercise, userLevel: FitnessLevel) async throws -> String {
        let prompt = """
        Provide form tips for the exercise "\(exercise.name)" for a \(userLevel.rawValue) level lifter.

        Include:
        1. Key form cues (3-4 points)
        2. Common mistakes to avoid
        3. Breathing pattern

        Keep it concise and actionable.
        """

        let response = try await sendChatRequest(
            systemPrompt: "You are an experienced personal trainer providing form guidance.",
            userPrompt: prompt
        )

        return response
    }

    func generateCustomExercise(
        description: String,
        profile: UserProfile
    ) async throws -> Exercise {
        let prompt = """
        Create a custom exercise based on this description: "\(description)"

        User's available equipment: \(profile.availableEquipment.map { $0.rawValue }.joined(separator: ", "))

        Return ONLY valid JSON with this structure:
        {
            "name": "Exercise Name",
            "primaryMuscles": ["chest", "triceps"],
            "secondaryMuscles": ["shoulders"],
            "equipment": "dumbbells",
            "difficulty": "intermediate",
            "instructions": "Step by step instructions",
            "formTips": "Key form cues"
        }

        Valid muscle groups: \(MuscleGroup.allCases.map { $0.rawValue }.joined(separator: ", "))
        Valid equipment: \(Equipment.allCases.map { $0.rawValue }.joined(separator: ", "))
        Valid difficulty: beginner, intermediate, advanced
        """

        let response = try await sendChatRequest(
            systemPrompt: "You are a fitness expert. Respond only with valid JSON.",
            userPrompt: prompt
        )

        return try parseCustomExerciseResponse(response)
    }

    func estimateCaloriesBurned(workoutSummary: String) async throws -> Int {
        let prompt = """
        Estimate calories burned for this workout:

        \(workoutSummary)

        Respond with ONLY a single integer representing the estimated calories burned.
        """

        let response = try await sendChatRequest(
            systemPrompt: "You are a fitness expert. Respond with only a number.",
            userPrompt: prompt
        )

        // Extract number from response
        let numbers = response.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 && $0 < 5000 }

        return numbers.first ?? 200
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
            "Authorization": "Bearer \(apiKey)"
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

    // MARK: - Prompt Building

    private func buildWorkoutSystemPrompt(
        profile: UserProfile,
        isDeload: Bool,
        allowDeloadRecommendation: Bool
    ) -> String {
        var prompt = """
        You are an expert personal trainer creating personalized workout programs.
        Always respond with valid JSON only - no markdown, no explanations.

        User Profile:
        - Fitness Level: \(profile.fitnessLevel.rawValue)
        - Goals: \(profile.goals.map { $0.rawValue }.joined(separator: ", "))
        - Training Style: \(profile.workoutPreferences.trainingStyle.rawValue)
        - Preferred Duration: \(profile.workoutPreferences.preferredWorkoutDuration) minutes
        - Rest Preference: \(profile.workoutPreferences.preferredRestTime) seconds
        """

        if isDeload {
            prompt += "\n\nThis is a DELOAD workout. Use 50-70% of normal weights and reduce volume."
        }

        return prompt
    }

    private func buildWorkoutUserPrompt(
        profile: UserProfile,
        targetMuscleGroups: Set<MuscleGroup>?,
        workoutHistory: [Workout],
        workoutType: String?,
        userNotes: String?,
        isDeload: Bool,
        availableExercises: [Exercise]
    ) -> String {
        // Get available equipment
        let availableEquipment: Set<Equipment>
        if let gymProfile = GymProfileManager.shared.activeProfile {
            availableEquipment = gymProfile.availableEquipment
        } else {
            availableEquipment = profile.availableEquipment
        }

        var prompt = """
        Generate a workout with these parameters:

        Workout Type: \(workoutType ?? "Full Body")
        Target Muscles: \(targetMuscleGroups?.map { $0.rawValue }.joined(separator: ", ") ?? "All")
        Available Equipment: \(availableEquipment.map { $0.rawValue }.joined(separator: ", "))

        Available Exercises (use ONLY these):
        \(availableExercises.prefix(50).map { "- \($0.name) (\($0.equipment.rawValue))" }.joined(separator: "\n"))
        """

        if let notes = userNotes, !notes.isEmpty {
            prompt += "\n\nUser Notes: \(notes)"
        }

        // Add recent workout history for progressive overload
        if !workoutHistory.isEmpty {
            prompt += "\n\nRecent workout history for progressive overload:"
            for workout in workoutHistory.prefix(3) {
                prompt += "\n- \(workout.name): "
                prompt += workout.exercises.prefix(3).map {
                    "\($0.exercise.name) @ \($0.sets.first?.weight ?? 0)lbs"
                }.joined(separator: ", ")
            }
        }

        prompt += """

        Return ONLY valid JSON with this structure:
        {
            "name": "Workout Name",
            "exercises": [
                {
                    "name": "Exercise Name (must be from available exercises list)",
                    "sets": 3,
                    "reps": "8-10",
                    "restSeconds": 90,
                    "equipment": "barbell",
                    "primaryMuscles": ["chest"],
                    "notes": "Optional form cues",
                    "weight": 135
                }
            ]
        }

        Include 4-6 exercises appropriate for the workout type and user's level.
        """

        return prompt
    }

    private func buildExerciseReplacementPrompt(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout,
        availableExercises: [Exercise]
    ) -> String {
        let otherExercises = currentWorkout.exercises
            .filter { $0.id != exercise.id }
            .map { $0.exercise.name }

        var prompt = """
        Suggest a replacement exercise.

        Current Exercise: \(exercise.exercise.name)
        - Sets: \(exercise.sets.count)
        - Target Reps: \(exercise.sets.first?.targetReps ?? 10)
        - Primary Muscles: \(exercise.exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))

        Other exercises in workout (avoid duplicates): \(otherExercises.joined(separator: ", "))

        Available exercises to choose from:
        \(availableExercises.filter { ex in
            !ex.primaryMuscleGroups.isDisjoint(with: exercise.exercise.primaryMuscleGroups)
        }.prefix(20).map { $0.name }.joined(separator: ", "))
        """

        if let reason = reason, !reason.isEmpty {
            prompt += "\n\nReason for replacement: \(reason)"
        }

        prompt += """

        Return ONLY valid JSON:
        {
            "name": "New Exercise Name",
            "sets": \(exercise.sets.count),
            "reps": "\(exercise.sets.first?.targetReps ?? 10)",
            "restSeconds": \(Int(exercise.sets.first?.restPeriod ?? 90)),
            "equipment": "equipment type",
            "primaryMuscles": ["muscle1", "muscle2"],
            "notes": "Why this is a good replacement"
        }
        """

        return prompt
    }

    // MARK: - Response Parsing

    private func parseWorkoutResponse(_ response: String, prompt: String) throws -> Workout {
        // Extract JSON from response (handle markdown code blocks)
        var jsonString = response
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards) {
            jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIProviderError.parseError(detail: "Could not convert response to data")
        }

        let decoder = JSONDecoder()
        let workoutJSON = try decoder.decode(WorkoutJSON.self, from: jsonData)

        // Build workout from JSON
        var exercises: [WorkoutExercise] = []

        for (index, exerciseJSON) in workoutJSON.exercises.enumerated() {
            let exercise = findOrCreateExercise(
                name: exerciseJSON.name,
                primaryMuscleGroups: Set(exerciseJSON.primaryMuscles.compactMap { MuscleGroup(rawValue: $0) }),
                equipment: Equipment.fromString(exerciseJSON.equipment)
            )

            let reps = parseReps(exerciseJSON.reps)
            var sets: [ExerciseSet] = []

            for setNum in 1...exerciseJSON.sets {
                sets.append(ExerciseSet(
                    setNumber: setNum,
                    targetReps: reps,
                    weight: exerciseJSON.weight,
                    restPeriod: TimeInterval(exerciseJSON.restSeconds)
                ))
            }

            exercises.append(WorkoutExercise(
                exercise: exercise,
                sets: sets,
                orderIndex: index,
                notes: exerciseJSON.notes ?? ""
            ))
        }

        return Workout(
            name: workoutJSON.name,
            exercises: exercises,
            claudeGenerationPrompt: prompt,
            isDeload: workoutJSON.isDeload ?? false
        )
    }

    private func parseExerciseReplacementResponse(_ response: String, originalExercise: WorkoutExercise) throws -> WorkoutExercise {
        var jsonString = response
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards) {
            jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIProviderError.parseError(detail: "Could not convert response to data")
        }

        let decoder = JSONDecoder()
        let exerciseJSON = try decoder.decode(ExerciseJSON.self, from: jsonData)

        let exercise = findOrCreateExercise(
            name: exerciseJSON.name,
            primaryMuscleGroups: Set(exerciseJSON.primaryMuscles.compactMap { MuscleGroup(rawValue: $0) }),
            equipment: Equipment.fromString(exerciseJSON.equipment)
        )

        let reps = parseReps(exerciseJSON.reps)
        var sets: [ExerciseSet] = []

        for setNum in 1...exerciseJSON.sets {
            sets.append(ExerciseSet(
                setNumber: setNum,
                targetReps: reps,
                weight: exerciseJSON.weight,
                restPeriod: TimeInterval(exerciseJSON.restSeconds)
            ))
        }

        return WorkoutExercise(
            exercise: exercise,
            sets: sets,
            orderIndex: originalExercise.orderIndex,
            notes: exerciseJSON.notes ?? ""
        )
    }

    private func parseCustomExerciseResponse(_ response: String) throws -> Exercise {
        var jsonString = response
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards) {
            jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIProviderError.parseError(detail: "Could not convert response to data")
        }

        let decoder = JSONDecoder()
        let exerciseJSON = try decoder.decode(CustomExerciseJSON.self, from: jsonData)

        return Exercise(
            name: exerciseJSON.name,
            primaryMuscleGroups: Set(exerciseJSON.primaryMuscles.compactMap { MuscleGroup(rawValue: $0) }),
            secondaryMuscleGroups: Set(exerciseJSON.secondaryMuscles.compactMap { MuscleGroup(rawValue: $0) }),
            equipment: Equipment.fromString(exerciseJSON.equipment),
            difficulty: ExerciseDifficulty(rawValue: exerciseJSON.difficulty) ?? .intermediate,
            instructions: exerciseJSON.instructions,
            formTips: exerciseJSON.formTips,
            isCustom: true
        )
    }

    // MARK: - Helpers

    private func findOrCreateExercise(
        name: String,
        primaryMuscleGroups: Set<MuscleGroup>,
        equipment: Equipment
    ) -> Exercise {
        let lowercasedName = name.lowercased()

        // Try exact match
        if let dbExercise = ExerciseDatabase.shared.exercises.first(where: {
            $0.name.lowercased() == lowercasedName
        }) {
            return dbExercise
        }

        // Try fuzzy match
        if let dbExercise = ExerciseDatabase.shared.exercises.first(where: {
            $0.name.lowercased().contains(lowercasedName) ||
            lowercasedName.contains($0.name.lowercased())
        }) {
            return dbExercise
        }

        // Create new exercise
        return Exercise(
            name: name,
            primaryMuscleGroups: primaryMuscleGroups,
            equipment: equipment
        )
    }

    private func parseReps(_ repsString: String) -> Int {
        // Handle range like "8-10" by taking the lower bound
        if repsString.contains("-") {
            let parts = repsString.split(separator: "-")
            if let first = parts.first, let reps = Int(first.trimmingCharacters(in: .whitespaces)) {
                return reps
            }
        }
        return Int(repsString) ?? 10
    }
}
