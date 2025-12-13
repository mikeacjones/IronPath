import SwiftUI

// MARK: - Training Program Step

struct TrainingProgramStep: View {
    @Binding var trainingStyle: TrainingStyle
    @Binding var workoutSplit: WorkoutSplit

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Choose your training program")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 20) {
                    trainingStyleSection
                    workoutSplitSection
                }
            }
            .padding(.vertical)
        }
    }

    private var trainingStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Style")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(TrainingStyle.allCases, id: \.self) { style in
                    Button {
                        trainingStyle = style
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(style.rawValue)
                                    .font(.headline)
                                Spacer()
                                if trainingStyle == style {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text(style.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(trainingStyle == style ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var workoutSplitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Split")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 10)

            VStack(spacing: 12) {
                ForEach(WorkoutSplit.allCases, id: \.self) { split in
                    Button {
                        workoutSplit = split
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(split.rawValue)
                                    .font(.headline)
                                Spacer()
                                if workoutSplit == split {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text(split.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(workoutSplit == split ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Advanced Techniques Step

struct AdvancedTechniquesStep: View {
    @Binding var warmupSetMode: TechniqueRequirementMode
    @Binding var dropSetMode: TechniqueRequirementMode
    @Binding var restPauseSetMode: TechniqueRequirementMode
    @Binding var supersetMode: TechniqueRequirementMode

    var body: some View {
        VStack(spacing: 20) {
            Text("Advanced techniques")
                .font(.title)
                .fontWeight(.bold)

            Text("Configure advanced training techniques for AI-generated workouts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            legend

            ScrollView {
                VStack(spacing: 16) {
                    AdvancedTechniqueRow(
                        title: "Warmup Sets",
                        description: "Light sets to prepare muscles before working sets",
                        icon: "flame",
                        color: .orange,
                        mode: $warmupSetMode
                    )

                    AdvancedTechniqueRow(
                        title: "Drop Sets",
                        description: "Continue with reduced weight after reaching failure",
                        icon: "arrow.down.circle",
                        color: .red,
                        mode: $dropSetMode
                    )

                    AdvancedTechniqueRow(
                        title: "Rest-Pause Sets",
                        description: "Brief rest then continue reps within the same set",
                        icon: "pause.circle",
                        color: .blue,
                        mode: $restPauseSetMode
                    )

                    AdvancedTechniqueRow(
                        title: "Supersets & Circuits",
                        description: "Multiple exercises performed back-to-back",
                        icon: "arrow.triangle.2.circlepath",
                        color: .purple,
                        mode: $supersetMode
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(TechniqueRequirementMode.allCases, id: \.self) { mode in
                HStack(spacing: 4) {
                    Circle()
                        .fill(mode.swiftUIColor)
                        .frame(width: 8, height: 8)
                    Text(mode.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Advanced Technique Row

struct AdvancedTechniqueRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    @Binding var mode: TechniqueRequirementMode

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Picker("", selection: $mode) {
                ForEach(TechniqueRequirementMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - TechniqueRequirementMode SwiftUI Extension

extension TechniqueRequirementMode {
    var swiftUIColor: Color {
        switch self {
        case .disabled: return .red
        case .allowed: return .orange
        case .required: return .green
        }
    }
}
