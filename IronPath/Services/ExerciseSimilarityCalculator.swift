import Foundation

/// Calculates similarity scores between exercises based on multiple factors
class ExerciseSimilarityCalculator {

    // MARK: - Similarity Weights

    /// Weight factors for similarity calculation (must sum to 1.0)
    struct Weights {
        static let primaryMuscles: Double = 0.35
        static let movementPattern: Double = 0.25
        static let secondaryMuscles: Double = 0.15
        static let equipment: Double = 0.10
        static let difficulty: Double = 0.10
        static let unilateral: Double = 0.05
    }

    // MARK: - Public Methods

    /// Calculate similarity score between two exercises
    /// - Returns: Score from 0.0 (completely different) to 1.0 (identical)
    static func calculateSimilarity(between exercise1: Exercise, and exercise2: Exercise) -> Double {
        // Same exercise - perfect match
        if exercise1.id == exercise2.id || exercise1.name == exercise2.name {
            return 1.0
        }

        let primaryScore = calculatePrimaryMuscleScore(exercise1, exercise2)
        let movementScore = calculateMovementPatternScore(exercise1, exercise2)
        let secondaryScore = calculateSecondaryMuscleScore(exercise1, exercise2)
        let equipmentScore = calculateEquipmentScore(exercise1, exercise2)
        let difficultyScore = calculateDifficultyScore(exercise1, exercise2)
        let unilateralScore = calculateUnilateralScore(exercise1, exercise2)

        let totalScore = (primaryScore * Weights.primaryMuscles) +
                        (movementScore * Weights.movementPattern) +
                        (secondaryScore * Weights.secondaryMuscles) +
                        (equipmentScore * Weights.equipment) +
                        (difficultyScore * Weights.difficulty) +
                        (unilateralScore * Weights.unilateral)

        return min(1.0, max(0.0, totalScore))
    }

    /// Calculate similarity scores for one exercise against all others
    /// - Returns: Array of (Exercise, score) pairs sorted by score descending
    static func calculateSimilarities(
        for exercise: Exercise,
        against exercises: [Exercise],
        limit: Int = 20
    ) -> [(Exercise, Double)] {
        let scores = exercises
            .filter { $0.id != exercise.id && $0.name != exercise.name }
            .map { other -> (Exercise, Double) in
                let score = calculateSimilarity(between: exercise, and: other)
                return (other, score)
            }
            .sorted { $0.1 > $1.1 }

        if limit > 0 {
            return Array(scores.prefix(limit))
        }
        return scores
    }

    /// Generate similarity data for all exercises in the database
    /// - Returns: Dictionary mapping exercise name to sorted list of similar exercises
    static func generateAllSimilarities(
        exercises: [Exercise],
        limit: Int = 20
    ) -> [String: [ExerciseSimilarity]] {
        var result: [String: [ExerciseSimilarity]] = [:]

        for exercise in exercises {
            let similarities = calculateSimilarities(for: exercise, against: exercises, limit: limit)
            result[exercise.name] = similarities.map { (ex, score) in
                ExerciseSimilarity(exerciseName: ex.name, score: score)
            }
        }

        return result
    }

    // MARK: - Private Scoring Methods

    /// Jaccard similarity coefficient for two sets
    private static func jaccardSimilarity<T: Hashable>(_ set1: Set<T>, _ set2: Set<T>) -> Double {
        guard !set1.isEmpty || !set2.isEmpty else { return 1.0 }
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        return Double(intersection) / Double(union)
    }

    /// Calculate primary muscle group similarity (Jaccard)
    private static func calculatePrimaryMuscleScore(_ e1: Exercise, _ e2: Exercise) -> Double {
        return jaccardSimilarity(e1.primaryMuscleGroups, e2.primaryMuscleGroups)
    }

    /// Calculate secondary muscle group similarity (Jaccard)
    private static func calculateSecondaryMuscleScore(_ e1: Exercise, _ e2: Exercise) -> Double {
        // If both have no secondary muscles, consider it a match
        if e1.secondaryMuscleGroups.isEmpty && e2.secondaryMuscleGroups.isEmpty {
            return 1.0
        }
        // If only one has secondary muscles, partial match
        if e1.secondaryMuscleGroups.isEmpty || e2.secondaryMuscleGroups.isEmpty {
            return 0.5
        }
        return jaccardSimilarity(e1.secondaryMuscleGroups, e2.secondaryMuscleGroups)
    }

    /// Calculate movement pattern similarity
    private static func calculateMovementPatternScore(_ e1: Exercise, _ e2: Exercise) -> Double {
        return MovementPattern.similarity(between: e1.movementPattern, and: e2.movementPattern)
    }

    /// Calculate equipment similarity
    private static func calculateEquipmentScore(_ e1: Exercise, _ e2: Exercise) -> Double {
        return EquipmentCategory.similarity(
            equipment1: e1.equipment,
            machine1: e1.specificMachine,
            equipment2: e2.equipment,
            machine2: e2.specificMachine
        )
    }

    /// Calculate difficulty similarity
    private static func calculateDifficultyScore(_ e1: Exercise, _ e2: Exercise) -> Double {
        let diff1 = difficultyValue(e1.difficulty)
        let diff2 = difficultyValue(e2.difficulty)
        let difference = abs(diff1 - diff2)

        switch difference {
        case 0: return 1.0    // Same difficulty
        case 1: return 0.5    // Adjacent difficulty
        default: return 0.25  // Two levels apart
        }
    }

    /// Convert difficulty to numeric value for comparison
    private static func difficultyValue(_ difficulty: ExerciseDifficulty) -> Int {
        switch difficulty {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        }
    }

    /// Calculate unilateral match score
    private static func calculateUnilateralScore(_ e1: Exercise, _ e2: Exercise) -> Double {
        return e1.isUnilateral == e2.isUnilateral ? 1.0 : 0.5
    }
}
