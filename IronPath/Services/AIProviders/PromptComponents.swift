import Foundation

// MARK: - Prompt Priority System

/// Three-level priority hierarchy for prompt instructions.
/// Research shows overusing emphasis dilutes its effect.
/// Limit [REQUIRED] markers to ≤3 per prompt.
enum PromptPriority {
    case critical   // [REQUIRED] - must follow or output is invalid
    case important  // [IMPORTANT] - affects quality significantly
    case guidance   // (no marker) - suggestions, flexibility OK

    var marker: String {
        switch self {
        case .critical: return "[REQUIRED]"
        case .important: return "[IMPORTANT]"
        case .guidance: return ""
        }
    }
}

// MARK: - Prompt Section

/// A discrete section of a prompt with priority and content.
struct PromptSection {
    let title: String
    let priority: PromptPriority
    let content: String

    /// Render section with appropriate formatting
    func render() -> String {
        let header: String
        switch priority {
        case .critical:
            header = "\(priority.marker) \(title)"
        case .important:
            header = "\(priority.marker) \(title)"
        case .guidance:
            header = title
        }
        return "\(header)\n\(content)"
    }
}

// MARK: - Prompt Components

/// Reusable prompt building blocks for workout generation.
/// Centralized to ensure consistency across standard and agentic generation.
enum PromptComponents {

    // MARK: - Core Identity

    /// Base persona for workout generation
    static let trainerPersona = "You are an expert personal trainer creating personalized workouts."

    /// JSON-only output instruction
    static let jsonOnlyInstruction = "Respond with valid JSON only. No markdown, no explanations."

    // MARK: - Profile Summary

    /// Compact user profile summary for prompt
    static func profileSummary(
        fitnessLevel: FitnessLevel,
        goals: Set<FitnessGoal>,
        trainingStyle: TrainingStyle,
        preferredDuration: Int,
        preferredRest: Int
    ) -> String {
        let goalsStr = goals.map { $0.rawValue }.joined(separator: ", ")
        return """
        User: \(fitnessLevel.rawValue) level, goals: \(goalsStr)
        Style: \(trainingStyle.rawValue), Duration: \(preferredDuration)min, Rest: \(preferredRest)s
        """
    }

    // MARK: - Weight Handling

    /// Centralized weight handling instructions
    static func weightRules(unit: WeightUnit, equipmentSummary: String) -> PromptSection {
        let unitAbbr = unit.abbreviation
        let barIncrement = unit == .kilograms ? "2.5" : "5"

        return PromptSection(
            title: "WEIGHT HANDLING",
            priority: .important,
            content: """
            All weights in \(unitAbbr). Weights auto-snap to valid equipment values.
            - Barbells: \(barIncrement) \(unitAbbr) increments
            \(equipmentSummary)
            """
        )
    }

    // MARK: - Technique Section

    /// Build technique requirements section based on options
    static func techniqueSection(
        options: WorkoutGenerationOptions,
        fitnessLevel: FitnessLevel
    ) -> PromptSection? {
        let warmupEnabled = options.warmupSetMode != .disabled
        let dropSetEnabled = options.dropSetMode != .disabled
        let restPauseEnabled = options.restPauseMode != .disabled
        let supersetEnabled = options.supersetMode != .disabled

        // No techniques enabled - return nil
        guard warmupEnabled || dropSetEnabled || restPauseEnabled || supersetEnabled else {
            return nil
        }

        var required: [String] = []
        var allowed: [String] = []

        // Categorize techniques
        if warmupEnabled {
            if options.warmupSetMode == .required {
                required.append("Warmup sets on every exercise (40-60% of working weight, 10-15 reps)")
            } else {
                allowed.append("warmup sets")
            }
        }

        if dropSetEnabled {
            if options.dropSetMode == .required {
                required.append("Drop sets on 1-2 exercises (reduce weight 20% per drop)")
            } else {
                allowed.append("drop sets")
            }
        }

        if restPauseEnabled {
            if options.restPauseMode == .required {
                required.append("Rest-pause sets on 1-2 exercises (10-20s pause, continue reps)")
            } else {
                allowed.append("rest-pause sets")
            }
        }

        if supersetEnabled {
            if options.supersetMode == .required {
                required.append("Supersets grouping 2-3 exercises (minimal rest between)")
            } else {
                allowed.append("supersets")
            }
        }

        // Build content
        var content = ""

        if !required.isEmpty {
            content += "Include these techniques:\n"
            for technique in required {
                content += "- \(technique)\n"
            }
        }

        if !allowed.isEmpty {
            if !content.isEmpty { content += "\n" }
            content += "Optional (use if appropriate): \(allowed.joined(separator: ", "))"
        }

        // Add format hint
        content += "\n\nAdvanced sets use advancedSets array: [{setNumber, type, reps, weight, ...}]"
        content += "\nTypes: standard, warmup, dropSet (add numberOfDrops), restPause (add numberOfPauses)"

        // Add beginner note
        if fitnessLevel == .beginner && required.isEmpty {
            content += "\n\nNote: User is a beginner - use advanced techniques sparingly."
        }

        let priority: PromptPriority = required.isEmpty ? .guidance : .critical

        return PromptSection(
            title: "TECHNIQUE REQUIREMENTS",
            priority: priority,
            content: content
        )
    }

