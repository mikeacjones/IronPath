import SwiftUI

// MARK: - Draggable Exercise List

/// A component that displays exercises with long-press drag-to-reorder capability
struct DraggableExerciseList: View {
    @Binding var workout: Workout
    let isLiveWorkout: Bool
    @ObservedObject var preferenceManager: ExercisePreferenceManager

    // Callbacks for exercise interactions
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void

    // Drag state
    @State private var draggingItemID: String?
    @State private var dragOffset: CGFloat = 0
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var initialDragItemIndex: Int?
    @State private var currentHoverIndex: Int?

    // State for group reordering sheet
    @State private var groupToReorder: ExerciseGroup?

    // Haptic feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(workout.displayItems.enumerated()), id: \.element.id) { index, item in
                let isDragging = draggingItemID == item.id
                let shouldOffset = calculateOffset(for: index)

                ExerciseItemView(
                    item: item,
                    workout: workout,
                    isLiveWorkout: isLiveWorkout,
                    preferenceManager: preferenceManager,
                    onExerciseTap: onExerciseTap,
                    onExerciseReplace: onExerciseReplace,
                    onExerciseRemove: onExerciseRemove,
                    onSetPreference: onSetPreference,
                    onReorderWithinGroup: { group in
                        groupToReorder = group
                    }
                )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                itemFrames[item.id] = geo.frame(in: .named("reorderSpace"))
                            }
                            .onChange(of: geo.frame(in: .named("reorderSpace"))) { _, newFrame in
                                if draggingItemID == nil {
                                    itemFrames[item.id] = newFrame
                                }
                            }
                    }
                )
                .offset(y: isDragging ? dragOffset : shouldOffset)
                .zIndex(isDragging ? 100 : 0)
                .scaleEffect(isDragging ? 1.03 : 1.0)
                .shadow(
                    color: isDragging ? .black.opacity(0.2) : .clear,
                    radius: isDragging ? 10 : 0,
                    y: isDragging ? 5 : 0
                )
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: shouldOffset)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
                .gesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .sequenced(before: DragGesture())
                        .onChanged { value in
                            switch value {
                            case .first(true):
                                // Long press recognized
                                break
                            case .second(true, let drag):
                                if let drag = drag {
                                    handleDragChange(item: item, index: index, translation: drag.translation.height)
                                }
                            default:
                                break
                            }
                        }
                        .onEnded { value in
                            handleDragEnd()
                        }
                )
            }
        }
        .coordinateSpace(name: "reorderSpace")
        .sheet(item: $groupToReorder) { group in
            GroupReorderSheet(group: group, workout: $workout)
        }
    }

    private func handleDragChange(item: ExerciseDisplayItem, index: Int, translation: CGFloat) {
        if draggingItemID == nil {
            // Starting drag
            draggingItemID = item.id
            initialDragItemIndex = index
            currentHoverIndex = index
            impactFeedback.impactOccurred()
        }

        dragOffset = translation

        // Calculate which index we're hovering over
        guard let initialIndex = initialDragItemIndex,
              let draggedFrame = itemFrames[item.id] else { return }

        let draggedCenter = draggedFrame.midY + translation
        let items = workout.displayItems

        var newHoverIndex = initialIndex

        for (i, otherItem) in items.enumerated() {
            guard i != initialIndex,
                  let frame = itemFrames[otherItem.id] else { continue }

            if translation > 0 {
                // Dragging down
                if i > initialIndex && draggedCenter > frame.midY {
                    newHoverIndex = i
                }
            } else {
                // Dragging up
                if i < initialIndex && draggedCenter < frame.midY {
                    newHoverIndex = i
                }
            }
        }

        if newHoverIndex != currentHoverIndex {
            currentHoverIndex = newHoverIndex
            impactFeedback.impactOccurred(intensity: 0.5)
        }
    }

    private func handleDragEnd() {
        guard let initialIndex = initialDragItemIndex,
              let hoverIndex = currentHoverIndex,
              initialIndex != hoverIndex else {
            // Reset without reordering
            withAnimation(.easeOut(duration: 0.2)) {
                draggingItemID = nil
                dragOffset = 0
                initialDragItemIndex = nil
                currentHoverIndex = nil
            }
            return
        }

        // Perform the reorder
        let destination = hoverIndex > initialIndex ? hoverIndex + 1 : hoverIndex
        workout.reorderDisplayItems(from: IndexSet(integer: initialIndex), to: destination)

        // Reset state
        withAnimation(.easeOut(duration: 0.2)) {
            draggingItemID = nil
            dragOffset = 0
            initialDragItemIndex = nil
            currentHoverIndex = nil
        }

        // Clear and rebuild frames after reorder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            itemFrames.removeAll()
        }
    }

    private func calculateOffset(for index: Int) -> CGFloat {
        guard let draggingID = draggingItemID,
              let initialIndex = initialDragItemIndex,
              let hoverIndex = currentHoverIndex,
              workout.displayItems[index].id != draggingID else {
            return 0
        }

        guard let draggedFrame = itemFrames[draggingID] else { return 0 }
        let itemHeight = draggedFrame.height + 12 // Include spacing

        if initialIndex < hoverIndex {
            // Dragging down - items between initial and hover move up
            if index > initialIndex && index <= hoverIndex {
                return -itemHeight
            }
        } else if initialIndex > hoverIndex {
            // Dragging up - items between hover and initial move down
            if index >= hoverIndex && index < initialIndex {
                return itemHeight
            }
        }

        return 0
    }
}

// MARK: - Exercise Item View

private struct ExerciseItemView: View {
    let item: ExerciseDisplayItem
    let workout: Workout
    let isLiveWorkout: Bool
    @ObservedObject var preferenceManager: ExercisePreferenceManager
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void
    let onReorderWithinGroup: (ExerciseGroup) -> Void

    var body: some View {
        switch item {
        case .standalone(let exercise):
            ActiveExerciseCard(
                exercise: exercise,
                currentPreference: preferenceManager.getPreference(for: exercise.exercise.name),
                isLiveWorkout: isLiveWorkout,
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
                    onSetPreference(exercise, preference)
                }
            )

        case .group(let group, let exercises):
            SupersetGroupCard(
                group: group,
                exercises: exercises,
                isLiveWorkout: isLiveWorkout,
                preferenceManager: preferenceManager,
                onExerciseTap: onExerciseTap,
                onExerciseReplace: onExerciseReplace,
                onExerciseRemove: onExerciseRemove
            )
            .contextMenu {
                Button {
                    onReorderWithinGroup(group)
                } label: {
                    Label("Reorder Exercises in \(group.groupType.displayName)", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }
}

// MARK: - Group Reorder Sheet

/// Sheet for reordering exercises within a group (superset/circuit)
struct GroupReorderSheet: View {
    let group: ExerciseGroup
    @Binding var workout: Workout
    @Environment(\.dismiss) private var dismiss

    private var groupColor: Color {
        group.groupType.swiftUIColor
    }

    /// Get exercises in this group, in group order
    private var groupExercises: [WorkoutExercise] {
        group.exerciseIds.compactMap { exerciseId in
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
                        Image(systemName: group.groupType.iconName)
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
