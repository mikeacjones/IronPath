import Foundation

/// Executes tool calls during agentic workout generation
@MainActor
class AgentToolExecutor {

    // MARK: - Properties

    private weak var builder: AgentWorkoutBuilder?

    // MARK: - Initialization

    init(builder: AgentWorkoutBuilder) {
        self.builder = builder
    }

    // MARK: - Main Execution

    /// Execute a tool call and return the result
    func execute(_ call: ToolCall) async throws -> ToolResult {
        switch call.name {
        // Read-only tools
        case "get_user_profile":
            return getUserProfile(call)
        case "get_gym_equipment":
            return getGymEquipment(call)
        case "get_dumbbell_weights":
            return getDumbbellWeights(call)
        case "get_cable_weights":
            return getCableWeights(call)
        case "get_available_exercises":
            return getAvailableExercises(call)
        case "get_exercise_history":
            return getExerciseHistory(call)
        case "get_exercise_preferences":
            return getExercisePreferences(call)
        case "get_workout_history":
            return getWorkoutHistory(call)
        case "get_technique_settings":
            return getTechniqueSettings(call)

        // Action tools
        case "set_workout_name":
            return setWorkoutName(call)
        case "add_exercise":
            return addExercise(call)
        case "create_exercise":
            return createExercise(call)
        case "add_warmup_set":
            return addWarmupSet(call)
        case "add_drop_set":
            return addDropSet(call)
        case "add_rest_pause_set":
            return addRestPauseSet(call)
        case "create_superset":
            return createSuperset(call)
        case "finalize_workout":
            return finalizeWorkout(call)

        default:
            throw AgentError.unknownTool(call.name)
        }
    }

    // MARK: - Read-Only Tool Handlers

