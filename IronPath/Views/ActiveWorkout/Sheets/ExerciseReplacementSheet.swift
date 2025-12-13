import SwiftUI

// MARK: - Exercise Replacement Sheet

/// Sheet for replacing an exercise with similarity-based suggestions or AI-powered replacement
struct ExerciseReplacementSheet: View {
    @Bindable var viewModel: ExerciseReplacementViewModel
    let exercise: WorkoutExercise
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Current exercise info
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exercise.name)
                            .font(.headline)
                        HStack(spacing: 8) {
                            Label(exercise.exercise.equipment.rawValue, systemImage: "dumbbell")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(exercise.exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Current Exercise")
                }

                // Similarity-ranked suggestions
                if !viewModel.topSuggestions.isEmpty {
                    Section {
                        ForEach(viewModel.topSuggestions, id: \.0.id) { (alt, score) in
                            Button {
                                viewModel.quickReplace(with: alt)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(alt.name)
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 4) {
                                            Text(alt.equipment.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if !alt.primaryMuscleGroups.intersection(exercise.exercise.primaryMuscleGroups).isEmpty {
                                                Text("•")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(alt.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    Spacer()
                                    // Similarity badge
                                    Text("\(Int(score * 100))%")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(viewModel.similarityColor(for: score))
                                        .clipShape(Capsule())
                                }
                            }
                            .disabled(viewModel.isLoading)
                        }
                    } header: {
                        HStack {
                            Text("Best Matches")
                            Spacer()
                            Text("Similarity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Ranked by muscle groups, movement pattern, and equipment")
                    }
                }

                // Browse All section
                Section {
                    NavigationLink {
                        ExerciseBrowserView(
                            sourceExercise: exercise.exercise,
                            excludedExerciseNames: viewModel.currentWorkoutExercises,
                            onSelect: { selectedExercise in
                                viewModel.quickReplace(with: selectedExercise)
                            }
                        )
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundStyle(.blue)
                            Text("Browse All Exercises")
                            Spacer()
                            Text("\(viewModel.totalExerciseCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }

                // AI Replacement section
                Section {
                    TextField("Why do you need a replacement?", text: $viewModel.replacementNotes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Label("AI Replacement", systemImage: "sparkles")
                } footer: {
                    Text("Describe your needs and AI will find the best alternative.\nExamples: \"My shoulder hurts\", \"Machine is taken\", \"Want something harder\"")
                }
            }
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelReplacement()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.requestAIReplacement()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Ask AI")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Replacement Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.error ?? "Failed to replace exercise")
            }
        }
    }
}
