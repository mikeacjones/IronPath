import SwiftUI
import Combine

struct ActiveWorkoutView: View {
    let workout: Workout
    let userProfile: UserProfile?
    let onComplete: (Workout) -> Void
    let onCancel: () -> Void

    @ObservedObject private var activeWorkoutManager = ActiveWorkoutManager.shared
    @ObservedObject private var preferenceManager = ExercisePreferenceManager.shared
    @State private var currentWorkout: Workout
    @State private var showCancelConfirmation = false
    @State private var selectedExercise: WorkoutExercise?
    @State private var workoutStartTime: Date

    // Exercise replacement state
    @State private var exerciseToReplace: WorkoutExercise?
    @State private var showReplacementSheet = false
    @State private var replacementNotes: String = ""
    @State private var isReplacingExercise = false
    @State private var replacementError: String?
    @State private var showReplacementError = false

    // Add exercise state
    @State private var showAddExerciseSheet = false

    // Remove exercise state
    @State private var exerciseToRemove: WorkoutExercise?
    @State private var showRemoveConfirmation = false

    // Workout completion state
    @State private var showCompletionSummary = false
    @State private var completedWorkoutForSummary: Workout?
    @State private var isFinishing = false

    init(workout: Workout, userProfile: UserProfile?, onComplete: @escaping (Workout) -> Void, onCancel: @escaping () -> Void) {
        self.workout = workout
        self.userProfile = userProfile
        self.onComplete = onComplete
        self.onCancel = onCancel
        _currentWorkout = State(initialValue: workout)
        // Use persisted start time from manager, falling back to workout's startedAt or current time
        let startTime = ActiveWorkoutManager.shared.workoutStartTime ?? workout.startedAt ?? Date()
        _workoutStartTime = State(initialValue: startTime)
    }

    var completedExercisesCount: Int {
        currentWorkout.exercises.filter { $0.isCompleted }.count
    }

    var allExercisesCompleted: Bool {
        currentWorkout.exercises.allSatisfy { $0.isCompleted }
    }

