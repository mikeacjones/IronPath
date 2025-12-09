import SwiftUI

// MARK: - Workout Setup View

struct WorkoutSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Binding var isGenerating: Bool
    let onGenerate: (WorkoutType, String, Bool, WorkoutGenerationOptions) -> Void // (workoutType, notes, isDeload, options)

    @State private var selectedWorkoutType: WorkoutType = .fullBody
    @State private var workoutNotes: String = ""
    @State private var isDeload: Bool = false
    @State private var showAdvancedOptions: Bool = false

    // Per-workout technique options (persisted between generations)
    @AppStorage("workout_warmup_mode") private var warmupMode: TechniqueRequirementMode = .allowed
    @AppStorage("workout_dropset_mode") private var dropSetMode: TechniqueRequirementMode = .allowed
    @AppStorage("workout_restpause_mode") private var restPauseMode: TechniqueRequirementMode = .allowed

    private var globalSettings: AdvancedTechniqueSettings {
        appState.userProfile?.workoutPreferences.advancedTechniqueSettings ?? AdvancedTechniqueSettings()
    }

    private var generationOptions: WorkoutGenerationOptions {
        WorkoutGenerationOptions(
            warmupSetMode: warmupMode,
            dropSetMode: dropSetMode,
            restPauseMode: restPauseMode
        ).applying(globalSettings: globalSettings)
    }

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

                    // Advanced Training Techniques Section
                    Section {
                        DisclosureGroup(isExpanded: $showAdvancedOptions) {
                            // Warmup Sets
                            TechniqueModePicker(
                                title: "Warmup Sets",
                                iconName: "flame",
                                iconColor: .orange,
                                mode: $warmupMode,
                                isGloballyEnabled: globalSettings.allowWarmupSets
                            )

                            // Drop Sets
                            TechniqueModePicker(
                                title: "Drop Sets",
                                iconName: "arrow.down.circle.fill",
                                iconColor: .purple,
                                mode: $dropSetMode,
                                isGloballyEnabled: globalSettings.allowDropSets
                            )

                            // Rest-Pause
                            TechniqueModePicker(
                                title: "Rest-Pause",
                                iconName: "pause.circle.fill",
                                iconColor: .green,
                                mode: $restPauseMode,
                                isGloballyEnabled: globalSettings.allowRestPauseSets
                            )
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                                Text("Advanced Techniques")
                                Spacer()
                                if hasActiveRequirements {
                                    Text(activeRequirementsLabel)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    } header: {
                        Text("Training Techniques")
                    } footer: {
                        Text("Control whether Claude can suggest or must include advanced techniques. Global settings can be changed in Profile.")
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
                        onGenerate(selectedWorkoutType, workoutNotes, isDeload, generationOptions)
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

    private var hasActiveRequirements: Bool {
        generationOptions.warmupSetMode == .required ||
        generationOptions.dropSetMode == .required ||
        generationOptions.restPauseMode == .required
    }

    private var activeRequirementsLabel: String {
        var required: [String] = []
        if generationOptions.warmupSetMode == .required { required.append("W") }
        if generationOptions.dropSetMode == .required { required.append("D") }
        if generationOptions.restPauseMode == .required { required.append("RP") }
        return required.isEmpty ? "" : "Required: \(required.joined(separator: ", "))"
    }
}

// MARK: - Technique Mode Picker

struct TechniqueModePicker: View {
    let title: String
    let iconName: String
    let iconColor: Color
    let mode: Binding<TechniqueRequirementMode>
    let isGloballyEnabled: Bool

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(isGloballyEnabled ? iconColor : .gray)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(isGloballyEnabled ? .primary : .secondary)

            Spacer()

            if isGloballyEnabled {
                Picker("", selection: mode) {
                    ForEach(TechniqueRequirementMode.allCases, id: \.self) { requirementMode in
                        HStack {
                            Image(systemName: requirementMode.iconName)
                            Text(requirementMode.rawValue)
                        }
                        .tag(requirementMode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            } else {
                Text("Disabled in settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
