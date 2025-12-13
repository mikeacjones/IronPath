import Foundation

/// Available Claude models for the app
enum ClaudeModel: String, CaseIterable, Codable {
    case haiku = "claude-haiku-4-5-20251001"
    case sonnet = "claude-sonnet-4-20250514"
    case opus = "claude-opus-4-20250514"

    var displayName: String {
        switch self {
        case .haiku: return "Claude 4.5 Haiku"
        case .sonnet: return "Claude 4 Sonnet"
        case .opus: return "Claude 4 Opus"
        }
    }

    var description: String {
        switch self {
        case .haiku: return "Fastest & cheapest - Good for most workouts"
        case .sonnet: return "Balanced - Better reasoning"
        case .opus: return "Most capable - Best for complex requests"
        }
    }

    var costTier: String {
        switch self {
        case .haiku: return "$"
        case .sonnet: return "$$"
        case .opus: return "$$$"
        }
    }
}

/// Manages the user's selected Claude model
@Observable
@MainActor
final class ModelConfigManager {
    static let shared = ModelConfigManager()

    private let modelKey = "selected_claude_model"

    var selectedModel: ClaudeModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: modelKey)
        }
    }

    private init() {
        if let savedModel = UserDefaults.standard.string(forKey: modelKey),
           let model = ClaudeModel(rawValue: savedModel) {
            self.selectedModel = model
        } else {
            self.selectedModel = .haiku // Default to cheapest
        }
    }

    /// Get the model ID string for API calls
    var modelId: String {
        selectedModel.rawValue
    }
}
