import Foundation

/// JSON schema definitions for AI workout generation output format.
/// These schemas are used by AI providers (Anthropic, OpenAI) to generate structured workout data.
enum WorkoutSchema {

    // MARK: - Core Schemas

    /// Complete workout output schema
    static let workoutOutputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "name": [
                "type": "string",
                "description": "Descriptive name for the workout (e.g., 'Upper Body Push Day', 'Lower Body Hypertrophy')"
            ],
            "isDeload": [
                "type": "boolean",
                "description": "Whether this is a deload/recovery workout with lighter weights. Deload workouts won't affect progressive overload tracking."
            ],
            "exercises": [
                "type": "array",
                "description": "List of exercises in the workout",
                "items": exerciseSchema
            ],
            "exerciseGroups": [
                "type": "array",
                "description": "Optional groupings for supersets, trisets, giant sets, or circuits",
                "items": exerciseGroupSchema
            ]
        ] as [String: Any],
        "required": ["name", "exercises"]
    ]

    /// Individual exercise schema
    static let exerciseSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "name": [
                "type": "string",
                "description": "Exercise name matching the exercise database (e.g., 'Barbell Bench Press', 'Dumbbell Lateral Raise')"
            ],
            "sets": [
                "type": "integer",
                "description": "Number of sets to perform"
            ],
            "reps": [
                "type": "string",
                "description": "Target reps per set. Use rep-based formats only: a number ('8'), range ('8-12'), or 'AMRAP'. Do not use time-based prescriptions like '30-60s'."
            ],
            "weight": [
                "type": "number",
                "description": "Suggested weight in the user's preferred unit (pounds or kilograms). Optional."
            ],
            "restSeconds": [
                "type": "integer",
                "description": "Rest period between sets in seconds (e.g., 90, 120, 180)"
            ],
            "equipment": [
                "type": "string",
                "description": "Equipment type required (e.g., 'barbell', 'dumbbells', 'cable', 'bodyweight')"
            ],
            "primaryMuscles": [
                "type": "array",
                "description": "Primary muscle groups targeted",
                "items": [
                    "type": "string"
                ]
            ],
            "notes": [
                "type": "string",
                "description": "Optional form cues, technique tips, or exercise-specific instructions"
            ],
            "advancedSets": [
                "type": "array",
                "description": "Optional advanced set configurations for specific sets (warmup, drop sets, rest-pause)",
                "items": advancedSetSchema
            ]
        ] as [String: Any],
        "required": ["name", "sets", "reps", "restSeconds", "equipment", "primaryMuscles"]
    ]

    /// Advanced set configuration schema
    static let advancedSetSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "setNumber": [
                "type": "integer",
                "description": "Which set number this configuration applies to (1-indexed)"
            ],
            "type": [
                "type": "string",
                "description": "Set type: 'standard', 'warmup', 'dropSet', 'restPause'",
                "enum": ["standard", "warmup", "dropSet", "restPause"]
            ],
            "reps": [
                "type": "string",
                "description": "Target reps for this specific set (overrides exercise-level reps)"
            ],
            "weight": [
                "type": "number",
                "description": "Weight for this specific set (overrides exercise-level weight)"
            ],
            "numberOfDrops": [
                "type": "integer",
                "description": "For drop sets: number of weight reductions (typically 2-3)"
            ],
            "dropPercentage": [
                "type": "number",
                "description": "For drop sets: percentage to reduce weight by on each drop (e.g., 0.2 = 20% reduction)"
            ],
            "numberOfPauses": [
                "type": "integer",
                "description": "For rest-pause sets: number of mini-sets after the initial set (typically 2-3)"
            ],
            "pauseDuration": [
                "type": "integer",
                "description": "For rest-pause sets: rest duration between mini-sets in seconds (typically 10-20)"
            ]
        ] as [String: Any],
        "required": ["setNumber", "type"]
    ]

    /// Exercise group schema (supersets, circuits, etc.)
    static let exerciseGroupSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "type": [
                "type": "string",
                "description": "Group type: 'superset' (2), 'triset' (3), 'giantSet' (4+), 'circuit' (4+)",
                "enum": ["superset", "triset", "giantSet", "circuit"]
            ],
            "exerciseIndices": [
                "type": "array",
                "description": "Zero-based indices of exercises in this group from the exercises array",
                "items": [
                    "type": "integer"
                ]
            ],
            "name": [
                "type": "string",
                "description": "Optional custom name for the group (e.g., 'Chest & Triceps Superset')"
            ],
            "restBetweenExercises": [
                "type": "integer",
                "description": "Seconds of rest between exercises within the group (typically 0-30)"
            ],
            "restAfterGroup": [
                "type": "integer",
                "description": "Seconds of rest after completing all exercises in the group (typically 90-180)"
            ],
            "rounds": [
                "type": "integer",
                "description": "For circuits: number of rounds to complete (overrides individual exercise sets)"
            ]
        ] as [String: Any],
        "required": ["type", "exerciseIndices"]
    ]

    // MARK: - Schema Rendering

    /// Render workout schema as compact prompt text for AI
    /// - Parameter includeGroups: Whether to include exercise groups in the schema
    /// - Returns: Formatted schema text for prompt inclusion
    static func schemaAsPromptText(includeGroups: Bool = true) -> String {
        var text = """
        Workout Output Format:
        {
          "name": "string (workout name)",
          "isDeload": boolean (optional, true for recovery workouts),
          "exercises": [
            {
              "name": "string (exercise name from database)",
              "sets": integer (number of sets),
              "reps": "string (e.g., '8', '8-12', 'AMRAP'; never use time-based formats like '30-60s')",
              "weight": number (optional, suggested weight),
              "restSeconds": integer (rest between sets),
              "equipment": "string (e.g., 'barbell', 'dumbbells', 'cable')",
              "primaryMuscles": ["string", ...] (muscle groups),
              "notes": "string (optional, form cues or tips)",
              "advancedSets": [
                {
                  "setNumber": integer (1-indexed),
                  "type": "warmup|dropSet|restPause",
                  "reps": "string (optional override)",
                  "weight": number (optional override),
                  "numberOfDrops": integer (drop sets only, typically 2-3),
                  "dropPercentage": number (drop sets only, e.g., 0.2 = 20%),
                  "numberOfPauses": integer (rest-pause only, typically 2-3),
                  "pauseDuration": integer (rest-pause only, seconds 10-20)
                }
              ] (optional)
            }
          ]
        """

        if includeGroups {
            text += """
            ,
              "exerciseGroups": [
                {
                  "type": "superset|triset|giantSet|circuit",
                  "exerciseIndices": [integer, ...] (0-based indices),
                  "name": "string (optional custom name)",
                  "restBetweenExercises": integer (seconds, typically 0-30),
                  "restAfterGroup": integer (seconds, typically 90-180),
                  "rounds": integer (circuits only, overrides exercise sets)
                }
              ] (optional)
            """
        }

        text += "\n}"

        return text
    }

    /// Render compact exercise schema text
    static func exerciseSchemaText() -> String {
        """
        Exercise Format:
        {
          "name": "string",
          "sets": integer,
          "reps": "string",
          "weight": number (optional),
          "restSeconds": integer,
          "equipment": "string",
          "primaryMuscles": ["string", ...],
          "notes": "string" (optional)
        }
        """
    }

    /// Render advanced set types reference
    static func advancedSetTypesReference() -> String {
        """
        Advanced Set Types:

        1. Warmup ("type": "warmup")
           - Lighter weight preparatory sets
           - Typically first 1-2 sets of an exercise
           - Example: Set 1 at 50% working weight

        2. Drop Set ("type": "dropSet")
           - Immediately reduce weight after reaching failure and continue
           - numberOfDrops: 2-3 typical (how many times to drop weight)
           - dropPercentage: 0.15-0.25 typical (15-25% reduction per drop)
           - Example: 225 lbs → 180 lbs → 135 lbs (20% drops)

        3. Rest-Pause ("type": "restPause")
           - Brief rest (10-20s) then continue with same weight
           - numberOfPauses: 2-3 typical (mini-sets after initial set)
           - pauseDuration: 10-20 seconds typical
           - Example: 8 reps → rest 15s → 3 reps → rest 15s → 2 reps
        """
    }

    /// Render exercise group types reference
    static func exerciseGroupTypesReference() -> String {
        """
        Exercise Group Types:

        1. Superset (2 exercises)
           - Two exercises performed back-to-back with minimal rest
           - Typically opposing muscle groups (push/pull) or same muscle group
           - restBetweenExercises: 0-15 seconds
           - restAfterGroup: 90-120 seconds

        2. Triset (3 exercises)
           - Three exercises performed sequentially
           - Often targeting same muscle group from different angles
           - restBetweenExercises: 0-20 seconds
           - restAfterGroup: 120-180 seconds

        3. Giant Set (4+ exercises)
           - Four or more exercises for same muscle group
           - Maximum metabolic stress and muscle fatigue
           - restBetweenExercises: 0-15 seconds
           - restAfterGroup: 180-240 seconds

        4. Circuit (4+ exercises)
           - Four or more exercises for different muscle groups
           - Full-body conditioning emphasis
           - restBetweenExercises: 0-30 seconds
           - restAfterGroup: 60-120 seconds
           - Use "rounds" field to specify total rounds
        """
    }

    /// Generate full schema documentation for prompt engineering
    static func fullSchemaDocumentation(includeGroups: Bool = true, includeAdvancedSets: Bool = true) -> String {
        var doc = schemaAsPromptText(includeGroups: includeGroups)

        if includeAdvancedSets {
            doc += "\n\n" + advancedSetTypesReference()
        }

        if includeGroups {
            doc += "\n\n" + exerciseGroupTypesReference()
        }

        doc += """


        Notes:
        - All exercises must use names from the exercise database
        - Equipment must match available equipment in user's gym profile
        - Primary muscles should use standard muscle group names
        - Rest periods should be appropriate for exercise intensity
        - Advanced sets are optional and should be used strategically
        - Exercise groups are optional but effective for time efficiency
        """

        return doc
    }

    // MARK: - Validation Helpers

    /// Validate that an exercise dictionary matches the schema requirements
    static func validateExercise(_ exercise: [String: Any]) -> [String] {
        var errors: [String] = []

        // Required fields
        let requiredFields = ["name", "sets", "reps", "restSeconds", "equipment", "primaryMuscles"]
        for field in requiredFields {
            if exercise[field] == nil {
                errors.append("Missing required field: \(field)")
            }
        }

        // Type validation
        if let sets = exercise["sets"], !(sets is Int || sets is String) {
            errors.append("Field 'sets' must be integer or string")
        }

        if let restSeconds = exercise["restSeconds"], !(restSeconds is Int || restSeconds is String) {
            errors.append("Field 'restSeconds' must be integer or string")
        }

        if let primaryMuscles = exercise["primaryMuscles"], !(primaryMuscles is [String]) {
            errors.append("Field 'primaryMuscles' must be array of strings")
        }

        if let weight = exercise["weight"], !(weight is Double || weight is Int || weight is String) {
            errors.append("Field 'weight' must be number or string")
        }

        return errors
    }

    /// Validate that a workout dictionary matches the schema requirements
    static func validateWorkout(_ workout: [String: Any]) -> [String] {
        var errors: [String] = []

        // Required fields
        if workout["name"] == nil {
            errors.append("Missing required field: name")
        }

        guard let exercises = workout["exercises"] as? [[String: Any]] else {
            errors.append("Missing or invalid 'exercises' array")
            return errors
        }

        // Validate each exercise
        for (index, exercise) in exercises.enumerated() {
            let exerciseErrors = validateExercise(exercise)
            for error in exerciseErrors {
                errors.append("Exercise \(index): \(error)")
            }
        }

        // Validate exercise groups if present
        if let groups = workout["exerciseGroups"] as? [[String: Any]] {
            for (index, group) in groups.enumerated() {
                let groupErrors = validateExerciseGroup(group, exerciseCount: exercises.count)
                for error in groupErrors {
                    errors.append("Exercise group \(index): \(error)")
                }
            }
        }

        return errors
    }

    /// Validate that an exercise group dictionary matches the schema requirements
    static func validateExerciseGroup(_ group: [String: Any], exerciseCount: Int) -> [String] {
        var errors: [String] = []

        // Required fields
        if group["type"] == nil {
            errors.append("Missing required field: type")
        }

        guard let indices = group["exerciseIndices"] as? [Int] else {
            errors.append("Missing or invalid 'exerciseIndices' array")
            return errors
        }

        // Validate indices are within bounds
        for index in indices {
            if index < 0 || index >= exerciseCount {
                errors.append("Invalid exercise index: \(index) (valid range: 0-\(exerciseCount-1))")
            }
        }

        // Validate type matches exercise count
        if let type = group["type"] as? String {
            switch type.lowercased() {
            case "superset":
                if indices.count != 2 {
                    errors.append("Superset must have exactly 2 exercises, found \(indices.count)")
                }
            case "triset":
                if indices.count != 3 {
                    errors.append("Triset must have exactly 3 exercises, found \(indices.count)")
                }
            case "giantset", "circuit":
                if indices.count < 4 {
                    errors.append("\(type) must have at least 4 exercises, found \(indices.count)")
                }
            default:
                errors.append("Invalid group type: \(type)")
            }
        }

        return errors
    }
}