    /// Organizes exercises into display items (standalone or grouped)
    /// Groups exercises that belong to the same superset/circuit together
    var exerciseDisplayItems: [ExerciseDisplayItem] {
        var items: [ExerciseDisplayItem] = []
        var processedExerciseIds: Set<UUID> = []

        for exercise in currentWorkout.exercises {
            // Skip if already processed (part of a group we already added)
            guard !processedExerciseIds.contains(exercise.id) else { continue }

            // Check if this exercise belongs to a group
            if let group = currentWorkout.group(for: exercise.id) {
                // Get all exercises in this group, in the order defined by the group
                let groupExercises = group.exerciseIds.compactMap { exerciseId in
                    currentWorkout.exercises.first { $0.id == exerciseId }
                }

                // Mark all exercises in this group as processed
                for groupExercise in groupExercises {
                    processedExerciseIds.insert(groupExercise.id)
                }

                items.append(.group(group, groupExercises))
            } else {
                // Standalone exercise
                processedExerciseIds.insert(exercise.id)
                items.append(.standalone(exercise))
            }
        }

        return items
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Timer header
                WorkoutTimerHeader(
                    startTime: workoutStartTime,
                    completedCount: completedExercisesCount,
                    totalCount: currentWorkout.exercises.count
                )

                // Global rest timer (visible when timer is active)
                // Isolated in its own view to prevent re-renders from affecting exercise list
                RestTimerBarContainer()

                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(exerciseDisplayItems) { item in
                            switch item {
                            case .standalone(let exercise):
                                ActiveExerciseCard(
                                    exercise: exercise,
                                    currentPreference: preferenceManager.getPreference(for: exercise.exercise.name),
                                    onTap: {
                                        selectedExercise = exercise
                                    },
                                    onReplace: {
                                        exerciseToReplace = exercise
                                        replacementNotes = ""
                                        showReplacementSheet = true
                                    },
                                    onRemove: {
                                        exerciseToRemove = exercise
                                        showRemoveConfirmation = true
                                    },
                                    onSetPreference: { preference in
                                        preferenceManager.setPreference(
                                            preference,
                                            for: exercise.exercise.name
                                        )
                                    }
                                )

                            case .group(let group, let exercises):
                                SupersetGroupCard(
                                    group: group,
                                    exercises: exercises,
                                    preferenceManager: preferenceManager,
                                    onExerciseTap: { exercise in
                                        selectedExercise = exercise
                                    },
                                    onExerciseReplace: { exercise in
                                        exerciseToReplace = exercise
                                        replacementNotes = ""
                                        showReplacementSheet = true
                                    },
                                    onExerciseRemove: { exercise in
                                        exerciseToRemove = exercise
                                        showRemoveConfirmation = true
                                    }
                                )
                            }
                        }

                        // Add Exercise button
                        Button {
                            showAddExerciseSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Add Exercise")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundStyle(.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }

                // Finish button
                VStack {
                    Button {
                        finishWorkout()
                    } label: {
                        HStack {
                            Image(systemName: allExercisesCompleted ? "checkmark.circle.fill" : "flag.checkered")
                            Text(allExercisesCompleted ? "Complete Workout" : "Finish Early")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(allExercisesCompleted ? .green : .blue)
                    .disabled(isFinishing)
                }
                .padding()
                .background(Color(.systemBackground))
            }

            // Rest complete banner overlay (isolated to prevent re-renders)
            RestCompleteBannerContainer()
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showCancelConfirmation = true
                }
                .foregroundStyle(.red)
                .confirmationDialog("Cancel Workout?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                    Button("Cancel Workout", role: .destructive) {
                        // Stop any active rest timers and cancel pending notifications
                        RestTimerManager.shared.skipTimer()
                        onCancel()
                    }
                    Button("Keep Going", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to cancel this workout? Your progress will be lost.")
                }
            }
        }
        .alert(
            "Remove Exercise?",
            isPresented: $showRemoveConfirmation,
            presenting: exerciseToRemove
        ) { exercise in
            Button("Remove", role: .destructive) {
                removeExercise(exercise)
            }
            Button("Cancel", role: .cancel) {
                exerciseToRemove = nil
            }
        } message: { exercise in
            Text("Remove \(exercise.exercise.name) from this workout? Any logged sets will be lost.")
        }
        .sheet(item: $selectedExercise) { exercise in
            // Get current version of exercise from workout (in case it was updated)
            let currentExercise = currentWorkout.exercises.first { $0.id == exercise.id } ?? exercise
            let groupInfo = getGroupInfo(for: currentExercise)
            let nextExercise = getNextExerciseInGroup(for: currentExercise)

            ExerciseDetailSheet(
                exercise: currentExercise,
                onUpdate: { updatedExercise in
                    updateExercise(updatedExercise)
                },
                onUpdateWithoutDismiss: { updatedExercise in
                    // Update without dismissing - used for superset navigation
                    updateExercise(updatedExercise, dismissSheet: false)
                },
                groupInfo: groupInfo,
                onNavigateToNextInGroup: groupInfo != nil ? {
                    // Smart navigation: find next exercise with incomplete sets
                    // Handles rest timer when completing a round
                    // Get fresh exercise state from currentWorkout
                    if let freshExercise = currentWorkout.exercises.first(where: { $0.id == currentExercise.id }) {
                        navigateToNextInSuperset(from: freshExercise)
                    }
                } : nil,
                nextExerciseInGroup: nextExercise
            )
        }
        .sheet(isPresented: $showReplacementSheet) {
            ExerciseReplacementSheet(
                exercise: exerciseToReplace,
                currentWorkoutExercises: currentWorkout.exercises.map { $0.exercise.name },
                notes: $replacementNotes,
                isLoading: $isReplacingExercise,
                onReplace: {
                    replaceExercise()
                },
                onQuickReplace: { newExercise in
                    quickReplaceExercise(with: newExercise)
                },
                onCancel: {
                    showReplacementSheet = false
                    exerciseToReplace = nil
                }
            )
        }
        .alert("Replacement Error", isPresented: $showReplacementError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(replacementError ?? "Failed to replace exercise")
        }
        .sheet(isPresented: $showAddExerciseSheet) {
            AddExerciseSheet(
                existingExercises: currentWorkout.exercises.map { $0.exercise.name },
                userProfile: userProfile
            ) { exercise in
                addExerciseFromLibrary(exercise)
            }
        }
        .sheet(isPresented: $showCompletionSummary, onDismiss: {
            // Reset finishing state when sheet is dismissed
            // This handles edge cases where the sheet might be dismissed unexpectedly
            isFinishing = false
        }) {
            if let completedWorkout = completedWorkoutForSummary {
                WorkoutCompletionSummaryView(
                    workout: completedWorkout,
                    userProfile: userProfile,
                    onDismiss: {
                        showCompletionSummary = false
                        onComplete(completedWorkout)
                    }
                )
                .interactiveDismissDisabled()
            } else {
                // Fallback view - should not normally appear
                // If this shows, there's a state synchronization issue
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading summary...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    // If workout data isn't ready, dismiss and retry
                    if completedWorkoutForSummary == nil {
                        showCompletionSummary = false
                        isFinishing = false
                    }
                }
            }
        }
    }

    private func addExercise(_ exercise: WorkoutExercise) {
        var newExercise = exercise
        newExercise.orderIndex = currentWorkout.exercises.count
        currentWorkout.exercises.append(newExercise)
        persistWorkoutState()
    }

    private func addExerciseFromLibrary(_ exercise: Exercise) {
        let sets = (1...3).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                targetReps: 10,
                restPeriod: 90
            )
        }

        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: sets,
            orderIndex: currentWorkout.exercises.count,
            notes: ""
        )

        currentWorkout.exercises.append(workoutExercise)
        persistWorkoutState()
    }

    private func removeExercise(_ exercise: WorkoutExercise) {
        // Don't allow removing the last exercise
        guard currentWorkout.exercises.count > 1 else { return }

        // Remove exercise from any group it belongs to
        if var groups = currentWorkout.exerciseGroups {
            for i in groups.indices {
                if groups[i].exerciseIds.contains(exercise.id) {
                    // Remove the exercise from this group
                    groups[i].exerciseIds.removeAll { $0 == exercise.id }
                }
            }

            // Remove any groups that now have only 1 or 0 exercises
            // (a group with 1 exercise is no longer a valid superset/circuit)
            groups.removeAll { $0.exerciseIds.count <= 1 }

            // Update group types based on new exercise counts
            for i in groups.indices {
                groups[i].groupType = ExerciseGroupType.suggestedType(for: groups[i].exerciseIds.count)
            }

            currentWorkout.exerciseGroups = groups.isEmpty ? nil : groups
        }

        currentWorkout.exercises.removeAll { $0.id == exercise.id }

        // Reindex remaining exercises
        for i in currentWorkout.exercises.indices {
            currentWorkout.exercises[i].orderIndex = i
        }

        exerciseToRemove = nil
        persistWorkoutState()
    }

    /// Persist current workout state to survive app restarts
    private func persistWorkoutState() {
        activeWorkoutManager.updateWorkout(currentWorkout)
    }

    private func updateExercise(_ updatedExercise: WorkoutExercise, dismissSheet: Bool = true) {
        if let index = currentWorkout.exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            currentWorkout.exercises[index] = updatedExercise
        }
        if dismissSheet {
            selectedExercise = nil
        }
        persistWorkoutState()
    }

    private func replaceExercise() {
        guard let exerciseToReplace = exerciseToReplace,
              let profile = userProfile else { return }

        isReplacingExercise = true

        Task {
            do {
                let provider = AIProviderManager.shared.currentProvider
                let replacement = try await provider.replaceExercise(
                    exercise: exerciseToReplace,
                    profile: profile,
                    reason: replacementNotes.isEmpty ? nil : replacementNotes,
                    currentWorkout: currentWorkout
                )

                await MainActor.run {
                    if let index = currentWorkout.exercises.firstIndex(where: { $0.id == exerciseToReplace.id }) {
                        currentWorkout.exercises[index] = replacement
                    }
                    persistWorkoutState()
                    isReplacingExercise = false
                    showReplacementSheet = false
                    self.exerciseToReplace = nil
                }
            } catch {
                await MainActor.run {
                    replacementError = error.localizedDescription
                    showReplacementError = true
                    isReplacingExercise = false
                }
            }
        }
    }

    private func quickReplaceExercise(with newExercise: Exercise) {
        guard let exerciseToReplace = exerciseToReplace else { return }

        // Create a new WorkoutExercise with the same sets structure but new exercise
        let newSets = exerciseToReplace.sets.map { oldSet in
            ExerciseSet(
                setNumber: oldSet.setNumber,
                targetReps: oldSet.targetReps,
                weight: oldSet.weight,
                restPeriod: oldSet.restPeriod
            )
        }

        let replacement = WorkoutExercise(
            exercise: newExercise,
            sets: newSets,
            orderIndex: exerciseToReplace.orderIndex,
            notes: ""
        )

        if let index = currentWorkout.exercises.firstIndex(where: { $0.id == exerciseToReplace.id }) {
            currentWorkout.exercises[index] = replacement
        }
        persistWorkoutState()

        showReplacementSheet = false
        self.exerciseToReplace = nil
    }

    private func finishWorkout() {
        // Prevent double-finishing (e.g., from double-tap)
        guard !isFinishing else { return }
        isFinishing = true

        // Stop any active rest timers and cancel pending notifications
        RestTimerManager.shared.skipTimer()

        var completedWorkout = currentWorkout
        completedWorkout.completedAt = Date()

        // Set the workout for summary BEFORE saving and showing sheet
        // This ensures the sheet content is ready when it appears
        completedWorkoutForSummary = completedWorkout

        // Save to history
        WorkoutDataManager.shared.saveWorkout(completedWorkout)

        // Show the summary sheet
        showCompletionSummary = true
    }

    /// Get grouping information for an exercise
    private func getGroupInfo(for exercise: WorkoutExercise) -> ExerciseGroupInfo? {
        guard let group = currentWorkout.group(for: exercise.id) else { return nil }

        let position = group.position(of: exercise.id) ?? 0
        let isFirst = group.isFirst(exercise.id)
        let isLast = group.isLast(exercise.id)

        return ExerciseGroupInfo(
            group: group,
            position: position,
            isFirst: isFirst,
            isLast: isLast
        )
    }

    /// Get the next exercise in the group that still has incomplete sets (for superset navigation)
    /// Returns nil if all exercises in the superset are fully complete
    private func getNextExerciseInGroup(for exercise: WorkoutExercise) -> WorkoutExercise? {
        return findNextExerciseWithIncompleteSets(for: exercise)?.exercise
    }

    /// Find the next exercise in the group that has incomplete sets
    /// Returns the exercise, its position, and whether navigation wraps around (completing a round)
    private func findNextExerciseWithIncompleteSets(for exercise: WorkoutExercise) -> (exercise: WorkoutExercise, position: Int, wrapsAround: Bool)? {
        guard let group = currentWorkout.group(for: exercise.id),
              let currentPosition = group.position(of: exercise.id) else {
            return nil
        }

        let exerciseCount = group.exerciseCount

        // Try each position in order, starting from the next one and wrapping around
        for offset in 1..<exerciseCount {
            let candidatePosition = (currentPosition + offset) % exerciseCount

            guard candidatePosition < group.exerciseIds.count else { continue }
            let candidateExerciseId = group.exerciseIds[candidatePosition]

            // Get the exercise and check if it has incomplete sets
            if let candidateExercise = currentWorkout.exercises.first(where: { $0.id == candidateExerciseId }) {
                let hasIncompleteSets = candidateExercise.sets.contains { !$0.isCompleted }
                if hasIncompleteSets {
                    // Check if we wrapped around (candidate position is <= current position)
                    let wrapsAround = candidatePosition <= currentPosition
                    return (candidateExercise, candidatePosition, wrapsAround)
                }
            }
        }

        // All other exercises in the superset are complete
        return nil
    }

    /// Navigate to next exercise in superset, handling rest timer if completing a round
    private func navigateToNextInSuperset(from exercise: WorkoutExercise) {
        guard let group = currentWorkout.group(for: exercise.id) else {
            return
        }

        // Find the next exercise with incomplete sets
        guard let nextInfo = findNextExerciseWithIncompleteSets(for: exercise) else {
            // All exercises complete - don't navigate
            return
        }

        // If wrapping around, we've completed a round - start rest timer
        if nextInfo.wrapsAround {
            // Count completed sets in current exercise to determine round number
            let completedSets = exercise.sets.filter { $0.isCompleted }.count
            let completedRound = completedSets

            RestTimerManager.shared.startGroupTimer(
                duration: group.restAfterGroup,
                groupType: group.groupType,
                exerciseNames: [nextInfo.exercise.exercise.name, exercise.exercise.name],
                completedRound: completedRound
            )
        }

        // Navigate to the next exercise (get fresh from currentWorkout)
        selectedExercise = currentWorkout.exercises.first { $0.id == nextInfo.exercise.id }
    }
}

