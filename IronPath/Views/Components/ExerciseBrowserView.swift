import SwiftUI

/// Full exercise browser for selecting a replacement exercise
/// Shows all exercises sorted by similarity, with search and filtering options
struct ExerciseBrowserView: View {
    let sourceExercise: Exercise
    let excludedExerciseNames: [String]
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showSimilarOnly = true
    @State private var selectedEquipment: Equipment?
    @State private var selectedMuscleGroup: MuscleGroup?

    /// Minimum similarity score to show when filtering
    private let similarityThreshold: Double = 0.25

    /// All exercises (built-in + custom) with similarity scores
    private var allExercisesWithScores: [(Exercise, Double)] {
        let availableEquipment = GymProfileManager.shared.activeProfile?.availableEquipment ?? Set(Equipment.allCases)
        let availableMachines = GymProfileManager.shared.activeProfile?.availableMachines ?? Set(SpecificMachine.allCases)

        return ExerciseSimilarityService.shared.getAllExercisesSortedBySimilarity(
            to: sourceExercise,
            excludeNames: Set(excludedExerciseNames),
            availableEquipment: availableEquipment,
            availableMachines: availableMachines
        )
    }

    /// Filtered and sorted exercises
    private var filteredExercises: [(Exercise, Double)] {
        var results = allExercisesWithScores

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter { (exercise, _) in
                exercise.name.lowercased().contains(query) ||
                exercise.alternateNames.contains { $0.lowercased().contains(query) }
            }
        }

        // Apply equipment filter
        if let equipment = selectedEquipment {
            results = results.filter { $0.0.equipment == equipment }
        }

        // Apply muscle group filter
        if let muscleGroup = selectedMuscleGroup {
            results = results.filter { exercise, _ in
                exercise.primaryMuscleGroups.contains(muscleGroup) ||
                exercise.secondaryMuscleGroups.contains(muscleGroup)
            }
        }

        // Apply similarity threshold if enabled
        if showSimilarOnly {
            results = results.filter { $0.1 >= similarityThreshold }
        }

        return results
    }

    var body: some View {
        List {
            // Filter controls
            Section {
                Toggle(isOn: $showSimilarOnly) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(.blue)
                        Text("Show Similar Only")
                    }
                }

                // Equipment filter
                Picker("Equipment", selection: $selectedEquipment) {
                    Text("All Equipment").tag(nil as Equipment?)
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Text(equipment.rawValue).tag(equipment as Equipment?)
                    }
                }

                // Muscle group filter
                Picker("Muscle Group", selection: $selectedMuscleGroup) {
                    Text("All Muscles").tag(nil as MuscleGroup?)
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        Text(muscle.rawValue).tag(muscle as MuscleGroup?)
                    }
                }
            } header: {
                Text("Filters")
            }

            // Results
            Section {
                if filteredExercises.isEmpty {
                    ContentUnavailableView {
                        Label("No Exercises Found", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try adjusting your filters or search term")
                    }
                } else {
                    ForEach(filteredExercises, id: \.0.id) { (exercise, score) in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            ExerciseBrowserRow(
                                exercise: exercise,
                                similarityScore: score,
                                sourceExercise: sourceExercise
                            )
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Exercises")
                    Spacer()
                    Text("\(filteredExercises.count) results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises...")
        .navigationTitle("Browse Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise Browser Row

struct ExerciseBrowserRow: View {
    let exercise: Exercise
    let similarityScore: Double
    let sourceExercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    // Equipment
                    Label(exercise.equipment.rawValue, systemImage: "dumbbell")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Shared muscle groups indicator
                    let sharedMuscles = exercise.primaryMuscleGroups.intersection(sourceExercise.primaryMuscleGroups)
                    if !sharedMuscles.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(sharedMuscles.map { $0.rawValue }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Movement pattern and difficulty
                HStack(spacing: 6) {
                    if let pattern = exercise.movementPattern {
                        Text(pattern.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    Text(exercise.difficulty.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.1))
                        .foregroundStyle(difficultyColor)
                        .clipShape(Capsule())

                    if exercise.isUnilateral {
                        Text("Unilateral")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Similarity badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(similarityScore * 100))%")
                    .font(.headline.bold())
                    .foregroundStyle(similarityColor)

                Text("match")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }

    private var similarityColor: Color {
        switch similarityScore {
        case 0.8...: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseBrowserView(
            sourceExercise: ExerciseDatabase.shared.exercises.first!,
            excludedExerciseNames: [],
            onSelect: { _ in }
        )
    }
}
