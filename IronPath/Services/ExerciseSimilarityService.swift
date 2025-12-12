import Foundation

/// Service for retrieving exercise similarity scores
/// Calculates similarities at initialization and caches them for fast lookup
class ExerciseSimilarityService {
    static let shared = ExerciseSimilarityService()

    /// Pre-calculated similarities for built-in exercises
    /// Maps exercise name -> array of similar exercises sorted by score descending
    private var builtInSimilarities: [String: [ExerciseSimilarity]] = [:]

    /// Cache for custom exercise similarities
    private var customSimilarities: [String: [ExerciseSimilarity]] = [:]

    /// Maximum number of similar exercises to store per exercise
    private let maxSimilaritiesPerExercise = 20

    /// Minimum similarity score to include (filters out very dissimilar exercises)
    private let minimumSimilarityScore: Double = 0.15

    private init() {
        generateBuiltInSimilarities()
    }

    // MARK: - Public Methods

    /// Get similar exercises for a given exercise name
    /// - Parameters:
    ///   - exerciseName: Name of the exercise to find similarities for
    ///   - limit: Maximum number of results to return (default 20)
    /// - Returns: Array of ExerciseSimilarity sorted by score descending
    func getSimilarExercises(for exerciseName: String, limit: Int = 20) -> [ExerciseSimilarity] {
        // Check built-in first
        if let similarities = builtInSimilarities[exerciseName] {
            return Array(similarities.prefix(limit))
        }

        // Check custom exercises
        if let similarities = customSimilarities[exerciseName] {
            return Array(similarities.prefix(limit))
        }

        // Try to find the exercise and calculate on demand
        if let exercise = findExercise(named: exerciseName) {
            let similarities = calculateAndCacheSimilarities(for: exercise)
            return Array(similarities.prefix(limit))
        }

        return []
    }

    /// Get similar exercises for a given Exercise object
    func getSimilarExercises(for exercise: Exercise, limit: Int = 20) -> [ExerciseSimilarity] {
        return getSimilarExercises(for: exercise.name, limit: limit)
    }

    /// Get all exercises sorted by similarity to a source exercise
    /// - Parameters:
    ///   - exercise: The source exercise to compare against
    ///   - excludeNames: Exercise names to exclude from results
    ///   - availableEquipment: Only include exercises with this equipment
    ///   - availableMachines: Only include exercises requiring these machines
    /// - Returns: Array of (Exercise, score) tuples sorted by score descending
    func getAllExercisesSortedBySimilarity(
        to exercise: Exercise,
        excludeNames: Set<String> = [],
        availableEquipment: Set<Equipment>? = nil,
        availableMachines: Set<SpecificMachine>? = nil
    ) -> [(Exercise, Double)] {
        let allExercises = getAllExercises()

        return allExercises
            .filter { other in
                // Exclude the source exercise
                guard other.name != exercise.name else { return false }

                // Exclude specified names
                guard !excludeNames.contains(other.name) else { return false }

                // Filter by equipment if specified
                if let equipment = availableEquipment {
                    if let requiredMachine = other.specificMachine {
                        guard availableMachines?.contains(requiredMachine) ?? false else {
                            return false
                        }
                    } else {
                        guard equipment.contains(other.equipment) else {
                            return false
                        }
                    }
                }

                return true
            }
            .map { other -> (Exercise, Double) in
                let score = ExerciseSimilarityCalculator.calculateSimilarity(between: exercise, and: other)
                return (other, score)
            }
            .sorted { $0.1 > $1.1 }
    }

    /// Calculate similarity between two specific exercises
    func calculateSimilarity(between exercise1: Exercise, and exercise2: Exercise) -> Double {
        return ExerciseSimilarityCalculator.calculateSimilarity(between: exercise1, and: exercise2)
    }

    /// Calculate and cache similarities for a custom exercise
    /// Call this when a custom exercise is created or modified
    func updateSimilaritiesForCustomExercise(_ exercise: Exercise) {
        let allExercises = getAllExercises()
        let similarities = ExerciseSimilarityCalculator.calculateSimilarities(
            for: exercise,
            against: allExercises,
            limit: maxSimilaritiesPerExercise
        )

        customSimilarities[exercise.name] = similarities
            .filter { $0.1 >= minimumSimilarityScore }
            .map { ExerciseSimilarity(exerciseName: $0.0.name, score: $0.1) }
    }

    /// Remove cached similarities for a custom exercise
    func removeSimilaritiesForCustomExercise(named name: String) {
        customSimilarities.removeValue(forKey: name)
    }

    /// Refresh all similarities (useful after database changes)
    func refreshAllSimilarities() {
        builtInSimilarities.removeAll()
        customSimilarities.removeAll()
        generateBuiltInSimilarities()

        // Recalculate custom exercise similarities
        for exercise in CustomExerciseStore.shared.exercises {
            updateSimilaritiesForCustomExercise(exercise)
        }
    }

    // MARK: - Private Methods

    /// Generate similarities for all built-in exercises
    private func generateBuiltInSimilarities() {
        let exercises = ExerciseDatabase.shared.exercises

        let result = ExerciseSimilarityCalculator.generateAllSimilarities(
            exercises: exercises,
            limit: maxSimilaritiesPerExercise
        )

        // Filter out low similarity scores
        builtInSimilarities = result.mapValues { similarities in
            similarities.filter { $0.score >= minimumSimilarityScore }
        }
    }

    /// Calculate and cache similarities for an exercise not yet in cache
    private func calculateAndCacheSimilarities(for exercise: Exercise) -> [ExerciseSimilarity] {
        let allExercises = getAllExercises()
        let similarities = ExerciseSimilarityCalculator.calculateSimilarities(
            for: exercise,
            against: allExercises,
            limit: maxSimilaritiesPerExercise
        )

        let result = similarities
            .filter { $0.1 >= minimumSimilarityScore }
            .map { ExerciseSimilarity(exerciseName: $0.0.name, score: $0.1) }

        // Cache based on whether it's custom or built-in
        if exercise.isCustom {
            customSimilarities[exercise.name] = result
        } else {
            builtInSimilarities[exercise.name] = result
        }

        return result
    }

    /// Get all exercises (built-in + custom)
    private func getAllExercises() -> [Exercise] {
        return ExerciseDatabase.shared.exercises + CustomExerciseStore.shared.exercises
    }

    /// Find an exercise by name
    private func findExercise(named name: String) -> Exercise? {
        // Check built-in
        if let exercise = ExerciseDatabase.shared.exercises.first(where: { $0.name == name }) {
            return exercise
        }

        // Check custom
        return CustomExerciseStore.shared.exercises.first(where: { $0.name == name })
    }
}

// MARK: - Helper Extensions

extension ExerciseSimilarityService {
    /// Get top replacement suggestions for an exercise with filtering
    /// This is the primary method used by the replacement UI
    func getReplacementSuggestions(
        for exercise: Exercise,
        excludingWorkoutExercises workoutExerciseNames: [String],
        availableEquipment: Set<Equipment>,
        availableMachines: Set<SpecificMachine>,
        limit: Int = 10
    ) -> [(Exercise, Double)] {
        let excludeNames = Set(workoutExerciseNames + [exercise.name])

        return getAllExercisesSortedBySimilarity(
            to: exercise,
            excludeNames: excludeNames,
            availableEquipment: availableEquipment,
            availableMachines: availableMachines
        ).prefix(limit).map { $0 }
    }
}
