import SwiftUI

// MARK: - Group Reorder Sheet

struct GroupReorderSheet: View {
    let group: ExerciseGroup
    @Binding var workout: Workout
    @Environment(\.dismiss) private var dismiss

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
                exerciseSelectionSection
                if selectedExerciseIds.count >= 2 {
                    groupTypeSection
                    restTimesSection
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
                if newCount >= 2 {
                    groupType = suggestedGroupType
                }
            }
        }
    }

    private var exerciseSelectionSection: some View {
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
    }

    private var groupTypeSection: some View {
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
    }

    private var restTimesSection: some View {
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

    private func toggleSelection(_ id: UUID) {
        if selectedExerciseIds.contains(id) {
            selectedExerciseIds.remove(id)
        } else {
            selectedExerciseIds.insert(id)
        }
    }

    private func createGroup() {
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
        workout.rebuildExercisesOrder()

        onGroupCreated()
        dismiss()
    }
}
