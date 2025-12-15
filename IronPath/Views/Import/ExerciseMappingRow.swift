import SwiftUI

// MARK: - Exercise Mapping Row

/// Row view for mapping an unmapped exercise to a database exercise
struct ExerciseMappingRow: View {
    let unmappedExercise: UnmappedExercise
    @Bindable var session: ImportSession
    let exerciseMatcher: ExerciseMatching

    @State private var suggestions: [ExerciseMatch] = []
    @State private var showingExercisePicker = false
    @State private var showingCustomExerciseCreator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Unmapped exercise name
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(unmappedExercise.name)
                        .font(.headline)

                    Text("Used in \(unmappedExercise.count) workout(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if currentMapping != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Current mapping or suggestions
            if let mapped = currentMapping {
                mappedExerciseView(mapped)
            } else if !suggestions.isEmpty {
                suggestionsView
            } else {
                noSuggestionsView
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadSuggestions()
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(
                onSelect: { exercise in
                    session.addMapping(from: unmappedExercise.name, to: exercise)
                    showingExercisePicker = false
                }
            )
        }
        .sheet(isPresented: $showingCustomExerciseCreator) {
            CustomExerciseCreatorSheet(
                suggestedName: unmappedExercise.name,
                onSave: { exercise in
                    session.addMapping(from: unmappedExercise.name, to: exercise)
                    showingCustomExerciseCreator = false
                }
            )
        }
    }

    // MARK: - Current Mapping

    private var currentMapping: Exercise? {
        session.exerciseMappings[unmappedExercise.name]
    }

    private func mappedExerciseView(_ exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Mapped to:", systemImage: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !exercise.alternateNames.isEmpty {
                    Text(exercise.alternateNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                session.removeMapping(for: unmappedExercise.name)
            } label: {
                Text("Change")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Suggestions

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested matches:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(suggestions.prefix(3)) { match in
                Button {
                    session.addMapping(from: unmappedExercise.name, to: match.exercise)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.exercise.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            HStack(spacing: 8) {
                                matchTypeBadge(match.matchType)
                                similarityIndicator(match.similarity)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Browse All Exercises", systemImage: "magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showingCustomExerciseCreator = true
                } label: {
                    Label("Create Custom Exercise", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var noSuggestionsView: some View {
        VStack(spacing: 8) {
            Text("No automatic matches found")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Browse Exercises", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showingCustomExerciseCreator = true
                } label: {
                    Label("Create Custom", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Helper Views

    private func matchTypeBadge(_ type: ExerciseMatch.MatchType) -> some View {
        let (label, color) = matchTypeInfo(type)
        return Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(4)
    }

    private func matchTypeInfo(_ type: ExerciseMatch.MatchType) -> (String, Color) {
        switch type {
        case .exact:
            return ("Exact", .green)
        case .alternate:
            return ("Alternate Name", .blue)
        case .fuzzy:
            return ("Similar", .orange)
        }
    }

    private func similarityIndicator(_ similarity: Double) -> some View {
        let percentage = Int(similarity * 100)
        return Text("\(percentage)% match")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: - Methods

    private func loadSuggestions() {
        suggestions = exerciseMatcher.findMatches(for: unmappedExercise.name, equipment: nil)
    }
}

// MARK: - Exercise Picker Sheet

/// Simple exercise picker for import mapping
private struct ExercisePickerSheet: View {
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedEquipment: Equipment?

    private var filteredExercises: [Exercise] {
        let allExercises = ExerciseDatabase.shared.exercises

        var exercises = allExercises
        if let equipment = selectedEquipment {
            exercises = exercises.filter { $0.equipment == equipment }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.alternateNames.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return exercises.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            HStack {
                                Label(exercise.equipment.rawValue, systemImage: "dumbbell")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if !exercise.primaryMuscleGroups.isEmpty {
                                    Text(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Picker("Equipment", selection: $selectedEquipment) {
                        Text("All").tag(Equipment?.none)
                        ForEach(Equipment.allCases, id: \.self) { equipment in
                            Text(equipment.rawValue).tag(Equipment?.some(equipment))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

// MARK: - Custom Exercise Creator Sheet

/// Sheet for creating a custom exercise during import mapping
private struct CustomExerciseCreatorSheet: View {
    let suggestedName: String
    let onSave: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedEquipment: Equipment = .barbell
    @State private var selectedPrimaryMuscles: Set<MuscleGroup> = []
    @State private var selectedSecondaryMuscles: Set<MuscleGroup> = []

    init(suggestedName: String, onSave: @escaping (Exercise) -> Void) {
        self.suggestedName = suggestedName
        self.onSave = onSave
        _name = State(initialValue: suggestedName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("Name", text: $name)
                }

                Section("Equipment") {
                    Picker("Equipment Type", selection: $selectedEquipment) {
                        ForEach(Equipment.allCases, id: \.self) { equipment in
                            Text(equipment.rawValue).tag(equipment)
                        }
                    }
                }

                Section("Primary Muscles") {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        Button {
                            toggleMuscle(muscle, in: .primary)
                        } label: {
                            HStack {
                                Text(muscle.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedPrimaryMuscles.contains(muscle) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Secondary Muscles (Optional)") {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        Button {
                            toggleMuscle(muscle, in: .secondary)
                        } label: {
                            HStack {
                                Text(muscle.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSecondaryMuscles.contains(muscle) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .disabled(selectedPrimaryMuscles.contains(muscle))
                    }
                }
            }
            .navigationTitle("Create Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedPrimaryMuscles.isEmpty
    }

    private enum MuscleSelection {
        case primary
        case secondary
    }

    private func toggleMuscle(_ muscle: MuscleGroup, in selection: MuscleSelection) {
        switch selection {
        case .primary:
            if selectedPrimaryMuscles.contains(muscle) {
                selectedPrimaryMuscles.remove(muscle)
            } else {
                selectedPrimaryMuscles.insert(muscle)
                selectedSecondaryMuscles.remove(muscle) // Can't be both
            }
        case .secondary:
            if selectedSecondaryMuscles.contains(muscle) {
                selectedSecondaryMuscles.remove(muscle)
            } else {
                selectedSecondaryMuscles.insert(muscle)
            }
        }
    }

    private func saveExercise() {
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespaces),
            primaryMuscleGroups: selectedPrimaryMuscles,
            secondaryMuscleGroups: selectedSecondaryMuscles,
            equipment: selectedEquipment,
            isCustom: true
        )

        // Save to custom exercise store
        CustomExerciseStore.shared.addExerciseUnchecked(exercise)

        onSave(exercise)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let session = ImportSession()
    let unmapped = UnmappedExercise(name: "DB Bench", count: 5)

    return List {
        ExerciseMappingRow(
            unmappedExercise: unmapped,
            session: session,
            exerciseMatcher: ExerciseMatcher()
        )
    }
    .listStyle(.plain)
}
