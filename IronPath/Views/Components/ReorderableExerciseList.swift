import SwiftUI

// MARK: - Draggable Exercise List

/// A component that displays exercises with drag handle for reordering
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
                    isDragging: isDragging,
                    onDragChanged: { translation in
                        handleDragChange(item: item, index: index, translation: translation)
                    },
                    onDragEnded: {
                        handleDragEnd()
                    },
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
                .scaleEffect(isDragging ? 1.02 : 1.0)
                .shadow(
                    color: isDragging ? .black.opacity(0.15) : .clear,
                    radius: isDragging ? 8 : 0,
                    y: isDragging ? 4 : 0
                )
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: shouldOffset)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
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
    let isDragging: Bool
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
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
                showDragHandle: true,
                onDragGesture: { value in
                    onDragChanged(value.translation.height)
                },
                onDragEnd: onDragEnded,
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
            SupersetGroupCardWithHandle(
                group: group,
                exercises: exercises,
                isLiveWorkout: isLiveWorkout,
                preferenceManager: preferenceManager,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded,
                onExerciseTap: onExerciseTap,
                onExerciseReplace: onExerciseReplace,
                onExerciseRemove: onExerciseRemove,
                onReorderWithinGroup: onReorderWithinGroup
            )
        }
    }
}

// MARK: - Superset Group Card With Handle

private struct SupersetGroupCardWithHandle: View {
    let group: ExerciseGroup
    let exercises: [WorkoutExercise]
    let isLiveWorkout: Bool
    @ObservedObject var preferenceManager: ExercisePreferenceManager
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onReorderWithinGroup: (ExerciseGroup) -> Void

    private var groupColor: Color {
        group.groupType.swiftUIColor
    }

    var body: some View {
        HStack(spacing: 0) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDragChanged(value.translation.height)
                        }
                        .onEnded { _ in
                            onDragEnded()
                        }
                )

            // The actual superset card content
            VStack(alignment: .leading, spacing: 0) {
                // Group header
                HStack(spacing: 8) {
                    Image(systemName: group.groupType.iconName)
                        .foregroundStyle(groupColor)
                    Text(group.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(groupColor)

                    Spacer()

                    // Reorder within group button
                    Button {
                        onReorderWithinGroup(group)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Exercise cards within the group
                VStack(spacing: 8) {
                    ForEach(exercises) { exercise in
                        GroupedExerciseRow(
                            exercise: exercise,
                            group: group,
                            isLiveWorkout: isLiveWorkout,
                            currentPreference: preferenceManager.getPreference(for: exercise.exercise.name),
                            onTap: { onExerciseTap(exercise) },
                            onReplace: { onExerciseReplace(exercise) },
                            onRemove: { onExerciseRemove(exercise) }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(groupColor.opacity(0.3), lineWidth: 1.5)
        )
    }
}

// MARK: - Grouped Exercise Row

private struct GroupedExerciseRow: View {
    let exercise: WorkoutExercise
    let group: ExerciseGroup
    let isLiveWorkout: Bool
    let currentPreference: ExerciseSuggestionPreference
    let onTap: () -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void

    private var groupColor: Color {
        group.groupType.swiftUIColor
    }

    var completedSetsCount: Int {
        exercise.sets.filter { $0.isCompleted }.count
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isLiveWorkout {
                    // Completion indicator
                    ZStack {
                        Circle()
                            .stroke(exercise.isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 32, height: 32)

                        if exercise.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("\(completedSetsCount)/\(exercise.sets.count)")
                                .font(.caption2)
                        }
                    }
                } else {
                    Circle()
                        .fill(groupColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "dumbbell.fill")
                                .font(.caption)
                                .foregroundStyle(groupColor)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exercise.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(exercise.sets.count) sets × \(exercise.sets.first?.targetReps ?? 0) reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Menu for this exercise
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
                        .frame(width: 32, height: 32)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
