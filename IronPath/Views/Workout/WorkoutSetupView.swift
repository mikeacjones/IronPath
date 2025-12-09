import SwiftUI

// MARK: - Workout Setup View

struct WorkoutSetupView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isGenerating: Bool
    let onGenerate: (WorkoutType, String, Bool) -> Void // (workoutType, notes, isDeload)

    @State private var selectedWorkoutType: WorkoutType = .fullBody
    @State private var workoutNotes: String = ""
    @State private var isDeload: Bool = false

    private var isCustomWorkout: Bool {
        selectedWorkoutType == .custom
    }

    private var canGenerate: Bool {
        // Custom workouts require a prompt
        if isCustomWorkout {
            return !workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private var promptPlaceholder: String {
        if isCustomWorkout {
            return "Describe what kind of workout you want..."
        }
        return "Any notes for today's workout?"
    }

    private var promptFooter: String {
        if isCustomWorkout {
            return "Example: \"A quick 20-minute arm workout\" or \"Heavy compound lifts focusing on strength\""
        }
        return "Example: \"My shoulder hurts so avoid overhead pressing\" or \"The cable machine is broken\""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(WorkoutType.allCases) { type in
                                WorkoutTypeCard(
                                    type: type,
                                    isSelected: selectedWorkoutType == type,
                                    onTap: { selectedWorkoutType = type }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Workout Type")
                    }

                    Section {
                        Toggle(isOn: $isDeload) {
                            HStack {
                                Image(systemName: "arrow.down.heart")
                                    .foregroundStyle(.green)
                                Text("Deload Week")
                            }
                        }
                    } header: {
                        Text("Recovery Options")
                    } footer: {
                        Text("Deload workouts use lighter weights (50-70%) and won't affect your progressive overload tracking.")
                    }

                    Section {
                        TextField(promptPlaceholder, text: $workoutNotes, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        if isCustomWorkout {
                            HStack {
                                Text("Custom Workout Prompt")
                                Text("(Required)")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        } else {
                            Text("Notes for Claude")
                        }
                    } footer: {
                        Text(promptFooter)
                    }
                }
                .disabled(isGenerating)
                .blur(radius: isGenerating ? 3 : 0)

                // Loading overlay with fun messages
                if isGenerating {
                    WorkoutGenerationLoadingView()
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onGenerate(selectedWorkoutType, workoutNotes, isDeload)
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Generate")
                        }
                    }
                    .disabled(isGenerating || !canGenerate)
                }
            }
        }
    }
}

// MARK: - Workout Type Card

struct WorkoutTypeCard: View {
    let type: WorkoutType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
