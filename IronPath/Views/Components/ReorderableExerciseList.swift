import SwiftUI

// MARK: - Draggable Exercise List

/// A component that displays exercises with long-press drag to reorder
struct DraggableExerciseList: View {
    @Binding var workout: Workout
    let isLiveWorkout: Bool
    let exercisePreferenceManager: ExercisePreferenceManaging

    // Callbacks for exercise interactions
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void
    var onAddExerciseToGroup: ((ExerciseGroup) -> Void)? = nil

    // Drag state
    @State private var longPressIndex: Int? // Which item has active long press (before drag)
    @State private var draggingIndex: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var itemHeights: [Int: CGFloat] = [:]

    // State for group reordering sheet
    @State private var groupToReorder: ExerciseGroup?

    // Haptic feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    private var averageItemHeight: CGFloat {
        guard !itemHeights.isEmpty else { return 80 }
        let total = itemHeights.values.reduce(0, +)
        return total / CGFloat(itemHeights.count) + 12 // Add spacing
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(workout.displayItems.enumerated()), id: \.element.id) { index, item in
                let isDragging = draggingIndex == index
                let isLongPressed = longPressIndex == index

                ExerciseCardWrapper(
                    item: item,
                    workout: $workout,
                    isLiveWorkout: isLiveWorkout,
                    exercisePreferenceManager: exercisePreferenceManager,
                    isDragging: isDragging,
                    isLongPressed: isLongPressed,
                    onExerciseTap: onExerciseTap,
                    onExerciseReplace: onExerciseReplace,
                    onExerciseRemove: onExerciseRemove,
                    onSetPreference: onSetPreference,
                    onReorderWithinGroup: { group in
                        groupToReorder = group
                    },
                    onAddExerciseToGroup: { exercise, group in
                        addExerciseToGroup(exercise, group: group)
                    },
                    onAddNewExerciseToGroup: { group in
                        onAddExerciseToGroup?(group)
                    },
                    onUngroupExercises: { group in
                        ungroupExercises(group)
                    }
                )
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ItemHeightPreferenceKey.self,
                            value: [index: geo.size.height]
                        )
                    }
                )
                .offset(y: offsetForItem(at: index))
                .zIndex(isDragging ? 100 : 0)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            switch value {
                            case .first(true):
                                // Long press is in progress but not yet completed
                                // Don't show visual feedback yet
                                break
                            case .second(true, let drag):
                                // Long press COMPLETED, now in drag phase
                                // Show elevated state first if not already shown
                                if longPressIndex != index && draggingIndex != index {
                                    longPressIndex = index
                                    impactFeedback.impactOccurred(intensity: 0.5)
                                }

                                // Only allow dragging after visual feedback has been shown
                                // (longPressIndex was set, or we're already dragging)
                                if let drag = drag, abs(drag.translation.height) > 2 {
                                    if longPressIndex == index || draggingIndex == index {
                                        // Switch from long press state to drag state
                                        if draggingIndex == nil {
                                            longPressIndex = nil
                                            draggingIndex = index
                                            impactFeedback.impactOccurred()
                                        }
                                        dragOffset = drag.translation.height
                                    }
                                }
                            default:
                                break
                            }
                        }
                        .onEnded { value in
                            longPressIndex = nil
                            finishDrag(from: index)
                        }
                )
            }
        }
        .onPreferenceChange(ItemHeightPreferenceKey.self) { heights in
            itemHeights.merge(heights) { _, new in new }
        }
        .sheet(item: $groupToReorder) { group in
            GroupReorderSheet(group: group, workout: $workout)
        }
    }

    private func offsetForItem(at index: Int) -> CGFloat {
        guard let draggingIdx = draggingIndex else { return 0 }

        if index == draggingIdx {
            // Dragged item follows the finger exactly
            return dragOffset
        }

        // Calculate where the dragged item currently is
        let currentPosition = calculateCurrentDragPosition()
        let itemHeight = averageItemHeight

        if draggingIdx < index {
            // Item is below the original drag position
            // Move up if dragged item has passed this position
            let threshold = CGFloat(index - draggingIdx) * itemHeight
            if dragOffset > threshold - itemHeight / 2 {
                return -itemHeight
            }
        } else {
            // Item is above the original drag position
            // Move down if dragged item has passed this position
            let threshold = CGFloat(draggingIdx - index) * itemHeight
            if dragOffset < -(threshold - itemHeight / 2) {
                return itemHeight
            }
        }

        return 0
    }

    private func calculateCurrentDragPosition() -> Int {
        guard let draggingIdx = draggingIndex else { return 0 }
        let itemHeight = averageItemHeight
        let movement = Int(round(dragOffset / itemHeight))
        let newPosition = draggingIdx + movement
        return max(0, min(workout.displayItems.count - 1, newPosition))
    }

    private func finishDrag(from index: Int) {
        guard let draggingIdx = draggingIndex else { return }

        let destinationIndex = calculateCurrentDragPosition()

        // Reset state immediately (no animation) to prevent snap-back visual
        draggingIndex = nil
        dragOffset = 0

        // Then perform the reorder - this happens after state reset
        // so the view updates with new order directly
        if destinationIndex != draggingIdx {
            let adjustedDest = destinationIndex > draggingIdx ? destinationIndex + 1 : destinationIndex
            workout.reorderDisplayItems(from: IndexSet(integer: draggingIdx), to: adjustedDest)
            impactFeedback.impactOccurred()
        }
    }

    private func addExerciseToGroup(_ exercise: WorkoutExercise, group: ExerciseGroup) {
        guard var groups = workout.exerciseGroups,
              let groupIndex = groups.firstIndex(where: { $0.id == group.id }) else { return }

        // Add exercise to the group
        groups[groupIndex].exerciseIds.append(exercise.id)

        // Update group type based on new count
        groups[groupIndex].groupType = ExerciseGroupType.suggestedType(for: groups[groupIndex].exerciseIds.count)

        workout.exerciseGroups = groups

        // Rebuild exercise order to keep grouped exercises together
        workout.rebuildExercisesOrder()
    }

    private func ungroupExercises(_ group: ExerciseGroup) {
        guard var groups = workout.exerciseGroups else { return }

        // Remove the group
        groups.removeAll { $0.id == group.id }

        workout.exerciseGroups = groups.isEmpty ? nil : groups
    }
}

