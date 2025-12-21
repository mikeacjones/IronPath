import Foundation

// MARK: - Workout Prompt Builder

/// Modular prompt builder that constructs workout generation prompts using PromptComponents.
/// Replaces inline prompt building in AIProviderHelpers with a reusable, maintainable structure.
@MainActor
struct WorkoutPromptBuilder {
    // MARK: - Properties

    let profile: UserProfile
    let techniqueOptions: WorkoutGenerationOptions
    let workoutType: String?
    let targetMuscles: Set<MuscleGroup>?
    let isDeload: Bool
    let userNotes: String?

    // MARK: - Computed Properties

    /// User's preferred weight unit with fallback to pounds
    private var weightUnit: WeightUnit {
        GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds
    }

    // MARK: - Initialization

    init(
        profile: UserProfile,
        techniqueOptions: WorkoutGenerationOptions,
        workoutType: String? = nil,
        targetMuscles: Set<MuscleGroup>? = nil,
        isDeload: Bool = false,
        userNotes: String? = nil
    ) {
        self.profile = profile
        self.techniqueOptions = techniqueOptions
        self.workoutType = workoutType
        self.targetMuscles = targetMuscles
        self.isDeload = isDeload
        self.userNotes = userNotes
    }

    // MARK: - System Prompt

    /// Build system prompt for workout generation
    /// Target: < 4000 characters for optimal token efficiency
    func buildSystemPrompt() -> String {
        var sections: [String] = []

        // 1. Trainer persona
        sections.append(PromptComponents.trainerPersona)
        sections.append(PromptComponents.jsonOnlyInstruction)

        // 2. Compact profile summary
        let profileSummary = PromptComponents.profileSummary(
            fitnessLevel: profile.fitnessLevel,
            goals: profile.goals,
            trainingStyle: profile.workoutPreferences.trainingStyle,
            preferredDuration: profile.workoutPreferences.preferredWorkoutDuration,
            preferredRest: profile.workoutPreferences.preferredRestTime
        )
        sections.append("\nUSER PROFILE:\n\(profileSummary)")

        // 3. Equipment constraints
        let gymSummary = GymSettings.shared.equipmentSummaryForLLM()
        sections.append("\nGYM EQUIPMENT:\n\(gymSummary)")

        // 4. Technique section (conditional)
        if let techniqueSection = PromptComponents.techniqueSection(
            options: techniqueOptions,
            fitnessLevel: profile.fitnessLevel
        ) {
            sections.append("\n\(techniqueSection.render())")
        }

        // 5. Exercise selection rules
        let exerciseCount = profile.workoutPreferences.preferredWorkoutDuration > 45 ? "5-7" : "4-5"
        let exerciseSelectionSection = PromptComponents.exerciseSelectionRules(exerciseCount: exerciseCount)
        sections.append("\n\(exerciseSelectionSection.render())")

        // 6. Weight handling
        let weightSection = PromptComponents.weightRules(unit: weightUnit, equipmentSummary: gymSummary)
        sections.append("\n\(weightSection.render())")

        // 7. JSON output instruction
        sections.append("\nReturn workout as valid JSON - no markdown blocks, no explanations.")

        return sections.joined(separator: "\n")
    }

    // MARK: - User Prompt

    /// Build user prompt for workout generation
    /// Includes workout context, history-based progression, and output format
    func buildUserPrompt(history: [Workout], availableExercises: String) -> String {
        var sections: [String] = []

        // 1. Date and workout type
        let todayStr = Date().formatted(date: .complete, time: .omitted)
        sections.append("Today's Date: \(todayStr)")
        sections.append("\nPlease create a workout for me.\n")

        // 2. Deload context
        if isDeload {
            sections.append("⚠️ THIS IS A DELOAD WORKOUT - Use lighter weights (50-70% of normal) for recovery.\n")
        }

        // 3. Workout type
        if let workoutType = workoutType {
            sections.append("Workout Type: \(workoutType)\n")
        }

        // 4. User notes
        if let notes = userNotes, !notes.isEmpty {
            sections.append("My Notes: \(notes)\n")
        }

        // 5. Pre-computed progression summary
        let progressionSummary = PromptComponents.progressionSummary(
            history: history,
            isDeload: isDeload,
            unit: weightUnit
        )
        sections.append(progressionSummary)

        // 6. Exercise preferences
        if let preferencePrompt = ExercisePreferenceManager.shared.generatePreferencePrompt() {
            sections.append("\n\(preferencePrompt)")
        }

        // 7. Available exercises
        sections.append("\n\(availableExercises)")

        // 8. Output format
        let includeGroups = techniqueOptions.supersetMode != .disabled
        let outputFormatSection = PromptComponents.outputFormatSection(includeGroups: includeGroups)
        sections.append("\n\(outputFormatSection.render())")

        // 9. Superset instructions (conditional)
        if let supersetInstructions = PromptComponents.supersetInstructions(mode: techniqueOptions.supersetMode) {
            sections.append("\n\(supersetInstructions)")
        }

        return sections.joined(separator: "\n")
    }

    // MARK: - Complete Prompt Pair

    /// Build both system and user prompts for workout generation
    func buildPrompts(history: [Workout], availableExercises: String) -> (system: String, user: String) {
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(history: history, availableExercises: availableExercises)
        return (systemPrompt, userPrompt)
    }
}
