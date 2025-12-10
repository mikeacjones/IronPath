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
        customEquipmentId: UUID? = nil
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
