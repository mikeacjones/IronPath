import SwiftUI

// MARK: - Exercise Detail Sheet

/// Shared view for editing exercise sets - used by both active workouts and historical workout entry
struct ExerciseDetailSheet: View {
    let exercise: WorkoutExercise
    let onUpdate: (WorkoutExercise) -> Void
    let onUpdateWithoutDismiss: ((WorkoutExercise) -> Void)?
    let groupInfo: ExerciseGroupInfo?
    let onNavigateToNextInGroup: (() -> Void)?
    let nextExerciseInGroup: WorkoutExercise?

    /// When true, rest timers and live workout features are enabled
    let isLiveWorkout: Bool

    /// When true, this is editing a pending (not started) workout - edits update target values
    let isPendingWorkout: Bool

    /// Override for showing YouTube videos (nil = use app settings)
    let showVideosOverride: Bool?

    /// Override for showing form tips (nil = use app settings)
    let showFormTipsOverride: Bool?

    @Environment(\.dismiss) var dismiss
    @State private var updatedExercise: WorkoutExercise
    @State private var showAddSetTypePicker = false
    @State private var exerciseNotes: String
    @ObservedObject private var restTimerManager = RestTimerManager.shared
    @ObservedObject private var appSettings = AppSettings.shared

    /// Check if this exercise is part of a superset/circuit
    private var isInSuperset: Bool {
        groupInfo != nil
    }

    /// Whether to show YouTube videos - uses override if set, otherwise app settings
    private var shouldShowVideos: Bool {
        showVideosOverride ?? appSettings.showYouTubeVideos
    }

    /// Whether to show form tips - uses override if set, otherwise app settings
    private var shouldShowFormTips: Bool {
        showFormTipsOverride ?? appSettings.showFormTips
    }

