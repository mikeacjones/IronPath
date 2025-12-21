import Foundation
import OSLog

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
                    let weightStr = workout.weightUnit.format(weight)
                    history.append("\(dateStr): \(weightStr) x \(reps)")
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
        let builder = WorkoutPromptBuilder(
            profile: profile,
            techniqueOptions: techniqueOptions,
            isDeload: isDeload
        )
        return builder.buildSystemPrompt()
    }

    /// Build advanced techniques prompt section
    static func buildAdvancedTechniquesPrompt(techniqueOptions: WorkoutGenerationOptions, fitnessLevel: FitnessLevel) -> String {
        // Delegate to PromptComponents
        if let section = PromptComponents.techniqueSection(options: techniqueOptions, fitnessLevel: fitnessLevel) {
            return "\n\n" + section.render()
        }
        return "\n\nADVANCED TRAINING TECHNIQUES: Do NOT include any advanced set types (warmup, dropSet, restPause). Use only standard sets."
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
        techniqueOptions: WorkoutGenerationOptions,
        profile: UserProfile? = nil
    ) -> String {
        // Get profile from parameter or fallback to creating from gym profile
        let userProfile: UserProfile
        if let profile = profile {
            userProfile = profile
        } else if let gymProfile = GymProfileManager.shared.activeProfile {
            // Create minimal profile from gym profile
            userProfile = UserProfile(
                name: gymProfile.name,
                fitnessLevel: .intermediate,
                goals: [.hypertrophy],
                availableEquipment: gymProfile.availableEquipment,
                workoutPreferences: WorkoutPreferences()
            )
        } else {
            // Last resort: use defaults
            userProfile = UserProfile(
                name: "User",
                fitnessLevel: .intermediate,
                goals: [.hypertrophy],
                availableEquipment: Set(Equipment.allCases),
                workoutPreferences: WorkoutPreferences()
            )
        }

        let builder = WorkoutPromptBuilder(
            profile: userProfile,
            techniqueOptions: techniqueOptions,
            workoutType: workoutType,
            targetMuscles: targetMuscleGroups,
            isDeload: isDeload,
            userNotes: userNotes
        )

        return builder.buildUserPrompt(history: workoutHistory, availableExercises: availableExercises)
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

        let weightStr = exercise.sets.first?.weight.map { currentWorkout.weightUnit.formatWithSpace($0) } ?? "not specified"

        var prompt = """
        Find a replacement for the exercise "\(exercise.exercise.name)".

        Current Exercise Details:
        - Name: \(exercise.exercise.name)
        - Equipment: \(exercise.exercise.equipment.rawValue)
        - Primary Muscles: \(exercise.exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
        - Sets: \(exercise.sets.count)
        - Target Reps: \(exercise.sets.first?.targetReps ?? 10)
        - Weight: \(weightStr)

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

    // MARK: - Weight Validation

    /// Standard kettlebell weights in lbs
    private static let standardKettlebellWeights: [Double] = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80, 90, 100]

    /// Validate and snap all weights in a workout to available equipment
    /// This ensures LLM-generated weights match gym equipment constraints
    static func validateAndSnapWeights(in workout: inout Workout) {
        for exerciseIndex in workout.exercises.indices {
            let equipment = workout.exercises[exerciseIndex].exercise.equipment
            let exerciseName = workout.exercises[exerciseIndex].exercise.name

            for setIndex in workout.exercises[exerciseIndex].sets.indices {
                var set = workout.exercises[exerciseIndex].sets[setIndex]

                // Snap main weight
                if let weight = set.weight {
                    let snappedWeight = snapWeight(weight, for: equipment, exerciseName: exerciseName)
                    if abs(weight - snappedWeight) > 0.01 {
                        AppLogger.ai.debug("Weight adjusted: \(weight) -> \(snappedWeight) lbs for \(exerciseName) (\(equipment.rawValue), \(set.setType.rawValue))")
                        set.weight = snappedWeight
                    }
                }

                // Handle drop set weights
                if var dropConfig = set.dropSetConfig {
                    for dropIndex in dropConfig.drops.indices {
                        if let targetWeight = dropConfig.drops[dropIndex].targetWeight {
                            let snappedWeight = snapWeight(targetWeight, for: equipment, exerciseName: exerciseName)
                            if abs(targetWeight - snappedWeight) > 0.01 {
                                AppLogger.ai.debug("Drop weight adjusted: \(targetWeight) -> \(snappedWeight) lbs for \(exerciseName) drop #\(dropIndex)")
                                dropConfig.drops[dropIndex].targetWeight = snappedWeight
                            }
                        }
                    }
                    set.dropSetConfig = dropConfig
                }

                workout.exercises[exerciseIndex].sets[setIndex] = set
            }
        }
    }

    /// Snap a weight to the nearest valid weight for equipment type
    private static func snapWeight(_ weight: Double, for equipment: Equipment, exerciseName: String) -> Double {
        let gymSettings = GymSettings.shared

        switch equipment {
        case .dumbbells:
            return gymSettings.roundToValidWeight(weight, for: .dumbbells)

        case .cables:
            return gymSettings.roundToValidWeight(weight, for: .cables, exerciseName: exerciseName)

        case .barbell, .trapBar, .squat, .smithMachine:
            // For plate-loaded equipment, round to nearest 5 lbs
            return (weight / 5.0).rounded() * 5.0

        case .kettlebells:
            // Snap to standard kettlebell weights
            return standardKettlebellWeights.min(by: { abs($0 - weight) < abs($1 - weight) }) ?? weight

        case .legPress:
            // Leg press typically uses plates - round to nearest 10 lbs
            return (weight / 10.0).rounded() * 10.0

        default:
            return weight
        }
    }

    // MARK: - Response Parsing

    /// Parse workout response from JSON string
    static func parseWorkoutResponse(_ response: String, prompt: String, profile: UserProfile) throws -> Workout {
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
            AppLogger.ai.error("JSON decode error: \(error)")
            AppLogger.ai.debug("JSON string was: \(jsonString.prefix(1000))")
            throw AIProviderError.parseError(detail: "JSON decode failed: \(error.localizedDescription)")
        }

        var workout = try buildWorkout(from: workoutJSON, prompt: prompt, profile: profile)

        // Validate and snap all weights to available equipment
        validateAndSnapWeights(in: &workout)

        return workout
    }

    /// Build Workout model from parsed JSON
    static func buildWorkout(from workoutJSON: WorkoutJSON, prompt: String, profile: UserProfile) throws -> Workout {
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
                            dropPercentage: advSet.dropPercentage ?? 0.2,
                            equipment: equipment,
                            exerciseName: exerciseJSON.name
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
                    case .timed:
                        // AI should not typically generate timed sets, but handle it gracefully
                        return ExerciseSet.createTimedSet(
                            setNumber: advSet.setNumber,
                            targetDuration: 30, // Default 30 seconds
                            restPeriod: TimeInterval(exerciseJSON.restSeconds)
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
            isDeload: workoutJSON.isDeload ?? false,
            weightUnit: GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds
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

    /// Build prompt for AI workout summary generation
    static func buildWorkoutSummaryPrompt(
        workout: Workout,
        recentWorkouts: [Workout],
        personalRecords: [WorkoutPR]
    ) -> String {
        let weightUnit = workout.weightUnit

        var prompt = "Generate a brief, encouraging summary (2-3 sentences) for this completed workout:\n\n"

        // Current workout details
        prompt += "WORKOUT: \(workout.name)\n"
        if let duration = workout.duration {
            let minutes = Int(duration / 60)
            prompt += "Duration: \(minutes) minutes\n"
        }

        prompt += "\nEXERCISES COMPLETED:\n"
        for exercise in workout.exercises {
            let completedSets = exercise.sets.filter { $0.completedAt != nil }
            guard !completedSets.isEmpty else { continue }

            prompt += "- \(exercise.exercise.name): "
            let setDescriptions = completedSets.map { set -> String in
                let weight = set.weight.map { weightUnit.format($0) } ?? "bodyweight"
                let reps = set.actualReps ?? set.targetReps
                return "\(weight) x \(reps)"
            }
            prompt += setDescriptions.joined(separator: ", ")
            prompt += "\n"
        }

        // Include any PRs hit
        if !personalRecords.isEmpty {
            prompt += "\nPERSONAL RECORDS SET:\n"
            for pr in personalRecords {
                let valueStr: String
                switch pr.type {
                case .weight:
                    valueStr = weightUnit.format(pr.newValue)
                case .volume:
                    valueStr = "\(weightUnit.format(pr.newValue)) total volume"
                case .reps:
                    valueStr = "\(Int(pr.newValue)) reps"
                }
                prompt += "- \(pr.exerciseName): \(valueStr) (\(pr.type.displayName))\n"
            }
        }

        // Recent context
        if !recentWorkouts.isEmpty {
            prompt += "\nRECENT TRAINING (for context):\n"
            for recentWorkout in recentWorkouts.prefix(3) {
                let dateStr = recentWorkout.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? "recent"
                prompt += "- \(dateStr): \(recentWorkout.name)\n"
            }
        }

        prompt += """

        GUIDELINES:
        - Be supportive and encouraging but not over-the-top
        - Highlight any notable achievements (PRs, heavy lifts, good volume)
        - Keep it natural and conversational
        - Do NOT use emojis
        - Maximum 2-3 sentences
        """

        return prompt
    }
}
