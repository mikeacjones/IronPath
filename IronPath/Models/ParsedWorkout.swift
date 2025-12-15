import Foundation

// MARK: - Parsed Workout Models

/// A workout parsed from imported CSV data, before validation and persistence
struct ParsedWorkout: Identifiable {
    var id: UUID
    var date: Date
    var name: String
    var exercises: [ParsedExercise]

    init(id: UUID = UUID(), date: Date, name: String, exercises: [ParsedExercise]) {
        self.id = id
        self.date = date
        self.name = name
        self.exercises = exercises
    }
}

/// An exercise parsed from CSV, may or may not be matched to database exercise
struct ParsedExercise: Identifiable {
    var id: UUID
    var name: String
    var sets: [ParsedSet]
    var matchedExercise: Exercise?

    var isMatched: Bool {
        matchedExercise != nil
    }

    init(id: UUID = UUID(), name: String, sets: [ParsedSet], matchedExercise: Exercise? = nil) {
        self.id = id
        self.name = name
        self.sets = sets
        self.matchedExercise = matchedExercise
    }
}

/// A single set parsed from CSV
struct ParsedSet: Identifiable {
    var id: UUID
    var reps: Int
    var weight: Double
    var isWarmup: Bool
    var note: String
    var multiplier: Double

    init(
        id: UUID = UUID(),
        reps: Int,
        weight: Double,
        isWarmup: Bool = false,
        note: String = "",
        multiplier: Double = 1.0
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
        self.note = note
        self.multiplier = multiplier
    }
}

// MARK: - Unmatched Exercise

/// Represents an exercise name from CSV that couldn't be automatically matched
struct UnmappedExercise: Identifiable {
    var id: UUID
    var name: String
    var count: Int // Number of workouts this exercise appears in

    init(id: UUID = UUID(), name: String, count: Int = 1) {
        self.id = id
        self.name = name
        self.count = count
    }
}
