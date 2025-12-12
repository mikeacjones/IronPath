import SwiftUI

// MARK: - Reorderable Exercise List

/// A shared component that displays exercises in either normal mode (VStack with cards) or reorder mode (List with drag handles)
struct ReorderableExerciseList: View {
    @Binding var workout: Workout
    let isLiveWorkout: Bool
    let isReordering: Bool
    @ObservedObject var preferenceManager: ExercisePreferenceManager

    // Callbacks for exercise interactions
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void

    // State for group reordering sheet
    @State private var groupToReorder: ExerciseGroup?

    var body: some View {
        if isReordering {
            ReorderingListView(
                workout: $workout,
                onGroupTap: { group in
                    groupToReorder = group
                }
            )
            .sheet(item: $groupToReorder) { group in
                GroupReorderSheet(group: group, workout: $workout)
            }
        } else {
            NormalDisplayView(
                workout: workout,
                isLiveWorkout: isLiveWorkout,
                preferenceManager: preferenceManager,
                onExerciseTap: onExerciseTap,
                onExerciseReplace: onExerciseReplace,
                onExerciseRemove: onExerciseRemove,
                onSetPreference: onSetPreference
            )
        }
    }
}

// MARK: - Reordering List View

/// List-based view with drag handles for reordering
private struct ReorderingListView: View {
    @Binding var workout: Workout
    let onGroupTap: (ExerciseGroup) -> Void

    var body: some View {
        List {
            ForEach(workout.displayItems) { item in
                ReorderRow(item: item, onGroupTap: onGroupTap)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
            .onMove { source, destination in
                workout.reorderDisplayItems(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }
}

// MARK: - Reorder Row

/// A row in the reordering list - shows simplified info for standalone or group
private struct ReorderRow: View {
    let item: ExerciseDisplayItem
    let onGroupTap: (ExerciseGroup) -> Void

    var body: some View {
        switch item {
        case .standalone(let exercise):
            StandaloneReorderRow(exercise: exercise)
        case .group(let group, let exercises):
            GroupReorderRow(group: group, exercises: exercises, onTap: {
                onGroupTap(group)
            })
        }
    }
}

/// Row for a standalone exercise in reorder mode
private struct StandaloneReorderRow: View {
    let exercise: WorkoutExercise

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.title3)
                .foregroundStyle(.blue)
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

/// Row for a group (superset/circuit) in reorder mode
private struct GroupReorderRow: View {
    let group: ExerciseGroup
    let exercises: [WorkoutExercise]
    let onTap: () -> Void

    private var groupColor: Color {
        group.groupType.swiftUIColor
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: group.groupType.iconName)
                    .font(.title3)
                    .foregroundStyle(groupColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(group.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(groupColor)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text("\(exercises.count) exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Show exercise names
                    Text(exercises.map { $0.exercise.name }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Hint to tap for internal reordering
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(groupColor.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
                        Text("Drag to reorder exercises within this \(group.groupType.displayName.lowercased())")
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

// MARK: - Normal Display View

/// Normal VStack display with exercise cards (non-reordering mode)
private struct NormalDisplayView: View {
    let workout: Workout
    let isLiveWorkout: Bool
    @ObservedObject var preferenceManager: ExercisePreferenceManager
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void
    let onSetPreference: (WorkoutExercise, ExerciseSuggestionPreference) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(workout.displayItems) { item in
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
                }
            }
        }
    }
}
