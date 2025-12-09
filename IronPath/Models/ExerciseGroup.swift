import Foundation
import SwiftUI

// MARK: - Exercise Group Type

/// Types of exercise groupings
enum ExerciseGroupType: String, Codable, CaseIterable, Equatable {
    case superset = "Superset"
    case triset = "Triset"
    case giantSet = "Giant Set"
    case circuit = "Circuit"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .superset:
            return "Two exercises performed back-to-back with no rest between"
        case .triset:
            return "Three exercises performed back-to-back with no rest between"
        case .giantSet:
            return "Four or more exercises performed back-to-back"
        case .circuit:
            return "Multiple exercises performed in sequence, typically for conditioning"
        }
    }

    var iconName: String {
        switch self {
        case .superset:
            return "arrow.triangle.2.circlepath"
        case .triset:
            return "arrow.triangle.capsulepath"
        case .giantSet:
            return "arrow.3.trianglepath"
        case .circuit:
            return "repeat.circle"
        }
    }

    var color: String {
        switch self {
        case .superset: return "purple"
        case .triset: return "indigo"
        case .giantSet: return "pink"
        case .circuit: return "teal"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .superset: return .purple
        case .triset: return .indigo
        case .giantSet: return .pink
        case .circuit: return .teal
        }
    }

    /// Suggested group type based on number of exercises
    static func suggestedType(for exerciseCount: Int) -> ExerciseGroupType {
        switch exerciseCount {
        case 2: return .superset
        case 3: return .triset
        default: return .giantSet
        }
    }
}

// MARK: - Exercise Group

/// A group of exercises performed together (superset, triset, circuit, etc.)
struct ExerciseGroup: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var groupType: ExerciseGroupType
    var name: String? // Optional custom name for the group
    var exerciseIds: [UUID] // IDs of exercises in this group, in order
    var restBetweenExercises: TimeInterval // Rest between exercises within the group (usually 0 for supersets)
    var restAfterGroup: TimeInterval // Rest after completing one round of the group
    var rounds: Int // Number of times to cycle through the group (mainly for circuits)

    init(
        id: UUID = UUID(),
        groupType: ExerciseGroupType,
        name: String? = nil,
        exerciseIds: [UUID] = [],
        restBetweenExercises: TimeInterval = 0,
        restAfterGroup: TimeInterval = 90,
        rounds: Int = 1
    ) {
        self.id = id
        self.groupType = groupType
        self.name = name
        self.exerciseIds = exerciseIds
        self.restBetweenExercises = restBetweenExercises
        self.restAfterGroup = restAfterGroup
        self.rounds = rounds
    }

    /// Display name for the group
    var displayName: String {
        name ?? groupType.displayName
    }

    /// Number of exercises in this group
    var exerciseCount: Int {
        exerciseIds.count
    }

    /// Check if an exercise is part of this group
    func contains(exerciseId: UUID) -> Bool {
        exerciseIds.contains(exerciseId)
    }

    /// Get the position of an exercise within the group (0-indexed)
    func position(of exerciseId: UUID) -> Int? {
        exerciseIds.firstIndex(of: exerciseId)
    }

    /// Check if this is the first exercise in the group
    func isFirst(_ exerciseId: UUID) -> Bool {
        exerciseIds.first == exerciseId
    }

    /// Check if this is the last exercise in the group
    func isLast(_ exerciseId: UUID) -> Bool {
        exerciseIds.last == exerciseId
    }
}

// MARK: - Workout Extension for Groups

extension Workout {
    /// Get the group containing a specific exercise, if any
    func group(for exerciseId: UUID) -> ExerciseGroup? {
        exerciseGroups?.first { $0.contains(exerciseId: exerciseId) }
    }

    /// Get all exercises in a specific group
    func exercises(in group: ExerciseGroup) -> [WorkoutExercise] {
        group.exerciseIds.compactMap { groupExerciseId in
            exercises.first { $0.id == groupExerciseId }
        }
    }

    /// Check if an exercise is grouped
    func isGrouped(_ exerciseId: UUID) -> Bool {
        exerciseGroups?.contains { $0.contains(exerciseId: exerciseId) } ?? false
    }
}