    init(
        exercise: WorkoutExercise,
        onUpdate: @escaping (WorkoutExercise) -> Void,
        onUpdateWithoutDismiss: ((WorkoutExercise) -> Void)? = nil,
        groupInfo: ExerciseGroupInfo? = nil,
        onNavigateToNextInGroup: (() -> Void)? = nil,
        nextExerciseInGroup: WorkoutExercise? = nil,
        isLiveWorkout: Bool = true,
        isPendingWorkout: Bool = false,
        showVideosOverride: Bool? = nil,
        showFormTipsOverride: Bool? = nil
    ) {
        self.exercise = exercise
        self.onUpdate = onUpdate
        self.onUpdateWithoutDismiss = onUpdateWithoutDismiss
        self.groupInfo = groupInfo
        self.onNavigateToNextInGroup = onNavigateToNextInGroup
        self.nextExerciseInGroup = nextExerciseInGroup
        self.isLiveWorkout = isLiveWorkout
        self.isPendingWorkout = isPendingWorkout
        self.showVideosOverride = showVideosOverride
        self.showFormTipsOverride = showFormTipsOverride
        _updatedExercise = State(initialValue: exercise)
        _exerciseNotes = State(initialValue: exercise.notes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Superset header (if part of a superset) - only for live workouts
                    if isLiveWorkout, let info = groupInfo {
                        SupersetHeaderView(
                            groupInfo: info,
                            currentExerciseName: exercise.exercise.name,
                            nextExerciseName: nextExerciseInGroup?.exercise.name
                        )
                        .padding(.horizontal)

                        // Group rest timer (shown when rest is active for superset/circuit)
                        if restTimerManager.isActive && restTimerManager.isGroupTimer {
                            GroupRestTimerView()
                                .padding(.horizontal)
                        }
                    }

                    // Exercise header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.exercise.name)
                            .font(.title)
                            .fontWeight(.bold)

                        if !exercise.exercise.primaryMuscleGroups.isEmpty {
                            Text(exercise.exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Video demonstration
                    if shouldShowVideos, let videoID = exercise.exercise.youtubeVideoID {
                        YouTubeVideoView(videoID: videoID)
                            .padding(.horizontal)
                    }

                    // Form tips if available
                    if shouldShowFormTips && !exercise.exercise.formTips.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Form Tips", systemImage: "lightbulb")
                                .font(.headline)
                            Text(exercise.exercise.formTips)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Sets
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Sets")
                                .font(.headline)
                            Spacer()
                            Text("Changes propagate to subsequent sets")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        ForEach(Array(updatedExercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                            HStack(alignment: .top, spacing: 8) {
                                AdvancedSetRowView(
                                    set: set,
                                    setIndex: setIndex,
                                    exerciseName: exercise.exercise.name,
                                    equipment: exercise.exercise.equipment,
                                    onUpdate: { updatedSet in
                                        updatedExercise.sets[setIndex] = updatedSet
                                    },
                                    onWeightChanged: { changedSetIndex, newWeight in
                                        // Propagate weight to all subsequent standard sets that haven't been completed
                                        for i in (changedSetIndex + 1)..<updatedExercise.sets.count {
                                            if !updatedExercise.sets[i].isCompleted && updatedExercise.sets[i].setType == .standard {
                                                updatedExercise.sets[i].weight = newWeight
                                            }
                                        }
                                    },
                                    onRepsChanged: { changedSetIndex, newReps in
                                        // Propagate reps to all subsequent standard sets that haven't been completed
                                        for i in (changedSetIndex + 1)..<updatedExercise.sets.count {
                                            if !updatedExercise.sets[i].isCompleted && updatedExercise.sets[i].setType == .standard {
                                                // For pending workouts, update targetReps instead of actualReps
                                                if isPendingWorkout {
                                                    updatedExercise.sets[i].targetReps = newReps
                                                } else {
                                                    updatedExercise.sets[i].actualReps = newReps
                                                }
                                            }
                                        }
                                    },
                                    onRestPeriodChanged: { changedSetIndex, newRestPeriod in
                                        // Propagate rest period to all subsequent standard sets that haven't been completed
                                        for i in (changedSetIndex + 1)..<updatedExercise.sets.count {
                                            if !updatedExercise.sets[i].isCompleted && updatedExercise.sets[i].setType == .standard {
                                                updatedExercise.sets[i].restPeriod = newRestPeriod
                                            }
                                        }
                                    },
                                    // Suppress rest timer for historical entries, pending workouts, or when in a superset
                                    suppressRestTimer: !isLiveWorkout || isPendingWorkout || isInSuperset,
                                    // Don't start rest timer after the last set of an exercise
                                    isLastSet: setIndex == updatedExercise.sets.count - 1,
                                    onSetCompleted: (isLiveWorkout && isInSuperset) ? {
                                        handleSupersetSetCompletion(forSetIndex: setIndex)
                                    } : nil,
                                    isLiveWorkout: isLiveWorkout,
                                    isPendingWorkout: isPendingWorkout
                                )

                                // Delete set button (only show if more than 1 set)
                                if updatedExercise.sets.count > 1 {
                                    Button {
                                        removeSet(at: setIndex)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.title3)
                                    }
                                    .padding(.top, 12)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Add set buttons
                        HStack(spacing: 12) {
                            // Quick add standard set
                            Button {
                                addSet(type: .standard)
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Set")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }

                            // More set types
                            Button {
                                showAddSetTypePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "ellipsis.circle.fill")
                                    Text("More")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)

                        // Advanced techniques hint
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.min")
                                .font(.caption2)
                            Text("Tap \"More\" for drop sets, rest-pause, and warmup sets")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }

                    // Notes section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)

                        TextField("Add notes about this exercise...", text: $exerciseNotes, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: exerciseNotes) { _, newValue in
                                updatedExercise.notes = newValue
                            }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Next exercise button for supersets (only for live workouts)
                    if isLiveWorkout && isInSuperset, let nextExercise = nextExerciseInGroup {
                        Button {
                            // Save current exercise first
                            onUpdate(updatedExercise)
                            // Navigate to next exercise
                            onNavigateToNextInGroup?()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Next: \(nextExercise.exercise.name)")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(groupInfo?.group.groupType.swiftUIColor ?? .blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onUpdate(updatedExercise)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddSetTypePicker) {
                SetTypePickerView { setType in
                    addSet(type: setType)
                }
            }
            .onDisappear {
                // Save changes when sheet is dismissed (including swipe-to-dismiss)
                // This ensures changes aren't lost if user swipes away instead of tapping Done
                onUpdate(updatedExercise)
            }
        }
    }

    private var navigationTitle: String {
        if isLiveWorkout && isInSuperset {
            return groupInfo?.group.groupType.displayName ?? "Log Sets"
        }
        return isLiveWorkout ? "Log Sets" : "Edit Exercise"
    }

    private func addSet(type: SetType) {
        let lastSet = updatedExercise.sets.last
        // Find first working set for warmup weight reference
        let firstWorkingSet = updatedExercise.sets.first { $0.setType != .warmup }

        // Use actual reps if user changed them, otherwise fall back to target reps
        let repsFromLastSet = lastSet?.actualReps ?? lastSet?.targetReps ?? 10

        let newSet: ExerciseSet
        switch type {
        case .standard:
            newSet = ExerciseSet(
                setNumber: 0, // Will be renumbered
                setType: .standard,
                targetReps: repsFromLastSet,
                weight: lastSet?.weight,
                restPeriod: lastSet?.restPeriod ?? 90
            )
            updatedExercise.sets.append(newSet)
        case .warmup:
            // Use working set weight for warmup calculation, or last set as fallback
            let referenceWeight = firstWorkingSet?.weight ?? lastSet?.weight ?? 100
            newSet = ExerciseSet.createWarmupSet(
                setNumber: 0, // Will be renumbered
                targetReps: 10,
                weight: referenceWeight * 0.5, // 50% of working weight
                restPeriod: 60
            )
            // Insert warmup at the beginning (before all other sets)
            updatedExercise.sets.insert(newSet, at: 0)
        case .dropSet:
            newSet = ExerciseSet.createDropSet(
                setNumber: 0, // Will be renumbered
                targetReps: repsFromLastSet > 0 ? repsFromLastSet : 8,
                weight: lastSet?.weight,
                restPeriod: lastSet?.restPeriod ?? 90,
                numberOfDrops: 2,
                dropPercentage: 0.2
            )
            updatedExercise.sets.append(newSet)
        case .restPause:
            newSet = ExerciseSet.createRestPauseSet(
                setNumber: 0, // Will be renumbered
                targetReps: repsFromLastSet > 0 ? repsFromLastSet : 8,
                weight: lastSet?.weight,
                restPeriod: lastSet?.restPeriod ?? 90,
                numberOfPauses: 2,
                pauseDuration: 15
            )
            updatedExercise.sets.append(newSet)
        }

        // Renumber all sets after insertion
        for i in updatedExercise.sets.indices {
            updatedExercise.sets[i].setNumber = i + 1
        }
    }

    private func removeSet(at index: Int) {
        guard updatedExercise.sets.count > 1 else { return }
        updatedExercise.sets.remove(at: index)
        // Renumber the remaining sets
        for i in 0..<updatedExercise.sets.count {
            updatedExercise.sets[i].setNumber = i + 1
        }
    }

    /// Handles set completion in a superset/circuit context
    /// Automatically navigates to the next exercise in the group that has incomplete sets
    /// Starts rest timer when completing a round (wrapping back to an earlier exercise)
    private func handleSupersetSetCompletion(forSetIndex setIndex: Int) {
        guard let _ = groupInfo else { return }

        // Save current exercise state without dismissing (so navigation works)
        if let updateWithoutDismiss = onUpdateWithoutDismiss {
            updateWithoutDismiss(updatedExercise)
        } else {
            onUpdate(updatedExercise)
        }

        // Navigation and rest timer are handled by the callback from ActiveWorkoutView
        // which has access to currentWorkout and can determine if we're completing a round
        onNavigateToNextInGroup?()
    }
}

// MARK: - Set Type Picker View

struct SetTypePickerView: View {
    let onSelect: (SetType) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(.standard)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "number.circle")
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text("Standard Set")
                                    .foregroundStyle(.primary)
                                Text("Regular working set")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        onSelect(.warmup)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "flame")
                                .foregroundStyle(.orange)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text("Warmup Set")
                                    .foregroundStyle(.primary)
                                Text("Light weight to prepare muscles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        onSelect(.dropSet)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.right")
                                .foregroundStyle(.purple)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text("Drop Set")
                                    .foregroundStyle(.primary)
                                Text("Reduce weight and continue without rest")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        onSelect(.restPause)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "pause.circle")
                                .foregroundStyle(.green)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text("Rest-Pause Set")
                                    .foregroundStyle(.primary)
                                Text("Brief pauses to extend the set")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Select Set Type")
                }
            }
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
