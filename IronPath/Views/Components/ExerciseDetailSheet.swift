import SwiftUI

// MARK: - Exercise Detail Sheet

/// Shared view for editing exercise sets - used by both active workouts and historical workout entry
struct ExerciseDetailSheet: View {
    @State private var viewModel: ExerciseDetailViewModel
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(\.dismiss) var dismiss

    /// Tracks whether changes have been saved to prevent double-save
    @State private var hasSaved = false

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
        let vm = ExerciseDetailViewModel(
            exercise: exercise,
            isLiveWorkout: isLiveWorkout,
            isPendingWorkout: isPendingWorkout,
            showVideosOverride: showVideosOverride,
            showFormTipsOverride: showFormTipsOverride,
            groupInfo: groupInfo,
            nextExerciseInGroup: nextExerciseInGroup
        )
        vm.onUpdate = onUpdate
        vm.onUpdateWithoutDismiss = onUpdateWithoutDismiss
        vm.onNavigateToNextInGroup = onNavigateToNextInGroup
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    supersetSection
                    exerciseHeader
                    exerciseModeToggle
                    videoSection
                    formTipsSection
                    historySection
                    setsSection
                    notesSection
                    nextExerciseButton
                }
                .padding(.vertical)
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        hasSaved = true
                        viewModel.saveAndDismiss()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSetTypePicker) {
                SetTypePickerView { setType in
                    viewModel.addSet(type: setType)
                }
            }
            .onDisappear {
                guard !hasSaved else { return }
                viewModel.saveAndDismiss()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var supersetSection: some View {
        if viewModel.isLiveWorkout, let info = viewModel.groupInfo {
            SupersetHeaderView(
                groupInfo: info,
                currentExerciseName: viewModel.exercise.exercise.name,
                nextExerciseName: viewModel.nextExerciseInGroup?.exercise.name
            )
            .padding(.horizontal)

            if dependencies.restTimerManager.isActive,
               let timerManager = dependencies.restTimerManager as? RestTimerManager,
               timerManager.isGroupTimer {
                GroupRestTimerView()
                    .padding(.horizontal)
            }
        }
    }

    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.exercise.exercise.name)
                .font(.title)
                .fontWeight(.bold)

            if !viewModel.exercise.exercise.primaryMuscleGroups.isEmpty {
                Text(viewModel.exercise.exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var exerciseModeToggle: some View {
        if viewModel.exercise.exercise.supportsTiming {
            HStack {
                Text("Mode:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("", selection: $viewModel.isTimedMode) {
                    Label("Reps", systemImage: "number").tag(false)
                    Label("Timed", systemImage: "timer").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var videoSection: some View {
        if viewModel.shouldShowVideos, let videoID = viewModel.exercise.exercise.youtubeVideoID {
            YouTubeVideoView(videoID: videoID)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var formTipsSection: some View {
        if viewModel.shouldShowFormTips && !viewModel.exercise.exercise.formTips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Form Tips", systemImage: "lightbulb")
                    .font(.headline)
                Text(viewModel.exercise.exercise.formTips)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !viewModel.exerciseHistory.isEmpty {
            ExerciseHistorySection(
                history: viewModel.exerciseHistory,
                isExpanded: $viewModel.showHistory
            )
            .padding(.horizontal)
        }
    }

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            setsHeader
            setsList
            addSetButtons
            advancedTechniqueHint
        }
    }

    private var setsHeader: some View {
        HStack {
            Text("Sets")
                .font(.headline)
            Spacer()
            Text("Changes propagate to subsequent sets")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var setsList: some View {
        ForEach(Array(viewModel.exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
            HStack(alignment: .top, spacing: 8) {
                AdvancedSetRowView(
                    set: set,
                    setIndex: setIndex,
                    exerciseName: viewModel.exercise.exercise.name,
                    equipment: viewModel.exercise.exercise.equipment,
                    onUpdate: { updatedSet in
                        viewModel.updateSet(at: setIndex, with: updatedSet)
                    },
                    onWeightChanged: { changedSetIndex, newWeight in
                        viewModel.propagateWeight(from: changedSetIndex, newWeight: newWeight)
                    },
                    onRepsChanged: { changedSetIndex, newReps in
                        viewModel.propagateReps(from: changedSetIndex, newReps: newReps)
                    },
                    onRestPeriodChanged: { changedSetIndex, newRestPeriod in
                        viewModel.propagateRestPeriod(from: changedSetIndex, newRestPeriod: newRestPeriod)
                    },
                    onDurationChanged: { changedSetIndex, newDuration in
                        viewModel.propagateDuration(from: changedSetIndex, newDuration: newDuration)
                    },
                    onAddedWeightChanged: { changedSetIndex, newWeight in
                        viewModel.propagateAddedWeight(from: changedSetIndex, newWeight: newWeight)
                    },
                    suppressRestTimer: viewModel.suppressRestTimer,
                    isLastSet: viewModel.isLastSet(index: setIndex),
                    onSetCompleted: (viewModel.isLiveWorkout && viewModel.isInSuperset) ? {
                        viewModel.handleSupersetSetCompletion(forSetIndex: setIndex)
                    } : nil,
                    isLiveWorkout: viewModel.isLiveWorkout,
                    isPendingWorkout: viewModel.isPendingWorkout,
                    workingSetNumber: viewModel.workingSetNumber(forSetIndex: setIndex),
                    previousSetWeight: viewModel.previousSetWeight(forSetIndex: setIndex),
                    isFirstIncompleteSet: isFirstIncompleteSet(at: setIndex)
                )

                if viewModel.exercise.sets.count > 1 {
                    Button {
                        viewModel.removeSet(at: setIndex)
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
    }

    private var addSetButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.addSet(type: .standard)
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

            Button {
                viewModel.showAddSetTypePicker = true
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
    }

    private var advancedTechniqueHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "lightbulb.min")
                .font(.caption2)
            Text("Tap \"More\" for drop sets, rest-pause, and warmup sets")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)

            TextField("Add notes about this exercise...", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.notes) { _, newValue in
                    viewModel.updateNotes(newValue)
                }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var nextExerciseButton: some View {
        if viewModel.isLiveWorkout && viewModel.isInSuperset, let nextExercise = viewModel.nextExerciseInGroup {
            Button {
                viewModel.navigateToNextInGroup()
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
                .background(viewModel.groupInfo?.group.groupType.swiftUIColor ?? .blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helper Methods

    private func isFirstIncompleteSet(at index: Int) -> Bool {
        // Check if this is the first incomplete set in the list
        for i in 0..<viewModel.exercise.sets.count {
            let currentSet = viewModel.exercise.sets[i]
            if !currentSet.isCompleted {
                return i == index
            }
        }
        return false
    }
}
