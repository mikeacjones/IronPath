import Foundation

// MARK: - Workout Type Selection

enum WorkoutType: String, CaseIterable, Identifiable {
    case fullBody = "Full Body"
    case upperBody = "Upper Body"
    case lowerBody = "Lower Body"
    case push = "Push"
    case pull = "Pull"
    case chestTriceps = "Chest & Triceps"
    case backBiceps = "Back & Biceps"
    case shoulders = "Shoulders"
    case core = "Core"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fullBody: return "figure.strengthtraining.traditional"
        case .upperBody: return "figure.arms.open"
        case .lowerBody: return "figure.walk"
        case .push: return "arrow.up.forward"
        case .pull: return "arrow.down.backward"
        case .chestTriceps: return "figure.arms.open"
        case .backBiceps: return "arrow.down.to.line"
        case .shoulders: return "figure.boxing"
        case .core: return "figure.core.training"
        case .custom: return "text.bubble"
        }
    }

    var targetMuscleGroups: Set<MuscleGroup> {
        switch self {
        case .fullBody: return Set(MuscleGroup.allCases)
        case .upperBody: return [.chest, .back, .shoulders, .biceps, .triceps, .forearms]
        case .lowerBody: return [.quads, .hamstrings, .glutes, .calves]
        case .push: return [.chest, .shoulders, .triceps]
        case .pull: return [.back, .biceps, .forearms]
        case .chestTriceps: return [.chest, .triceps]
        case .backBiceps: return [.back, .biceps]
        case .shoulders: return [.shoulders, .traps]
        case .core: return [.abs, .obliques, .lowerBack]
        case .custom: return []  // No predefined muscles - user describes in prompt
        }
    }

    var requiresCustomPrompt: Bool {
        self == .custom
    }
}
