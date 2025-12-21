import Foundation

/// Maintains state across multiple LLM tool calls during agentic workout generation
@Observable
@MainActor
final class AgentWorkoutBuilder {

    // MARK: - Workout State

    /// The name of the workout being built
    private(set) var workoutName: String = "New Workout"

    /// Whether this is a deload workout
    private(set) var isDeload: Bool = false

    /// Exercises added to the workout
    private(set) var exercises: [WorkoutExercise] = []

    /// Exercise groups (supersets, circuits)
    private(set) var exerciseGroups: [ExerciseGroup] = []

    /// Generation summary from LLM
    private(set) var summary: String?

    // MARK: - Generation Context

    /// Target workout type (e.g., "Push Day", "Upper Body")
    let workoutType: String?

    /// Target muscle groups for the workout
    let targetMuscleGroups: Set<MuscleGroup>?

    /// User-provided notes for the workout
    let userNotes: String?

    /// Advanced technique options for this workout
    let techniqueOptions: WorkoutGenerationOptions

    /// User profile for context
    let profile: UserProfile

    // MARK: - Conversation State

    /// Full conversation history for multi-turn
    private(set) var conversationMessages: [[String: Any]] = []

    // MARK: - Progress Tracking

    /// Current agent state
    private(set) var state: AgentState = .idle

    /// Whether the workout has been finalized
    private(set) var isFinalized: Bool = false

    /// Current iteration count
    private(set) var iterationCount: Int = 0

    /// Maximum allowed iterations (expect 2 rounds: gather context + build workout)
    let maxIterations: Int = 5

    /// Whether to enable refinement pass after workout is built
    let enableRefinement: Bool

    /// Last tool that was called
    private(set) var lastToolCall: String?

    // MARK: - Tool Executor

    /// Executor for handling tool calls
    @ObservationIgnored
    private lazy var toolExecutor = AgentToolExecutor(builder: self)

    // MARK: - Initialization

    init(
        workoutType: String?,
        targetMuscleGroups: Set<MuscleGroup>?,
        userNotes: String?,
        techniqueOptions: WorkoutGenerationOptions,
        profile: UserProfile,
        enableRefinement: Bool = false
    ) {
        self.workoutType = workoutType
        self.targetMuscleGroups = targetMuscleGroups
        self.userNotes = userNotes
        self.techniqueOptions = techniqueOptions
        self.profile = profile
        self.enableRefinement = enableRefinement
    }

    // MARK: - State Management

    /// Update agent state
    func setState(_ newState: AgentState) {
        self.state = newState
    }

    /// Increment iteration count
    func incrementIteration() {
        iterationCount += 1
    }

    /// Get current progress info
    var progress: AgentProgress {
        AgentProgress(
            state: state,
            iteration: iterationCount,
            maxIterations: maxIterations,
            exerciseCount: exercises.count,
            lastToolCall: lastToolCall,
            message: state.displayName
        )
    }

    // MARK: - Conversation Management

    /// Add system message to conversation
    func addSystemMessage(_ content: String) {
        conversationMessages.append([
            "role": "system",
            "content": content
        ])
    }

    /// Add user message to conversation
    func addUserMessage(_ content: String) {
        conversationMessages.append([
            "role": "user",
            "content": content
        ])
    }

    /// Add assistant message to conversation (Anthropic format)
    func addAssistantMessage(from response: [String: Any]) {
        // Extract content from response for conversation history
        if let content = response["content"] {
            conversationMessages.append([
                "role": "assistant",
                "content": content
            ])
        }
    }

    /// Add tool results to conversation (Anthropic format)
    func addToolResultsMessage(_ results: [ToolResult]) {
        let toolResultContent = results.map { result -> [String: Any] in
            [
                "type": "tool_result",
                "tool_use_id": result.toolCallId,
                "content": result.contentAsJSON()
            ]
        }

        conversationMessages.append([
            "role": "user",
            "content": toolResultContent
        ])

        // Compact history if it's getting too long (keep system, first user, and recent messages)
        compactHistoryIfNeeded()
    }

