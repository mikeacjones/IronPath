import Foundation

// MARK: - Set Type Enum

/// Types of sets supported by the app
enum SetType: String, Codable, CaseIterable, Hashable {
    case standard = "Standard"
    case warmup = "Warmup"
    case dropSet = "Drop Set"
    case restPause = "Rest-Pause"

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .standard: return "STD"
        case .warmup: return "W"
        case .dropSet: return "DROP"
        case .restPause: return "RP"
        }
    }

    var iconName: String {
        switch self {
        case .standard: return "circle.fill"
        case .warmup: return "flame"
        case .dropSet: return "arrow.down.circle.fill"
        case .restPause: return "pause.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "Regular working set"
        case .warmup:
            return "Lighter weight to prepare muscles"
        case .dropSet:
            return "Reduce weight immediately after failure and continue"
        case .restPause:
            return "Brief rest (10-20s) then continue with same weight"
        }
    }

    var color: String {
        switch self {
        case .standard: return "blue"
        case .warmup: return "orange"
        case .dropSet: return "purple"
        case .restPause: return "green"
        }
    }
}

// MARK: - Drop Set Configuration

/// Configuration for a drop set (multiple weight reductions within one set)
struct DropSetConfig: Codable, Hashable {
    /// Number of drops (weight reductions) in this set
    var numberOfDrops: Int

    /// Percentage to reduce weight by on each drop (e.g., 0.2 = 20% reduction)
    var dropPercentage: Double

    /// Completed drops with actual weights and reps
    var drops: [DropSetEntry]

    init(numberOfDrops: Int = 2, dropPercentage: Double = 0.2, drops: [DropSetEntry] = []) {
        self.numberOfDrops = numberOfDrops
        self.dropPercentage = dropPercentage
        self.drops = drops
    }

    /// Calculate suggested weights for drops based on starting weight
    func suggestedWeights(startingWeight: Double) -> [Double] {
        var weights: [Double] = [startingWeight]
        var currentWeight = startingWeight

        for _ in 0..<numberOfDrops {
            currentWeight = currentWeight * (1 - dropPercentage)
            // Round to nearest 2.5 lbs for practical weight selection
            currentWeight = (currentWeight / 2.5).rounded() * 2.5
            weights.append(max(currentWeight, 5)) // Minimum 5 lbs
        }

        return weights
    }
}

/// A single drop within a drop set
struct DropSetEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var dropNumber: Int // 0 = initial weight, 1 = first drop, etc.
    var targetWeight: Double?
    var actualWeight: Double?
    var targetReps: Int
    var actualReps: Int?
    var completedAt: Date?

    var isCompleted: Bool {
        actualReps != nil && completedAt != nil
    }

    init(
        id: UUID = UUID(),
        dropNumber: Int,
        targetWeight: Double? = nil,
        actualWeight: Double? = nil,
        targetReps: Int = 8,
        actualReps: Int? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.dropNumber = dropNumber
        self.targetWeight = targetWeight
        self.actualWeight = actualWeight
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.completedAt = completedAt
    }
}

// MARK: - Rest-Pause Configuration

/// Configuration for a rest-pause set
struct RestPauseConfig: Codable, Hashable {
    /// Number of mini-sets after the initial set
    var numberOfPauses: Int

    /// Rest duration between mini-sets (typically 10-20 seconds)
    var pauseDuration: TimeInterval

    /// Completed mini-sets
    var miniSets: [RestPauseMiniSet]

    init(numberOfPauses: Int = 2, pauseDuration: TimeInterval = 15, miniSets: [RestPauseMiniSet] = []) {
        self.numberOfPauses = numberOfPauses
        self.pauseDuration = pauseDuration
        self.miniSets = miniSets
    }

    /// Total reps across all mini-sets
    var totalActualReps: Int {
        miniSets.compactMap { $0.actualReps }.reduce(0, +)
    }
}

/// A mini-set within a rest-pause set
struct RestPauseMiniSet: Codable, Identifiable, Hashable {
    let id: UUID
    var miniSetNumber: Int // 0 = initial set, 1 = first pause set, etc.
    var targetReps: Int
    var actualReps: Int?
    var completedAt: Date?

    var isCompleted: Bool {
        actualReps != nil && completedAt != nil
    }

    init(
        id: UUID = UUID(),
        miniSetNumber: Int,
        targetReps: Int = 4,
        actualReps: Int? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.miniSetNumber = miniSetNumber
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.completedAt = completedAt
    }
}

// MARK: - Helper Extensions

extension ExerciseSet {
    /// Create a drop set with default configuration
    static func createDropSet(
        setNumber: Int,
        targetReps: Int = 8,
        weight: Double? = nil,
        restPeriod: TimeInterval = 90,
        numberOfDrops: Int = 2,
        dropPercentage: Double = 0.2
    ) -> ExerciseSet {
        var dropConfig = DropSetConfig(numberOfDrops: numberOfDrops, dropPercentage: dropPercentage)

        // Pre-populate drops
        for i in 0...(numberOfDrops) {
            let suggestedWeight: Double?
            if let w = weight {
                let weights = dropConfig.suggestedWeights(startingWeight: w)
                suggestedWeight = weights[safe: i]
            } else {
                suggestedWeight = nil
            }

            dropConfig.drops.append(DropSetEntry(
                dropNumber: i,
                targetWeight: suggestedWeight,
                targetReps: targetReps
            ))
        }

        return ExerciseSet(
            setNumber: setNumber,
            setType: .dropSet,
            targetReps: targetReps,
            weight: weight,
            restPeriod: restPeriod,
            dropSetConfig: dropConfig
        )
    }

    /// Create a rest-pause set with default configuration
    static func createRestPauseSet(
        setNumber: Int,
        targetReps: Int = 8,
        weight: Double? = nil,
        restPeriod: TimeInterval = 90,
        numberOfPauses: Int = 2,
        pauseDuration: TimeInterval = 15
    ) -> ExerciseSet {
        var restPauseConfig = RestPauseConfig(numberOfPauses: numberOfPauses, pauseDuration: pauseDuration)

        // Pre-populate mini-sets (initial set + pauses)
        // Initial set targets full reps, subsequent sets target fewer
        restPauseConfig.miniSets.append(RestPauseMiniSet(miniSetNumber: 0, targetReps: targetReps))
        for i in 1...numberOfPauses {
            restPauseConfig.miniSets.append(RestPauseMiniSet(miniSetNumber: i, targetReps: max(targetReps / 2, 2)))
        }

        return ExerciseSet(
            setNumber: setNumber,
            setType: .restPause,
            targetReps: targetReps,
            weight: weight,
            restPeriod: restPeriod,
            restPauseConfig: restPauseConfig
        )
    }

    /// Create a warmup set
    static func createWarmupSet(
        setNumber: Int,
        targetReps: Int = 10,
        weight: Double? = nil,
        restPeriod: TimeInterval = 60
    ) -> ExerciseSet {
        ExerciseSet(
            setNumber: setNumber,
            setType: .warmup,
            targetReps: targetReps,
            weight: weight,
            restPeriod: restPeriod
        )
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