    // MARK: - Exercise Selection

    /// Instructions for exercise selection
    static func exerciseSelectionRules(exerciseCount: String) -> PromptSection {
        return PromptSection(
            title: "EXERCISE SELECTION",
            priority: .important,
            content: """
            - Select \(exerciseCount) exercises for a balanced workout
            - Use only exercises from the available list (exact name match)
            - Prioritize compound movements, add isolation if time permits
            - Respect user preferences (PREFERS/DISLIKES markers)
            """
        )
    }

    // MARK: - Progressive Overload

    /// Pre-computed progression summary from workout history
    static func progressionSummary(
        history: [Workout],
        isDeload: Bool,
        unit: WeightUnit
    ) -> String {
        guard !history.isEmpty else {
            return "No workout history. Use sensible defaults for fitness level."
        }

        var summary = "PROGRESSION CONTEXT:\n"

        // Collect exercise progress data
        var exerciseProgress: [(name: String, lastWeight: Double, lastReps: Int, suggestion: String)] = []

        for workout in history.prefix(5) {
            for exercise in workout.exercises {
                // Skip if we already have this exercise
                if exerciseProgress.contains(where: { $0.name == exercise.exercise.name }) {
                    continue
                }

                let completedSets = exercise.sets.filter { $0.completedAt != nil }
                guard let lastSet = completedSets.last,
                      let weight = lastSet.weight else { continue }

                let reps = lastSet.actualReps ?? lastSet.targetReps
                let suggestion = calculateProgression(
                    weight: weight,
                    reps: reps,
                    isDeload: isDeload,
                    unit: unit
                )

                exerciseProgress.append((
                    name: exercise.exercise.name,
                    lastWeight: weight,
                    lastReps: reps,
                    suggestion: suggestion
                ))
            }
        }

        // Format output (limit to 10 exercises)
        for data in exerciseProgress.prefix(10) {
            let weightStr = unit.format(data.lastWeight)
            summary += "- \(data.name): Last \(weightStr)x\(data.lastReps) -> \(data.suggestion)\n"
        }

        return summary
    }

    /// Calculate progression suggestion for an exercise
    private static func calculateProgression(
        weight: Double,
        reps: Int,
        isDeload: Bool,
        unit: WeightUnit
    ) -> String {
        if isDeload {
            let deloadWeight = unit.format(weight * 0.6)
            return "Use \(deloadWeight) (60% deload)"
        }

        let increment = unit == .kilograms ? 2.5 : 5.0

        // Simple progressive overload logic
        if reps >= 12 {
            let newWeight = unit.format(weight + increment)
            return "Try \(newWeight) for 8-10 reps"
        } else if reps >= 8 {
            let currentWeight = unit.format(weight)
            return "Try \(currentWeight) for \(reps + 1)-\(reps + 2) reps"
        } else {
            let currentWeight = unit.format(weight)
            return "Stay at \(currentWeight) until 8+ reps"
        }
    }

    // MARK: - Superset Instructions

    /// Superset/circuit group instructions
    static func supersetInstructions(mode: TechniqueRequirementMode) -> String? {
        guard mode != .disabled else { return nil }

        let prefix = mode == .required
            ? "[REQUIRED] Include at least one superset or circuit.\n"
            : "Supersets are optional. Use for:\n"

        return """
        \(prefix)- Antagonist pairs (biceps/triceps, chest/back)
        - Time efficiency
        Format: exerciseGroups array with exerciseIndices, restBetweenExercises (0-15s), restAfterGroup
        """
    }

    // MARK: - Output Format

    /// JSON output format specification
    static func outputFormatSection(includeGroups: Bool) -> PromptSection {
        var schema = """
        {
          "name": "Workout Name",
          "isDeload": false,
          "exercises": [{
            "name": "Exercise Name (exact match)",
            "sets": 3,
            "reps": "8-12",
            "weight": 100,
            "restSeconds": 90,
            "equipment": "barbell",
            "primaryMuscles": ["chest"],
            "advancedSets": [...]  // optional
          }]
        """

        if includeGroups {
            schema += """
            ,
              "exerciseGroups": [{
                "type": "superset",
                "exerciseIndices": [0, 1],
                "restBetweenExercises": 0,
                "restAfterGroup": 90
              }]
            """
        }

        schema += "\n}"

        return PromptSection(
            title: "OUTPUT FORMAT",
            priority: .critical,
            content: "Return JSON with this structure:\n\(schema)"
        )
    }
}
