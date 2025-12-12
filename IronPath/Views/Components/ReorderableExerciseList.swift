import SwiftUI
import UniformTypeIdentifiers

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
    @State private var draggingItem: ExerciseDisplayItem?
    @State private var draggedOverItem: ExerciseDisplayItem?

    // State for group reordering sheet
    @State private var groupToReorder: ExerciseGroup?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(workout.displayItems) { item in
                DraggableItemView(
                    item: item,
                    workout: workout,
                    isLiveWorkout: isLiveWorkout,
                    preferenceManager: preferenceManager,
                    draggingItem: $draggingItem,
                    draggedOverItem: $draggedOverItem,
                    onExerciseTap: onExerciseTap,
                    onExerciseReplace: onExerciseReplace,
                    onExerciseRemove: onExerciseRemove,
                    onSetPreference: onSetPreference,
                    onReorderWithinGroup: { group in
                        groupToReorder = group
                    },
                    onDrop: { fromItem, toItem in
                        reorderItems(from: fromItem, to: toItem)
                    }
                )
            }
        }
        .sheet(item: $groupToReorder) { group in
            GroupReorderSheet(group: group, workout: $workout)
        }
    }

    private func reorderItems(from sourceItem: ExerciseDisplayItem, to destItem: ExerciseDisplayItem) {
        let items = workout.displayItems
        guard let sourceIndex = items.firstIndex(where: { $0.id == sourceItem.id }),
              let destIndex = items.firstIndex(where: { $0.id == destItem.id }),
              sourceIndex != destIndex else { return }

        let direction = sourceIndex < destIndex ? 1 : 0
        workout.reorderDisplayItems(from: IndexSet(integer: sourceIndex), to: destIndex + direction)
    }
}

// MARK: - Draggable Item View

private struct DraggableItemView: View {
    let item: ExerciseDisplayItem
    let workout: Workout
    let isLiveWorkout: Bool
    @ObservedObject var preferenceManager: ExercisePreferenceManager
    @Binding var draggingItem: ExerciseDisplayItem?
    @Binding var draggedOverItem: ExerciseDisplayItem?
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void
    let onReorderWithinGroup: (ExerciseGroup) -> Void
    let onDrop: (ExerciseDisplayItem, ExerciseDisplayItem) -> Void

    private var isDragging: Bool {
        draggingItem?.id == item.id
    }

    private var isDropTarget: Bool {
        draggedOverItem?.id == item.id && draggingItem?.id != item.id
    }

    var body: some View {
        itemContent
            .opacity(isDragging ? 0.5 : 1.0)
            .overlay(
                // Drop indicator
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
                    .opacity(isDropTarget ? 1 : 0)
            )
            .onDrag {
                self.draggingItem = item
                return NSItemProvider(object: item.id as NSString)
            }
            .onDrop(of: [.text], delegate: ExerciseDropDelegate(
                item: item,
                draggingItem: $draggingItem,
                draggedOverItem: $draggedOverItem,
                onDrop: onDrop
            ))
    }

    @ViewBuilder
    private var itemContent: some View {
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

// MARK: - Exercise Drop Delegate

private struct ExerciseDropDelegate: DropDelegate {
    let item: ExerciseDisplayItem
    @Binding var draggingItem: ExerciseDisplayItem?
    @Binding var draggedOverItem: ExerciseDisplayItem?
    let onDrop: (ExerciseDisplayItem, ExerciseDisplayItem) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem, dragging.id != item.id else { return }
        draggedOverItem = item
    }

    func dropExited(info: DropInfo) {
        draggedOverItem = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let dragging = draggingItem else { return false }
        onDrop(dragging, item)
        draggingItem = nil
        draggedOverItem = nil
        return true
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
