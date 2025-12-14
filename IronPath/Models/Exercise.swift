import Foundation

/// An exercise definition (e.g., "Barbell Bench Press")
struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var alternateNames: [String] // Alternate names for search (e.g., "Flat Bench" for "Barbell Bench Press")
    var primaryMuscleGroups: Set<MuscleGroup>
    var secondaryMuscleGroups: Set<MuscleGroup>
    var equipment: Equipment
    var specificMachine: SpecificMachine? // For exercises requiring specific gym machines
    var difficulty: ExerciseDifficulty
    var instructions: String
    var formTips: String
    var videoURL: String? // YouTube video URL for demonstration
    var isCustom: Bool // User-created vs pre-defined
    var customEquipmentId: UUID? // Reference to CustomEquipment if using custom equipment
    var movementPattern: MovementPattern? // Classification for similarity matching
    var isUnilateral: Bool // Single-arm/leg exercises (e.g., single-arm rows, lunges)
    var supportsTiming: Bool // Can be performed as timed exercise (e.g., planks, ball slams)
    var multiplier: Double // Weight multiplier (2.0 for dumbbells = per-dumbbell weight, 1.0 for barbell)

    init(
        id: UUID = UUID(),
        name: String,
        alternateNames: [String] = [],
        primaryMuscleGroups: Set<MuscleGroup>,
        secondaryMuscleGroups: Set<MuscleGroup> = [],
        equipment: Equipment,
        specificMachine: SpecificMachine? = nil,
        difficulty: ExerciseDifficulty = .intermediate,
        instructions: String = "",
        formTips: String = "",
        videoURL: String? = nil,
        isCustom: Bool = false,
        customEquipmentId: UUID? = nil,
        movementPattern: MovementPattern? = nil,
        isUnilateral: Bool = false,
        supportsTiming: Bool = false,
        multiplier: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.alternateNames = alternateNames
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.specificMachine = specificMachine
        self.difficulty = difficulty
        self.instructions = instructions
        self.formTips = formTips
        self.videoURL = videoURL
        self.isCustom = isCustom
        self.customEquipmentId = customEquipmentId
        self.movementPattern = movementPattern
        self.isUnilateral = isUnilateral
        self.supportsTiming = supportsTiming
        self.multiplier = multiplier
    }

    /// Whether this is a compound (multi-joint) movement
    var isCompound: Bool {
        guard let pattern = movementPattern else {
            // Fallback: compound if targets multiple muscle groups
            return primaryMuscleGroups.count > 1 || !secondaryMuscleGroups.isEmpty
        }
        // Isolation and isometric are not compound
        return pattern != .isolation && pattern != .isometric
    }

    /// Extract YouTube video ID from URL
    var youtubeVideoID: String? {
        guard let urlString = videoURL else { return nil }

        // Handle various YouTube URL formats
        if let url = URL(string: urlString) {
            // Format: youtube.com/watch?v=VIDEO_ID
            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                if let videoID = queryItems.first(where: { $0.name == "v" })?.value {
                    return videoID
                }
            }

            // Format: youtu.be/VIDEO_ID
            if url.host == "youtu.be" {
                return url.lastPathComponent
            }

            // Format: youtube.com/embed/VIDEO_ID
            if url.pathComponents.contains("embed"), let index = url.pathComponents.firstIndex(of: "embed") {
                let nextIndex = url.pathComponents.index(after: index)
                if nextIndex < url.pathComponents.endIndex {
                    return url.pathComponents[nextIndex]
                }
            }
        }

        return nil
    }

    // MARK: - Codable (backward compatibility)

    private enum CodingKeys: String, CodingKey {
        case id, name, alternateNames, primaryMuscleGroups, secondaryMuscleGroups
        case equipment, specificMachine, difficulty, instructions, formTips
        case videoURL, isCustom, customEquipmentId, movementPattern, isUnilateral, supportsTiming
        case multiplier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        alternateNames = try container.decodeIfPresent([String].self, forKey: .alternateNames) ?? []
        primaryMuscleGroups = try container.decode(Set<MuscleGroup>.self, forKey: .primaryMuscleGroups)
        secondaryMuscleGroups = try container.decodeIfPresent(Set<MuscleGroup>.self, forKey: .secondaryMuscleGroups) ?? []
        equipment = try container.decode(Equipment.self, forKey: .equipment)
        specificMachine = try container.decodeIfPresent(SpecificMachine.self, forKey: .specificMachine)
        difficulty = try container.decodeIfPresent(ExerciseDifficulty.self, forKey: .difficulty) ?? .intermediate
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        formTips = try container.decodeIfPresent(String.self, forKey: .formTips) ?? ""
        videoURL = try container.decodeIfPresent(String.self, forKey: .videoURL)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        customEquipmentId = try container.decodeIfPresent(UUID.self, forKey: .customEquipmentId)
        // New properties - default to nil/false for backward compatibility
        movementPattern = try container.decodeIfPresent(MovementPattern.self, forKey: .movementPattern)
        isUnilateral = try container.decodeIfPresent(Bool.self, forKey: .isUnilateral) ?? false
        supportsTiming = try container.decodeIfPresent(Bool.self, forKey: .supportsTiming) ?? false
        multiplier = try container.decodeIfPresent(Double.self, forKey: .multiplier) ?? 1.0
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Hashable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case abs = "Abs"
    case obliques = "Obliques"
    case quads = "Quadriceps"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case lowerBack = "Lower Back"
    case traps = "Traps"
}

enum ExerciseDifficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

/// Tracks muscle recovery status
struct MuscleRecovery: Codable {
    var muscleGroup: MuscleGroup
    var lastWorkedDate: Date
    var recoveryPercentage: Double // 0.0 to 1.0

    var isRecovered: Bool {
        recoveryPercentage >= 1.0
    }

    var recoveryStatus: RecoveryStatus {
        if recoveryPercentage < 0.5 {
            return .fatigued
        } else if recoveryPercentage < 1.0 {
            return .recovering
        } else {
            return .recovered
        }
    }

    enum RecoveryStatus: String {
        case fatigued = "Fatigued"
        case recovering = "Recovering"
        case recovered = "Recovered"
    }
}
