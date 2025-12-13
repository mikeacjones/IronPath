import SwiftUI

// MARK: - Standalone Exercise Card

struct StandaloneExerciseCard: View {
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
            HStack(spacing: 12) {
                if isLiveWorkout {
                    progressIndicator
                } else {
                    Image(systemName: "dumbbell.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                }

                exerciseInfo

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            exerciseMenu
        }
        .padding(12)
    }

    private var progressIndicator: some View {
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
    }

    private var exerciseInfo: some View {
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
    }

    private var exerciseMenu: some View {
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

    private var preferenceColor: Color {
        switch currentPreference {
        case .normal: return .gray
        case .preferMore: return .green
        case .preferLess: return .orange
        case .doNotSuggest: return .red
        }
    }
}

// MARK: - Group Exercise Row

struct GroupExerciseRow: View {
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
            HStack(spacing: 10) {
                if isLiveWorkout {
                    progressIndicator
                } else {
                    staticIndicator
                }

                exerciseInfo

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            exerciseMenu
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var progressIndicator: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 28, height: 28)

            if !exercise.isCompleted && completedSetsCount > 0 {
                Circle()
                    .trim(from: 0, to: setProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: setProgress)
            }

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
    }

    private var staticIndicator: some View {
        Circle()
            .fill(groupColor.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(groupColor)
            )
    }

    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(exercise.exercise.name)
                .font(.subheadline)
                .fontWeight(.medium)
            Text("\(exercise.sets.count) sets × \(exercise.sets.first?.targetReps ?? 0) reps")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var exerciseMenu: some View {
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
}
