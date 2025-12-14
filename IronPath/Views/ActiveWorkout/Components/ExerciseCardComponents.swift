import SwiftUI

// MARK: - Exercise Group Info

/// Information about an exercise's position within a group
struct ExerciseGroupInfo {
    let group: ExerciseGroup
    let position: Int
    let isFirst: Bool
    let isLast: Bool
}

// MARK: - Exercise Card With Grouping

/// Wrapper that adds grouping visual indicators to exercise cards
struct ExerciseCardWithGrouping: View {
    let exercise: WorkoutExercise
    let groupInfo: ExerciseGroupInfo?
    let currentPreference: ExerciseSuggestionPreference
    let onTap: () -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void
    let onSetPreference: (ExerciseSuggestionPreference) -> Void

    private var groupColor: Color {
        guard let info = groupInfo else { return .clear }
        switch info.group.groupType.color {
        case "purple": return .purple
        case "indigo": return .indigo
        case "pink": return .pink
        case "teal": return .teal
        default: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Group indicator bar on the left
            if let info = groupInfo {
                VStack(spacing: 0) {
                    // Top connector (hidden for first item)
                    Rectangle()
                        .fill(info.isFirst ? Color.clear : groupColor)
                        .frame(width: 3)

                    // Group type icon (only on first item)
                    if info.isFirst {
                        VStack(spacing: 2) {
                            Image(systemName: info.group.groupType.iconName)
                                .font(.caption2)
                                .foregroundStyle(groupColor)
                            Text(info.group.groupType.displayName)
                                .font(.system(size: 8))
                                .foregroundStyle(groupColor)
                        }
                        .frame(width: 40)
                        .padding(.vertical, 4)
                    }

                    // Bottom connector (hidden for last item)
                    Rectangle()
                        .fill(info.isLast ? Color.clear : groupColor)
                        .frame(width: 3)
                }
                .frame(width: 44)
            }

            // The actual exercise card
            ActiveExerciseCard(
                exercise: exercise,
                currentPreference: currentPreference,
                onTap: onTap,
                onReplace: onReplace,
                onRemove: onRemove,
                onSetPreference: onSetPreference
            )
            .overlay(
                // Subtle border for grouped exercises
                RoundedRectangle(cornerRadius: 12)
                    .stroke(groupInfo != nil ? groupColor.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Superset Group Card

/// Displays a group of exercises (superset/circuit) with a visual container
struct SupersetGroupCard: View {
    let group: ExerciseGroup
    let exercises: [WorkoutExercise]
    var isLiveWorkout: Bool = true
    var preferenceManager: ExercisePreferenceManager
    let onExerciseTap: (WorkoutExercise) -> Void
    let onExerciseReplace: (WorkoutExercise) -> Void
    let onExerciseRemove: (WorkoutExercise) -> Void

    private var groupColor: Color {
        group.groupType.swiftUIColor
    }

    private var completedExercisesInGroup: Int {
        exercises.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            HStack(spacing: 8) {
                Image(systemName: group.groupType.iconName)
                    .font(.subheadline)
                    .foregroundStyle(groupColor)

                Text(group.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(groupColor)

                Spacer()

                // Progress indicator (only shown during live workout)
                if isLiveWorkout {
                    Text("\(completedExercisesInGroup)/\(exercises.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(exercises.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(groupColor.opacity(0.1))

            // Exercise cards within the group
            VStack(spacing: 8) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
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
                            preferenceManager.setPreference(
                                preference,
                                for: exercise.exercise.name
                            )
                        }
                    )

                    // Arrow between exercises (except after last)
                    if index < exercises.count - 1 {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(groupColor.opacity(0.6))
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(groupColor, lineWidth: 2)
        )
    }
}

// MARK: - Active Exercise Card

/// Card showing exercise status and actions during active workout
struct ActiveExerciseCard: View {
    let exercise: WorkoutExercise
    let currentPreference: ExerciseSuggestionPreference
    var isLiveWorkout: Bool = true
    var showDragHandle: Bool = false
    var onDragGesture: ((DragGesture.Value) -> Void)?
    var onDragEnd: (() -> Void)?
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
        HStack(spacing: 0) {
            // Drag handle (shown when reordering is enabled)
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                onDragGesture?(value)
                            }
                            .onEnded { _ in
                                onDragEnd?()
                            }
                    )
            }

            Button(action: onTap) {
                HStack(spacing: 16) {
                    if isLiveWorkout {
                    // Completion indicator with progress circle (live workout)
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                            .frame(width: 44, height: 44)

                        // Progress arc (only shown when not fully completed)
                        if !exercise.isCompleted && completedSetsCount > 0 {
                            Circle()
                                .trim(from: 0, to: setProgress)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.3), value: setProgress)
                        }

                        // Completed state: full green circle
                        if exercise.isCompleted {
                            Circle()
                                .stroke(Color.green, lineWidth: 3)
                                .frame(width: 44, height: 44)
                        }

                        if exercise.isCompleted {
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
                    // Simple dumbbell icon for preview mode
                    Image(systemName: "dumbbell.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                }

                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(exercise.exercise.name)
                            .font(.headline)
                            .foregroundStyle(isLiveWorkout && exercise.isCompleted ? .secondary : .primary)

                        // Preference indicator
                        if currentPreference != .normal {
                            Image(systemName: currentPreference.iconName)
                                .font(.caption)
                                .foregroundStyle(preferenceColor)
                        }
                    }

                    HStack {
                        Label("\(exercise.sets.count) sets", systemImage: "repeat")
                        Text("•")
                        Label("\(exercise.sets.first?.actualReps ?? exercise.sets.first?.targetReps ?? 0) reps", systemImage: "number")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Actions menu
                Menu {
                    Button {
                        onReplace()
                    } label: {
                        Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Divider()

                    // Suggestion preference submenu
                    Menu {
                        ForEach(ExerciseSuggestionPreference.allCases, id: \.self) { preference in
                            Button {
                                onSetPreference(preference)
                            } label: {
                                HStack {
                                    Label(preference.displayName, systemImage: preference.iconName)
                                    if preference == currentPreference {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Suggestion Preference", systemImage: "hand.thumbsup")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove from Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)
        }
        .background(isLiveWorkout && exercise.isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLiveWorkout && exercise.isCompleted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
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

// MARK: - Superset Header View

/// Header shown in exercise detail sheet when exercise is part of a superset/circuit
struct SupersetHeaderView: View {
    let groupInfo: ExerciseGroupInfo
    let currentExerciseName: String
    let nextExerciseName: String?

    var body: some View {
        VStack(spacing: 8) {
            // Group type badge
            HStack {
                Image(systemName: groupInfo.group.groupType.iconName)
                Text(groupInfo.group.groupType.displayName)
                    .fontWeight(.semibold)

                Spacer()

                // Position indicator
                Text("Exercise \(groupInfo.position + 1) of \(groupInfo.group.exerciseCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(groupInfo.group.groupType.swiftUIColor)

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<groupInfo.group.exerciseCount, id: \.self) { index in
                    Circle()
                        .fill(index == groupInfo.position ? groupInfo.group.groupType.swiftUIColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Instructions
            if groupInfo.group.restBetweenExercises == 0 {
                Text("No rest between exercises - move directly to next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(groupInfo.group.groupType.swiftUIColor.opacity(0.1))
        .cornerRadius(12)
    }
}