    /// Compact conversation history to reduce token usage
    private func compactHistoryIfNeeded() {
        // Keep conversation under a reasonable size
        // System message + initial user message + last 6 exchanges (12 messages)
        let maxMessages = 14

        guard conversationMessages.count > maxMessages else { return }

        // Find system message index
        let systemIndex = conversationMessages.firstIndex { ($0["role"] as? String) == "system" }

        // Find first user message (the initial prompt)
        let firstUserIndex = conversationMessages.firstIndex { ($0["role"] as? String) == "user" }

        var newMessages: [[String: Any]] = []

        // Keep system message
        if let sysIdx = systemIndex {
            newMessages.append(conversationMessages[sysIdx])
        }

        // Keep first user message
        if let userIdx = firstUserIndex, userIdx != systemIndex {
            newMessages.append(conversationMessages[userIdx])
        }

        // Keep the most recent messages (last 10)
        let recentStart = max(newMessages.count, conversationMessages.count - 10)
        for i in recentStart..<conversationMessages.count {
            // Avoid duplicating messages we already added
            let msg = conversationMessages[i]
            if !newMessages.contains(where: { NSDictionary(dictionary: $0).isEqual(to: msg) }) {
                newMessages.append(msg)
            }
        }

        conversationMessages = newMessages
    }

    // MARK: - Tool Execution

    /// Execute a list of tool calls and return results
    func executeTools(_ toolCalls: [ToolCall]) async throws -> [ToolResult] {
        var results: [ToolResult] = []

        for call in toolCalls {
            lastToolCall = call.name
            let result = try await toolExecutor.execute(call)
            results.append(result)

            // Check if finalize was called
            if call.name == "finalize_workout" && !result.isError {
                isFinalized = true
            }
        }

        return results
    }

    // MARK: - Workout Modification (Called by Tool Executor)

    /// Set the workout name
    func setWorkoutName(_ name: String, isDeload: Bool = false) {
        self.workoutName = name
        self.isDeload = isDeload
    }

    /// Add an exercise to the workout
    func addExercise(_ workoutExercise: WorkoutExercise) -> Int {
        let index = exercises.count
        var exercise = workoutExercise
        exercise.orderIndex = index
        exercises.append(exercise)
        return index
    }

    /// Get exercise at index
    func getExercise(at index: Int) -> WorkoutExercise? {
        guard index >= 0 && index < exercises.count else { return nil }
        return exercises[index]
    }

    /// Update exercise at index
    func updateExercise(at index: Int, _ exercise: WorkoutExercise) {
        guard index >= 0 && index < exercises.count else { return }
        exercises[index] = exercise
    }

    /// Add a warmup set to an exercise
    func addWarmupSet(exerciseIndex: Int, reps: Int, weight: Double) throws {
        guard exerciseIndex >= 0 && exerciseIndex < exercises.count else {
            throw AgentError.invalidExerciseIndex(exerciseIndex)
        }

        var exercise = exercises[exerciseIndex]
        let warmupSet = ExerciseSet.createWarmupSet(
            setNumber: 0, // Will be renumbered
            targetReps: reps,
            weight: weight,
            restPeriod: 60
        )

        // Insert warmup at beginning and renumber all sets
        var allSets = [warmupSet] + exercise.sets
        for i in 0..<allSets.count {
            allSets[i].setNumber = i + 1
        }
        exercise.sets = allSets

        exercises[exerciseIndex] = exercise
    }