// MARK: - Preference Key for Item Heights

private struct ItemHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Exercise Card Wrapper

private struct ExerciseCardWrapper: View {
    let item: ExerciseDisplayItem
    @Binding var workout: Workout
    let isLiveWorkout: Bool
    let exercisePreferenceManager: ExercisePreferenceManaging
    let isDragging: Bool
    let isLongPressed: Bool
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void
    let onReorderWithinGroup: (ExerciseGroup) -> Void
    let onAddExerciseToGroup: (WorkoutExercise, ExerciseGroup) -> Void
    let onAddNewExerciseToGroup: (ExerciseGroup) -> Void
    let onUngroupExercises: (ExerciseGroup) -> Void

    private var isElevated: Bool {
        isDragging || isLongPressed
    }

    /// Exercises not in any group (for "Add Exercise" menu in supersets)
    private var ungroupedExercises: [WorkoutExercise] {
        workout.exercises.filter { !workout.isGrouped($0.id) }
    }

    var body: some View {
        ExerciseCardContent(
            item: item,
            ungroupedExercises: ungroupedExercises,
            isLiveWorkout: isLiveWorkout,
            exercisePreferenceManager: exercisePreferenceManager,
            onExerciseTap: onExerciseTap,
            onExerciseReplace: onExerciseReplace,
            onExerciseRemove: onExerciseRemove,
            onSetPreference: onSetPreference,
            onReorderWithinGroup: onReorderWithinGroup,
            onAddExerciseToGroup: onAddExerciseToGroup,
            onAddNewExerciseToGroup: onAddNewExerciseToGroup,
            onUngroupExercises: onUngroupExercises
        )
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isElevated ? Color.blue : Color(.systemGray4), lineWidth: isElevated ? 2 : 1)
        )
        .shadow(
            color: isElevated ? .black.opacity(0.2) : .black.opacity(0.05),
            radius: isElevated ? 12 : 2,
            y: isElevated ? 8 : 1
        )
        .scaleEffect(isElevated ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isLongPressed)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - Exercise Card Content

