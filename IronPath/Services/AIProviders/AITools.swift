import Foundation

/// Tool definitions for structured AI responses using Claude's tool calling API
enum AITools {

    // MARK: - Equipment Exercise Generation Tool

    /// Tool for generating exercises for custom equipment
    static let generateEquipmentExercisesTool: [String: Any] = [
        "name": "generate_equipment_exercises",
        "description": "Generate a list of exercises that can be performed with a specific piece of gym equipment. Returns structured exercise data including name, muscle groups, difficulty, instructions, and form tips.",
        "input_schema": [
            "type": "object",
            "properties": [
                "equipment_name": [
                    "type": "string",
                    "description": "The name of the equipment to generate exercises for"
                ],
                "equipment_type": [
                    "type": "string",
                    "enum": ["equipment_category", "specific_machine"],
                    "description": "Whether this is a general equipment category (like barbells) or a specific machine (like a pec deck)"
                ],
                "exercises": [
                    "type": "array",
                    "description": "List of 10-15 exercises for this equipment",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": [
                                "type": "string",
                                "description": "The name of the exercise"
                            ],
                            "primary_muscles": [
                                "type": "array",
                                "items": ["type": "string"],
                                "description": "Primary muscle groups targeted. Valid values: Chest, Back, Shoulders, Biceps, Triceps, Forearms, Abs, Obliques, Quadriceps, Hamstrings, Glutes, Calves, Lower Back, Traps"
                            ],
                            "secondary_muscles": [
                                "type": "array",
                                "items": ["type": "string"],
                                "description": "Secondary muscle groups engaged. Valid values: Chest, Back, Shoulders, Biceps, Triceps, Forearms, Abs, Obliques, Quadriceps, Hamstrings, Glutes, Calves, Lower Back, Traps"
                            ],
                            "difficulty": [
                                "type": "string",
                                "enum": ["Beginner", "Intermediate", "Advanced"],
                                "description": "The difficulty level of the exercise"
                            ],
                            "instructions": [
                                "type": "string",
                                "description": "Step-by-step instructions for performing the exercise correctly"
                            ],
                            "form_tips": [
                                "type": "string",
                                "description": "Key form cues and tips for proper execution and injury prevention"
                            ]
                        ],
                        "required": ["name", "primary_muscles", "difficulty", "instructions", "form_tips"]
                    ]
                ]
            ],
            "required": ["equipment_name", "equipment_type", "exercises"]
        ]
    ]

    // MARK: - Custom Exercise Generation Tool

    /// Tool for generating a single custom exercise based on description
    static let generateCustomExerciseTool: [String: Any] = [
        "name": "generate_custom_exercise",
        "description": "Generate a single custom exercise based on a user's description. Returns structured exercise data that matches the user's requirements.",
        "input_schema": [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "The name of the exercise"
                ],
                "primary_muscles": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Primary muscle groups. Valid values: Chest, Back, Shoulders, Biceps, Triceps, Forearms, Abs, Obliques, Quadriceps, Hamstrings, Glutes, Calves, Lower Back, Traps"
                ],
                "secondary_muscles": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Secondary muscle groups. Valid values: Chest, Back, Shoulders, Biceps, Triceps, Forearms, Abs, Obliques, Quadriceps, Hamstrings, Glutes, Calves, Lower Back, Traps"
                ],
                "equipment": [
                    "type": "string",
                    "description": "Equipment required. Valid values: Barbell, Trap Bar, Dumbbells, Kettlebells, Resistance Bands, Pull-up Bar, Bench, Squat Rack, Cable Machine, Leg Press, Smith Machine, Bodyweight Only"
                ],
                "difficulty": [
                    "type": "string",
                    "enum": ["Beginner", "Intermediate", "Advanced"],
                    "description": "The difficulty level"
                ],
                "instructions": [
                    "type": "string",
                    "description": "Step-by-step instructions"
                ],
                "form_tips": [
                    "type": "string",
                    "description": "Key form cues and tips"
                ]
            ],
            "required": ["name", "primary_muscles", "equipment", "difficulty", "instructions", "form_tips"]
        ]
    ]

    // MARK: - Tool Collections

    /// All available tools
    static var allTools: [[String: Any]] {
        [generateEquipmentExercisesTool, generateCustomExerciseTool]
    }

    /// Tools for equipment exercise generation
    static var equipmentExerciseTools: [[String: Any]] {
        [generateEquipmentExercisesTool]
    }

    /// Tools for single custom exercise generation
    static var customExerciseTools: [[String: Any]] {
        [generateCustomExerciseTool]
    }

    // MARK: - Prompt Builders

    /// Build system prompt for equipment exercise generation
    static func buildEquipmentExercisesSystemPrompt() -> String {
        """
        You are a fitness expert and exercise specialist. Your task is to generate a comprehensive list of exercises that can be performed with specific gym equipment.

        When generating exercises:
        1. Create 10-15 unique, practical exercises
        2. Cover a variety of muscle groups appropriate for the equipment
        3. Include exercises for different difficulty levels (beginner, intermediate, advanced)
        4. Provide clear, actionable instructions
        5. Include important form tips for safety and effectiveness
        6. Avoid duplicate or very similar exercises

        Use the generate_equipment_exercises tool to return your response in a structured format.
        """
    }

    /// Build user prompt for equipment exercise generation
    static func buildEquipmentExercisesUserPrompt(
        equipmentName: String,
        equipmentType: CustomEquipment.CustomEquipmentType,
        existingExerciseNames: [String]
    ) -> String {
        let typeDescription = equipmentType == .specificMachine ?
            "a specific gym machine" : "a general equipment category"

        var prompt = """
        Generate exercises for: \(equipmentName)

        This is \(typeDescription).

        """

        if !existingExerciseNames.isEmpty {
            let namesToExclude = existingExerciseNames.prefix(50).joined(separator: ", ")
            prompt += """

            IMPORTANT: Do NOT generate exercises with these names as they already exist in the database:
            \(namesToExclude)

            """
        }

        prompt += """

        Please generate 10-15 unique exercises that can be performed with this equipment, covering different muscle groups and difficulty levels.
        """

        return prompt
    }

    /// Build system prompt for custom exercise generation
    static func buildCustomExerciseSystemPrompt(availableEquipment: Set<Equipment>) -> String {
        let equipmentList = availableEquipment.map { $0.rawValue }.joined(separator: ", ")

        return """
        You are a fitness expert. Create a custom exercise based on the user's description.

        The user has access to the following equipment: \(equipmentList)

        Requirements:
        1. The exercise should use only equipment the user has available
        2. Provide clear, step-by-step instructions
        3. Include important form tips for safety
        4. Be creative but practical

        Use the generate_custom_exercise tool to return your response.
        """
    }
}
