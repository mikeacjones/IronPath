import Foundation

// MARK: - Exercise Suggestion Preference

/// User preference for how often an exercise should be suggested
enum ExerciseSuggestionPreference: String, Codable, CaseIterable, Equatable {
    case normal = "Normal"
    case preferMore = "Suggest More"
    case preferLess = "Suggest Less"
    case doNotSuggest = "Do Not Suggest"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .normal:
            return "AI will suggest this exercise normally"
        case .preferMore:
            return "AI will prioritize this exercise"
        case .preferLess:
            return "AI will rarely suggest this exercise"
        case .doNotSuggest:
            return "AI will never suggest this exercise"
        }
    }

    var iconName: String {
        switch self {
        case .normal: return "equal.circle"
        case .preferMore: return "arrow.up.circle.fill"
        case .preferLess: return "arrow.down.circle"
        case .doNotSuggest: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .normal: return "gray"
        case .preferMore: return "green"
        case .preferLess: return "orange"
        case .doNotSuggest: return "red"
        }
    }

    /// Weight multiplier for AI prompt (higher = more likely)
    var promptWeight: String {
        switch self {
        case .normal: return ""
        case .preferMore: return "PREFERRED - prioritize this exercise"
        case .preferLess: return "AVOID unless necessary"
        case .doNotSuggest: return "DO NOT USE"
        }
    }
}

// MARK: - Exercise Preference Entry

/// A single exercise preference entry
struct ExercisePreferenceEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let exerciseName: String
    var preference: ExerciseSuggestionPreference
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        exerciseName: String,
        preference: ExerciseSuggestionPreference,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.preference = preference
        self.updatedAt = updatedAt
    }
}