    private func getUserProfile(_ call: ToolCall) -> ToolResult {
        guard let profile = builder?.profile else {
            return .error(toolCallId: call.id, message: "Builder not available")
        }

        let content: [String: Any] = [
            "fitnessLevel": profile.fitnessLevel.rawValue,
            "goals": profile.goals.map { $0.rawValue },
            "trainingStyle": profile.workoutPreferences.trainingStyle.rawValue,
            "preferredDuration": profile.workoutPreferences.preferredWorkoutDuration,
            "preferredRestTime": profile.workoutPreferences.preferredRestTime,
            "workoutSplit": profile.workoutPreferences.workoutSplit.rawValue,
            "workoutsPerWeek": profile.workoutPreferences.workoutsPerWeek
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func getGymEquipment(_ call: ToolCall) -> ToolResult {
        let gymProfile = GymProfileManager.shared.activeProfile

        let equipment = gymProfile?.availableEquipment.map { $0.rawValue } ?? Equipment.allCases.map { $0.rawValue }
        let machines = gymProfile?.availableMachines.map { $0.rawValue } ?? []

        let content: [String: Any] = [
            "gymName": gymProfile?.name ?? "Default Gym",
            "equipment": equipment,
            "specificMachines": machines
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func getDumbbellWeights(_ call: ToolCall) -> ToolResult {
        let gymSettings = GymSettings.shared

        var content: [String: Any] = [:]

        if let specificDumbbells = gymSettings.availableDumbbells {
            content["availableWeights"] = specificDumbbells.sorted()
            content["mode"] = "specific"
        } else {
            let weights = stride(from: gymSettings.dumbbellMinWeight,
                               through: gymSettings.dumbbellMaxWeight,
                               by: gymSettings.dumbbellIncrement).map { $0 }
            content["availableWeights"] = weights
            content["mode"] = "range"
            content["increment"] = gymSettings.dumbbellIncrement
        }

        content["minWeight"] = gymSettings.dumbbellMinWeight
        content["maxWeight"] = gymSettings.dumbbellMaxWeight

        return .success(toolCallId: call.id, content: content)
    }

    private func getCableWeights(_ call: ToolCall) -> ToolResult {
        let gymSettings = GymSettings.shared
        let exerciseName = call.input["exercise_name"] as? String

        let config = gymSettings.cableConfig(for: exerciseName ?? "")
        let weightUnit = GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds

        let content: [String: Any] = [
            "exerciseName": exerciseName ?? "default",
            "availableWeights": config.availableWeights,
            "stackDescription": config.stackDescription(unit: weightUnit)
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func getAvailableExercises(_ call: ToolCall) -> ToolResult {
        let muscleGroupStrings = call.input["muscle_groups"] as? [String]
        let equipmentStrings = call.input["equipment"] as? [String]
        let difficultyString = call.input["difficulty"] as? String
        let limit = call.input["limit"] as? Int ?? 20

        // Parse muscle groups
        var targetMuscles: Set<MuscleGroup> = []
        if let muscleStrings = muscleGroupStrings {
            for str in muscleStrings {
                if let muscle = MuscleGroup(rawValue: str) {
                    targetMuscles.insert(muscle)
                }
            }
        }

        // Get available equipment from gym profile
        let gymProfile = GymProfileManager.shared.activeProfile
        var availableEquipment = gymProfile?.availableEquipment ?? Set(Equipment.allCases)

        // Filter by requested equipment if specified
        if let equipStrings = equipmentStrings {
            let requestedEquipment = Set(equipStrings.compactMap { Equipment.fromString($0) })
            availableEquipment = availableEquipment.intersection(requestedEquipment)
        }

        // Filter exercises
        var exercises = ExerciseDatabase.shared.exercises.filter { exercise in
            // Equipment check
            guard availableEquipment.contains(exercise.equipment) else { return false }

            // Specific machine check
            if let specificMachine = exercise.specificMachine {
                guard gymProfile?.availableMachines.contains(specificMachine) ?? false else { return false }
            }

            // Muscle group check (if specified)
            if !targetMuscles.isEmpty {
                let exerciseMuscles = exercise.primaryMuscleGroups.union(exercise.secondaryMuscleGroups)
                guard !exerciseMuscles.isDisjoint(with: targetMuscles) else { return false }
            }

            // Difficulty check
            if let diffStr = difficultyString, let targetDifficulty = ExerciseDifficulty(rawValue: diffStr.lowercased()) {
                guard exercise.difficulty == targetDifficulty else { return false }
            }

            return true
        }

        // Apply preferences
        let preferenceManager = ExercisePreferenceManager.shared
        exercises = exercises.filter { preferenceManager.getPreference(for: $0.name) != .doNotSuggest }

        // Sort by preference then name
        exercises.sort { e1, e2 in
            let pref1 = preferenceManager.getPreference(for: e1.name)
            let pref2 = preferenceManager.getPreference(for: e2.name)

            if pref1 == .preferMore && pref2 != .preferMore { return true }
            if pref2 == .preferMore && pref1 != .preferMore { return false }
            if pref1 == .preferLess && pref2 != .preferLess { return false }
            if pref2 == .preferLess && pref1 != .preferLess { return true }

            return e1.name < e2.name
        }

        // Limit results
        let limitedExercises = Array(exercises.prefix(limit))

        // Build response
        let exerciseData = limitedExercises.map { exercise -> [String: Any] in
            let pref = preferenceManager.getPreference(for: exercise.name)
            return [
                "name": exercise.name,
                "equipment": exercise.equipment.rawValue,
                "primaryMuscles": exercise.primaryMuscleGroups.map { $0.rawValue },
                "secondaryMuscles": exercise.secondaryMuscleGroups.map { $0.rawValue },
                "difficulty": exercise.difficulty.rawValue,
                "userPreference": pref.rawValue
            ]
        }

        let content: [String: Any] = [
            "exercises": exerciseData,
            "totalCount": limitedExercises.count,
            "filteredBy": [
                "muscleGroups": muscleGroupStrings ?? [],
                "equipment": equipmentStrings ?? [],
                "difficulty": difficultyString ?? "any"
            ]
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func getExerciseHistory(_ call: ToolCall) -> ToolResult {
        guard let exerciseName = call.input["exercise_name"] as? String else {
            return .error(toolCallId: call.id, message: "Missing required field: exercise_name")
        }

        let workoutHistory = WorkoutDataManager.shared.getWorkoutHistory()

        var recentSessions: [[String: Any]] = []

        for workout in workoutHistory.prefix(10) {
            for exercise in workout.exercises {
                if exercise.exercise.name.lowercased() == exerciseName.lowercased() {
                    let completedSets = exercise.sets.filter { $0.completedAt != nil }
                    if !completedSets.isEmpty {
                        let setData = completedSets.map { set -> [String: Any] in
                            [
                                "weight": set.weight ?? 0,
                                "reps": set.actualReps ?? set.targetReps,
                                "setType": set.setType.rawValue
                            ]
                        }

                        recentSessions.append([
                            "date": workout.completedAt?.ISO8601Format() ?? "unknown",
                            "sets": setData
                        ])
                    }
                }
            }
        }

        let content: [String: Any] = [
            "exerciseName": exerciseName,
            "hasHistory": !recentSessions.isEmpty,
            "sessions": Array(recentSessions.prefix(5))
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func getExercisePreferences(_ call: ToolCall) -> ToolResult {
        let preferenceManager = ExercisePreferenceManager.shared

        let content: [String: Any] = [
            "preferred": preferenceManager.getPreferredExercises(),
            "avoided": preferenceManager.getAvoidedExercises(),
            "blocked": preferenceManager.getBlockedExercises()
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func getWorkoutHistory(_ call: ToolCall) -> ToolResult {
        let limit = call.input["limit"] as? Int ?? 5
        let workoutHistory = WorkoutDataManager.shared.getWorkoutHistory()

        let workoutData = workoutHistory.prefix(limit).map { workout -> [String: Any] in
            let muscleGroups = Set(workout.exercises.flatMap { $0.exercise.primaryMuscleGroups })
            return [
                "name": workout.name,
                "date": workout.completedAt?.ISO8601Format() ?? workout.createdAt.ISO8601Format(),
                "isDeload": workout.isDeload,
                "muscleGroups": muscleGroups.map { $0.rawValue },
                "exerciseCount": workout.exercises.count,
                "duration": workout.duration.map { Int($0 / 60) } ?? 0
            ]
        }

        // Calculate stats
        let thisWeek = workoutHistory.filter {
            guard let completed = $0.completedAt else { return false }
            return Calendar.current.isDate(completed, equalTo: Date(), toGranularity: .weekOfYear)
        }

        let lastDeload = workoutHistory.first { $0.isDeload }
        let workoutsSinceDeload = workoutHistory.prefix { !$0.isDeload }.count

        let content: [String: Any] = [
            "workouts": Array(workoutData),
            "totalWorkoutsThisWeek": thisWeek.count,
            "lastDeloadDate": lastDeload?.completedAt?.ISO8601Format() ?? "none",
            "workoutsSinceDeload": workoutsSinceDeload
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func getTechniqueSettings(_ call: ToolCall) -> ToolResult {
        guard let options = builder?.techniqueOptions else {
            return .error(toolCallId: call.id, message: "Builder not available")
        }

        let content: [String: Any] = [
            "warmupSets": options.warmupSetMode.rawValue,
            "dropSets": options.dropSetMode.rawValue,
            "restPause": options.restPauseMode.rawValue,
            "supersets": options.supersetMode.rawValue
        ]

        return .success(toolCallId: call.id, content: content)
    }

    // MARK: - Action Tool Handlers

    private func setWorkoutName(_ call: ToolCall) -> ToolResult {
        guard let name = call.input["name"] as? String else {
            return .error(toolCallId: call.id, message: "Missing required field: name")
        }

        let isDeload = call.input["is_deload"] as? Bool ?? false

        builder?.setWorkoutName(name, isDeload: isDeload)

        let content: [String: Any] = [
            "success": true,
            "workoutName": name,
            "isDeload": isDeload
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func addExercise(_ call: ToolCall) -> ToolResult {
        guard let builder = builder else {
            return .error(toolCallId: call.id, message: "Builder not available")
        }

        // Validate required fields
        guard let name = call.input["name"] as? String else {
            return .error(toolCallId: call.id, message: "Missing required field: name")
        }
        guard let sets = call.input["sets"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: sets")
        }
        guard let reps = call.input["reps"] as? String else {
            return .error(toolCallId: call.id, message: "Missing required field: reps")
        }
        guard let weight = call.input["weight"] as? Double ?? (call.input["weight"] as? Int).map({ Double($0) }) else {
            return .error(toolCallId: call.id, message: "Missing required field: weight")
        }
        guard let restSeconds = call.input["rest_seconds"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: rest_seconds")
        }

        let notes = call.input["notes"] as? String ?? ""

        // Find exercise in database
        let exercise = AIProviderHelpers.findOrCreateExercise(
            name: name,
            primaryMuscleGroups: [],
            equipment: .bodyweightOnly
        )

        // Parse reps
        let targetReps = Int(reps.components(separatedBy: "-").first ?? "10") ?? 10

        // Create sets
        let exerciseSets = (1...sets).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                setType: .standard,
                targetReps: targetReps,
                weight: weight,
                restPeriod: TimeInterval(restSeconds)
            )
        }

        // Create workout exercise
        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: exerciseSets,
            orderIndex: builder.exercises.count,
            notes: notes
        )

        let index = builder.addExercise(workoutExercise)

        let content: [String: Any] = [
            "success": true,
            "exerciseIndex": index,
            "exerciseName": exercise.name,
            "message": "Added \(exercise.name) as exercise \(index + 1)"
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func createExercise(_ call: ToolCall) -> ToolResult {
        // Validate required fields
        guard let name = call.input["name"] as? String else {
            return .error(toolCallId: call.id, message: "Missing required field: name")
        }
        guard let equipmentStr = call.input["equipment"] as? String else {
            return .error(toolCallId: call.id, message: "Missing required field: equipment")
        }
        guard let primaryMuscleStrs = call.input["primary_muscles"] as? [String] else {
            return .error(toolCallId: call.id, message: "Missing required field: primary_muscles")
        }
        guard let difficultyStr = call.input["difficulty"] as? String else {
            return .error(toolCallId: call.id, message: "Missing required field: difficulty")
        }
        guard let reason = call.input["reason"] as? String else {
            return .error(toolCallId: call.id, message: "Missing required field: reason")
        }

        // Check if exercise already exists
        if ExerciseDatabase.shared.exercises.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            return .error(
                toolCallId: call.id,
                message: "Exercise '\(name)' already exists in the database",
                suggestion: "Use add_exercise with the existing exercise name instead"
            )
        }

        // Parse equipment
        let equipment = Equipment.fromString(equipmentStr)

        // Parse muscle groups
        let primaryMuscles = Set(primaryMuscleStrs.compactMap { MuscleGroup(rawValue: $0) })
        let secondaryMuscleStrs = call.input["secondary_muscles"] as? [String] ?? []
        let secondaryMuscles = Set(secondaryMuscleStrs.compactMap { MuscleGroup(rawValue: $0) })

        // Parse difficulty
        let difficulty = ExerciseDifficulty(rawValue: difficultyStr.lowercased()) ?? .intermediate

        // Get optional instructions
        let instructions = call.input["instructions"] as? String ?? ""

        // Create the custom exercise
        let exercise = Exercise(
            name: name,
            primaryMuscleGroups: primaryMuscles,
            secondaryMuscleGroups: secondaryMuscles,
            equipment: equipment,
            difficulty: difficulty,
            instructions: instructions,
            isCustom: true
        )

        // Add to custom exercise store so it persists
        do {
            try CustomExerciseStore.shared.addExercise(exercise)
        } catch {
            return .error(toolCallId: call.id, message: "Failed to save custom exercise: \(error.localizedDescription)")
        }

        let content: [String: Any] = [
            "success": true,
            "exerciseName": exercise.name,
            "equipment": equipment.rawValue,
            "primaryMuscles": primaryMuscles.map { $0.rawValue },
            "secondaryMuscles": secondaryMuscles.map { $0.rawValue },
            "difficulty": difficulty.rawValue,
            "reason": reason,
            "message": "Created custom exercise '\(name)'. Use add_exercise with this name to add it to the workout."
        ]

        return .success(toolCallId: call.id, content: content)
    }

    private func addWarmupSet(_ call: ToolCall) -> ToolResult {
        guard let builder = builder else {
            return .error(toolCallId: call.id, message: "Builder not available")
        }

        guard let exerciseIndex = call.input["exercise_index"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: exercise_index")
        }
        guard let reps = call.input["reps"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: reps")
        }
        guard let weight = call.input["weight"] as? Double ?? (call.input["weight"] as? Int).map({ Double($0) }) else {
            return .error(toolCallId: call.id, message: "Missing required field: weight")
        }

        do {
            try builder.addWarmupSet(exerciseIndex: exerciseIndex, reps: reps, weight: weight)

            let content: [String: Any] = [
                "success": true,
                "exerciseIndex": exerciseIndex,
                "warmupReps": reps,
                "warmupWeight": weight,
                "message": "Added warmup set to exercise \(exerciseIndex + 1)"
            ]

            return .success(toolCallId: call.id, content: content)
        } catch {
            return .error(toolCallId: call.id, message: error.localizedDescription)
        }
    }

    private func addDropSet(_ call: ToolCall) -> ToolResult {
        guard let builder = builder else {
            return .error(toolCallId: call.id, message: "Builder not available")
        }

        guard let exerciseIndex = call.input["exercise_index"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: exercise_index")
        }
        guard let startingWeight = call.input["starting_weight"] as? Double ?? (call.input["starting_weight"] as? Int).map({ Double($0) }) else {
            return .error(toolCallId: call.id, message: "Missing required field: starting_weight")
        }
        guard let numDrops = call.input["num_drops"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: num_drops")
        }

        let dropPercentage = call.input["drop_percentage"] as? Double ?? 0.2

        do {
            try builder.addDropSet(
                exerciseIndex: exerciseIndex,
                startingWeight: startingWeight,
                numDrops: numDrops,
                dropPercentage: dropPercentage
            )

            let content: [String: Any] = [
                "success": true,
                "exerciseIndex": exerciseIndex,
                "startingWeight": startingWeight,
                "numDrops": numDrops,
                "message": "Converted last set of exercise \(exerciseIndex + 1) to drop set"
            ]

            return .success(toolCallId: call.id, content: content)
        } catch {
            return .error(toolCallId: call.id, message: error.localizedDescription)
        }
    }

    private func addRestPauseSet(_ call: ToolCall) -> ToolResult {
        guard let builder = builder else {
            return .error(toolCallId: call.id, message: "Builder not available")
        }

        guard let exerciseIndex = call.input["exercise_index"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: exercise_index")
        }
        guard let weight = call.input["weight"] as? Double ?? (call.input["weight"] as? Int).map({ Double($0) }) else {
            return .error(toolCallId: call.id, message: "Missing required field: weight")
        }
        guard let numPauses = call.input["num_pauses"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: num_pauses")
        }
        guard let pauseDuration = call.input["pause_duration"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: pause_duration")
        }

        do {
            try builder.addRestPauseSet(
                exerciseIndex: exerciseIndex,
                weight: weight,
                numPauses: numPauses,
                pauseDuration: pauseDuration
            )

            let content: [String: Any] = [
                "success": true,
                "exerciseIndex": exerciseIndex,
                "weight": weight,
                "numPauses": numPauses,
                "pauseDuration": pauseDuration,
                "message": "Converted last set of exercise \(exerciseIndex + 1) to rest-pause set"
            ]

            return .success(toolCallId: call.id, content: content)
        } catch {
            return .error(toolCallId: call.id, message: error.localizedDescription)
        }
    }

    private func createSuperset(_ call: ToolCall) -> ToolResult {
        guard let builder = builder else {
            return .error(toolCallId: call.id, message: "Builder not available")
        }

        guard let indices = call.input["exercise_indices"] as? [Int] else {
            return .error(toolCallId: call.id, message: "Missing required field: exercise_indices")
        }
        guard let restBetween = call.input["rest_between"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: rest_between")
        }
        guard let restAfter = call.input["rest_after"] as? Int else {
            return .error(toolCallId: call.id, message: "Missing required field: rest_after")
        }

        let name = call.input["name"] as? String

        do {
            try builder.createSuperset(
                indices: indices,
                restBetween: restBetween,
                restAfter: restAfter,
                name: name
            )

            let groupType = ExerciseGroupType.suggestedType(for: indices.count)

            let content: [String: Any] = [
                "success": true,
                "groupType": groupType.rawValue,
                "exerciseIndices": indices,
                "message": "Created \(groupType.rawValue) with exercises \(indices.map { $0 + 1 })"
            ]

            return .success(toolCallId: call.id, content: content)
        } catch {
            return .error(toolCallId: call.id, message: error.localizedDescription)
        }
    }

    private func finalizeWorkout(_ call: ToolCall) -> ToolResult {
        guard let builder = builder else {
            return .error(toolCallId: call.id, message: "Builder not available")
        }

        let summary = call.input["summary"] as? String
        if let summary = summary {
            builder.setSummary(summary)
        }

        // Validate workout has exercises
        guard !builder.exercises.isEmpty else {
            return .error(
                toolCallId: call.id,
                message: "Cannot finalize: no exercises added",
                suggestion: "Use add_exercise to add at least one exercise before finalizing"
            )
        }

        let content: [String: Any] = [
            "success": true,
            "workoutName": builder.workoutName,
            "exerciseCount": builder.exercises.count,
            "groupCount": builder.exerciseGroups.count,
            "isDeload": builder.isDeload,
            "message": "Workout finalized with \(builder.exercises.count) exercises"
        ]

        return .success(toolCallId: call.id, content: content)
    }
}