    /// Convert last set of exercise to drop set
    func addDropSet(exerciseIndex: Int, startingWeight: Double, numDrops: Int, dropPercentage: Double = 0.2) throws {
        guard exerciseIndex >= 0 && exerciseIndex < exercises.count else {
            throw AgentError.invalidExerciseIndex(exerciseIndex)
        }

        var exercise = exercises[exerciseIndex]
        guard !exercise.sets.isEmpty else { return }

        let lastIndex = exercise.sets.count - 1
        let lastSet = exercise.sets[lastIndex]

        // Create equipment-aware drop set
        let dropSet = ExerciseSet.createDropSet(
            setNumber: lastSet.setNumber,
            targetReps: lastSet.targetReps,
            weight: startingWeight,
            restPeriod: lastSet.restPeriod,
            numberOfDrops: numDrops,
            dropPercentage: dropPercentage,
            equipment: exercise.exercise.equipment,
            exerciseName: exercise.exercise.name
        )

        exercise.sets[lastIndex] = dropSet
        exercises[exerciseIndex] = exercise
    }

    /// Convert last set of exercise to rest-pause set
    func addRestPauseSet(exerciseIndex: Int, weight: Double, numPauses: Int, pauseDuration: Int) throws {
        guard exerciseIndex >= 0 && exerciseIndex < exercises.count else {
            throw AgentError.invalidExerciseIndex(exerciseIndex)
        }

        var exercise = exercises[exerciseIndex]
        guard !exercise.sets.isEmpty else { return }

        let lastIndex = exercise.sets.count - 1
        let lastSet = exercise.sets[lastIndex]

        let restPauseSet = ExerciseSet.createRestPauseSet(
            setNumber: lastSet.setNumber,
            targetReps: lastSet.targetReps,
            weight: weight,
            restPeriod: lastSet.restPeriod,
            numberOfPauses: numPauses,
            pauseDuration: TimeInterval(pauseDuration)
        )

        exercise.sets[lastIndex] = restPauseSet
        exercises[exerciseIndex] = exercise
    }

    /// Create a superset from exercise indices
    func createSuperset(indices: [Int], restBetween: Int, restAfter: Int, name: String? = nil) throws {
        // Validate all indices
        for index in indices {
            guard index >= 0 && index < exercises.count else {
                throw AgentError.invalidExerciseIndex(index)
            }
        }

        guard indices.count >= 2 else {
            throw AgentError.invalidToolInput(tool: "create_superset", reason: "Need at least 2 exercises")
        }

        let exerciseIds = indices.map { exercises[$0].id }

        let group = ExerciseGroup(
            groupType: ExerciseGroupType.suggestedType(for: indices.count),
            name: name,
            exerciseIds: exerciseIds,
            restBetweenExercises: TimeInterval(restBetween),
            restAfterGroup: TimeInterval(restAfter),
            rounds: 1
        )

        exerciseGroups.append(group)
    }

    /// Set the generation summary
    func setSummary(_ summary: String) {
        self.summary = summary
    }

    // MARK: - Refinement Support

    /// Build a summary of the current workout for refinement
    func buildWorkoutSummary() -> String {
        guard !exercises.isEmpty else {
            return "No exercises added yet."
        }

        var summary = "Workout: \(workoutName)\n"
        if isDeload {
            summary += "Type: Deload\n"
        }
        summary += "Exercises: \(exercises.count)\n\n"

        for (index, exercise) in exercises.enumerated() {
            summary += "\(index + 1). \(exercise.exercise.name)\n"
            summary += "   Sets: \(exercise.sets.count)"

            if let firstSet = exercise.sets.first {
                if let weight = firstSet.weight, weight > 0 {
                    summary += ", Weight: \(Int(weight)) lbs"
                }
                summary += ", Reps: \(firstSet.targetReps)"
                summary += ", Rest: \(Int(firstSet.restPeriod))s"
            }

            // Identify special set types
            let hasWarmup = exercise.sets.contains(where: { $0.setType == .warmup })
            let hasDropSet = exercise.sets.contains(where: { $0.setType == .dropSet })
            let hasRestPause = exercise.sets.contains(where: { $0.setType == .restPause })

            var techniques: [String] = []
            if hasWarmup { techniques.append("warmup") }
            if hasDropSet { techniques.append("drop set") }
            if hasRestPause { techniques.append("rest-pause") }

            if !techniques.isEmpty {
                summary += " [\(techniques.joined(separator: ", "))]"
            }

            summary += "\n"
        }

        if !exerciseGroups.isEmpty {
            summary += "\nSupersets/Groups: \(exerciseGroups.count)\n"
        }

        return summary
    }

