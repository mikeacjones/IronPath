import Foundation

// MARK: - AI Response JSON Models
// These models are used by all AI providers (Anthropic, OpenAI, etc.)
// to parse workout generation responses

struct WorkoutJSON: Codable {
    let name: String
    let exercises: [ExerciseJSON]
    let exerciseGroups: [ExerciseGroupJSON]? // Optional groupings (supersets, circuits)
    let isDeload: Bool?  // Claude can recommend a deload workout

    enum CodingKeys: String, CodingKey {
        case name, exercises, exerciseGroups, isDeload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        exercises = try container.decode([ExerciseJSON].self, forKey: .exercises)
        exerciseGroups = try container.decodeIfPresent([ExerciseGroupJSON].self, forKey: .exerciseGroups)
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

// MARK: - Exercise Group JSON Model

struct ExerciseGroupJSON: Codable {
    let type: String // "superset", "triset", "giantSet", "circuit"
    let exerciseIndices: [Int] // Indices of exercises in this group (0-based)
    let name: String? // Optional custom name
    let restBetweenExercises: Int? // Seconds of rest between exercises in group
    let restAfterGroup: Int? // Seconds of rest after completing the group
    let rounds: Int? // Number of rounds (for circuits)

    enum CodingKeys: String, CodingKey {
        case type, exerciseIndices, name, restBetweenExercises, restAfterGroup, rounds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        rounds = try container.decodeIfPresent(Int.self, forKey: .rounds)

        // Handle exerciseIndices as array of ints or strings
        if let intArray = try? container.decode([Int].self, forKey: .exerciseIndices) {
            exerciseIndices = intArray
        } else if let stringArray = try? container.decode([String].self, forKey: .exerciseIndices) {
            exerciseIndices = stringArray.compactMap { Int($0) }
        } else {
            exerciseIndices = []
        }

        // Handle rest times
        if let intRest = try? container.decodeIfPresent(Int.self, forKey: .restBetweenExercises) {
            restBetweenExercises = intRest
        } else if let stringRest = try? container.decodeIfPresent(String.self, forKey: .restBetweenExercises),
                  let parsed = Int(stringRest) {
            restBetweenExercises = parsed
        } else {
            restBetweenExercises = nil
        }

        if let intRest = try? container.decodeIfPresent(Int.self, forKey: .restAfterGroup) {
            restAfterGroup = intRest
        } else if let stringRest = try? container.decodeIfPresent(String.self, forKey: .restAfterGroup),
                  let parsed = Int(stringRest) {
            restAfterGroup = parsed
        } else {
            restAfterGroup = nil
        }
    }

    /// Convert to ExerciseGroupType enum
    var groupType: ExerciseGroupType {
        switch type.lowercased() {
        case "superset", "super-set", "super set":
            return .superset
        case "triset", "tri-set", "tri set":
            return .triset
        case "giantset", "giant-set", "giant set":
            return .giantSet
        case "circuit":
            return .circuit
        default:
            // Infer from count
            return ExerciseGroupType.suggestedType(for: exerciseIndices.count)
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
    let advancedSets: [AdvancedSetJSON]? // Optional advanced set configurations

    enum CodingKeys: String, CodingKey {
        case name, sets, reps, restSeconds, equipment, primaryMuscles, notes, weight, advancedSets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        equipment = try container.decode(String.self, forKey: .equipment)
        primaryMuscles = try container.decode([String].self, forKey: .primaryMuscles)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        advancedSets = try container.decodeIfPresent([AdvancedSetJSON].self, forKey: .advancedSets)

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

// MARK: - Advanced Set Type JSON Models

struct AdvancedSetJSON: Codable {
    let setNumber: Int
    let type: String // "standard", "warmup", "dropSet", "restPause"
    let reps: String?
    let weight: Double?

    // Drop set specific
    let numberOfDrops: Int?
    let dropPercentage: Double?

    // Rest-pause specific
    let numberOfPauses: Int?
    let pauseDuration: Int?

    enum CodingKeys: String, CodingKey {
        case setNumber, type, reps, weight
        case numberOfDrops, dropPercentage
        case numberOfPauses, pauseDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        reps = try container.decodeIfPresent(String.self, forKey: .reps)
        numberOfDrops = try container.decodeIfPresent(Int.self, forKey: .numberOfDrops)
        numberOfPauses = try container.decodeIfPresent(Int.self, forKey: .numberOfPauses)
        pauseDuration = try container.decodeIfPresent(Int.self, forKey: .pauseDuration)

        // Handle setNumber
        if let intSetNumber = try? container.decode(Int.self, forKey: .setNumber) {
            setNumber = intSetNumber
        } else if let stringSetNumber = try? container.decode(String.self, forKey: .setNumber),
                  let parsed = Int(stringSetNumber) {
            setNumber = parsed
        } else {
            setNumber = 1
        }

        // Handle weight
        if let doubleWeight = try? container.decodeIfPresent(Double.self, forKey: .weight) {
            weight = doubleWeight
        } else if let intWeight = try? container.decodeIfPresent(Int.self, forKey: .weight) {
            weight = Double(intWeight)
        } else {
            weight = nil
        }

        // Handle dropPercentage
        if let doubleDrop = try? container.decodeIfPresent(Double.self, forKey: .dropPercentage) {
            dropPercentage = doubleDrop
        } else if let intDrop = try? container.decodeIfPresent(Int.self, forKey: .dropPercentage) {
            dropPercentage = Double(intDrop) / 100.0 // Convert percentage to decimal
        } else {
            dropPercentage = nil
        }
    }

    /// Convert to SetType enum
    var setType: SetType {
        switch type.lowercased() {
        case "warmup", "warm-up", "warm up":
            return .warmup
        case "dropset", "drop-set", "drop set", "drop":
            return .dropSet
        case "restpause", "rest-pause", "rest pause", "rp":
            return .restPause
        default:
            return .standard
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
