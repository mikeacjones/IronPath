import SwiftUI

/// View for selecting and editing AI-generated exercises before saving
struct ExerciseSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var customExerciseStore = CustomExerciseStore.shared
    @ObservedObject private var customEquipmentStore = CustomEquipmentStore.shared

    @State private var draft: CustomEquipmentDraft
    @State private var editingExercise: ExerciseDraft?
    @State private var errorMessage: String?
    @State private var isSaving = false

    let onComplete: () -> Void

    init(draft: CustomEquipmentDraft, onComplete: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onComplete = onComplete
    }

    private var selectedCount: Int {
        draft.selectedExerciseIds.count
    }

    private var totalCount: Int {
        draft.suggestedExercises.count
    }

    var body: some View {
        List {
            // Equipment Summary Section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: draft.equipment.icon)
                        .font(.title)
                        .foregroundStyle(.purple)
                        .frame(width: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.equipment.displayName)
                            .font(.headline)
                        Text(draft.equipment.equipmentType.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(selectedCount)/\(totalCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Equipment")
            }

            // Selection Controls Section
            Section {
                HStack {
                    Button("Select All") {
                        selectAll()
                    }
                    .disabled(selectedCount == totalCount)

                    Spacer()

                    Button("Deselect All") {
                        deselectAll()
                    }
                    .disabled(selectedCount == 0)
                }
            }

            // Exercises Section
            Section {
                if draft.suggestedExercises.isEmpty {
                    Text("No exercises were generated")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(draft.suggestedExercises) { exercise in
                        ExerciseDraftRow(
                            exercise: exercise,
                            isSelected: draft.selectedExerciseIds.contains(exercise.id),
                            isDuplicate: customExerciseStore.exerciseExists(name: exercise.name),
                            onToggle: { toggleSelection(exercise) },
                            onEdit: { editingExercise = exercise }
                        )
                    }
                }
            } header: {
                Text("Suggested Exercises")
            } footer: {
                Text("Tap to select/deselect. Exercises marked as duplicates already exist and will be skipped.")
            }

            // Error Section
            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Select Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSaving)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving)
            }
        }
        .sheet(item: $editingExercise) { exercise in
            EditExerciseDraftView(
                exercise: exercise,
                equipmentName: draft.equipment.displayName
            ) { updated in
                updateExercise(updated)
            }
        }
    }

    private func selectAll() {
        draft.selectedExerciseIds = Set(draft.suggestedExercises.map { $0.id })
    }

    private func deselectAll() {
        draft.selectedExerciseIds.removeAll()
    }

    private func toggleSelection(_ exercise: ExerciseDraft) {
        if draft.selectedExerciseIds.contains(exercise.id) {
            draft.selectedExerciseIds.remove(exercise.id)
        } else {
            draft.selectedExerciseIds.insert(exercise.id)
        }
    }

    private func updateExercise(_ updated: ExerciseDraft) {
        if let index = draft.suggestedExercises.firstIndex(where: { $0.id == updated.id }) {
            draft.suggestedExercises[index] = updated
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        // First, save the equipment
        do {
            try customEquipmentStore.addEquipment(draft.equipment)
        } catch {
            errorMessage = "Failed to save equipment: \(error.localizedDescription)"
            isSaving = false
            return
        }

        // Then, save selected exercises (skipping duplicates)
        let selectedExercises = draft.suggestedExercises
            .filter { draft.selectedExerciseIds.contains($0.id) }
            .map { exerciseDraft -> Exercise in
                // Map Equipment enum - for custom equipment, use "Other" as the Equipment type
                let equipmentType = Equipment.fromString(draft.equipment.displayName) ?? .bodyweightOnly

                return exerciseDraft.toExercise(
                    equipment: equipmentType,
                    customEquipmentId: draft.equipment.id
                )
            }

        let result = customExerciseStore.addExercises(selectedExercises)

        isSaving = false

        // Show summary if some were skipped
        if !result.skipped.isEmpty && result.added.isEmpty {
            errorMessage = "All selected exercises already exist"
        } else {
            onComplete()
        }
    }
}

// MARK: - Exercise Draft Row

struct ExerciseDraftRow: View {
    let exercise: ExerciseDraft
    let isSelected: Bool
    let isDuplicate: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            // Selection indicator
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.name)
                        .fontWeight(.medium)
                        .strikethrough(isDuplicate)

                    if isDuplicate {
                        Text("Duplicate")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .cornerRadius(4)
                    }
                }

                Text(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

// MARK: - Edit Exercise Draft View

struct EditExerciseDraftView: View {
    @Environment(\.dismiss) var dismiss

    @State private var exercise: ExerciseDraft
    let equipmentName: String
    let onSave: (ExerciseDraft) -> Void

    init(exercise: ExerciseDraft, equipmentName: String, onSave: @escaping (ExerciseDraft) -> Void) {
        _exercise = State(initialValue: exercise)
        self.equipmentName = equipmentName
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise Name", text: $exercise.name)
                } header: {
                    Text("Name")
                }

                Section {
                    HStack {
                        Text("Equipment")
                        Spacer()
                        Text(equipmentName)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    MuscleGroupPicker(
                        title: "Primary Muscles",
                        selection: $exercise.primaryMuscleGroups
                    )

                    MuscleGroupPicker(
                        title: "Secondary Muscles",
                        selection: $exercise.secondaryMuscleGroups
                    )
                } header: {
                    Text("Target Muscles")
                }

                Section {
                    Picker("Difficulty", selection: $exercise.difficulty) {
                        ForEach(ExerciseDifficulty.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section {
                    TextEditor(text: $exercise.instructions)
                        .frame(minHeight: 100)
                } header: {
                    Text("Instructions")
                }

                Section {
                    TextEditor(text: $exercise.formTips)
                        .frame(minHeight: 100)
                } header: {
                    Text("Form Tips")
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(exercise.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Muscle Group Picker

struct MuscleGroupPicker: View {
    let title: String
    @Binding var selection: Set<MuscleGroup>

    var body: some View {
        NavigationLink {
            MuscleGroupSelectionView(title: title, selection: $selection)
        } label: {
            HStack {
                Text(title)
                Spacer()
                if selection.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    Text(selection.map { $0.rawValue }.sorted().joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct MuscleGroupSelectionView: View {
    let title: String
    @Binding var selection: Set<MuscleGroup>

    var body: some View {
        List {
            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                Button {
                    if selection.contains(muscle) {
                        selection.remove(muscle)
                    } else {
                        selection.insert(muscle)
                    }
                } label: {
                    HStack {
                        Text(muscle.rawValue)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection.contains(muscle) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ExerciseSelectionView(
            draft: CustomEquipmentDraft(
                equipment: CustomEquipment(
                    id: UUID(),
                    name: "cable-crossover",
                    displayName: "Cable Crossover",
                    icon: "figure.strengthtraining.traditional",
                    equipmentType: .specificMachine,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                suggestedExercises: [
                    ExerciseDraft(
                        id: UUID(),
                        name: "Cable Fly",
                        primaryMuscleGroups: [.chest],
                        secondaryMuscleGroups: [.shoulders],
                        equipmentName: "Cable Crossover",
                        difficulty: .intermediate,
                        instructions: "Stand in the center of the cable machine...",
                        formTips: "Keep a slight bend in your elbows..."
                    )
                ]
            )
        ) {
            print("Complete")
        }
    }
}
