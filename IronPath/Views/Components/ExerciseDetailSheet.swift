import SwiftUI

// MARK: - Exercise Detail Sheet

/// Shared view for editing exercise sets - used by both active workouts and historical workout entry
struct ExerciseDetailSheet: View {
    @StateObject private var viewModel: ExerciseDetailViewModel
    @EnvironmentObject private var dependencies: DependencyContainer
    @Environment(\.dismiss) var dismiss

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
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Superset header (if part of a superset) - only for live workouts
                    if viewModel.isLiveWorkout, let info = viewModel.groupInfo {
                        SupersetHeaderView(
                            groupInfo: info,
                            currentExerciseName: viewModel.exercise.exercise.name,
                            nextExerciseName: viewModel.nextExerciseInGroup?.exercise.name
                        )
                        .padding(.horizontal)

                        // Group rest timer (shown when rest is active for superset/circuit)
                        if dependencies.restTimerManager.isActive,
                           let timerManager = dependencies.restTimerManager as? RestTimerManager,
                           timerManager.isGroupTimer {
                            GroupRestTimerView()
                                .padding(.horizontal)
                        }
                    }

                    // Exercise header
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

                    // Video demonstration
                    if viewModel.shouldShowVideos, let videoID = viewModel.exercise.exercise.youtubeVideoID {
                        YouTubeVideoView(videoID: videoID)
                            .padding(.horizontal)
                    }

                    // Form tips if available
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

                    // Exercise history section
                    if !viewModel.exerciseHistory.isEmpty {
                        ExerciseHistorySection(
                            history: viewModel.exerciseHistory,
                            isExpanded: $viewModel.showHistory
                        )
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
                                    suppressRestTimer: viewModel.suppressRestTimer,
                                    isLastSet: viewModel.isLastSet(index: setIndex),
                                    onSetCompleted: (viewModel.isLiveWorkout && viewModel.isInSuperset) ? {
                                        viewModel.handleSupersetSetCompletion(forSetIndex: setIndex)
                                    } : nil,
                                    isLiveWorkout: viewModel.isLiveWorkout,
                                    isPendingWorkout: viewModel.isPendingWorkout,
                                    workingSetNumber: viewModel.workingSetNumber(forSetIndex: setIndex),
                                    previousSetWeight: viewModel.previousSetWeight(forSetIndex: setIndex)
                                )

                                // Delete set button (only show if more than 1 set)
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

                        // Add set buttons
                        HStack(spacing: 12) {
                            // Quick add standard set
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

                            // More set types
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

                    // Next exercise button for supersets (only for live workouts)
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
                .padding(.vertical)
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
                // Always save changes when sheet is dismissed (including swipe-to-dismiss)
                viewModel.saveAndDismiss()
            }
        }
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

// MARK: - Exercise History Section

struct ExerciseHistorySection: View {
    let history: [(date: Date, sets: [ExerciseSet])]
    @Binding var isExpanded: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button to toggle expansion
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(history.count) session\(history.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(isExpanded ? 12 : 12, corners: isExpanded ? [.topLeft, .topRight] : .allCorners)
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(history.enumerated()), id: \.offset) { index, session in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(dateFormatter.string(from: session.date))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            // Show sets summary
                            HStack(spacing: 16) {
                                // Max weight
                                if let maxWeight = session.sets.compactMap({ $0.weight }).max() {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Max")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(Int(maxWeight)) lbs")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                }

                                // Sets breakdown
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sets")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(setsBreakdown(session.sets))
                                        .font(.subheadline)
                                }

                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)

                        if index < history.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
        }
    }

    /// Format sets as "3×10 @ 135 lbs" style
    private func setsBreakdown(_ sets: [ExerciseSet]) -> String {
        // Group by weight and show reps
        var breakdown: [String] = []

        for set in sets {
            let reps = set.actualReps ?? set.targetReps
            if let weight = set.weight {
                breakdown.append("\(reps)×\(Int(weight))")
            } else {
                breakdown.append("\(reps) reps")
            }
        }

        // If all the same, combine (e.g., "3×10 @ 135")
        let uniqueBreakdowns = Set(breakdown)
        if uniqueBreakdowns.count == 1, let first = breakdown.first, sets.count > 1 {
            return "\(sets.count)×\(first.components(separatedBy: "×").last ?? first)"
        }

        return breakdown.joined(separator: ", ")
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
