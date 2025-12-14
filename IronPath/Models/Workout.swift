import Foundation

/// A complete workout session
struct Workout: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExercise]
    var exerciseGroups: [ExerciseGroup]? // Optional groupings (supersets, circuits, etc.)
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var notes: String
    var claudeGenerationPrompt: String? // Store the prompt used to generate this workout
    var isDeload: Bool // Whether this is a deload/recovery workout (lighter weights, won't affect progressive overload)
    var estimatedCalories: Int? // AI-estimated calories burned during this workout
    var weightUnit: WeightUnit // Unit used for all weights in this workout

    var duration: TimeInterval? {
        guard let start = startedAt, let completed = completedAt else { return nil }
        return completed.timeIntervalSince(start)
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var totalVolume: Double {
        exercises.reduce(0) { total, exercise in
            total + (exercise.totalVolume * exercise.exercise.multiplier)
        }
    }

    /// Check if this workout contains any exercise groups
    var hasGroups: Bool {
        guard let groups = exerciseGroups else { return false }
        return !groups.isEmpty
    }

    init(
        id: UUID = UUID(),
        name: String,
        exercises: [WorkoutExercise] = [],
        exerciseGroups: [ExerciseGroup]? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        notes: String = "",
        claudeGenerationPrompt: String? = nil,
        isDeload: Bool = false,
        estimatedCalories: Int? = nil,
        weightUnit: WeightUnit = .pounds
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.exerciseGroups = exerciseGroups
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.claudeGenerationPrompt = claudeGenerationPrompt
        self.isDeload = isDeload
        self.estimatedCalories = estimatedCalories
        self.weightUnit = weightUnit
    }

    // MARK: - Codable (backward compatibility)

    private enum CodingKeys: String, CodingKey {
        case id, name, exercises, exerciseGroups
        case createdAt, startedAt, completedAt, notes
        case claudeGenerationPrompt, isDeload, estimatedCalories
        case weightUnit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        exercises = try container.decode([WorkoutExercise].self, forKey: .exercises)
        exerciseGroups = try container.decodeIfPresent([ExerciseGroup].self, forKey: .exerciseGroups)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        claudeGenerationPrompt = try container.decodeIfPresent(String.self, forKey: .claudeGenerationPrompt)
        isDeload = try container.decodeIfPresent(Bool.self, forKey: .isDeload) ?? false
        estimatedCalories = try container.decodeIfPresent(Int.self, forKey: .estimatedCalories)
        // Migration: Default to pounds for existing workouts without weightUnit
        weightUnit = try container.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .pounds
    }
}

/// An exercise within a workout with its sets
struct WorkoutExercise: Codable, Identifiable, Hashable {
    let id: UUID
    var exercise: Exercise
    var sets: [ExerciseSet]
    var orderIndex: Int
    var notes: String
    var isTimedMode: Bool // Whether this exercise instance is in timed mode

    var totalVolume: Double {
        let baseVolume = sets.reduce(0) { total, set in
            total + set.totalVolume
        }
        return baseVolume * exercise.multiplier
    }

    var isCompleted: Bool {
        sets.allSatisfy { $0.isCompleted }
    }

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        sets: [ExerciseSet] = [],
        orderIndex: Int,
        notes: String = "",
        isTimedMode: Bool = false
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.orderIndex = orderIndex
        self.notes = notes
        self.isTimedMode = isTimedMode
    }
}

/// A single set of an exercise
struct ExerciseSet: Codable, Identifiable, Hashable {
    let id: UUID
    var setNumber: Int
    var setType: SetType
    var targetReps: Int
    var actualReps: Int?
    var weight: Double? // in pounds or kg
    var restPeriod: TimeInterval // seconds
    var completedAt: Date?

    // Advanced set type configurations
    var dropSetConfig: DropSetConfig?
    var restPauseConfig: RestPauseConfig?
    var timedSetConfig: TimedSetConfig?

    var isCompleted: Bool {
        switch setType {
        case .standard, .warmup:
            return actualReps != nil && completedAt != nil
        case .dropSet:
            // Drop set is complete when all drops are completed
            guard let config = dropSetConfig else { return actualReps != nil && completedAt != nil }
            return config.drops.allSatisfy { $0.isCompleted }
        case .restPause:
            // Rest-pause is complete when all mini-sets are completed
            guard let config = restPauseConfig else { return actualReps != nil && completedAt != nil }
            return config.miniSets.allSatisfy { $0.isCompleted }
        case .timed:
            // Timed set is complete when actualDuration is recorded
            guard let config = timedSetConfig else { return false }
            return config.actualDuration != nil && completedAt != nil
        }
    }

    /// Total actual reps for this set (accounting for drop sets and rest-pause)
    var totalActualReps: Int {
        switch setType {
        case .standard, .warmup:
            return actualReps ?? 0
        case .dropSet:
            return dropSetConfig?.drops.compactMap { $0.actualReps }.reduce(0, +) ?? actualReps ?? 0
        case .restPause:
            return restPauseConfig?.totalActualReps ?? actualReps ?? 0
        case .timed:
            return 0 // Timed sets don't use reps
        }
    }

    /// Total volume (weight × reps) for this set
    var totalVolume: Double {
        switch setType {
        case .standard, .warmup:
            return (weight ?? 0) * Double(actualReps ?? 0)
        case .dropSet:
            guard let config = dropSetConfig else { return (weight ?? 0) * Double(actualReps ?? 0) }
            return config.drops.reduce(0) { total, drop in
                let w = drop.actualWeight ?? drop.targetWeight ?? 0
                let r = drop.actualReps ?? 0
                return total + (w * Double(r))
            }
        case .restPause:
            // Rest-pause uses same weight for all mini-sets
            guard let config = restPauseConfig else { return (weight ?? 0) * Double(actualReps ?? 0) }
            return (weight ?? 0) * Double(config.totalActualReps)
        case .timed:
            // Timed sets: volume = addedWeight × (duration in minutes)
            guard let config = timedSetConfig else { return 0 }
            let durationMinutes = (config.actualDuration ?? 0) / 60.0
            let addedWeight = config.addedWeight ?? 0
            return addedWeight * durationMinutes
        }
    }

    init(
        id: UUID = UUID(),
        setNumber: Int,
        setType: SetType = .standard,
        targetReps: Int,
        actualReps: Int? = nil,
        weight: Double? = nil,
        restPeriod: TimeInterval = 90,
        completedAt: Date? = nil,
        dropSetConfig: DropSetConfig? = nil,
        restPauseConfig: RestPauseConfig? = nil,
        timedSetConfig: TimedSetConfig? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.setType = setType
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.weight = weight
        self.restPeriod = restPeriod
        self.completedAt = completedAt
        self.dropSetConfig = dropSetConfig
        self.restPauseConfig = restPauseConfig
        self.timedSetConfig = timedSetConfig
    }
}