private struct ExerciseCardContent: View {
    let item: ExerciseDisplayItem
    let ungroupedExercises: [WorkoutExercise]
    let isLiveWorkout: Bool
    let exercisePreferenceManager: ExercisePreferenceManaging
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void
    let onReorderWithinGroup: (ExerciseGroup) -> Void
    let onAddExerciseToGroup: (WorkoutExercise, ExerciseGroup) -> Void
    let onAddNewExerciseToGroup: (ExerciseGroup) -> Void
    let onUngroupExercises: (ExerciseGroup) -> Void

    var body: some View {
        switch item {
        case .standalone(let exercise):
            StandaloneExerciseCard(
                exercise: exercise,
                isLiveWorkout: isLiveWorkout,
                currentPreference: exercisePreferenceManager.getPreference(for: exercise.exercise.name),
                onTap: { onExerciseTap(exercise) },
                onReplace: { onExerciseReplace(exercise) },
                onRemove: { onExerciseRemove(exercise) },
                onSetPreference: { onSetPreference(exercise, $0) }
            )

        case .group(let group, let exercises):
            SupersetGroupContent(
                group: group,
                exercises: exercises,
                ungroupedExercises: ungroupedExercises,
                isLiveWorkout: isLiveWorkout,
                onExerciseTap: onExerciseTap,
                onExerciseReplace: onExerciseReplace,
                onExerciseRemove: onExerciseRemove,
                onReorderWithinGroup: onReorderWithinGroup,
                onAddExerciseToGroup: { exercise in onAddExerciseToGroup(exercise, group) },
                onAddNewExerciseToGroup: { onAddNewExerciseToGroup(group) },
                onUngroupExercises: { onUngroupExercises(group) }
            )
        }
    }
}

// MARK: - Standalone Exercise Card

