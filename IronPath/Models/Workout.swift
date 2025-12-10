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

    var duration: TimeInterval? {
        guard let start = startedAt, let completed = completedAt else { return nil }
        return completed.timeIntervalSince(start)
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var totalVolume: Double {
        exercises.reduce(0) { total, exercise in
            total + exercise.totalVolume
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
        isDeload: Bool = false
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
    }
}

/// An exercise within a workout with its sets
struct WorkoutExercise: Codable, Identifiable, Hashable {
    let id: UUID
    var exercise: Exercise
    var sets: [ExerciseSet]
    var orderIndex: Int
    var notes: String

    var totalVolume: Double {
        sets.reduce(0) { total, set in
            if let weight = set.weight {
                let reps = set.actualReps ?? set.targetReps
                return total + (weight * Double(reps))
            }
            return total
        }
    }

    var isCompleted: Bool {
        sets.allSatisfy { $0.isCompleted }
    }

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        sets: [ExerciseSet] = [],
        orderIndex: Int,
        notes: String = ""
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.orderIndex = orderIndex
        self.notes = notes
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
        restPauseConfig: RestPauseConfig? = nil
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
    }
}
