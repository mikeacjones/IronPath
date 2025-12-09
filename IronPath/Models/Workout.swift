import Foundation

/// A complete workout session
struct Workout: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExercise]
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var notes: String
    var claudeGenerationPrompt: String? // Store the prompt used to generate this workout

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

    init(
        id: UUID = UUID(),
        name: String,
        exercises: [WorkoutExercise] = [],
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        notes: String = "",
        claudeGenerationPrompt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.claudeGenerationPrompt = claudeGenerationPrompt
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
    var targetReps: Int
    var actualReps: Int?
    var weight: Double? // in pounds or kg
    var restPeriod: TimeInterval // seconds
    var completedAt: Date?

    var isCompleted: Bool {
        actualReps != nil && completedAt != nil
    }

    init(
        id: UUID = UUID(),
        setNumber: Int,
        targetReps: Int,
        actualReps: Int? = nil,
        weight: Double? = nil,
        restPeriod: TimeInterval = 90,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.weight = weight
        self.restPeriod = restPeriod
        self.completedAt = completedAt
    }
}
