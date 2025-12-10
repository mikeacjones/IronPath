import Foundation

/// User's fitness profile and preferences
struct UserProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var fitnessLevel: FitnessLevel
    var goals: Set<FitnessGoal>
    var availableEquipment: Set<Equipment>
    var workoutPreferences: WorkoutPreferences
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        fitnessLevel: FitnessLevel,
        goals: Set<FitnessGoal>,
        availableEquipment: Set<Equipment>,
        workoutPreferences: WorkoutPreferences = WorkoutPreferences(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fitnessLevel = fitnessLevel
        self.goals = goals
        self.availableEquipment = availableEquipment
        self.workoutPreferences = workoutPreferences
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum FitnessLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var description: String {
        switch self {
        case .beginner:
            return "New to fitness or returning after a long break"
        case .intermediate:
            return "Regular training for 6+ months"
        case .advanced:
            return "Consistent training for 2+ years"
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable, Hashable {
    case strength = "Build Strength"
    case hypertrophy = "Build Muscle"
    case endurance = "Improve Endurance"
    case weightLoss = "Lose Weight"
    case general = "General Fitness"
}

/// Training style determines rep ranges, rest times, and exercise selection
enum TrainingStyle: String, Codable, CaseIterable, Hashable {
    case hypertrophy = "Hypertrophy"
    case strength = "Strength"
    case powerbuilding = "Powerbuilding"
    case endurance = "Endurance"

    var description: String {
        switch self {
        case .hypertrophy:
            return "8-12 reps, moderate weight, muscle growth focus"
        case .strength:
            return "3-6 reps, heavy weight, strength gains focus"
        case .powerbuilding:
            return "Mix of strength and hypertrophy training"
        case .endurance:
            return "12-20 reps, lighter weight, muscular endurance"
        }
    }

    var typicalRepRange: String {
        switch self {
        case .hypertrophy: return "8-12"
        case .strength: return "3-6"
        case .powerbuilding: return "5-8"
        case .endurance: return "12-20"
        }
    }

    var typicalRestSeconds: Int {
        switch self {
        case .hypertrophy: return 90
        case .strength: return 180
        case .powerbuilding: return 120
        case .endurance: return 60
        }
    }
}

/// Workout split determines how muscle groups are organized across the week
enum WorkoutSplit: String, Codable, CaseIterable, Hashable {
    case upperLower = "Upper/Lower"
    case pushPullLegs = "Push/Pull/Legs"
    case fullBody = "Full Body"
    case bro = "Bro Split"

    var description: String {
        switch self {
        case .upperLower:
            return "4 days/week: Upper, Lower, Upper, Lower"
        case .pushPullLegs:
            return "3-6 days/week: Push, Pull, Legs rotation"
        case .fullBody:
            return "2-4 days/week: Full body each session"
        case .bro:
            return "5 days/week: Chest, Back, Shoulders, Arms, Legs"
        }
    }

    /// Returns the workout types in order for this split
    var workoutRotation: [WorkoutSplitDay] {
        switch self {
        case .upperLower:
            return [.upper, .lower, .upper, .lower]
        case .pushPullLegs:
            return [.push, .pull, .legs]
        case .fullBody:
            return [.fullBody]
        case .bro:
            return [.chest, .back, .shoulders, .arms, .legs]
        }
    }
}

/// Individual workout day types within a split
enum WorkoutSplitDay: String, Codable, CaseIterable, Hashable {
    case upper = "Upper Body"
    case lower = "Lower Body"
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case fullBody = "Full Body"
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"

    /// Target muscle groups for this workout day
    var targetMuscleGroups: Set<MuscleGroup> {
        switch self {
        case .upper:
            return [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower:
            return [.quads, .hamstrings, .glutes, .calves]
        case .push:
            return [.chest, .shoulders, .triceps]
        case .pull:
            return [.back, .biceps, .traps]
        case .legs:
            return [.quads, .hamstrings, .glutes, .calves]
        case .fullBody:
            return Set(MuscleGroup.allCases)
        case .chest:
            return [.chest, .triceps]
        case .back:
            return [.back, .biceps]
        case .shoulders:
            return [.shoulders, .traps]
        case .arms:
            return [.biceps, .triceps, .forearms]
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Hashable {
    case barbell = "Barbell"
    case dumbbells = "Dumbbells"
    case kettlebells = "Kettlebells"
    case resistanceBands = "Resistance Bands"
    case pullUpBar = "Pull-up Bar"
    case bench = "Bench"
    case squat = "Squat Rack"
    case cables = "Cable Machine"
    case legPress = "Leg Press"
    case smithMachine = "Smith Machine"
    case bodyweightOnly = "Bodyweight Only"

    /// Parse equipment from a string, with fuzzy matching for Claude API responses
    static func fromString(_ string: String) -> Equipment {
        let lowercased = string.lowercased().trimmingCharacters(in: .whitespaces)

        // Direct case-insensitive match on raw values
        if let match = Equipment.allCases.first(where: { $0.rawValue.lowercased() == lowercased }) {
            return match
        }

        // Map common variations from Claude responses to equipment types
        switch lowercased {
        case "barbell", "bb":
            return .barbell
        case "dumbbell", "dumbbells", "db":
            return .dumbbells
        case "kettlebell", "kettlebells", "kb":
            return .kettlebells
        case "resistance bands", "bands", "resistance band":
            return .resistanceBands
        case "pull-up bar", "pullup bar", "pull up bar", "chin up bar":
            return .pullUpBar
        case "bench", "flat bench", "incline bench", "decline bench":
            return .bench
        case "squat rack", "squat", "power rack", "rack":
            return .squat
        case "cable", "cables", "cable machine":
            return .cables
        case "leg press", "legpress":
            return .legPress
        case "smith machine", "smith":
            return .smithMachine
        case "bodyweight", "bodyweight only", "bw", "none":
            return .bodyweightOnly
        default:
            return .bodyweightOnly
        }
    }
}

/// Specific machines that fall under "Other Machines" category
enum SpecificMachine: String, Codable, CaseIterable, Hashable {
    case pecDeck = "Pec Deck"
    case chestPress = "Chest Press Machine"
    case shoulderPress = "Shoulder Press Machine"
    case reversePecDeck = "Reverse Pec Deck"
    case dipMachine = "Dip Machine"
    case hackSquat = "Hack Squat"
    case seatedCalfRaise = "Seated Calf Raise"
    case standingCalfRaise = "Standing Calf Raise Machine"
    case gluteKickback = "Glute Kickback Machine"
    case hipAdduction = "Hip Adduction Machine"
    case hipAbduction = "Hip Abduction Machine"

    /// The exercise names that require this machine
    var exerciseNames: [String] {
        switch self {
        case .pecDeck:
            return ["Pec Deck"]
        case .chestPress:
            return ["Machine Chest Press"]
        case .shoulderPress:
            return ["Machine Shoulder Press"]
        case .reversePecDeck:
            return ["Reverse Pec Deck"]
        case .dipMachine:
            return ["Dip Machine"]
        case .hackSquat:
            return ["Hack Squat"]
        case .seatedCalfRaise:
            return ["Seated Calf Raise"]
        case .standingCalfRaise:
            return ["Standing Calf Raise Machine"]
        case .gluteKickback:
            return ["Glute Kickback Machine"]
        case .hipAdduction:
            return ["Hip Adduction Machine"]
        case .hipAbduction:
            return ["Hip Abduction Machine"]
        }
    }
}

struct WorkoutPreferences: Codable {
    var preferredWorkoutDuration: Int // minutes
    var workoutsPerWeek: Int
    var preferredRestTime: Int // seconds between sets
    var avoidInjuries: [String] // body parts to avoid
    var trainingStyle: TrainingStyle
    var workoutSplit: WorkoutSplit
    var advancedTechniqueSettings: AdvancedTechniqueSettings

    init(
        preferredWorkoutDuration: Int = 60,
        workoutsPerWeek: Int = 3,
        preferredRestTime: Int = 90,
        avoidInjuries: [String] = [],
        trainingStyle: TrainingStyle = .hypertrophy,
        workoutSplit: WorkoutSplit = .pushPullLegs,
        advancedTechniqueSettings: AdvancedTechniqueSettings = AdvancedTechniqueSettings()
    ) {
        self.preferredWorkoutDuration = preferredWorkoutDuration
        self.workoutsPerWeek = workoutsPerWeek
        self.preferredRestTime = preferredRestTime
        self.avoidInjuries = avoidInjuries
        self.trainingStyle = trainingStyle
        self.workoutSplit = workoutSplit
        self.advancedTechniqueSettings = advancedTechniqueSettings
    }
}

// MARK: - Advanced Training Technique Settings

/// Global settings for how AI should handle advanced training techniques
struct AdvancedTechniqueSettings: Codable, Equatable {
    /// Mode for warmup sets
    var warmupSetMode: TechniqueRequirementMode

    /// Mode for drop sets
    var dropSetMode: TechniqueRequirementMode

    /// Mode for rest-pause sets
    var restPauseSetMode: TechniqueRequirementMode

    /// Mode for supersets/circuits
    var supersetMode: TechniqueRequirementMode

    init(
        warmupSetMode: TechniqueRequirementMode = .allowed,
        dropSetMode: TechniqueRequirementMode = .allowed,
        restPauseSetMode: TechniqueRequirementMode = .allowed,
        supersetMode: TechniqueRequirementMode = .allowed
    ) {
        self.warmupSetMode = warmupSetMode
        self.dropSetMode = dropSetMode
        self.restPauseSetMode = restPauseSetMode
        self.supersetMode = supersetMode
    }

    /// Whether any advanced techniques are enabled (allowed or required)
    var anyEnabled: Bool {
        warmupSetMode != .disabled || dropSetMode != .disabled ||
        restPauseSetMode != .disabled || supersetMode != .disabled
    }

    // Legacy compatibility - convert from old boolean format
    init(
        allowWarmupSets: Bool,
        allowDropSets: Bool,
        allowRestPauseSets: Bool,
        allowSupersets: Bool
    ) {
        self.warmupSetMode = allowWarmupSets ? .allowed : .disabled
        self.dropSetMode = allowDropSets ? .allowed : .disabled
        self.restPauseSetMode = allowRestPauseSets ? .allowed : .disabled
        self.supersetMode = allowSupersets ? .allowed : .disabled
    }
}

// MARK: - Per-Workout Generation Options

/// Options for a single workout generation request
struct WorkoutGenerationOptions: Codable, Equatable {
    /// Requirement mode for warmup sets
    var warmupSetMode: TechniqueRequirementMode

    /// Requirement mode for drop sets
    var dropSetMode: TechniqueRequirementMode

    /// Requirement mode for rest-pause sets
    var restPauseMode: TechniqueRequirementMode

    /// Requirement mode for supersets/circuits
    var supersetMode: TechniqueRequirementMode

    init(
        warmupSetMode: TechniqueRequirementMode = .allowed,
        dropSetMode: TechniqueRequirementMode = .allowed,
        restPauseMode: TechniqueRequirementMode = .allowed,
        supersetMode: TechniqueRequirementMode = .allowed
    ) {
        self.warmupSetMode = warmupSetMode
        self.dropSetMode = dropSetMode
        self.restPauseMode = restPauseMode
        self.supersetMode = supersetMode
    }

    /// Apply global settings - combine per-workout options with global profile settings
    func applying(globalSettings: AdvancedTechniqueSettings) -> WorkoutGenerationOptions {
        WorkoutGenerationOptions(
            warmupSetMode: effectiveMode(perWorkout: warmupSetMode, global: globalSettings.warmupSetMode),
            dropSetMode: effectiveMode(perWorkout: dropSetMode, global: globalSettings.dropSetMode),
            restPauseMode: effectiveMode(perWorkout: restPauseMode, global: globalSettings.restPauseSetMode),
            supersetMode: effectiveMode(perWorkout: supersetMode, global: globalSettings.supersetMode)
        )
    }

    /// Determines the effective mode based on global and per-workout settings
    /// - Global "required" always wins (user wants this on all workouts)
    /// - Global "disabled" always wins (user never wants this)
    /// - Global "allowed" defers to per-workout setting
    private func effectiveMode(perWorkout: TechniqueRequirementMode, global: TechniqueRequirementMode) -> TechniqueRequirementMode {
        switch global {
        case .required:
            // Global required = always required, can't be overridden
            return .required
        case .disabled:
            // Global disabled = always disabled, can't be overridden
            return .disabled
        case .allowed:
            // Global allowed = defer to per-workout setting
            return perWorkout
        }
    }
}

/// How a technique should be handled in workout generation
enum TechniqueRequirementMode: String, Codable, CaseIterable, Equatable, RawRepresentable {
    case disabled = "Disabled"
    case allowed = "Allowed"
    case required = "Required"

    var description: String {
        switch self {
        case .disabled:
            return "AI will not include this technique"
        case .allowed:
            return "AI may include if appropriate"
        case .required:
            return "AI must include this technique"
        }
    }

    var iconName: String {
        switch self {
        case .disabled: return "xmark.circle"
        case .allowed: return "checkmark.circle"
        case .required: return "exclamationmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .disabled: return "gray"
        case .allowed: return "blue"
        case .required: return "orange"
        }
    }
}
