import SwiftUI

// MARK: - Gym Equipment Settings View

struct GymEquipmentSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(DependencyContainer.self) private var dependencies
    @State private var settings = GymSettings.shared
    @State private var showingDefaultCableEditor = false
    @State private var showingDumbbellConfig = false

    private var weightUnit: WeightUnit {
        dependencies.gymProfileManager.activeProfile?.preferredWeightUnit ?? .pounds
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingDefaultCableEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Default Cable Machine")
                                    .foregroundStyle(.primary)
                                Text(settings.defaultCableConfig.stackDescription(unit: weightUnit))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !settings.cableMachineConfigs.isEmpty {
                        ForEach(Array(settings.cableMachineConfigs.keys.sorted()), id: \.self) { exercise in
                            if let config = settings.cableMachineConfigs[exercise] {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(exercise)
                                        Text(config.stackDescription(unit: weightUnit))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Custom")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let keys = Array(settings.cableMachineConfigs.keys.sorted())
                            for index in indexSet {
                                settings.cableMachineConfigs.removeValue(forKey: keys[index])
                            }
                        }
                    }
                } header: {
                    Label("Cable Machines", systemImage: "cable.connector")
                } footer: {
                    Text("Configure plate stacks and free weights for your cable machines. Custom configs can be set per-exercise when logging sets.")
                }

                Section {
                    Button {
                        showingDumbbellConfig = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Configure Dumbbells")
                                    .foregroundStyle(.primary)
                                Text(dumbbellSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Dumbbells", systemImage: "dumbbell")
                } footer: {
                    Text("Configure the dumbbell weights available at your gym. You can select specific weights or use a range.")
                }

                Section {
                    Text("These settings are sent to your AI when generating workouts to ensure only achievable weights are suggested.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Gym Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDefaultCableEditor) {
                CableMachineConfigEditor(
                    config: settings.defaultCableConfig,
                    title: "Default Cable Machine",
                    onSave: { newConfig in
                        settings.defaultCableConfig = newConfig
                    }
                )
            }
            .sheet(isPresented: $showingDumbbellConfig) {
                DumbbellConfigurationView()
            }
        }
    }

    private var dumbbellSummary: String {
        let unit = weightUnit.abbreviation
        if let dumbbells = settings.availableDumbbells {
            let sorted = dumbbells.sorted()
            if sorted.count <= 5 {
                return sorted.map { formatWeight($0) }.joined(separator: ", ") + " \(unit)"
            } else {
                return "\(sorted.count) weights: \(formatWeight(sorted.first ?? 0))-\(formatWeight(sorted.last ?? 0)) \(unit)"
            }
        } else {
            return "\(formatWeight(settings.dumbbellMinWeight))-\(formatWeight(settings.dumbbellMaxWeight)) \(unit) (\(formatWeight(settings.dumbbellIncrement)) \(unit) increments)"
        }
    }

    private func formatWeight(_ w: Double) -> String {
        WeightConverter.format(w, unit: settings.preferredWeightUnit, includeUnit: false)
    }
}

// MARK: - Flow Layout

/// A simple flow layout that wraps content to new lines
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (height: CGFloat, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (y + rowHeight, positions)
    }
}
