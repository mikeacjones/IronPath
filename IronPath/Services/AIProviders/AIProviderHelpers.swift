import Foundation

// MARK: - AI Provider Helpers

/// Shared helper functions for AI providers to ensure consistent prompt building and response parsing
enum AIProviderHelpers {

    // MARK: - Exercise Database Lookup

    /// Find a matching exercise from the database by name
    /// Returns the database exercise (with video URL) if found, otherwise creates a new one
    static func findOrCreateExercise(
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

    // MARK: - Available Exercises

    /// Get available exercises filtered by equipment and muscle groups, formatted for AI prompt
    static func getAvailableExercisesPrompt(
        muscleGroups: Set<MuscleGroup>,
        availableEquipment: Set<Equipment>,
        workoutHistory: [Workout]
    ) -> String {
        // Get available specific machines from active gym profile
        let availableMachines = GymProfileManager.shared.activeProfile?.availableMachines ?? []

        // Filter exercises by equipment
        let equipmentFilteredExercises = ExerciseDatabase.shared.exercises.filter { exercise in
            // Check if user has the required equipment
            if availableEquipment.contains(exercise.equipment) {
                // If exercise requires a specific machine, check if it's available
                if let specificMachine = exercise.specificMachine {
                    return availableMachines.contains(specificMachine)
                }
                return true
            }

            return false
        }

        // Also filter by target muscle groups
        let matchingExercises = equipmentFilteredExercises.filter { exercise in
            !muscleGroups.isDisjoint(with: exercise.primaryMuscleGroups) ||
            !muscleGroups.isDisjoint(with: exercise.secondaryMuscleGroups)
        }

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

        return result
    }

    /// Get exercise history string for a specific exercise
    private static func getExerciseHistory(exerciseName: String, from workouts: [Workout]) -> String {
        var history: [String] = []

        for workout in workouts.prefix(5) {
            for exercise in workout.exercises where exercise.exercise.name.lowercased() == exerciseName.lowercased() {
                let completedSets = exercise.sets.filter { $0.completedAt != nil }
                if let lastSet = completedSets.last, let weight = lastSet.weight {
                    let reps = lastSet.actualReps ?? lastSet.targetReps
                    let dateStr = workout.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? "recent"
                    history.append("\(dateStr): \(Int(weight))lbs x \(reps)")
                }
            }
        }

        return history.prefix(3).joined(separator: ", ")
    }

    // MARK: - Prompt Building

    /// Build system prompt for workout generation
    static func buildWorkoutSystemPrompt(
        profile: UserProfile,
        isDeload: Bool,
        allowDeloadRecommendation: Bool,
        techniqueOptions: WorkoutGenerationOptions
    ) -> String {
        // Get gym equipment summary
        let gymSummary = GymSettings.shared.equipmentSummaryForClaude()

        var prompt = """
        You are an expert personal trainer creating personalized workout programs.
        Always respond with valid JSON only - no markdown code blocks, no explanations outside the JSON.

        USER PROFILE:
        - Fitness Level: \(profile.fitnessLevel.rawValue)
        - Goals: \(profile.goals.map { $0.rawValue }.joined(separator: ", "))
        - Training Style: \(profile.workoutPreferences.trainingStyle.rawValue)
        - Preferred Duration: \(profile.workoutPreferences.preferredWorkoutDuration) minutes
        - Preferred Rest: \(profile.workoutPreferences.preferredRestTime) seconds between sets

        GYM EQUIPMENT:
        \(gymSummary)

        WORKOUT GENERATION RULES:
        1. ONLY use exercises from the available exercises list provided
        2. Match exercise names EXACTLY as they appear in the list
        3. Create \(profile.workoutPreferences.preferredWorkoutDuration > 45 ? "5-7" : "4-5") exercises for a balanced workout
        4. Use the exercise history to suggest appropriate weights\(isDeload ? " (reduced to 50-70% for deload)" : " (progressive overload)")
        5. Return the workout in JSON format
        """

        // Build advanced techniques section
        prompt += buildAdvancedTechniquesPrompt(techniqueOptions: techniqueOptions, fitnessLevel: profile.fitnessLevel)

        return prompt
    }

    /// Build advanced techniques prompt section
    static func buildAdvancedTechniquesPrompt(techniqueOptions: WorkoutGenerationOptions, fitnessLevel: FitnessLevel) -> String {
        var prompt = ""

        let warmupEnabled = techniqueOptions.warmupSetMode != .disabled
        let dropSetEnabled = techniqueOptions.dropSetMode != .disabled
        let restPauseEnabled = techniqueOptions.restPauseMode != .disabled

        guard warmupEnabled || dropSetEnabled || restPauseEnabled else {
            return "\n\nADVANCED TRAINING TECHNIQUES: Do NOT include any advanced set types (warmup, dropSet, restPause). Use only standard sets."
        }

        prompt += "\n\nADVANCED TRAINING TECHNIQUES:\n"

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

        prompt += """
        To use advanced sets, add an "advancedSets" array to the exercise:
        "advancedSets": [
          {"setNumber": 1, "type": "warmup", "reps": "10", "weight": 50},
          {"setNumber": 2, "type": "standard", "reps": "8", "weight": 100},
          {"setNumber": 3, "type": "dropSet", "reps": "8", "weight": 100, "numberOfDrops": 2, "dropPercentage": 0.2},
          {"setNumber": 4, "type": "restPause", "reps": "8", "weight": 100, "numberOfPauses": 2, "pauseDuration": 15}
        ]
        """

        if fitnessLevel == .beginner && required.isEmpty {
            prompt += "\nNote: User is a beginner - only use advanced techniques sparingly unless specifically required."
        }

        return prompt
    }

    /// Build user prompt for workout generation
    static func buildWorkoutUserPrompt(
        workoutType: String?,
        targetMuscleGroups: Set<MuscleGroup>?,
        userNotes: String?,
        workoutHistory: [Workout],
        isDeload: Bool,
        allowDeloadRecommendation: Bool,
        availableExercises: String,
        techniqueOptions: WorkoutGenerationOptions
    ) -> String {
        let todayStr = Date().formatted(date: .complete, time: .omitted)
        var prompt = "Today's Date: \(todayStr)\n\nPlease create a workout for me.\n\n"

        if isDeload {
            prompt += "⚠️ THIS IS A DELOAD WORKOUT - Use lighter weights (50-70% of normal) for recovery.\n\n"
        }

        if let workoutType = workoutType {
            prompt += "Workout Type: \(workoutType)\n\n"
        }

        if let notes = userNotes, !notes.isEmpty {
            prompt += "My Notes: \(notes)\n\n"
        }

        // Add workout history
        if !workoutHistory.isEmpty {
            prompt += "RECENT WORKOUT HISTORY:\n"

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

        // Add exercise preferences
        if let preferencePrompt = ExercisePreferenceManager.shared.generatePreferencePrompt() {
            prompt += preferencePrompt
            prompt += "\n"
        }

        // Add available exercises
        prompt += availableExercises
        prompt += "\n"

        // Add JSON format specification
        let supersetEnabled = techniqueOptions.supersetMode != .disabled
        let supersetRequired = techniqueOptions.supersetMode == .required

        let weightInstruction = isDeload ? "reduced weight (50-70% of history)" : "suggested weight based on history or appropriate starting weight"
        let deloadComment = allowDeloadRecommendation ? " // Set to true if you recommend a deload based on training history" : ""

        prompt += "Return the workout as JSON with this structure:\n"
        prompt += "{\n"
        prompt += "  \"name\": \"\(isDeload ? "Deload - " : "")Workout name\",\n"
        prompt += "  \"isDeload\": \(isDeload ? "true" : "false")\(deloadComment),\n"
        prompt += "  \"exercises\": [\n"
        prompt += "    {\n"
        prompt += "      \"name\": \"Exercise name (must match exactly from the list)\",\n"
        prompt += "      \"sets\": number,\n"
        prompt += "      \"reps\": \"rep range or target\",\n"
        prompt += "      \"weight\": \(weightInstruction),\n"
        prompt += "      \"restSeconds\": number,\n"
        prompt += "      \"equipment\": \"equipment type\",\n"
        prompt += "      \"primaryMuscles\": [\"muscle1\"],\n"
        prompt += "      \"notes\": \"Optional coaching notes\"\n"
        prompt += "    }\n"
        prompt += "  ]"

        if supersetEnabled {
            prompt += ",\n"
            prompt += "  \"exerciseGroups\": [\n"
            prompt += "    {\n"
            prompt += "      \"type\": \"superset|triset|giantSet|circuit\",\n"
            prompt += "      \"exerciseIndices\": [0, 1],\n"
            prompt += "      \"restBetweenExercises\": 0,\n"
            prompt += "      \"restAfterGroup\": 90\n"
            prompt += "    }\n"
            prompt += "  ]\n"
        } else {
            prompt += "\n"
        }

        prompt += "}\n"

        // Add superset instructions based on mode
        if supersetRequired {
            prompt += "\n⚠️ SUPERSETS REQUIRED:\n"
            prompt += "You MUST include at least one superset or circuit in this workout.\n"
            prompt += "Group exercises together as supersets (2 exercises), trisets (3), giant sets (4+), or circuits.\n"
            prompt += "- Use supersets for antagonist pairs (e.g., biceps/triceps, chest/back) or to save time\n"
            prompt += "- exerciseIndices are 0-based indices into the exercises array\n"
            prompt += "- restBetweenExercises is typically 0 for supersets (exercises done back-to-back)\n"
            prompt += "- restAfterGroup is rest after completing one round of the group\n"
        } else if supersetEnabled {
            prompt += "\nSUPERSETS & CIRCUITS (optional):\n"
            prompt += "You can group exercises together as supersets (2 exercises), trisets (3), giant sets (4+), or circuits.\n"
            prompt += "- Use supersets for antagonist pairs (e.g., biceps/triceps, chest/back) or to save time\n"
            prompt += "- exerciseIndices are 0-based indices into the exercises array\n"
            prompt += "- restBetweenExercises is typically 0 for supersets (exercises done back-to-back)\n"
            prompt += "- restAfterGroup is rest after completing one round of the group\n"
            prompt += "- Only include exerciseGroups if you want to create supersets/circuits; omit for standard workouts\n"
        } else {
            prompt += "\nNOTE: Do NOT include exerciseGroups or supersets in this workout. Keep all exercises separate with standard rest periods.\n"
        }

        return prompt
    }

    /// Build prompt for exercise replacement
    static func buildExerciseReplacementPrompt(
        exercise: WorkoutExercise,
        profile: UserProfile,
        reason: String?,
        currentWorkout: Workout,
        availableExercises: String
    ) -> String {
        let otherExercises = currentWorkout.exercises
            .filter { $0.id != exercise.id }
            .map { $0.exercise.name }

        var prompt = """
        Find a replacement for the exercise "\(exercise.exercise.name)".

        Current Exercise Details:
        - Name: \(exercise.exercise.name)
        - Equipment: \(exercise.exercise.equipment.rawValue)
        - Primary Muscles: \(exercise.exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
        - Sets: \(exercise.sets.count)
        - Target Reps: \(exercise.sets.first?.targetReps ?? 10)
        - Weight: \(exercise.sets.first?.weight.map { "\(Int($0)) lbs" } ?? "not specified")

        Other exercises already in workout (DO NOT suggest these): \(otherExercises.joined(separator: ", "))

        """

        if let reason = reason, !reason.isEmpty {
            prompt += "Reason for replacement: \(reason)\n\n"
        }

        prompt += availableExercises

        prompt += """

        Return ONLY valid JSON (no markdown, no explanations):
        {
            "name": "Replacement Exercise Name (must match exactly from available list)",
            "sets": \(exercise.sets.count),
            "reps": "\(exercise.sets.first?.targetReps ?? 10)",
            "weight": suggested_weight_number,
            "restSeconds": \(Int(exercise.sets.first?.restPeriod ?? 90)),
            "equipment": "equipment type",
            "primaryMuscles": ["muscle1", "muscle2"],
            "notes": "Brief explanation of why this is a good replacement"
        }

        Requirements:
        1. The replacement MUST target the same primary muscle groups
        2. The replacement MUST be from the available exercises list
        3. The replacement MUST NOT be an exercise already in the workout
        4. Match the original exercise's difficulty level
        """

        return prompt
    }

    // MARK: - Response Parsing

    /// Parse workout response from JSON string
    static func parseWorkoutResponse(_ response: String, prompt: String) throws -> Workout {
        // Extract JSON from response (handle markdown code blocks)
        var jsonString = response
        if let jsonStart = response.firstIndex(of: "{"),
           let jsonEnd = response.lastIndex(of: "}"),
           jsonStart <= jsonEnd {
            jsonString = String(response[jsonStart...jsonEnd])
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIProviderError.parseError(detail: "Could not convert response to data")
        }

        let decoder = JSONDecoder()
        let workoutJSON: WorkoutJSON
        do {
            workoutJSON = try decoder.decode(WorkoutJSON.self, from: jsonData)
        } catch {
            print("DEBUG: JSON decode error: \(error)")
            print("DEBUG: JSON string was: \(jsonString.prefix(1000))")
            throw AIProviderError.parseError(detail: "JSON decode failed: \(error.localizedDescription)")
        }

        return try buildWorkout(from: workoutJSON, prompt: prompt)
    }

    /// Build Workout model from parsed JSON
    static func buildWorkout(from workoutJSON: WorkoutJSON, prompt: String) throws -> Workout {
        let exercises = workoutJSON.exercises.enumerated().map { index, exerciseJSON in
            let equipment = Equipment.fromString(exerciseJSON.equipment)
            let primaryMuscles = Set(exerciseJSON.primaryMuscles.compactMap { MuscleGroup(rawValue: $0) })

            let exercise = findOrCreateExercise(
                name: exerciseJSON.name,
                primaryMuscleGroups: primaryMuscles,
                equipment: equipment
            )

            let targetReps = Int(exerciseJSON.reps.components(separatedBy: "-").first ?? "10") ?? 10

            let sets: [ExerciseSet]

            if let advancedSets = exerciseJSON.advancedSets, !advancedSets.isEmpty {
                sets = advancedSets.map { advSet in
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

        // Build exercise groups if provided
        var exerciseGroups: [ExerciseGroup]? = nil
        if let groupsJSON = workoutJSON.exerciseGroups, !groupsJSON.isEmpty {
            exerciseGroups = groupsJSON.compactMap { groupJSON -> ExerciseGroup? in
                let exerciseIds = groupJSON.exerciseIndices.compactMap { index -> UUID? in
                    guard index >= 0 && index < exercises.count else { return nil }
                    return exercises[index].id
                }

                guard exerciseIds.count >= 2 else { return nil }

                return ExerciseGroup(
                    groupType: groupJSON.groupType,
                    name: groupJSON.name,
                    exerciseIds: exerciseIds,
                    restBetweenExercises: TimeInterval(groupJSON.restBetweenExercises ?? 0),
                    restAfterGroup: TimeInterval(groupJSON.restAfterGroup ?? 90),
                    rounds: groupJSON.rounds ?? 1
                )
            }
        }

        return Workout(
            name: workoutJSON.name,
            exercises: exercises,
            exerciseGroups: exerciseGroups,
            claudeGenerationPrompt: prompt,
            isDeload: workoutJSON.isDeload ?? false
        )
    }

    /// Parse exercise replacement response
    static func parseExerciseReplacementResponse(_ response: String, originalExercise: WorkoutExercise) throws -> WorkoutExercise {
        var jsonString = response
        if let jsonStart = response.firstIndex(of: "{"),
           let jsonEnd = response.lastIndex(of: "}"),
           jsonStart <= jsonEnd {
            jsonString = String(response[jsonStart...jsonEnd])
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

        let targetReps = Int(exerciseJSON.reps.components(separatedBy: "-").first ?? "10") ?? 10

        let sets: [ExerciseSet] = (1...exerciseJSON.sets).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                setType: .standard,
                targetReps: targetReps,
                weight: exerciseJSON.weight,
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

    /// Parse custom exercise response
    static func parseCustomExerciseResponse(_ response: String) throws -> Exercise {
        var jsonString = response
        if let jsonStart = response.firstIndex(of: "{"),
           let jsonEnd = response.lastIndex(of: "}"),
           jsonStart <= jsonEnd {
            jsonString = String(response[jsonStart...jsonEnd])
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

    /// Parse calorie estimation response
    static func parseCalorieEstimation(_ response: String) -> Int {
        let numbers = response.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 && $0 < 5000 }

        return numbers.first ?? 200
    }

    // MARK: - Prompt Templates

    /// Form tips prompt
    static func buildFormTipsPrompt(exercise: Exercise, userLevel: FitnessLevel) -> String {
        """
        Provide form tips for the exercise "\(exercise.name)" for a \(userLevel.rawValue) level lifter.

        Include:
        1. Key form cues (3-4 points)
        2. Common mistakes to avoid
        3. Breathing pattern

        Keep it concise and actionable. Do not use markdown formatting.
        """
    }

    /// Custom exercise prompt
    static func buildCustomExercisePrompt(description: String, availableEquipment: Set<Equipment>) -> String {
        """
        Create a custom exercise based on this description: "\(description)"

        User's available equipment: \(availableEquipment.map { $0.rawValue }.joined(separator: ", "))

        Return ONLY valid JSON with this structure (no markdown, no explanations):
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
    }

    /// Calorie estimation prompt
    static func buildCalorieEstimationPrompt(workoutSummary: String) -> String {
        """
        Estimate calories burned for this workout:

        \(workoutSummary)

        IMPORTANT: Be CONSERVATIVE in your estimates. It's better to underestimate than overestimate.

        Typical calorie burn rates for strength training:
        - Light intensity: 3-4 calories per minute
        - Moderate intensity: 5-7 calories per minute
        - High intensity: 8-10 calories per minute

        Respond with ONLY a single integer representing the estimated calories burned.
        No explanation, no text, just the number.
        """
    }
}
