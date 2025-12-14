import Foundation
import SwiftUI

/// Manages custom exercises created by the user via AI generation
@Observable
@MainActor
final class CustomExerciseStore {
    static let shared = CustomExerciseStore()

    var exercises: [Exercise] = [] {
        didSet { save() }
    }

    private let storageKey = "customExercises"

    private init() {
        load()
    }

    // MARK: - Duplicate Checking

    /// Check if an exercise with the given name already exists (custom or in database)
    func exerciseExists(name: String) -> Bool {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Check custom exercises
        if exercises.contains(where: { $0.name.lowercased() == normalizedName }) {
            return true
        }

        // Check database exercises
        if ExerciseDatabase.shared.exercises.contains(where: {
            $0.name.lowercased() == normalizedName ||
            $0.alternateNames.contains { $0.lowercased() == normalizedName }
        }) {
            return true
        }

        return false
    }

    // MARK: - Add Exercises

    /// Add a single exercise with duplicate checking
    /// - Throws: EquipmentError.duplicateExercise if exercise with same name exists
    func addExercise(_ exercise: Exercise) throws {
        if exerciseExists(name: exercise.name) {
            throw EquipmentError.duplicateExercise(name: exercise.name)
        }

        var customExercise = exercise
        customExercise.isCustom = true
        exercises.append(customExercise)

        // Calculate similarity scores for the new exercise
        ExerciseSimilarityService.shared.updateSimilaritiesForCustomExercise(customExercise)
    }

    /// Add a single exercise without duplicate checking (legacy method for compatibility)
    func addExerciseUnchecked(_ exercise: Exercise) {
        var customExercise = exercise
        customExercise.isCustom = true
        exercises.append(customExercise)

        // Calculate similarity scores for the new exercise
        ExerciseSimilarityService.shared.updateSimilaritiesForCustomExercise(customExercise)
    }

    /// Batch add exercises, filtering out duplicates
    /// - Returns: Tuple of (added exercises, skipped duplicates)
    func addExercises(_ newExercises: [Exercise]) -> (added: [Exercise], skipped: [Exercise]) {
        var added: [Exercise] = []
        var skipped: [Exercise] = []

        for exercise in newExercises {
            if exerciseExists(name: exercise.name) {
                skipped.append(exercise)
            } else {
                var customExercise = exercise
                customExercise.isCustom = true
                exercises.append(customExercise)
                added.append(customExercise)

                // Calculate similarity scores for the new exercise
                ExerciseSimilarityService.shared.updateSimilaritiesForCustomExercise(customExercise)
            }
        }

        return (added, skipped)
    }

    // MARK: - Update & Delete

    /// Update an existing exercise
    func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            let oldName = exercises[index].name
            exercises[index] = exercise

            // Update similarity cache if name changed
            if oldName != exercise.name {
                ExerciseSimilarityService.shared.removeSimilaritiesForCustomExercise(named: oldName)
            }
            ExerciseSimilarityService.shared.updateSimilaritiesForCustomExercise(exercise)
        }
    }

    /// Delete an exercise by ID
    func deleteExercise(id: UUID) {
        if let exercise = exercises.first(where: { $0.id == id }) {
            ExerciseSimilarityService.shared.removeSimilaritiesForCustomExercise(named: exercise.name)
        }
        exercises.removeAll { $0.id == id }
    }

    /// Delete exercises at specified indices
    func deleteExercises(at offsets: IndexSet) {
        // Remove from similarity cache first
        for index in offsets {
            if index < exercises.count {
                ExerciseSimilarityService.shared.removeSimilaritiesForCustomExercise(named: exercises[index].name)
            }
        }
        exercises.remove(atOffsets: offsets)
    }

    // MARK: - Query

    /// Get exercises for a specific custom equipment
    func getExercises(forCustomEquipmentId id: UUID) -> [Exercise] {
        exercises.filter { $0.customEquipmentId == id }
    }

    /// Get all exercise names (for duplicate checking during AI generation)
    func getAllExerciseNames() -> [String] {
        let customNames = exercises.map { $0.name }
        let databaseNames = ExerciseDatabase.shared.exercises.map { $0.name }
        return customNames + databaseNames
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Exercise].self, from: data) {
            exercises = saved
        }
    }
}
