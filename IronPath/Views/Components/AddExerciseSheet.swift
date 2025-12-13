import SwiftUI

/// Unified sheet for adding exercises to workouts (active or historical)
/// Provides both library browsing and AI-powered custom exercise generation
struct AddExerciseSheet: View {
    let existingExercises: [String]
    let userProfile: UserProfile?
    let onAdd: (Exercise) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var selectedEquipment: Equipment?

    // Custom exercise state
    @State private var customPrompt = ""
    @State private var isGenerating = false
    @State private var generationError: String?

    @ObservedObject private var customExercises = CustomExerciseStore.shared

    var filteredExercises: [Exercise] {
        var results = ExerciseDatabase.shared.exercises + customExercises.exercises

        // Filter out exercises already in workout
        results = results.filter { !existingExercises.contains($0.name) }

        if !searchText.isEmpty {
            results = results.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        if let muscleGroup = selectedMuscleGroup {
            results = results.filter {
                $0.primaryMuscleGroups.contains(muscleGroup) ||
                $0.secondaryMuscleGroups.contains(muscleGroup)
            }
        }

        if let equipment = selectedEquipment {
            results = results.filter { $0.equipment == equipment }
        }

        return results.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Source", selection: $selectedTab) {
                    Text("Library").tag(0)
                    Text("Custom").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    // Exercise Library
                    VStack(spacing: 0) {
                        // Filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Menu {
                                    Button("All Muscles") { selectedMuscleGroup = nil }
                                    Divider()
                                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                                        Button(muscle.rawValue) { selectedMuscleGroup = muscle }
                                    }
                                } label: {
                                    FilterChip(
                                        title: selectedMuscleGroup?.rawValue ?? "Muscle",
                                        isActive: selectedMuscleGroup != nil
                                    )
                                }

                                Menu {
                                    Button("All Equipment") { selectedEquipment = nil }
                                    Divider()
                                    ForEach(Equipment.allCases, id: \.self) { equip in
                                        Button(equip.rawValue) { selectedEquipment = equip }
                                    }
                                } label: {
                                    FilterChip(
                                        title: selectedEquipment?.rawValue ?? "Equipment",
                                        isActive: selectedEquipment != nil
                                    )
                                }

                                if selectedMuscleGroup != nil || selectedEquipment != nil {
                                    Button {
                                        selectedMuscleGroup = nil
                                        selectedEquipment = nil
                                    } label: {
                                        Text("Clear")
                                            .font(.subheadline)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .background(Color(.systemGroupedBackground))

                        // Exercise list
                        List(filteredExercises) { exercise in
                            Button {
                                onAdd(exercise)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(exercise.name)
                                                .fontWeight(.medium)
                                            if exercise.isCustom {
                                                Text("Custom")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple)
                                                    .foregroundStyle(.white)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text("\(exercise.equipment.rawValue) • \(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                        .listStyle(.plain)
                    }
                    .searchable(text: $searchText, prompt: "Search exercises")
                } else {
                    // Custom exercise generator
                    Form {
                        Section {
                            TextField("Describe the exercise you want...", text: $customPrompt, axis: .vertical)
                                .lineLimit(3...6)
                        } header: {
                            Text("Describe Your Exercise")
                        } footer: {
                            Text("Examples:\n• \"A chest exercise using only resistance bands\"\n• \"An ab exercise I can do at home\"\n• \"A rear delt exercise on the cable machine\"")
                        }

                        Section {
                            Button {
                                generateCustomExercise()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isGenerating {
                                        ProgressView()
                                            .padding(.trailing, 8)
                                        Text("Generating...")
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("Generate with AI")
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(customPrompt.isEmpty || isGenerating)
                        }

                        if let error = generationError {
                            Section {
                                Text(error)
                                    .foregroundStyle(.red)
                            }
                        }

                        // Show custom exercises
                        if !customExercises.exercises.isEmpty {
                            Section {
                                ForEach(customExercises.exercises) { exercise in
                                    Button {
                                        onAdd(exercise)
                                        dismiss()
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(exercise.name)
                                                    .fontWeight(.medium)
                                                Text(exercise.equipment.rawValue)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.title2)
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                                .onDelete { indexSet in
                                    customExercises.exercises.remove(atOffsets: indexSet)
                                }
                            } header: {
                                Text("Your Custom Exercises")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateCustomExercise() {
        guard !customPrompt.isEmpty else { return }

        isGenerating = true
        generationError = nil

        // Use active gym profile's equipment if available
        guard let profile = userProfile else {
            generationError = "User profile not available"
            isGenerating = false
            return
        }

        Task {
            do {
                let provider = AIProviderManager.shared.currentProvider
                let exercise = try await provider.generateCustomExercise(
                    description: customPrompt,
                    profile: profile
                )

                await MainActor.run {
                    // Check for duplicates before adding
                    if customExercises.exerciseExists(name: exercise.name) {
                        generationError = "An exercise named '\(exercise.name)' already exists. Please try a different description."
                        isGenerating = false
                        return
                    }

                    do {
                        try customExercises.addExercise(exercise)
                        onAdd(exercise)
                        dismiss()
                    } catch {
                        generationError = error.localizedDescription
                        isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    generationError = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}
