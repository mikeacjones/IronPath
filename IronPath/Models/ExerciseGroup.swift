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

// MARK: - Exercise Display Item

/// Represents either a standalone exercise or a group of exercises for display purposes
enum ExerciseDisplayItem: Identifiable {
    case standalone(WorkoutExercise)
    case group(ExerciseGroup, [WorkoutExercise])

    var id: String {
        switch self {
        case .standalone(let exercise):
            return "standalone-\(exercise.id.uuidString)"
        case .group(let group, _):
            return "group-\(group.id.uuidString)"
        }
    }

    /// Get the first exercise ID (for ordering purposes)
    var firstExerciseId: UUID {
        switch self {
        case .standalone(let exercise):
            return exercise.id
        case .group(_, let exercises):
            return exercises.first?.id ?? UUID()
        }
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

    /// Get display items for the workout (standalone exercises and groups)
    var displayItems: [ExerciseDisplayItem] {
        var items: [ExerciseDisplayItem] = []
        var processedExerciseIds: Set<UUID> = []

        for exercise in exercises {
            guard !processedExerciseIds.contains(exercise.id) else { continue }

            if let group = group(for: exercise.id) {
                let groupExercises = group.exerciseIds.compactMap { exerciseId in
                    exercises.first { $0.id == exerciseId }
                }
                for groupExercise in groupExercises {
                    processedExerciseIds.insert(groupExercise.id)
                }
                items.append(.group(group, groupExercises))
            } else {
                processedExerciseIds.insert(exercise.id)
                items.append(.standalone(exercise))
            }
        }

        return items
    }

    /// Reorder display items (moves groups as a unit, standalone exercises individually)
    mutating func reorderDisplayItems(from source: IndexSet, to destination: Int) {
        var items = displayItems
        items.move(fromOffsets: source, toOffset: destination)

        // Rebuild exercises array from new item order
        var newExercises: [WorkoutExercise] = []
        for item in items {
            switch item {
            case .standalone(let exercise):
                var updatedExercise = exercise
                updatedExercise.orderIndex = newExercises.count
                newExercises.append(updatedExercise)
            case .group(_, let groupExercises):
                for exercise in groupExercises {
                    var updatedExercise = exercise
                    updatedExercise.orderIndex = newExercises.count
                    newExercises.append(updatedExercise)
                }
            }
        }

        exercises = newExercises
    }

    /// Reorder exercises within a specific group
    mutating func reorderExercisesInGroup(_ groupId: UUID, from source: IndexSet, to destination: Int) {
        guard var groups = exerciseGroups,
              let groupIndex = groups.firstIndex(where: { $0.id == groupId }) else { return }

        // Reorder exerciseIds in the group
        groups[groupIndex].exerciseIds.move(fromOffsets: source, toOffset: destination)
        exerciseGroups = groups

        // Rebuild exercises array to match new group order
        rebuildExercisesOrder()
    }

    /// Rebuild the exercises array order to match the current display items and group ordering
    mutating func rebuildExercisesOrder() {
        var newExercises: [WorkoutExercise] = []
        var processedExerciseIds: Set<UUID> = []

        for exercise in exercises {
            guard !processedExerciseIds.contains(exercise.id) else { continue }

            if let group = group(for: exercise.id) {
                // Add exercises in the order defined by the group
                for exerciseId in group.exerciseIds {
                    if let groupExercise = exercises.first(where: { $0.id == exerciseId }) {
                        var updatedExercise = groupExercise
                        updatedExercise.orderIndex = newExercises.count
                        newExercises.append(updatedExercise)
                        processedExerciseIds.insert(exerciseId)
                    }
                }
            } else {
                var updatedExercise = exercise
                updatedExercise.orderIndex = newExercises.count
                newExercises.append(updatedExercise)
                processedExerciseIds.insert(exercise.id)
            }
        }

        exercises = newExercises
    }

    /// Replace an exercise with a new one, maintaining group membership
    /// - Parameters:
    ///   - oldExerciseId: The ID of the exercise to replace
    ///   - newExercise: The new exercise to replace it with
    /// - Returns: True if the replacement was successful
    @discardableResult
    mutating func replaceExercise(oldExerciseId: UUID, with newExercise: WorkoutExercise) -> Bool {
        // Find and replace the exercise in the exercises array
        guard let index = exercises.firstIndex(where: { $0.id == oldExerciseId }) else {
            return false
        }

        exercises[index] = newExercise

        // Update group membership: replace old ID with new ID in any group
        if var groups = exerciseGroups {
            for groupIndex in groups.indices {
                if let exerciseIdIndex = groups[groupIndex].exerciseIds.firstIndex(of: oldExerciseId) {
                    groups[groupIndex].exerciseIds[exerciseIdIndex] = newExercise.id
                }
            }
            exerciseGroups = groups
        }

        return true
    }
}
