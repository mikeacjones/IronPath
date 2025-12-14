import SwiftUI

// MARK: - Draggable Exercise List

/// A component that displays exercises with long-press drag to reorder
struct DraggableExerciseList: View {
    @Binding var workout: Workout
    let isLiveWorkout: Bool
    let exercisePreferenceManager: ExercisePreferenceManaging

    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void
    var onAddExerciseToGroup: ((ExerciseGroup) -> Void)? = nil

    @State private var longPressIndex: Int?
    @State private var draggingIndex: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var itemHeights: [Int: CGFloat] = [:]
    @State private var groupToReorder: ExerciseGroup?

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    private var averageItemHeight: CGFloat {
        guard !itemHeights.isEmpty else { return 80 }
        let total = itemHeights.values.reduce(0, +)
        return total / CGFloat(itemHeights.count) + 12
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
                .gesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            handleDragChange(value: value, index: index)
                        }
                        .onEnded { _ in
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

    private func handleDragChange(value: SequenceGesture<LongPressGesture, DragGesture>.Value, index: Int) {
        switch value {
        case .first(true):
            break
        case .second(true, let drag):
            if longPressIndex != index && draggingIndex != index {
                longPressIndex = index
                impactFeedback.impactOccurred(intensity: 0.5)
            }

            if let drag = drag, abs(drag.translation.height) > 2 {
                if longPressIndex == index || draggingIndex == index {
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

    private func offsetForItem(at index: Int) -> CGFloat {
        guard let draggingIdx = draggingIndex else { return 0 }

        if index == draggingIdx {
            return dragOffset
        }

        let itemHeight = averageItemHeight

        if draggingIdx < index {
            let threshold = CGFloat(index - draggingIdx) * itemHeight
            if dragOffset > threshold - itemHeight / 2 {
                return -itemHeight
            }
        } else {
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

        draggingIndex = nil
        dragOffset = 0

        if destinationIndex != draggingIdx {
            let adjustedDest = destinationIndex > draggingIdx ? destinationIndex + 1 : destinationIndex
            workout.reorderDisplayItems(from: IndexSet(integer: draggingIdx), to: adjustedDest)
            impactFeedback.impactOccurred()
        }
    }

    private func addExerciseToGroup(_ exercise: WorkoutExercise, group: ExerciseGroup) {
        guard var groups = workout.exerciseGroups,
              let groupIndex = groups.firstIndex(where: { $0.id == group.id }) else { return }

        groups[groupIndex].exerciseIds.append(exercise.id)
        groups[groupIndex].groupType = ExerciseGroupType.suggestedType(for: groups[groupIndex].exerciseIds.count)
        workout.exerciseGroups = groups
        workout.rebuildExercisesOrder()
    }

    private func ungroupExercises(_ group: ExerciseGroup) {
        guard var groups = workout.exerciseGroups else { return }
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
