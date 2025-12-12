import Foundation

/// Tool definitions for agentic workout generation
enum WorkoutAgentTools {

    // MARK: - Read-Only Data Tools

    static let getUserProfileTool: [String: Any] = [
        "name": "get_user_profile",
        "description": "Get user's fitness level, goals, training style, preferred workout duration, and rest preferences.",
        "input_schema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String]
        ]
    ]

    static let getGymEquipmentTool: [String: Any] = [
        "name": "get_gym_equipment",
        "description": "Get raw gym equipment list. Usually not needed - get_available_exercises already filters by equipment.",
        "input_schema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String]
        ]
    ]

    static let getDumbbellWeightsTool: [String: Any] = [
        "name": "get_dumbbell_weights",
        "description": "Get available dumbbell weights. ONLY call if you are adding a dumbbell exercise to the workout. Skip entirely for bodyweight/barbell/cable/machine workouts. Weights auto-snap anyway.",
        "input_schema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String]
        ]
    ]

    static let getCableWeightsTool: [String: Any] = [
        "name": "get_cable_weights",
        "description": "Get cable machine weights. ONLY call if you are adding a cable exercise to the workout. Skip entirely for non-cable workouts. Weights auto-snap anyway.",
        "input_schema": [
            "type": "object",
            "properties": [
                "exercise_name": [
                    "type": "string",
                    "description": "Optional: Exercise name for machine-specific configuration"
                ]
            ],
            "required": [] as [String]
        ]
    ]

    static let getAvailableExercisesTool: [String: Any] = [
        "name": "get_available_exercises",
        "description": "Get exercises filtered by muscle groups. Returns exercises available with user's gym equipment, including equipment type for each. Blocked exercises are excluded.",
        "input_schema": [
            "type": "object",
            "properties": [
                "muscle_groups": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Filter by muscle groups: Chest, Back, Shoulders, Biceps, Triceps, Forearms, Abs, Obliques, Quadriceps, Hamstrings, Glutes, Calves, Lower Back, Traps"
                ],
                "equipment": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Filter by equipment type (optional)"
                ],
                "difficulty": [
                    "type": "string",
                    "enum": ["Beginner", "Intermediate", "Advanced"],
                    "description": "Filter by difficulty (optional)"
                ],
                "limit": [
                    "type": "integer",
                    "description": "Max exercises to return (default: 20)"
                ]
            ],
            "required": [] as [String]
        ]
    ]

    static let getExerciseHistoryTool: [String: Any] = [
        "name": "get_exercise_history",
        "description": "Get user's recent performance and suggested weight for an exercise. Returns progressive overload recommendation. If no history, use sensible defaults.",
        "input_schema": [
            "type": "object",
            "properties": [
                "exercise_name": [
                    "type": "string",
                    "description": "Exact exercise name"
                ]
            ],
            "required": ["exercise_name"]
        ]
    ]

    static let getExercisePreferencesTool: [String: Any] = [
        "name": "get_exercise_preferences",
        "description": "Get preferred/avoided/blocked exercises. Usually not needed - get_available_exercises includes this.",
        "input_schema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String]
        ]
    ]

    static let getWorkoutHistoryTool: [String: Any] = [
        "name": "get_workout_history",
        "description": "Get recent workout summaries. Useful to avoid repeating the same workout or check if deload is needed.",
        "input_schema": [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": "Max workouts (default: 5)"
                ]
            ],
            "required": [] as [String]
        ]
    ]

    static let getTechniqueSettingsTool: [String: Any] = [
        "name": "get_technique_settings",
        "description": "Get technique settings: warmup/dropset/rest-pause/superset modes (disabled/allowed/required).",
        "input_schema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String]
        ]
    ]

    // MARK: - Action Tools

    static let setWorkoutNameTool: [String: Any] = [
        "name": "set_workout_name",
        "description": "Set workout name. Call before adding exercises.",
        "input_schema": [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "Workout name (e.g., 'Push Day', 'Full Body Strength')"
                ],
                "is_deload": [
                    "type": "boolean",
                    "description": "Whether this is a deload workout (default: false)"
                ]
            ],
            "required": ["name"]
        ]
    ]

    static let addExerciseTool: [String: Any] = [
        "name": "add_exercise",
        "description": "Add an exercise to the workout. Returns exercise index for warmup/dropset/superset tools. Call multiple times in parallel to add all exercises at once.",
        "input_schema": [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "Exercise name (must match from get_available_exercises, or use create_exercise first)"
                ],
                "sets": [
                    "type": "integer",
                    "description": "Number of working sets"
                ],
                "reps": [
                    "type": "string",
                    "description": "Rep target or range (e.g., '8', '8-12')"
                ],
                "weight": [
                    "type": "number",
                    "description": "Target weight in pounds (use 0 for bodyweight). Weights auto-snap to valid equipment."
                ],
                "rest_seconds": [
                    "type": "integer",
                    "description": "Rest between sets in seconds"
                ],
                "notes": [
                    "type": "string",
                    "description": "Optional coaching notes"
                ]
            ],
            "required": ["name", "sets", "reps", "weight", "rest_seconds"]
        ]
    ]

    static let createExerciseTool: [String: Any] = [
        "name": "create_exercise",
        "description": "Create a new custom exercise. ONLY use if the exercise doesn't exist in get_available_exercises AND there's a good reason (user requested specific exercise, equipment-specific variation, etc). Returns the exercise name to use with add_exercise.",
        "input_schema": [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "Exercise name"
                ],
                "equipment": [
                    "type": "string",
                    "enum": ["Bodyweight", "Dumbbells", "Barbell", "Cables", "Machine", "Kettlebells", "Resistance Bands", "Other"],
                    "description": "Primary equipment needed"
                ],
                "primary_muscles": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Primary muscle groups worked"
                ],
                "secondary_muscles": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Secondary muscle groups (optional)"
                ],
                "difficulty": [
                    "type": "string",
                    "enum": ["Beginner", "Intermediate", "Advanced"],
                    "description": "Difficulty level"
                ],
                "instructions": [
                    "type": "string",
                    "description": "Brief form instructions"
                ],
                "reason": [
                    "type": "string",
                    "description": "Why this exercise needs to be created (required)"
                ]
            ],
            "required": ["name", "equipment", "primary_muscles", "difficulty", "reason"]
        ]
    ]

    static let addWarmupSetTool: [String: Any] = [
        "name": "add_warmup_set",
        "description": "Add a warmup set to an exercise. Warmup sets use lighter weight (40-60% of working weight).",
        "input_schema": [
            "type": "object",
            "properties": [
                "exercise_index": [
                    "type": "integer",
                    "description": "Exercise index (0-based)"
                ],
                "reps": [
                    "type": "integer",
                    "description": "Reps (typically 10-15)"
                ],
                "weight": [
                    "type": "number",
                    "description": "Weight in pounds"
                ]
            ],
            "required": ["exercise_index", "reps", "weight"]
        ]
    ]

    static let addDropSetTool: [String: Any] = [
        "name": "add_drop_set",
        "description": "Convert last set to a drop set. Only for weighted exercises.",
        "input_schema": [
            "type": "object",
            "properties": [
                "exercise_index": [
                    "type": "integer",
                    "description": "Exercise index (0-based)"
                ],
                "starting_weight": [
                    "type": "number",
                    "description": "Starting weight in pounds"
                ],
                "num_drops": [
                    "type": "integer",
                    "description": "Number of drops (typically 2-3)"
                ],
                "drop_percentage": [
                    "type": "number",
                    "description": "Weight reduction per drop (default: 0.2 = 20%)"
                ]
            ],
            "required": ["exercise_index", "starting_weight", "num_drops"]
        ]
    ]

    static let addRestPauseSetTool: [String: Any] = [
        "name": "add_rest_pause_set",
        "description": "Convert last set to rest-pause (brief 10-20s rests between mini-sets).",
        "input_schema": [
            "type": "object",
            "properties": [
                "exercise_index": [
                    "type": "integer",
                    "description": "Exercise index (0-based)"
                ],
                "weight": [
                    "type": "number",
                    "description": "Weight in pounds"
                ],
                "num_pauses": [
                    "type": "integer",
                    "description": "Number of pauses (typically 2-3)"
                ],
                "pause_duration": [
                    "type": "integer",
                    "description": "Pause duration in seconds (typically 10-20)"
                ]
            ],
            "required": ["exercise_index", "weight", "num_pauses", "pause_duration"]
        ]
    ]

    static let createSupersetTool: [String: Any] = [
        "name": "create_superset",
        "description": "Group exercises into a superset/triset/giant set (back-to-back with minimal rest).",
        "input_schema": [
            "type": "object",
            "properties": [
                "exercise_indices": [
                    "type": "array",
                    "items": ["type": "integer"],
                    "description": "Exercise indices to group"
                ],
                "rest_between": [
                    "type": "integer",
                    "description": "Rest between exercises in group (usually 0-15s)"
                ],
                "rest_after": [
                    "type": "integer",
                    "description": "Rest after completing the group"
                ],
                "name": [
                    "type": "string",
                    "description": "Optional group name"
                ]
            ],
            "required": ["exercise_indices", "rest_between", "rest_after"]
        ]
    ]

    static let finalizeWorkoutTool: [String: Any] = [
        "name": "finalize_workout",
        "description": "Finalize and complete the workout. Call when done adding all exercises.",
        "input_schema": [
            "type": "object",
            "properties": [
                "summary": [
                    "type": "string",
                    "description": "Brief workout summary (optional)"
                ]
            ],
            "required": [] as [String]
        ]
    ]

    // MARK: - Tool Collections

    static var readOnlyTools: [[String: Any]] {
        [
            getUserProfileTool,
            getGymEquipmentTool,
            getDumbbellWeightsTool,
            getCableWeightsTool,
            getAvailableExercisesTool,
            getExerciseHistoryTool,
            getExercisePreferencesTool,
            getWorkoutHistoryTool,
            getTechniqueSettingsTool
        ]
    }

    static var actionTools: [[String: Any]] {
        [
            setWorkoutNameTool,
            addExerciseTool,
            createExerciseTool,
            addWarmupSetTool,
            addDropSetTool,
            addRestPauseSetTool,
            createSupersetTool,
            finalizeWorkoutTool
        ]
    }

    static var allTools: [[String: Any]] {
        readOnlyTools + actionTools
    }

    // MARK: - Prompt Builders

    static func buildAgentSystemPrompt(techniqueOptions: WorkoutGenerationOptions) -> String {
        var prompt = """
        You are an expert personal trainer. Build a workout using the available tools.

        ## CRITICAL: Minimize API Rounds
        Complete the workout in exactly 2 rounds:

        ### Round 1 - Gather Context
        Call in parallel: get_user_profile + get_available_exercises (+ get_exercise_history for key exercises if needed)

        ### Round 2 - Build ENTIRE Workout in ONE Response
        After reviewing Round 1 data, call ALL of these in a SINGLE response:
        - set_workout_name
        - add_exercise (call once for EACH exercise - all in parallel)
        - add_warmup_set (if needed, all in parallel)
        - add_drop_set / add_rest_pause_set (if needed)
        - create_superset (if needed)
        - finalize_workout

        Example Round 2 response should include 8+ tool calls: 1 set_workout_name + 5 add_exercise + 1 add_warmup_set + 1 finalize_workout

        ## Decision Making
        You decide based on user profile:
        - Number of exercises (~4 min per exercise including rest, based on user's preferred duration)
        - Exercise selection (compound movements for efficiency, isolation if time permits)
        - Sets/reps/rest (based on goals: strength vs hypertrophy vs endurance)
        - Weights (estimate based on fitness level, they auto-snap to valid values)

        ## Equipment Awareness
        - Bodyweight-only gym: use weight=0, skip weight lookups
        - Dumbbells/cables: weights auto-snap, no need to verify exact values
        - No exercise history: use sensible defaults for fitness level

        ## Creating New Exercises
        Use create_exercise ONLY when an exercise doesn't exist AND is specifically needed.
        """

        // Add technique-specific instructions
        if techniqueOptions.warmupSetMode == .required {
            prompt += "\n\n## IMPORTANT: Warmup sets are REQUIRED for every exercise. Use add_warmup_set for each exercise."
        }

        if techniqueOptions.dropSetMode == .required {
            prompt += "\n\n## IMPORTANT: Drop sets are REQUIRED. Include at least 1-2 exercises with drop sets using add_drop_set."
        }

        if techniqueOptions.restPauseMode == .required {
            prompt += "\n\n## IMPORTANT: Rest-pause sets are REQUIRED. Include at least 1-2 exercises with rest-pause using add_rest_pause_set."
        }

        if techniqueOptions.supersetMode == .required {
            prompt += "\n\n## IMPORTANT: Supersets are REQUIRED. Group at least 2-3 exercises using create_superset."
        }

        return prompt
    }

    /// Build initial user prompt for workout generation
    static func buildAgentUserPrompt(
        workoutType: String?,
        targetMuscleGroups: Set<MuscleGroup>?,
        userNotes: String?,
        isDeload: Bool
    ) -> String {
        var prompt = "Generate a workout for me.\n\n"

        if let workoutType = workoutType {
            prompt += "Workout Type: \(workoutType)\n"

            if let muscleGroups = targetMuscleGroups, !muscleGroups.isEmpty {
                let groupNames = muscleGroups.map { $0.rawValue }.joined(separator: ", ")
                prompt += "Target Muscle Groups: \(groupNames)\n"
            }
        } else {
            // No workout type specified - LLM should decide based on user's split and history
            prompt += """
            I want you to decide what type of workout I should do today. To make this decision:
            1. Call get_user_profile to see my workout split type (e.g., Push/Pull/Legs, Upper/Lower, etc.)
            2. Call get_workout_history to see my recent workouts

            IMPORTANT: The split type tells you how many distinct workout types are in the rotation, but the user's HISTORY tells you what order they prefer. Do NOT assume a fixed order like Push→Pull→Legs. Instead:
            - Look at the user's recent workouts in chronological order (oldest to newest)
            - Identify the pattern/cycle they have been following
            - Continue THEIR established rotation

            Example: If split is "Push/Pull/Legs" and history shows:
            - 3 days ago: Lower Body
            - 2 days ago: Push
            - 1 day ago: Pull
            Then the user's pattern is Lower Body→Push→Pull, so today should be Lower Body.

            Note: "Legs" workouts are called "Lower Body" in this app.

            After determining the workout type, build that workout.

            """
        }

        if isDeload {
            prompt += "\nThis should be a DELOAD workout with reduced intensity (50-70% of normal weights).\n"
        }

        if let notes = userNotes, !notes.isEmpty {
            prompt += "\nMy notes: \(notes)\n"
        }

        prompt += "\nPlease build the workout using the available tools."

        return prompt
    }
}
