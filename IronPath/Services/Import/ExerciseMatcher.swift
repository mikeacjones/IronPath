import Foundation

// MARK: - Exercise Match

/// Represents a potential match between a CSV exercise name and a database exercise
struct ExerciseMatch: Identifiable {
    var id: UUID { exercise.id }
    var exercise: Exercise
    var similarity: Double // 0.0 to 1.0
    var matchType: MatchType

    enum MatchType {
        case exact // Exact name match
        case alternate // Matched via alternate name
        case fuzzy // Fuzzy string matching
    }
}

// MARK: - Exercise Matching Protocol

protocol ExerciseMatching {
    /// Find potential matches for an exercise name
    func findMatches(for name: String, equipment: Equipment?) -> [ExerciseMatch]

    /// Find exact match for an exercise name
    func exactMatch(for name: String) -> Exercise?
}

// MARK: - Exercise Matcher

/// Matches exercise names from CSV to database exercises using various strategies
@MainActor
final class ExerciseMatcher: ExerciseMatching {
    private let exerciseDatabase: ExerciseDatabaseProviding

    // MARK: - Configuration

    private let similarityThreshold: Double = 0.6 // Minimum similarity for fuzzy matches
    private let maxFuzzyMatches: Int = 5 // Maximum fuzzy matches to return

    // MARK: - Initialization

    init(exerciseDatabase: ExerciseDatabaseProviding? = nil) {
        self.exerciseDatabase = exerciseDatabase ?? ExerciseDatabase.shared
    }

    // MARK: - Public Methods

    func findMatches(for name: String, equipment: Equipment? = nil) -> [ExerciseMatch] {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return [] }

        var matches: [ExerciseMatch] = []

        // Try exact match first
        if let exactExercise = exactMatch(for: cleanName) {
            matches.append(ExerciseMatch(
                exercise: exactExercise,
                similarity: 1.0,
                matchType: .exact
            ))
            return matches // Return immediately for exact match
        }

        // Try alternate name match
        if let alternateExercise = alternateNameMatch(for: cleanName) {
            matches.append(ExerciseMatch(
                exercise: alternateExercise,
                similarity: 0.95,
                matchType: .alternate
            ))
            // Continue to find fuzzy matches too
        }

        // Try fuzzy matching
        let fuzzyMatches = fuzzyMatch(for: cleanName, equipment: equipment)
        matches.append(contentsOf: fuzzyMatches)

        // Sort by similarity (highest first)
        matches.sort { $0.similarity > $1.similarity }

        // Remove duplicates (keep highest similarity)
        var seen = Set<UUID>()
        matches = matches.filter { match in
            if seen.contains(match.exercise.id) {
                return false
            }
            seen.insert(match.exercise.id)
            return true
        }

        return matches
    }

    func exactMatch(for name: String) -> Exercise? {
        let cleanName = name.lowercased().trimmingCharacters(in: .whitespaces)
        return exerciseDatabase.exercises.first { exercise in
            exercise.name.lowercased() == cleanName
        }
    }

    // MARK: - Private Methods

    private func alternateNameMatch(for name: String) -> Exercise? {
        let cleanName = name.lowercased().trimmingCharacters(in: .whitespaces)
        return exerciseDatabase.exercises.first { exercise in
            exercise.alternateNames.contains { alternate in
                alternate.lowercased() == cleanName
            }
        }
    }

    private func fuzzyMatch(for name: String, equipment: Equipment?) -> [ExerciseMatch] {
        let cleanName = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Filter exercises by equipment if provided
        let candidateExercises = if let equipment = equipment {
            exerciseDatabase.exercises.filter { $0.equipment == equipment }
        } else {
            exerciseDatabase.exercises
        }

        var matches: [ExerciseMatch] = []

        for exercise in candidateExercises {
            // Calculate similarity against exercise name
            let nameSimilarity = stringSimilarity(cleanName, exercise.name.lowercased())

            // Calculate similarity against alternate names
            let alternateSimilarities = exercise.alternateNames.map { alternate in
                stringSimilarity(cleanName, alternate.lowercased())
            }

            // Take the best similarity score
            let bestSimilarity = max(nameSimilarity, alternateSimilarities.max() ?? 0.0)

            // Only include if above threshold
            if bestSimilarity >= similarityThreshold {
                matches.append(ExerciseMatch(
                    exercise: exercise,
                    similarity: bestSimilarity,
                    matchType: .fuzzy
                ))
            }
        }

        // Sort by similarity and limit results
        matches.sort { $0.similarity > $1.similarity }
        return Array(matches.prefix(maxFuzzyMatches))
    }

    /// Calculate string similarity using Levenshtein distance
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        guard !s1.isEmpty && !s2.isEmpty else { return 0.0 }

        let distance = levenshteinDistance(s1, s2)
        let maxLength = Double(max(s1.count, s2.count))

        // Convert distance to similarity (0.0 = completely different, 1.0 = identical)
        return 1.0 - (Double(distance) / maxLength)
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        let m = s1Array.count
        let n = s2Array.count

        // Create distance matrix
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        // Initialize first row and column
        for i in 0...m {
            matrix[i][0] = i
        }
        for j in 0...n {
            matrix[0][j] = j
        }

        // Fill in the matrix
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,    // deletion
                        matrix[i][j - 1] + 1,    // insertion
                        matrix[i - 1][j - 1] + 1  // substitution
                    )
                }
            }
        }

        return matrix[m][n]
    }
}
