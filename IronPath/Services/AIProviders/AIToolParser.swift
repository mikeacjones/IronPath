import Foundation

/// Parses AI tool call responses into strongly-typed models
enum AIToolParser {

    // MARK: - Result Types

    struct EquipmentExercisesResult {
        let equipmentName: String
        let equipmentType: CustomEquipment.CustomEquipmentType
        let exercises: [ExerciseDraft]
    }

    // MARK: - Equipment Exercises Parsing

    /// Parse equipment exercises from tool call response
    static func parseEquipmentExercises(from toolInput: [String: Any]) throws -> EquipmentExercisesResult {
        guard let equipmentName = toolInput["equipment_name"] as? String else {
            throw AIProviderError.parseError(detail: "Missing equipment_name in tool response")
        }

        guard let typeString = toolInput["equipment_type"] as? String else {
            throw AIProviderError.parseError(detail: "Missing equipment_type in tool response")
        }

        guard let exercisesArray = toolInput["exercises"] as? [[String: Any]] else {
            throw AIProviderError.parseError(detail: "Missing or invalid exercises array in tool response")
        }

        let equipmentType: CustomEquipment.CustomEquipmentType =
            typeString == "specific_machine" ? .specificMachine : .equipmentCategory

        let exercises = exercisesArray.compactMap { exerciseDict -> ExerciseDraft? in
            parseExerciseDraft(from: exerciseDict, equipmentName: equipmentName)
        }

        guard !exercises.isEmpty else {
            throw AIProviderError.parseError(detail: "No valid exercises parsed from tool response")
        }

        return EquipmentExercisesResult(
            equipmentName: equipmentName,
            equipmentType: equipmentType,
            exercises: exercises
        )
    }

    // MARK: - Custom Exercise Parsing

    /// Parse a single custom exercise from tool call response
    static func parseCustomExercise(from toolInput: [String: Any]) throws -> ExerciseDraft {
        guard let name = toolInput["name"] as? String, !name.isEmpty else {
            throw AIProviderError.parseError(detail: "Missing or empty exercise name")
        }

        guard let primaryMuscles = toolInput["primary_muscles"] as? [String], !primaryMuscles.isEmpty else {
            throw AIProviderError.parseError(detail: "Missing or empty primary_muscles")
        }

        guard let equipmentString = toolInput["equipment"] as? String else {
            throw AIProviderError.parseError(detail: "Missing equipment")
        }

        guard let difficulty = toolInput["difficulty"] as? String else {
            throw AIProviderError.parseError(detail: "Missing difficulty")
        }

        guard let instructions = toolInput["instructions"] as? String else {
            throw AIProviderError.parseError(detail: "Missing instructions")
        }

        guard let formTips = toolInput["form_tips"] as? String else {
            throw AIProviderError.parseError(detail: "Missing form_tips")
        }

        let secondaryMuscles = toolInput["secondary_muscles"] as? [String] ?? []

        return ExerciseDraft(
            id: UUID(),
            name: name,
            primaryMuscleGroups: parseMuscleGroups(primaryMuscles),
            secondaryMuscleGroups: parseMuscleGroups(secondaryMuscles),
            equipmentName: equipmentString,
            difficulty: parseDifficulty(difficulty),
            instructions: instructions,
            formTips: formTips
        )
    }

    // MARK: - Private Helpers

    private static func parseExerciseDraft(from dict: [String: Any], equipmentName: String) -> ExerciseDraft? {
        guard let name = dict["name"] as? String, !name.isEmpty else {
            return nil
        }

        guard let primaryMuscles = dict["primary_muscles"] as? [String], !primaryMuscles.isEmpty else {
            return nil
        }

        let secondaryMuscles = dict["secondary_muscles"] as? [String] ?? []
        let difficulty = dict["difficulty"] as? String ?? "Intermediate"
        let instructions = dict["instructions"] as? String ?? ""
        let formTips = dict["form_tips"] as? String ?? ""

        return ExerciseDraft(
            id: UUID(),
            name: name,
            primaryMuscleGroups: parseMuscleGroups(primaryMuscles),
            secondaryMuscleGroups: parseMuscleGroups(secondaryMuscles),
            equipmentName: equipmentName,
            difficulty: parseDifficulty(difficulty),
            instructions: instructions,
            formTips: formTips
        )
    }

    private static func parseMuscleGroups(_ strings: [String]) -> Set<MuscleGroup> {
        Set(strings.compactMap { string in
            // Try direct match first
            if let muscleGroup = MuscleGroup(rawValue: string) {
                return muscleGroup
            }

            // Try case-insensitive match
            let lowercased = string.lowercased().trimmingCharacters(in: .whitespaces)
            return MuscleGroup.allCases.first { $0.rawValue.lowercased() == lowercased }
        })
    }

    private static func parseDifficulty(_ string: String) -> ExerciseDifficulty {
        // Try direct match
        if let difficulty = ExerciseDifficulty(rawValue: string) {
            return difficulty
        }

        // Try case-insensitive match
        let lowercased = string.lowercased().trimmingCharacters(in: .whitespaces)
        return ExerciseDifficulty.allCases.first { $0.rawValue.lowercased() == lowercased } ?? .intermediate
    }

    // MARK: - Tool Response Extraction

    /// Extract tool input from Anthropic API response
    static func extractToolInput(from response: [String: Any]) throws -> [String: Any] {
        // Anthropic response structure: content[].type == "tool_use" -> input
        guard let content = response["content"] as? [[String: Any]] else {
            throw AIProviderError.parseError(detail: "Missing content array in response")
        }

        // Find tool_use block
        guard let toolUseBlock = content.first(where: { ($0["type"] as? String) == "tool_use" }) else {
            throw AIProviderError.parseError(detail: "No tool_use block found in response")
        }

        guard let input = toolUseBlock["input"] as? [String: Any] else {
            throw AIProviderError.parseError(detail: "Missing input in tool_use block")
        }

        return input
    }

    /// Extract tool input from OpenAI API response
    static func extractToolInputFromOpenAI(from response: [String: Any]) throws -> [String: Any] {
        // OpenAI response structure: choices[0].message.tool_calls[0].function.arguments (JSON string)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw AIProviderError.parseError(detail: "Invalid OpenAI response structure")
        }

        guard let toolCalls = message["tool_calls"] as? [[String: Any]],
              let firstToolCall = toolCalls.first,
              let function = firstToolCall["function"] as? [String: Any],
              let argumentsString = function["arguments"] as? String else {
            throw AIProviderError.parseError(detail: "No tool_calls found in OpenAI response")
        }

        guard let argumentsData = argumentsString.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
            throw AIProviderError.parseError(detail: "Failed to parse tool arguments JSON")
        }

        return arguments
    }
}