    /// Build user constraints string for refinement
    func buildUserConstraints() -> String {
        var constraints = ""

        if let workoutType = workoutType {
            constraints += "Workout Type: \(workoutType)\n"
        }

        if let targetMuscles = targetMuscleGroups, !targetMuscles.isEmpty {
            constraints += "Target Muscles: \(targetMuscles.map { $0.rawValue }.joined(separator: ", "))\n"
        }

        if let notes = userNotes, !notes.isEmpty {
            constraints += "User Notes: \(notes)\n"
        }

        constraints += "Fitness Level: \(profile.fitnessLevel.rawValue)\n"

        if let primaryGoal = profile.goals.first {
            constraints += "Goal: \(primaryGoal.rawValue)\n"
        }

        // Technique requirements
        var requiredTechniques: [String] = []
        if techniqueOptions.warmupSetMode == .required {
            requiredTechniques.append("warmup sets")
        }
        if techniqueOptions.dropSetMode == .required {
            requiredTechniques.append("drop sets")
        }
        if techniqueOptions.restPauseMode == .required {
            requiredTechniques.append("rest-pause sets")
        }
        if techniqueOptions.supersetMode == .required {
            requiredTechniques.append("supersets")
        }

        if !requiredTechniques.isEmpty {
            constraints += "Required Techniques: \(requiredTechniques.joined(separator: ", "))\n"
        }

        return constraints
    }

    // MARK: - Build Final Workout

    /// Build the final Workout object from collected state
    func buildWorkout() throws -> Workout {
        guard !exercises.isEmpty else {
            throw AgentError.noExercisesAdded
        }

        // Apply final weight validation
        var validatedExercises = exercises
        for i in 0..<validatedExercises.count {
            let equipment = validatedExercises[i].exercise.equipment
            let exerciseName = validatedExercises[i].exercise.name

            for j in 0..<validatedExercises[i].sets.count {
                var set = validatedExercises[i].sets[j]

                // Snap weight to valid equipment
                if let weight = set.weight {
                    set.weight = snapWeight(weight, for: equipment, exerciseName: exerciseName)
                }

                // Snap drop set weights
                if var dropConfig = set.dropSetConfig {
                    for k in 0..<dropConfig.drops.count {
                        if let dropWeight = dropConfig.drops[k].targetWeight {
                            dropConfig.drops[k].targetWeight = snapWeight(dropWeight, for: equipment, exerciseName: exerciseName)
                        }
                    }
                    set.dropSetConfig = dropConfig
                }

                validatedExercises[i].sets[j] = set
            }
        }

        return Workout(
            name: workoutName,
            exercises: validatedExercises,
            exerciseGroups: exerciseGroups.isEmpty ? nil : exerciseGroups,
            claudeGenerationPrompt: summary ?? "",
            isDeload: isDeload,
            weightUnit: GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds
        )
    }

    // MARK: - Weight Snapping

    private static let standardKettlebellWeights: [Double] = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80, 90, 100]

    private func snapWeight(_ weight: Double, for equipment: Equipment, exerciseName: String) -> Double {
        let gymSettings = GymSettings.shared

        switch equipment {
        case .dumbbells:
            return gymSettings.roundToValidWeight(weight, for: .dumbbells)
        case .cables:
            return gymSettings.roundToValidWeight(weight, for: .cables, exerciseName: exerciseName)
        case .barbell, .trapBar, .squat, .smithMachine:
            return (weight / 5.0).rounded() * 5.0
        case .kettlebells:
            return Self.standardKettlebellWeights.min(by: { abs($0 - weight) < abs($1 - weight) }) ?? weight
        case .legPress:
            return (weight / 10.0).rounded() * 10.0
        default:
            return weight
        }
    }
}
