import Foundation

/// Classification of exercise movement patterns for similarity calculation
enum MovementPattern: String, Codable, CaseIterable, Hashable {
    case horizontalPush = "Horizontal Push"   // Bench press, push-ups
    case horizontalPull = "Horizontal Pull"   // Rows
    case verticalPush = "Vertical Push"       // Overhead press
    case verticalPull = "Vertical Pull"       // Pull-ups, lat pulldown
    case hipHinge = "Hip Hinge"               // Deadlift, RDL, good mornings
    case squat = "Squat"                      // Squats, leg press
    case lunge = "Lunge"                      // Lunges, split squats, step-ups
    case isolation = "Isolation"              // Curls, extensions, flyes, raises
    case carry = "Carry"                      // Farmer's walk, loaded carries
    case rotational = "Rotational"            // Woodchops, russian twists
    case isometric = "Isometric"              // Planks, wall sits, holds

    /// Display name for UI
    var displayName: String {
        return rawValue
    }

    /// Related movement patterns for partial similarity matching
    /// Returns patterns that share biomechanical similarities
    var relatedPatterns: Set<MovementPattern> {
        switch self {
        case .horizontalPush:
            return [.verticalPush]  // Both are pushing movements
        case .horizontalPull:
            return [.verticalPull]  // Both are pulling movements
        case .verticalPush:
            return [.horizontalPush]
        case .verticalPull:
            return [.horizontalPull]
        case .hipHinge:
            return [.squat, .lunge]  // All lower body compound movements
        case .squat:
            return [.hipHinge, .lunge]
        case .lunge:
            return [.squat, .hipHinge]
        case .isolation:
            return []  // Isolation exercises relate by muscle group, not pattern
        case .carry:
            return [.isometric]  // Both involve static holds under tension
        case .rotational:
            return []  // Unique movement pattern
        case .isometric:
            return [.carry]
        }
    }

    /// Calculate similarity score between two movement patterns
    /// - Returns: 1.0 for exact match, 0.5 for related patterns, 0.0 for unrelated
    static func similarity(between pattern1: MovementPattern?, and pattern2: MovementPattern?) -> Double {
        // If either is nil, return neutral score
        guard let p1 = pattern1, let p2 = pattern2 else {
            return 0.5
        }

        // Exact match
        if p1 == p2 {
            return 1.0
        }

        // Related patterns
        if p1.relatedPatterns.contains(p2) || p2.relatedPatterns.contains(p1) {
            return 0.5
        }

        // Unrelated patterns
        return 0.0
    }
}
