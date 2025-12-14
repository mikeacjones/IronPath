import SwiftUI

// MARK: - Superset Group Content

struct SupersetGroupContent: View {
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

    private var nextExerciseWithIncompleteSets: WorkoutExercise? {
        for exercise in exercises {
            if exercise.sets.contains(where: { !$0.isCompleted }) {
                return exercise
            }
        }
        return exercises.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            groupHeader
            exercisesList
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(groupColor.opacity(0.3), lineWidth: 1.5)
        )
    }

    private var groupHeader: some View {
        HStack(spacing: 8) {
            Button {
                if isLiveWorkout, let nextExercise = nextExerciseWithIncompleteSets {
                    onExerciseTap(nextExercise)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: group.groupType.iconName)
                        .foregroundStyle(groupColor)
                    Text(group.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(groupColor)

                    Spacer()

                    if isLiveWorkout {
                        let completedSets = exercises.flatMap { $0.sets }.filter { $0.isCompleted }.count
                        let totalSets = exercises.flatMap { $0.sets }.count
                        Text("\(completedSets)/\(totalSets)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .allowsHitTesting(isLiveWorkout)

            groupMenu
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var groupMenu: some View {
        Menu {
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

    private var exercisesList: some View {
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
}