private struct StandaloneExerciseCard: View {
    let exercise: WorkoutExercise
    let isLiveWorkout: Bool
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
        HStack(spacing: 12) {
            // Tappable content area
            HStack(spacing: 12) {
                if isLiveWorkout {
                    // Progress indicator
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                            .frame(width: 40, height: 40)

                        if !exercise.isCompleted && completedSetsCount > 0 {
                            Circle()
                                .trim(from: 0, to: setProgress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))
                        }

                        if exercise.isCompleted {
                            Circle()
                                .stroke(Color.green, lineWidth: 3)
                                .frame(width: 40, height: 40)
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                                .fontWeight(.bold)
                        } else {
                            Text("\(completedSetsCount)/\(exercise.sets.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    Image(systemName: "dumbbell.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(exercise.exercise.name)
                            .font(.headline)
                            .foregroundStyle(isLiveWorkout && exercise.isCompleted ? .secondary : .primary)

                        if currentPreference != .normal {
                            Image(systemName: currentPreference.iconName)
                                .font(.caption)
                                .foregroundStyle(preferenceColor)
                        }
                    }

                    HStack {
                        Text("\(exercise.sets.count) sets")
                        Text("•")
                        Text("\(exercise.sets.first?.actualReps ?? exercise.sets.first?.targetReps ?? 0) reps")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            // Menu - separate from tap area
            Menu {
                Button(action: onReplace) {
                    Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                }

                Divider()
                Menu {
                    ForEach(ExerciseSuggestionPreference.allCases, id: \.self) { pref in
                        Button {
                            onSetPreference(pref)
                        } label: {
                            HStack {
                                Label(pref.displayName, systemImage: pref.iconName)
                                if pref == currentPreference {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Suggestion Preference", systemImage: "hand.thumbsup")
                }
                Divider()
                Button(role: .destructive, action: onRemove) {
                    Label("Remove from Workout", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
        .padding(12)
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

// MARK: - Superset Group Content

private struct SupersetGroupContent: View {
    let group: ExerciseGroup
    let exercises: [WorkoutExercise]
    let ungroupedExercises: [WorkoutExercise]
    let isLiveWorkout: Bool
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onReorderWithinGroup: (ExerciseGroup) -> Void
    let onAddExerciseToGroup: (WorkoutExercise) -> Void
    let onAddNewExerciseToGroup: () -> Void
    let onUngroupExercises: () -> Void

    private var groupColor: Color {
        group.groupType.swiftUIColor
    }

    /// Find the next exercise with incomplete sets in this group
    private var nextExerciseWithIncompleteSets: WorkoutExercise? {
        // First, try to find the first exercise with incomplete sets
        for exercise in exercises {
            if exercise.sets.contains(where: { !$0.isCompleted }) {
                return exercise
            }
        }
        // All complete, return first exercise
        return exercises.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                // Tappable area - jump to next exercise (excludes menu)
                HStack(spacing: 8) {
                    Image(systemName: group.groupType.iconName)
                        .foregroundStyle(groupColor)
                    Text(group.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(groupColor)

                    Spacer()

                    if isLiveWorkout {
                        // Show progress
                        let completedSets = exercises.flatMap { $0.sets }.filter { $0.isCompleted }.count
                        let totalSets = exercises.flatMap { $0.sets }.count
                        Text("\(completedSets)/\(totalSets)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isLiveWorkout, let nextExercise = nextExerciseWithIncompleteSets {
                        onExerciseTap(nextExercise)
                    }
                }

                // Menu - separate from tap area
                Menu {
                    // Add exercise options
                    Button {
                        onAddNewExerciseToGroup()
                    } label: {
                        Label("Add New Exercise", systemImage: "plus.circle")
                    }

                    if !ungroupedExercises.isEmpty {
                        Menu {
                            ForEach(ungroupedExercises) { exercise in
                                Button {
                                    onAddExerciseToGroup(exercise)
                                } label: {
                                    Text(exercise.exercise.name)
                                }
                            }
                        } label: {
                            Label("Add from Workout", systemImage: "arrow.right.circle")
                        }
                    }

                    Divider()

                    Button {
                        onReorderWithinGroup(group)
                    } label: {
                        Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onUngroupExercises()
                    } label: {
                        Label("Ungroup Exercises", systemImage: "rectangle.expand.vertical")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Exercises
            VStack(spacing: 6) {
                ForEach(exercises) { exercise in
                    GroupExerciseRow(
                        exercise: exercise,
                        groupColor: groupColor,
                        isLiveWorkout: isLiveWorkout,
                        onTap: { onExerciseTap(exercise) },
                        onReplace: { onExerciseReplace(exercise) },
                        onRemove: { onExerciseRemove(exercise) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(groupColor.opacity(0.3), lineWidth: 1.5)
        )
    }
}

// MARK: - Group Exercise Row

private struct GroupExerciseRow: View {
    let exercise: WorkoutExercise
    let groupColor: Color
    let isLiveWorkout: Bool
    let onTap: () -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void

    var completedSetsCount: Int {
        exercise.sets.filter { $0.isCompleted }.count
    }

    var setProgress: Double {
        guard exercise.sets.count > 0 else { return 0 }
        return Double(completedSetsCount) / Double(exercise.sets.count)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Tappable content area
            HStack(spacing: 10) {
                if isLiveWorkout {
                    // Progress indicator with circular progress (matching standalone cards)
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 28, height: 28)

                        // Progress arc (only shown when partially complete)
                        if !exercise.isCompleted && completedSetsCount > 0 {
                            Circle()
                                .trim(from: 0, to: setProgress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 28, height: 28)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: setProgress)
                        }

                        // Completed state: full green circle
                        if exercise.isCompleted {
                            Circle()
                                .stroke(Color.green, lineWidth: 2)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                        } else {
                            Text("\(completedSetsCount)/\(exercise.sets.count)")
                                .font(.system(size: 9))
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    Circle()
                        .fill(groupColor.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(groupColor)
                        )
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(exercise.exercise.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(exercise.sets.count) sets × \(exercise.sets.first?.targetReps ?? 0) reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            // Menu - separate from tap area
            Menu {
                Button(action: onReplace) {
                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Group Reorder Sheet

struct GroupReorderSheet: View {
    let group: ExerciseGroup  // Initial group (for ID and display name)
    @Binding var workout: Workout
    @Environment(\.dismiss) private var dismiss

    // Get current group from workout to reflect any changes
    private var currentGroup: ExerciseGroup? {
        workout.exerciseGroups?.first { $0.id == group.id }
    }

    private var groupColor: Color {
        (currentGroup ?? group).groupType.swiftUIColor
    }

    private var groupExercises: [WorkoutExercise] {
        guard let current = currentGroup else { return [] }
        return current.exerciseIds.compactMap { exerciseId in
            workout.exercises.first { $0.id == exerciseId }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(groupExercises) { exercise in
                        HStack(spacing: 12) {
                            Image(systemName: "dumbbell.fill")
                                .font(.title3)
                                .foregroundStyle(groupColor)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.exercise.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("\(exercise.sets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { source, destination in
                        workout.reorderExercisesInGroup(group.id, from: source, to: destination)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: (currentGroup ?? group).groupType.iconName)
                            .foregroundStyle(groupColor)
                        Text("Drag to reorder exercises")
                    }
                    .font(.subheadline)
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder \(group.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Create Exercise Group Sheet

struct CreateExerciseGroupSheet: View {
    @Binding var workout: Workout
    let onGroupCreated: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedExerciseIds: Set<UUID> = []
    @State private var groupType: ExerciseGroupType = .superset
    @State private var restBetween: Int = 0
    @State private var restAfter: Int = 90

    /// Exercises that are not already in a group
    private var availableExercises: [WorkoutExercise] {
        workout.exercises.filter { exercise in
            !workout.isGrouped(exercise.id)
        }
    }

    private var canCreate: Bool {
        selectedExerciseIds.count >= 2
    }

    private var suggestedGroupType: ExerciseGroupType {
        ExerciseGroupType.suggestedType(for: selectedExerciseIds.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(availableExercises) { exercise in
                        HStack {
                            Image(systemName: selectedExerciseIds.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedExerciseIds.contains(exercise.id) ? .blue : .secondary)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.exercise.name)
                                Text("\(exercise.sets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(exercise.id)
                        }
                    }
                } header: {
                    Text("Select Exercises")
                } footer: {
                    Text("Select 2 or more exercises to group together. They will be performed back-to-back.")
                }

                if selectedExerciseIds.count >= 2 {
                    Section {
                        Picker("Group Type", selection: $groupType) {
                            ForEach(ExerciseGroupType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.iconName)
                                    .tag(type)
                            }
                        }
                    } header: {
                        Text("Group Type")
                    } footer: {
                        Text(groupType.description)
                    }

                    Section {
                        Stepper(value: $restBetween, in: 0...60, step: 5) {
                            HStack {
                                Text("Rest Between Exercises")
                                Spacer()
                                Text("\(restBetween)s")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Stepper(value: $restAfter, in: 30...300, step: 15) {
                            HStack {
                                Text("Rest After Round")
                                Spacer()
                                Text("\(restAfter)s")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Rest Times")
                    }
                }
            }
            .navigationTitle("Create Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(!canCreate)
                }
            }
            .onChange(of: selectedExerciseIds.count) { _, newCount in
                // Auto-update group type based on selection count
                if newCount >= 2 {
                    groupType = suggestedGroupType
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedExerciseIds.contains(id) {
            selectedExerciseIds.remove(id)
        } else {
            selectedExerciseIds.insert(id)
        }
    }

    private func createGroup() {
        // Order selected exercises by their current order in the workout
        let orderedIds = workout.exercises
            .filter { selectedExerciseIds.contains($0.id) }
            .map { $0.id }

        let newGroup = ExerciseGroup(
            groupType: groupType,
            exerciseIds: orderedIds,
            restBetweenExercises: TimeInterval(restBetween),
            restAfterGroup: TimeInterval(restAfter)
        )

        if workout.exerciseGroups == nil {
            workout.exerciseGroups = []
        }
        workout.exerciseGroups?.append(newGroup)

        // Rebuild exercise order to keep grouped exercises together
        workout.rebuildExercisesOrder()

        onGroupCreated()
        dismiss()
    }
}