// MARK: - Exercise Group Info

/// Information about an exercise's position within a group
struct ExerciseGroupInfo {
    let group: ExerciseGroup
    let position: Int
    let isFirst: Bool
    let isLast: Bool
}

// MARK: - Exercise Display Item

/// Represents either a standalone exercise or a group of exercises for display
enum ExerciseDisplayItem: Identifiable {
    case standalone(WorkoutExercise)
    case group(ExerciseGroup, [WorkoutExercise])

    var id: String {
        switch self {
        case .standalone(let exercise):
            return "standalone-\(exercise.id.uuidString)"
        case .group(let group, _):
            return "group-\(group.id.uuidString)"
        }
    }
}

// MARK: - Exercise Card With Grouping

/// Wrapper that adds grouping visual indicators to exercise cards
struct ExerciseCardWithGrouping: View {
    let exercise: WorkoutExercise
    let groupInfo: ExerciseGroupInfo?
    let currentPreference: ExerciseSuggestionPreference
    let onTap: () -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void
    let onSetPreference: (ExerciseSuggestionPreference) -> Void

    private var groupColor: Color {
        guard let info = groupInfo else { return .clear }
        switch info.group.groupType.color {
        case "purple": return .purple
        case "indigo": return .indigo
        case "pink": return .pink
        case "teal": return .teal
        default: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Group indicator bar on the left
            if let info = groupInfo {
                VStack(spacing: 0) {
                    // Top connector (hidden for first item)
                    Rectangle()
                        .fill(info.isFirst ? Color.clear : groupColor)
                        .frame(width: 3)

                    // Group type icon (only on first item)
                    if info.isFirst {
                        VStack(spacing: 2) {
                            Image(systemName: info.group.groupType.iconName)
                                .font(.caption2)
                                .foregroundStyle(groupColor)
                            Text(info.group.groupType.displayName)
                                .font(.system(size: 8))
                                .foregroundStyle(groupColor)
                        }
                        .frame(width: 40)
                        .padding(.vertical, 4)
                    }

                    // Bottom connector (hidden for last item)
                    Rectangle()
                        .fill(info.isLast ? Color.clear : groupColor)
                        .frame(width: 3)
                }
                .frame(width: 44)
            }

            // The actual exercise card
            ActiveExerciseCard(
                exercise: exercise,
                currentPreference: currentPreference,
                onTap: onTap,
                onReplace: onReplace,
                onRemove: onRemove,
                onSetPreference: onSetPreference
            )
            .overlay(
                // Subtle border for grouped exercises
                RoundedRectangle(cornerRadius: 12)
                    .stroke(groupInfo != nil ? groupColor.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Superset Group Card

/// Displays a group of exercises (superset/circuit) with a visual container
struct SupersetGroupCard: View {
    let group: ExerciseGroup
    let exercises: [WorkoutExercise]
    @ObservedObject var preferenceManager: ExercisePreferenceManager
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void

    private var groupColor: Color {
        group.groupType.swiftUIColor
    }

    private var completedExercisesInGroup: Int {
        exercises.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            HStack(spacing: 8) {
                Image(systemName: group.groupType.iconName)
                    .font(.subheadline)
                    .foregroundStyle(groupColor)

                Text(group.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(groupColor)

                Spacer()

                // Progress indicator
                Text("\(completedExercisesInGroup)/\(exercises.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(groupColor.opacity(0.1))

            // Exercise cards within the group
            VStack(spacing: 8) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ActiveExerciseCard(
                        exercise: exercise,
                        currentPreference: preferenceManager.getPreference(for: exercise.exercise.name),
                        onTap: {
                            onExerciseTap(exercise)
                        },
                        onReplace: {
                            onExerciseReplace(exercise)
                        },
                        onRemove: {
                            onExerciseRemove(exercise)
                        },
                        onSetPreference: { preference in
                            preferenceManager.setPreference(
                                preference,
                                for: exercise.exercise.name
                            )
                        }
                    )

                    // Arrow between exercises (except after last)
                    if index < exercises.count - 1 {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(groupColor.opacity(0.6))
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(groupColor, lineWidth: 2)
        )
    }
}

// MARK: - Workout Completion Summary View

struct WorkoutCompletionSummaryView: View {
    let workout: Workout
    let userProfile: UserProfile?
    let onDismiss: () -> Void

    @State private var estimatedCalories: Int?
    @State private var isEstimatingCalories = false
    @State private var isExportingToHealth = false
    @State private var exportSuccess = false
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var healthKitAuthorized = false
    @State private var workoutPRs: [WorkoutPR] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Success header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("Workout Complete!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(workout.name)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Stats cards
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            CompletionStatCard(
                                icon: "clock.fill",
                                value: formatDuration(workout.duration ?? 0),
                                label: "Duration",
                                color: .blue
                            )

                            CompletionStatCard(
                                icon: "scalemass.fill",
                                value: formatVolume(workout.totalVolume),
                                label: "Volume",
                                color: .purple
                            )
                        }

                        HStack(spacing: 16) {
                            CompletionStatCard(
                                icon: "figure.strengthtraining.traditional",
                                value: "\(workout.exercises.count)",
                                label: "Exercises",
                                color: .orange
                            )

                            CompletionStatCard(
                                icon: "flame.fill",
                                value: estimatedCalories.map { "\($0)" } ?? "...",
                                label: "Est. Calories",
                                color: .red,
                                isLoading: isEstimatingCalories
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Deload badge if applicable
                    if workout.isDeload {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.heart.fill")
                            Text("Deload workout - using lighter weights for recovery")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Personal Records section
                    if !workoutPRs.isEmpty {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                Text("Personal Records!")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            ForEach(workoutPRs) { pr in
                                PRCard(pr: pr)
                            }
                        }
                    }

                    // Apple Health export section
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.horizontal)

                        if HealthKitManager.shared.isHealthKitAvailable {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                    Text("Apple Health")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(.horizontal)

                                if exportSuccess {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Workout saved to Apple Health")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                } else {
                                    Button {
                                        exportToHealth()
                                    } label: {
                                        HStack {
                                            if isExportingToHealth {
                                                ProgressView()
                                                    .tint(.white)
                                            } else {
                                                Image(systemName: "square.and.arrow.up")
                                            }
                                            Text(isExportingToHealth ? "Exporting..." : "Export to Apple Health")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundStyle(.white)
                                        .cornerRadius(12)
                                    }
                                    .disabled(isExportingToHealth || isEstimatingCalories)
                                    .padding(.horizontal)

                                    Text("Saves workout duration and estimated calories burned")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .alert("Export Failed", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportError ?? "Failed to export workout to Apple Health")
            }
            .task {
                await estimateCalories()
                detectPRs()
            }
        }
    }

    private func detectPRs() {
        workoutPRs = WorkoutDataManager.shared.detectWorkoutPRs(in: workout)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK", volume / 1000)
        }
        return "\(Int(volume))"
    }

    private func estimateCalories() async {
        isEstimatingCalories = true

        let summary = HealthKitManager.shared.createWorkoutSummaryForCalorieEstimation(
            workout: workout,
            userProfile: userProfile
        )

        do {
            let provider = AIProviderManager.shared.currentProvider
            let calories = try await provider.estimateCaloriesBurned(workoutSummary: summary)
            await MainActor.run {
                // Ensure we never show 0 calories
                estimatedCalories = max(calories, 50)
                isEstimatingCalories = false
            }
        } catch {
            // Fallback to a simple estimate based on duration
            let durationMinutes = (workout.duration ?? 0) / 60
            let fallbackCalories = Int(durationMinutes * 5) // ~5 cal/min conservative estimate
            await MainActor.run {
                estimatedCalories = max(fallbackCalories, 50)
                isEstimatingCalories = false
            }
        }
    }

    private func exportToHealth() {
        isExportingToHealth = true

        Task {
            do {
                // Request authorization first
                let authorized = try await HealthKitManager.shared.requestAuthorization()

                guard authorized else {
                    throw HealthKitError.notAuthorized
                }

                // Use estimated calories or fallback
                let calories = Double(estimatedCalories ?? 150)

                try await HealthKitManager.shared.saveWorkout(
                    workout: workout,
                    activeCalories: calories
                )

                await MainActor.run {
                    exportSuccess = true
                    isExportingToHealth = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    showExportError = true
                    isExportingToHealth = false
                }
            }
        }
    }
}

struct CompletionStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            if isLoading {
                ProgressView()
                    .frame(height: 28)
            } else {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - PR Card

struct PRCard: View {
    let pr: WorkoutPR

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pr.type.icon)
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(pr.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(pr.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatValue(pr.newValue, for: pr.type))
                    .font(.headline)
                    .foregroundStyle(.green)

                if let prev = pr.previousValue {
                    Text("was \(formatValue(prev, for: pr.type))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("First time!")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatValue(_ value: Double, for type: WorkoutPR.PRType) -> String {
        switch type {
        case .weight:
            return "\(Int(value)) lbs"
        case .volume:
            if value >= 1000 {
                return String(format: "%.1fK lbs", value / 1000)
            }
            return "\(Int(value)) lbs"
        case .reps:
            return "\(Int(value)) reps"
        }
    }
}

// MARK: - Workout Timer Header

struct WorkoutTimerHeader: View {
    let startTime: Date
    let completedCount: Int
    let totalCount: Int

    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formattedTime)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(completedCount)/\(totalCount)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .onAppear {
            elapsedTime = Date().timeIntervalSince(startTime)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    let exercise: WorkoutExercise
    let currentPreference: ExerciseSuggestionPreference
    let onTap: () -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void
    let onSetPreference: (ExerciseSuggestionPreference) -> Void

    var completedSetsCount: Int {
        exercise.sets.filter { $0.isCompleted }.count
    }

    var setProgress: Double {
        guard exercise.sets.count > 0 else { return 0 }
        return Double(completedSetsCount) / Double(exercise.sets.count)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Completion indicator with progress circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)

                    // Progress arc (only shown when not fully completed)
                    if !exercise.isCompleted && completedSetsCount > 0 {
                        Circle()
                            .trim(from: 0, to: setProgress)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: setProgress)
                    }

                    // Completed state: full green circle
                    if exercise.isCompleted {
                        Circle()
                            .stroke(Color.green, lineWidth: 3)
                            .frame(width: 44, height: 44)
                    }

                    if exercise.isCompleted {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .fontWeight(.bold)
                    } else {
                        Text("\(completedSetsCount)/\(exercise.sets.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(exercise.exercise.name)
                            .font(.headline)
                            .foregroundStyle(exercise.isCompleted ? .secondary : .primary)

                        // Preference indicator
                        if currentPreference != .normal {
                            Image(systemName: currentPreference.iconName)
                                .font(.caption)
                                .foregroundStyle(preferenceColor)
                        }
                    }

                    HStack {
                        Label("\(exercise.sets.count) sets", systemImage: "repeat")
                        Text("•")
                        Label("\(exercise.sets.first?.targetReps ?? 0) reps", systemImage: "number")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Actions menu
                Menu {
                    Button {
                        onReplace()
                    } label: {
                        Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Divider()

                    // Suggestion preference submenu
                    Menu {
                        ForEach(ExerciseSuggestionPreference.allCases, id: \.self) { preference in
                            Button {
                                onSetPreference(preference)
                            } label: {
                                HStack {
                                    Label(preference.displayName, systemImage: preference.iconName)
                                    if preference == currentPreference {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Suggestion Preference", systemImage: "hand.thumbsup")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove from Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(exercise.isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(exercise.isCompleted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var preferenceColor: Color {
        switch currentPreference {
        case .normal: return .gray
        case .preferMore: return .green
        case .preferLess: return .orange
        case .doNotSuggest: return .red
        }
    }
}

// MARK: - Superset Header View

/// Header shown in exercise detail sheet when exercise is part of a superset/circuit
struct SupersetHeaderView: View {
    let groupInfo: ExerciseGroupInfo
    let currentExerciseName: String
    let nextExerciseName: String?

    var body: some View {
        VStack(spacing: 8) {
            // Group type badge
            HStack {
                Image(systemName: groupInfo.group.groupType.iconName)
                Text(groupInfo.group.groupType.displayName)
                    .fontWeight(.semibold)

                Spacer()

                // Position indicator
                Text("Exercise \(groupInfo.position + 1) of \(groupInfo.group.exerciseCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(groupInfo.group.groupType.swiftUIColor)

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<groupInfo.group.exerciseCount, id: \.self) { index in
                    Circle()
                        .fill(index == groupInfo.position ? groupInfo.group.groupType.swiftUIColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Instructions
            if groupInfo.group.restBetweenExercises == 0 {
                Text("No rest between exercises - move directly to next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(groupInfo.group.groupType.swiftUIColor.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Exercise Replacement Sheet

struct ExerciseReplacementSheet: View {
    let exercise: WorkoutExercise?
    let currentWorkoutExercises: [String]
    @Binding var notes: String
    @Binding var isLoading: Bool
    let onReplace: () -> Void
    let onQuickReplace: (Exercise) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss

    /// Get suggested alternative exercises that target the same muscles
    private var suggestedAlternatives: [Exercise] {
        guard let exercise = exercise else { return [] }

        let targetMuscles = exercise.exercise.primaryMuscleGroups
        let currentEquipment = exercise.exercise.equipment

        // Get available equipment from gym profile
        let availableEquipment = GymProfileManager.shared.activeProfile?.availableEquipment ?? Set(Equipment.allCases)
        let availableMachines = GymProfileManager.shared.activeProfile?.availableMachines ?? Set(SpecificMachine.allCases)

        // Find exercises that:
        // 1. Target at least one of the same primary muscle groups
        // 2. Are available with user's equipment
        // 3. Are not the current exercise
        // 4. Are not already in the workout
        let alternatives = ExerciseDatabase.shared.exercises.filter { alt in
            // Must target at least one same muscle group
            let targetsSameMuscle = !targetMuscles.isDisjoint(with: alt.primaryMuscleGroups)

            // Must be available with user's equipment
            let isAvailable: Bool
            if let requiredMachine = alt.specificMachine {
                isAvailable = availableMachines.contains(requiredMachine)
            } else {
                isAvailable = availableEquipment.contains(alt.equipment)
            }

            // Must not be the current exercise
            let isNotCurrent = alt.name != exercise.exercise.name

            // Must not already be in the workout
            let isNotInWorkout = !currentWorkoutExercises.contains(alt.name)

            return targetsSameMuscle && isAvailable && isNotCurrent && isNotInWorkout
        }

        // Sort: prefer different equipment first (variety), then by difficulty match
        let currentDifficulty = exercise.exercise.difficulty
        return alternatives.sorted { a, b in
            // Prioritize different equipment for variety
            let aDiffEquip = a.equipment != currentEquipment
            let bDiffEquip = b.equipment != currentEquipment
            if aDiffEquip != bDiffEquip {
                return aDiffEquip
            }

            // Then sort by difficulty (prefer same difficulty)
            let aDiffMatch = a.difficulty == currentDifficulty
            let bDiffMatch = b.difficulty == currentDifficulty
            if aDiffMatch != bDiffMatch {
                return aDiffMatch
            }

            return a.name < b.name
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let exercise = exercise {
                    Section {
                        HStack {
                            Text("Current Exercise")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(exercise.exercise.name)
                                .fontWeight(.medium)
                        }
                    }

                    // Suggested alternatives section
                    if !suggestedAlternatives.isEmpty {
                        Section {
                            ForEach(suggestedAlternatives.prefix(5)) { alt in
                                Button {
                                    onQuickReplace(alt)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(alt.name)
                                                .foregroundStyle(.primary)
                                            Text(alt.equipment.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .disabled(isLoading)
                            }
                        } header: {
                            Text("Quick Swap")
                        } footer: {
                            Text("Tap to instantly replace with a similar exercise")
                        }
                    }
                }

                Section {
                    TextField("Why do you need a replacement?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("AI Replacement")
                } footer: {
                    Text("Describe your needs and AI will find the best alternative.\nExamples: \"My shoulder hurts\", \"Machine is taken\", \"Want something harder\"")
                }
            }
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onReplace()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Ask AI")
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
}

struct SetRowView: View {
    let set: ExerciseSet
    let setIndex: Int  // 0-based index of this set
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let onWeightChanged: ((Int, Double) -> Void)?  // Callback when weight changes (setIndex, newWeight)
    let onRepsChanged: ((Int, Int) -> Void)?  // Callback when reps change (setIndex, newReps)

    @State private var weight: String
    @State private var reps: String
    @State private var isCompleted: Bool
    @State private var showPlateCalculator: Bool = false
    @ObservedObject private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        setIndex: Int,
        exerciseName: String,
        equipment: Equipment = .dumbbells,
        onUpdate: @escaping (ExerciseSet) -> Void,
        onWeightChanged: ((Int, Double) -> Void)? = nil,
        onRepsChanged: ((Int, Int) -> Void)? = nil
    ) {
        self.set = set
        self.setIndex = setIndex
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.onWeightChanged = onWeightChanged
        self.onRepsChanged = onRepsChanged

        // Get suggested weight from history if available
        let suggestedWeight = WorkoutDataManager.shared.getSuggestedWeight(
            for: exerciseName,
            targetReps: set.targetReps
        )

        _weight = State(initialValue: set.weight.map { String(format: "%.0f", $0) } ?? suggestedWeight.map { String(format: "%.0f", $0) } ?? "")
        _reps = State(initialValue: set.actualReps.map { String($0) } ?? String(set.targetReps))
        _isCompleted = State(initialValue: set.isCompleted)
    }

    /// Check if rest timer is active for THIS specific set
    private var isRestTimerActiveForThisSet: Bool {
        restTimerManager.isActive &&
        restTimerManager.exerciseName == exerciseName &&
        restTimerManager.setNumber == set.setNumber
    }

    private var showPlateCalcButton: Bool {
        switch equipment {
        case .barbell, .squat, .legPress, .smithMachine:
            return true  // Plate-loaded equipment
        case .cables:
            return true  // Cable machine weight selector
        default:
            return false
        }
    }

    /// Whether this equipment uses standard plates (vs cable weight stack)
    private var usesPlates: Bool {
        switch equipment {
        case .barbell, .squat, .legPress, .smithMachine:
            return true
        default:
            return false
        }
    }

    /// Check if current weight is valid for cable machine
    private var isInvalidCableWeight: Bool {
        guard equipment == .cables, let weightValue = Double(weight), weightValue > 0 else {
            return false
        }
        let config = GymSettings.shared.cableConfig(for: exerciseName)
        return !config.isValidWeight(weightValue)
    }

    /// Get pin location for current weight (cable machines only)
    private var currentPinLocation: Int? {
        guard equipment == .cables, let weightValue = Double(weight), weightValue > 0 else {
            return nil
        }
        let config = GymSettings.shared.cableConfig(for: exerciseName)
        return config.pinLocation(for: weightValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Set number
                Text("Set \(set.setNumber)")
                    .font(.headline)
                    .frame(width: 50, alignment: .leading)

                // Weight input
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isInvalidCableWeight ? Color.orange : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: weight) { _, newValue in
                                if let weightValue = Double(newValue) {
                                    onWeightChanged?(setIndex, weightValue)
                                }
                            }
                        Text("lbs")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Plate calculator button for plate-loaded and cable exercises
                        if showPlateCalcButton {
                            Button {
                                showPlateCalculator = true
                            } label: {
                                Image(systemName: usesPlates ? "circle.grid.2x2" : "slider.horizontal.3")
                                    .font(.caption)
                                    .foregroundStyle(isInvalidCableWeight ? .orange : .blue)
                            }
                        }
                    }

                    // Show pin location for valid cable weights
                    if let pin = currentPinLocation {
                        HStack(spacing: 2) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                            Text("Pin \(pin)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.blue)
                    }

                    // Show invalid weight warning for cables
                    if isInvalidCableWeight {
                        Button {
                            showPlateCalculator = true
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text("Invalid weight - tap to fix")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.orange)
                        }
                    }

                    // Show if this is a suggested weight from history
                    if let suggestedWeight = WorkoutDataManager.shared.getSuggestedWeight(
                        for: exerciseName,
                        targetReps: set.targetReps
                    ), !weight.isEmpty, Double(weight) == suggestedWeight {
                        Text("↑ +2.5%")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                // Reps input
                HStack(spacing: 4) {
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .onChange(of: reps) { _, newValue in
                            if let repsValue = Int(newValue) {
                                onRepsChanged?(setIndex, repsValue)
                            }
                        }
                    Text("× \(set.targetReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Complete button
                Button {
                    markComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isCompleted ? .green : .gray)
                }
            }
            .padding()
            .background(isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground))

            // Rest timer appears inline after completing a set (only for this specific set)
            if isRestTimerActiveForThisSet {
                RestTimerView(
                    duration: restTimerManager.totalDuration,
                    remainingTime: restTimerManager.remainingTime,
                    onComplete: {
                        // Handled by RestTimerManager
                    },
                    onSkip: {
                        restTimerManager.skipTimer()
                    }
                )
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRestTimerActiveForThisSet ? Color.blue : (isCompleted ? Color.green : Color.gray.opacity(0.3)), lineWidth: isRestTimerActiveForThisSet ? 2 : 1)
        )
        .sheet(isPresented: $showPlateCalculator) {
            if usesPlates {
                PlateCalculatorView(
                    totalWeight: Double(weight) ?? 0,
                    equipment: equipment,
                    exerciseName: exerciseName
                )
            } else {
                CableWeightCalculatorView(
                    targetWeight: Double(weight) ?? 0,
                    exerciseName: exerciseName,
                    onSelectWeight: { selectedWeight in
                        weight = String(format: "%.0f", selectedWeight)
                        showPlateCalculator = false
                    }
                )
            }
        }
        .onChange(of: set.weight) { _, newWeight in
            // Update local state when external weight changes (propagation from set 1)
            if let newWeight = newWeight {
                weight = String(format: "%.0f", newWeight)
            }
        }
        .onChange(of: set.actualReps) { _, newReps in
            // Update local state when external reps changes (propagation from set 1)
            if let newReps = newReps {
                reps = String(newReps)
            }
        }
    }

    private func markComplete() {
        var updatedSet = set

        if !isCompleted {
            // Mark as complete
            if let weightValue = Double(weight) {
                updatedSet.weight = weightValue
            }
            if let repsValue = Int(reps) {
                updatedSet.actualReps = repsValue
            }
            updatedSet.completedAt = Date()

            // Start global rest timer
            restTimerManager.startTimer(
                duration: set.restPeriod,
                exerciseName: exerciseName,
                setNumber: set.setNumber
            )
        } else {
            // Unmark
            updatedSet.completedAt = nil
            // Stop rest timer if it was for this set
            if isRestTimerActiveForThisSet {
                restTimerManager.stopTimer()
            }
        }

        isCompleted.toggle()
        onUpdate(updatedSet)
    }
}

// MARK: - Plate Calculator View

struct PlateCalculatorView: View {
    let totalWeight: Double
    let equipment: Equipment
    let exerciseName: String

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var showingPlateEditor = false

    /// Whether this equipment has a bar (vs leg press sled)
    private var hasBar: Bool {
        switch equipment {
        case .legPress:
            return false
        default:
            return true
        }
    }

    private var barWeight: Double {
        hasBar ? settings.selectedBarWeight : 0
    }

    private var equipmentLabel: String {
        switch equipment {
        case .legPress:
            return "Leg Press"
        case .smithMachine:
            return "Smith Machine"
        case .squat:
            return "Squat Rack"
        default:
            return "Barbell"
        }
    }

    private var weightPerSide: Double {
        max(0, (totalWeight - barWeight) / 2)
    }

    private var currentPlates: [Double] {
        settings.availablePlates(for: exerciseName)
    }

    private var platesNeeded: [(Double, Int)] {
        var remaining = weightPerSide
        var plates: [(Double, Int)] = []

        for plateSize in currentPlates {
            let count = Int(remaining / plateSize)
            if count > 0 {
                plates.append((plateSize, count))
                remaining -= Double(count) * plateSize
            }
        }

        return plates
    }

    private var isValidWeight: Bool {
        var remaining = weightPerSide
        for plateSize in currentPlates {
            let count = Int(remaining / plateSize)
            remaining -= Double(count) * plateSize
        }
        return remaining < 0.01
    }

    private var hasCustomConfig: Bool {
        settings.hasCustomPlateConfig(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Total weight display
                    VStack(spacing: 8) {
                        Text("Total Weight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(totalWeight)) lbs")
                            .font(.system(size: 48, weight: .bold))

                        Text(equipmentLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if hasCustomConfig {
                            Text("Custom plates for \(exerciseName)")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.top)

                    // Bar weight selector (only for barbell exercises)
                    if hasBar {
                        VStack(spacing: 8) {
                            Text("Bar Weight")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Picker("Bar Weight", selection: $settings.selectedBarWeight) {
                                Text("45 lbs").tag(45.0)
                                Text("35 lbs").tag(35.0)
                                Text("20 lbs").tag(20.0)
                                Text("15 lbs").tag(15.0)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }
                    }

                    Divider()

                    // Weight per side
                    VStack(spacing: 8) {
                        Text("Each Side")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.1f", weightPerSide)) lbs")
                            .font(.title)
                            .fontWeight(.semibold)
                    }

                    // Plate breakdown
                    if weightPerSide == 0 {
                        Text(hasBar ? "Bar only - no plates needed" : "No plates needed")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Plates per side:")
                                .font(.headline)

                            ForEach(platesNeeded, id: \.0) { plate, count in
                                HStack {
                                    PlateVisual(weight: plate)
                                    Spacer()
                                    Text("\(formatWeight(plate)) lbs")
                                        .fontWeight(.medium)
                                    Text("× \(count)")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    if !isValidWeight && weightPerSide > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Cannot achieve exact weight with available plates")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // Available plates section
                    Button {
                        showingPlateEditor = true
                    } label: {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Available Plates")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if hasCustomConfig {
                                            Text("(Custom)")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    Text(currentPlates.map { formatWeight($0) }.joined(separator: ", ") + " lbs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }

                            Text("Tap to customize plates for this exercise")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPlateEditor) {
                AvailablePlatesEditor(exerciseName: exerciseName)
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

/// Editor for customizing available plate sizes (per-exercise)
struct AvailablePlatesEditor: View {
    let exerciseName: String

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var newPlateWeight: String = ""
    @State private var localPlates: [Double] = []

    private var hasCustomConfig: Bool {
        settings.hasCustomPlateConfig(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(.blue)
                        Text(exerciseName)
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("Exercise")
                } footer: {
                    if hasCustomConfig {
                        Text("This exercise has custom plate settings")
                    } else {
                        Text("Using default plate settings")
                    }
                }

                Section {
                    ForEach(localPlates, id: \.self) { plate in
                        HStack {
                            PlateVisual(weight: plate)
                            Text("\(formatWeight(plate)) lbs")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        localPlates.remove(atOffsets: indexSet)
                        saveChanges()
                    }
                } header: {
                    Text("Available Plates")
                } footer: {
                    Text("Swipe left to remove a plate size")
                }

                Section {
                    HStack {
                        TextField("Weight (lbs)", text: $newPlateWeight)
                            .keyboardType(.decimalPad)

                        Button {
                            addPlate()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                        .disabled(newPlateWeight.isEmpty)
                    }
                } header: {
                    Text("Add Plate")
                } footer: {
                    Text("Add custom plate sizes available for this exercise (e.g., 100, 35)")
                }

                Section {
                    if hasCustomConfig {
                        Button("Use Default Plates") {
                            settings.resetPlateConfig(for: exerciseName)
                            localPlates = settings.defaultAvailablePlates
                        }
                        .foregroundStyle(.blue)
                    }

                    Button("Reset to Standard Plates") {
                        localPlates = GymSettings.standardPlates
                        saveChanges()
                    }
                    .foregroundStyle(.orange)
                } footer: {
                    Text("Standard: 45, 35, 25, 10, 5, 2.5 lbs")
                }
            }
            .navigationTitle("Available Plates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                localPlates = settings.availablePlates(for: exerciseName)
            }
        }
    }

    private func addPlate() {
        guard let weight = Double(newPlateWeight), weight > 0 else { return }

        if !localPlates.contains(weight) {
            localPlates.append(weight)
            localPlates.sort(by: >)
            saveChanges()
        }
        newPlateWeight = ""
    }

    private func saveChanges() {
        settings.setAvailablePlates(localPlates, for: exerciseName)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

struct PlateVisual: View {
    let weight: Double

    private var plateColor: Color {
        switch weight {
        case 100: return .purple
        case 45: return .red
        case 35: return .blue
        case 25: return .green
        case 10: return .yellow
        case 5: return .orange
        case 2.5: return .gray
        default:
            // Custom plates get a color based on weight range
            if weight >= 50 { return .purple }
            else if weight >= 30 { return .blue }
            else if weight >= 15 { return .green }
            else if weight >= 7 { return .yellow }
            else { return .orange }
        }
    }

    private var plateHeight: CGFloat {
        // Scale height based on weight
        let minHeight: CGFloat = 14
        let maxHeight: CGFloat = 44
        let heightRange = maxHeight - minHeight

        // Log scale for better visual representation
        let normalizedWeight = min(max(weight, 1), 100)
        let logScale = log10(normalizedWeight) / log10(100)

        return minHeight + (heightRange * logScale)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(plateColor)
            .frame(width: 12, height: plateHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Cable Weight Calculator View

struct CableWeightCalculatorView: View {
    let targetWeight: Double
    let exerciseName: String
    let onSelectWeight: (Double) -> Void
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var showingConfigEditor = false

    private var config: CableMachineConfig {
        settings.cableConfig(for: exerciseName)
    }

    private var availableWeights: [Double] {
        config.availableWeights
    }

    private var nearestWeight: Double {
        config.nearestWeight(to: targetWeight)
    }

    private var weightsNearTarget: [Double] {
        config.weightsNear(targetWeight, count: 7)
    }

    private var hasCustomConfig: Bool {
        settings.cableMachineConfigs[exerciseName] != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current target
                    VStack(spacing: 4) {
                        Text("Target Weight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(targetWeight)) lbs")
                            .font(.system(size: 48, weight: .bold))
                    }
                    .padding(.top)

                    // Cable machine config info
                    Button {
                        showingConfigEditor = true
                    } label: {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(hasCustomConfig ? exerciseName : "Default Cable Machine")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if hasCustomConfig {
                                            Text("Custom")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue)
                                                .foregroundStyle(.white)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(config.stackDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }

                            Text("Tap to configure plate stack for this exercise")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Divider()

                    // Available weights grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Weight")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(weightsNearTarget, id: \.self) { weight in
                                Button {
                                    onSelectWeight(weight)
                                } label: {
                                    CableWeightButton(
                                        weight: weight,
                                        pinNumber: config.pinLocation(for: weight),
                                        isSelected: weight == nearestWeight
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)

                        // Show more weights option
                        if availableWeights.count > 7 {
                            DisclosureGroup("All available weights (\(availableWeights.count))") {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(availableWeights, id: \.self) { weight in
                                        Button {
                                            onSelectWeight(weight)
                                        } label: {
                                            Text("\(formatWeight(weight))")
                                                .font(.caption)
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Cable Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingConfigEditor) {
                CableMachineConfigEditor(
                    config: config,
                    title: exerciseName,
                    onSave: { newConfig in
                        settings.setCableConfig(newConfig, for: exerciseName)
                    }
                )
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

/// Button showing weight with pin location indicator
struct CableWeightButton: View {
    let weight: Double
    let pinNumber: Int?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(formatWeight(weight))")
                .font(.title3)
                .fontWeight(.semibold)
            Text("lbs")
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)

            // Pin location indicator
            if let pin = pinNumber {
                HStack(spacing: 2) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                    Text("Pin \(pin)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .blue)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isSelected ? Color.blue : Color(.systemGray6))
        .foregroundStyle(isSelected ? .white : .primary)
        .cornerRadius(12)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

struct WeightOptionRow: View {
    let weight: Double
    let label: String
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(formatWeight(weight)) lbs")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.gray)
                    .font(.title2)
            }
        }
        .padding()
        .background(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Rest Time Editor Sheet

struct RestTimeEditorSheet: View {
    @Binding var isPresented: Bool
    let currentDuration: TimeInterval
    let onSetRestTime: (TimeInterval) -> Void

    @State private var minutes: Int
    @State private var seconds: Int

    init(isPresented: Binding<Bool>, currentDuration: TimeInterval, onSetRestTime: @escaping (TimeInterval) -> Void) {
        _isPresented = isPresented
        self.currentDuration = currentDuration
        self.onSetRestTime = onSetRestTime
        _minutes = State(initialValue: Int(currentDuration) / 60)
        _seconds = State(initialValue: Int(currentDuration) % 60)
    }

    private var totalSeconds: TimeInterval {
        TimeInterval(minutes * 60 + seconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Set Rest Time")
                    .font(.headline)

                HStack(spacing: 8) {
                    // Minutes picker
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0...10, id: \.self) { min in
                            Text("\(min)").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text(":")
                        .font(.title)
                        .fontWeight(.bold)

                    // Seconds picker
                    Picker("Seconds", selection: $seconds) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { sec in
                            Text(String(format: "%02d", sec)).tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                }
                .frame(height: 150)

                // Quick presets
                Text("Quick Presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach([60, 90, 120, 180], id: \.self) { preset in
                        Button {
                            minutes = preset / 60
                            seconds = preset % 60
                        } label: {
                            Text(formatDuration(TimeInterval(preset)))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(totalSeconds == TimeInterval(preset) ? Color.blue : Color(.secondarySystemBackground))
                                .foregroundStyle(totalSeconds == TimeInterval(preset) ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        onSetRestTime(totalSeconds)
                        isPresented = false
                    }
                    .disabled(totalSeconds < 5)
                }
            }
        }
        .presentationDetents([.height(350)])
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 && secs > 0 {
            return "\(mins)m \(secs)s"
        } else if mins > 0 {
            return "\(mins) min"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Rest Timer View

struct RestTimerView: View {
    let duration: TimeInterval
    let remainingTime: TimeInterval
    let onComplete: () -> Void
    let onSkip: () -> Void
    var onRestTimeChanged: ((TimeInterval) -> Void)?

    @ObservedObject private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    init(duration: TimeInterval, remainingTime: TimeInterval, onComplete: @escaping () -> Void, onSkip: @escaping () -> Void, onRestTimeChanged: ((TimeInterval) -> Void)? = nil) {
        self.duration = duration
        self.remainingTime = remainingTime
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.onRestTimeChanged = onRestTimeChanged
    }

    var progress: Double {
        guard timerManager.totalDuration > 0 else { return 0 }
        return 1 - (timerManager.remainingTime / timerManager.totalDuration)
    }

    var formattedTime: String {
        let time = timerManager.remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Timer circle - tappable to edit
            Button {
                showingRestTimeEditor = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)

                    Text(formattedTime)
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Rest Time")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .onTapGesture {
                    showingRestTimeEditor = true
                }

                Text(timerManager.remainingTime > 0 ? "Tap time to edit" : "Ready for next set!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Control buttons
            HStack(spacing: 12) {
                Button {
                    let newDuration = timerManager.totalDuration + 30
                    timerManager.addTime(30)
                    onRestTimeChanged?(newDuration)
                } label: {
                    Text("+30s")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .sheet(isPresented: $showingRestTimeEditor) {
            RestTimeEditorSheet(
                isPresented: $showingRestTimeEditor,
                currentDuration: timerManager.totalDuration
            ) { newDuration in
                timerManager.setRestTime(newDuration)
                onRestTimeChanged?(newDuration)
            }
        }
    }
}

// MARK: - Group Rest Timer View

/// Rest timer displayed in exercise detail sheet for superset/circuit rest periods
struct GroupRestTimerView: View {
    @ObservedObject private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    var body: some View {
        HStack(spacing: 16) {
            // Timer circle with group type color - tappable
            Button {
                showingRestTimeEditor = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: timerManager.progress)
                        .stroke(groupColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: timerManager.progress)

                    Text(timerManager.formattedTime)
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if let groupType = timerManager.groupType {
                        Image(systemName: groupType.iconName)
                            .foregroundStyle(groupColor)
                    }
                    Text("\(timerManager.groupType?.displayName ?? "Group") Rest")
                        .font(.headline)
                        .foregroundStyle(groupColor)
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundStyle(groupColor.opacity(0.7))
                }
                .onTapGesture {
                    showingRestTimeEditor = true
                }

                Text("Round \(timerManager.setNumber) complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let nextExercise = timerManager.nextExerciseName {
                    Text("Next: \(nextExercise)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Control buttons
            VStack(spacing: 8) {
                Button {
                    timerManager.addTime(30)
                } label: {
                    Text("+30s")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    timerManager.skipTimer()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(groupColor)
                .controlSize(.small)
            }
        }
        .padding()
        .background(groupColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(groupColor.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showingRestTimeEditor) {
            RestTimeEditorSheet(
                isPresented: $showingRestTimeEditor,
                currentDuration: timerManager.totalDuration
            ) { newDuration in
                timerManager.setRestTime(newDuration)
            }
        }
    }

    private var groupColor: Color {
        timerManager.groupType?.swiftUIColor ?? .blue
    }
}

// MARK: - Rest Timer Container Views

/// Container that isolates rest timer observation from parent view
/// This prevents timer updates from re-rendering the exercise list and closing menus
struct RestTimerBarContainer: View {
    @ObservedObject private var timerManager = RestTimerManager.shared

    var body: some View {
        if timerManager.isActive {
            GlobalRestTimerBar()
        }
    }
}

/// Container that isolates rest completion banner observation from parent view
struct RestCompleteBannerContainer: View {
    @ObservedObject private var timerManager = RestTimerManager.shared

    var body: some View {
        if timerManager.showCompletionBanner {
            RestCompleteBanner()
        }
    }
}

// MARK: - Global Rest Timer Bar

/// Compact rest timer bar shown at the top of the workout overview
struct GlobalRestTimerBar: View {
    @ObservedObject private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    var body: some View {
        HStack(spacing: 12) {
            // Animated timer icon
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(.blue)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)

            // Timer info
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest - \(timerManager.exerciseName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("Set \(timerManager.setNumber) complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Time remaining - tappable
            Button {
                showingRestTimeEditor = true
            } label: {
                HStack(spacing: 4) {
                    Text(timerManager.formattedTime)
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
            .buttonStyle(.plain)

            // Control buttons
            HStack(spacing: 8) {
                Button {
                    timerManager.addTime(30)
                } label: {
                    Text("+30s")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    timerManager.skipTimer()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: geometry.size.width * timerManager.progress, alignment: .leading)
            }
            .allowsHitTesting(false),
            alignment: .leading
        )
        .sheet(isPresented: $showingRestTimeEditor) {
            RestTimeEditorSheet(
                isPresented: $showingRestTimeEditor,
                currentDuration: timerManager.totalDuration
            ) { newDuration in
                timerManager.setRestTime(newDuration)
            }
        }
    }
}

// MARK: - Rest Complete Banner

/// In-app notification banner when rest timer completes
struct RestCompleteBanner: View {
    @ObservedObject private var timerManager = RestTimerManager.shared

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Complete!")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Time for your next set of \(timerManager.exerciseName)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                Button {
                    timerManager.showCompletionBanner = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            )
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: timerManager.showCompletionBanner)
    }
}

// MARK: - Export Data Helper
