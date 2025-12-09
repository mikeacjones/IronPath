import Foundation

// MARK: - Claude API Response Models

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
    // For tool_use blocks
    let id: String?
    let name: String?
    let input: ToolInput?
}

struct ToolInput: Codable {
    let muscleGroups: [String]?

    enum CodingKeys: String, CodingKey {
        case muscleGroups = "muscle_groups"
    }
}

// MARK: - Workout Generation Models

struct WorkoutJSON: Codable {
    let name: String
    let exercises: [ExerciseJSON]
    let isDeload: Bool?  // Claude can recommend a deload workout

    enum CodingKeys: String, CodingKey {
        case name, exercises, isDeload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        exercises = try container.decode([ExerciseJSON].self, forKey: .exercises)
        // Handle isDeload as optional bool or string
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .isDeload) {
            isDeload = boolValue
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .isDeload) {
            isDeload = stringValue.lowercased() == "true"
        } else {
            isDeload = nil
        }
    }
}

struct ExerciseJSON: Codable {
    let name: String
    let sets: Int
    let reps: String
    let restSeconds: Int
    let equipment: String
    let primaryMuscles: [String]
    let notes: String?
    let weight: Double?  // Suggested weight from Claude

    enum CodingKeys: String, CodingKey {
        case name, sets, reps, restSeconds, equipment, primaryMuscles, notes, weight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        equipment = try container.decode(String.self, forKey: .equipment)
        primaryMuscles = try container.decode([String].self, forKey: .primaryMuscles)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // Handle sets as either Int or String
        if let intSets = try? container.decode(Int.self, forKey: .sets) {
            sets = intSets
        } else if let stringSets = try? container.decode(String.self, forKey: .sets),
                  let parsedSets = Int(stringSets) {
            sets = parsedSets
        } else {
            sets = 3  // Default
        }

        // Handle reps as either String or Int
        if let stringReps = try? container.decode(String.self, forKey: .reps) {
            reps = stringReps
        } else if let intReps = try? container.decode(Int.self, forKey: .reps) {
            reps = String(intReps)
        } else {
            reps = "10"  // Default
        }

        // Handle restSeconds as either Int or String
        if let intRest = try? container.decode(Int.self, forKey: .restSeconds) {
            restSeconds = intRest
        } else if let stringRest = try? container.decode(String.self, forKey: .restSeconds),
                  let parsedRest = Int(stringRest) {
            restSeconds = parsedRest
        } else {
            restSeconds = 90  // Default
        }

        // Handle weight as either Double, Int, or String
        if let doubleWeight = try? container.decodeIfPresent(Double.self, forKey: .weight) {
            weight = doubleWeight
        } else if let intWeight = try? container.decodeIfPresent(Int.self, forKey: .weight) {
            weight = Double(intWeight)
        } else if let stringWeight = try? container.decodeIfPresent(String.self, forKey: .weight),
                  let parsedWeight = Double(stringWeight) {
            weight = parsedWeight
        } else {
            weight = nil
        }
    }
}

// MARK: - Custom Exercise Generation Models

struct CustomExerciseJSON: Codable {
    let name: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let equipment: String
    let difficulty: String
    let instructions: String
    let formTips: String
}

// MARK: - Anthropic API Errors

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int)
    case apiErrorWithMessage(statusCode: Int, message: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key is missing. Please add your API key in Profile settings."
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let code):
            return "API error with status code: \(code)"
        case .apiErrorWithMessage(let code, let message):
            return "API error (\(code)): \(message)"
        case .parseError:
            return "Failed to parse Claude's response"
        }
    }
}
