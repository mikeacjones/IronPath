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
        "description": "Get raw equipment list. Usually unnecessary - exercises are pre-filtered.",
        "input_schema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String]
        ]
    ]

    static func getDumbbellWeightsTool(unit: WeightUnit) -> [String: Any] {
        [
            "name": "get_dumbbell_weights",
            "description": "Get available dumbbell weights in \(unit.abbreviation). Only needed for dumbbell exercises. Weights auto-snap.",
            "input_schema": [
                "type": "object",
                "properties": [:] as [String: Any],
                "required": [] as [String]
            ]
        ]
    }

    static let getCableWeightsTool: [String: Any] = [
        "name": "get_cable_weights",
        "description": "Get cable machine weights. Only needed for cable exercises. Weights auto-snap.",
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
        "description": "Get exercises filtered by muscle groups. Returns exercises available with user's equipment. Blocked exercises excluded.",
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
        "description": "Get exercise history. Returns recent sessions with weights/reps for progressive overload.",
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
        "description": "Get exercise preferences (preferred/avoided/blocked). Usually unnecessary - already filtered.",
        "input_schema": [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String]
        ]
    ]

    static let getWorkoutHistoryTool: [String: Any] = [
        "name": "get_workout_history",
        "description": "Get recent workout summaries. Useful for rotation planning and deload checks.",
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
        "description": "Get technique modes (warmup/dropset/rest-pause/superset): disabled/allowed/required.",
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

    static func addExerciseTool(unit: WeightUnit) -> [String: Any] {
        [
            "name": "add_exercise",
            "description": "Add exercise to workout. Returns index for technique tools. Call in parallel for all exercises.",
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
                        "description": "Target weight in \(unit.abbreviation) (use 0 for bodyweight). Weights auto-snap to valid equipment."
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
    }

    static let createExerciseTool: [String: Any] = [
        "name": "create_exercise",
        "description": "Create custom exercise. Only use if unavailable and specifically needed. Returns name for add_exercise.",
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

    static func addWarmupSetTool(unit: WeightUnit) -> [String: Any] {
        [
            "name": "add_warmup_set",
            "description": "Add warmup set to exercise. Use 40-60% of working weight.",
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
                        "description": "Weight in \(unit.abbreviation)"
                    ]
                ],
                "required": ["exercise_index", "reps", "weight"]
            ]
        ]
    }

    static func addDropSetTool(unit: WeightUnit) -> [String: Any] {
        [
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
                        "description": "Starting weight in \(unit.abbreviation)"
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
    }

    static func addRestPauseSetTool(unit: WeightUnit) -> [String: Any] {
        [
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
                        "description": "Weight in \(unit.abbreviation)"
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
    }

    static let createSupersetTool: [String: Any] = [
        "name": "create_superset",
        "description": "Group exercises into superset/triset/giant set with minimal rest.",
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
        "description": "Complete the workout. Call after adding all exercises.",
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

    static func readOnlyTools(unit: WeightUnit) -> [[String: Any]] {
        [
            getUserProfileTool,
            getGymEquipmentTool,
            getDumbbellWeightsTool(unit: unit),
            getCableWeightsTool,
            getAvailableExercisesTool,
            getExerciseHistoryTool,
            getExercisePreferencesTool,
            getWorkoutHistoryTool,
            getTechniqueSettingsTool
        ]
    }

    static func actionTools(unit: WeightUnit) -> [[String: Any]] {
        [
            setWorkoutNameTool,
            addExerciseTool(unit: unit),
            createExerciseTool,
            addWarmupSetTool(unit: unit),
            addDropSetTool(unit: unit),
            addRestPauseSetTool(unit: unit),
            createSupersetTool,
            finalizeWorkoutTool
        ]
    }

    static func allTools(unit: WeightUnit) -> [[String: Any]] {
        readOnlyTools(unit: unit) + actionTools(unit: unit)
    }

    // MARK: - Prompt Builders

    static func buildAgentSystemPrompt(techniqueOptions: WorkoutGenerationOptions, weightUnit: WeightUnit) -> String {
        var prompt = """
        You are an expert personal trainer building workouts with tools.

        ## WEIGHT UNIT
        User's preferred weight unit: \(weightUnit.abbreviation)
        All weights should be specified in \(weightUnit.abbreviation).

        ## CRITICAL: Complete in 2 API Rounds

        ### Round 1 - Gather Context
        Call in parallel: get_user_profile + get_available_exercises (+ get_exercise_history if needed)

        ### Round 2 - Build Entire Workout
        Call ALL tools in ONE response:
        - set_workout_name
        - add_exercise (once per exercise, all parallel)
        - add_warmup_set / add_drop_set / add_rest_pause_set (if needed, parallel)
        - create_superset (if needed)
        - finalize_workout

        Example: 8+ tool calls (1 name + 5 exercises + 1 warmup + 1 finalize)

        ## Decision Making
        Based on user profile, decide:
        - Exercise count (~4 min per exercise with rest, fit to preferred duration)
        - Exercise selection (compounds first, isolation if time permits)
        - Sets/reps/rest (align with goals: strength/hypertrophy/endurance)
        - Weights (estimate by fitness level, auto-snap to equipment)

        ## Notes
        - Bodyweight gyms: use weight=0, skip weight lookups
        - Weights auto-snap - no need to verify exact values
        - No history: use fitness-appropriate defaults
        - Create custom exercises only when necessary

        ## Self-Verification
        Before calling finalize_workout, verify:
        - Exercise selection matches workout type and user goals
        - Difficulty is appropriate for fitness level
        - Weights follow progressive overload from history (or sensible defaults)
        - Required techniques (warmup/dropset/rest-pause/superset) are included
        If any issues found, fix them before finalizing.
        """

        // Add technique-specific instructions
        if techniqueOptions.warmupSetMode == .required {
            prompt += "\n\n## REQUIRED: Add warmup set to every exercise (add_warmup_set)."
        }

        if techniqueOptions.dropSetMode == .required {
            prompt += "\n\n## REQUIRED: Include 1-2 drop sets (add_drop_set)."
        }

        if techniqueOptions.restPauseMode == .required {
            prompt += "\n\n## REQUIRED: Include 1-2 rest-pause sets (add_rest_pause_set)."
        }

        if techniqueOptions.supersetMode == .required {
            prompt += "\n\n## REQUIRED: Group 2-3 exercises into supersets (create_superset)."
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
            // targetMuscleGroups intentionally not added to prompt - LLM infers muscles from workout type name
            // (e.g., "Push Day" implies chest/shoulders/triceps). Parameter kept for internal exercise filtering.
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

    /// Build refinement prompt for Self-Refine pass (optional 3rd round)
    /// Research: Self-Refine shows 5-40% improvement on constrained generation
    static func buildRefinementPrompt(workoutSummary: String, userConstraints: String) -> String {
        """
        Review this workout and identify any issues:

        WORKOUT:
        \(workoutSummary)

        USER CONSTRAINTS:
        \(userConstraints)

        VERIFICATION CHECKLIST:
        1. Does exercise selection match the workout type?
        2. Is exercise difficulty appropriate for the user's fitness level?
        3. Do weights follow progressive overload from history?
        4. Are all required techniques included (warmup/dropset/rest-pause/superset)?
        5. Is the workout duration appropriate for user preferences?

        If ALL checks pass, respond: "VERIFIED: Workout meets all constraints."

        If ANY issues found, respond with:
        "ISSUES FOUND:"
        - [List each issue]

        "FIXES:"
        - [List specific fixes using available tools]

        Then apply the fixes using the tools.
        """
    }
}
