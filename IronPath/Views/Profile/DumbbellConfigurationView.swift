import SwiftUI

// MARK: - Dumbbell Configuration View

struct DumbbellConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(DependencyContainer.self) private var dependencies
    @State private var settings = GymSettings.shared

    @State private var useSpecificDumbbells: Bool
    @State private var selectedDumbbells: Set<Double>

    private var weightUnit: WeightUnit {
        dependencies.gymProfileManager.activeProfile?.preferredWeightUnit ?? .pounds
    }

    private var standardDumbbells: [Double] {
        weightUnit == .kilograms ? GymSettings.standardDumbbellsKg : GymSettings.standardDumbbells
    }

    private var limitedDumbbells: [Double] {
        weightUnit == .kilograms ? GymSettings.limitedDumbbellsKg : GymSettings.limitedDumbbells
    }

    init(gymProfileManager: GymProfileManaging? = nil) {
        let settings = GymSettings.shared
        let hasSpecific = settings.availableDumbbells != nil
        _useSpecificDumbbells = State(initialValue: hasSpecific)

        // Use the appropriate standard set based on current unit
        let unit = (gymProfileManager ?? GymProfileManager.shared).activeProfile?.preferredWeightUnit ?? .pounds
        let defaultStandard = unit == .kilograms ? GymSettings.standardDumbbellsKg : GymSettings.standardDumbbells
        _selectedDumbbells = State(initialValue: settings.availableDumbbells ?? Set(defaultStandard.filter { $0 <= settings.dumbbellMaxWeight }))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Select Specific Dumbbells", isOn: $useSpecificDumbbells)
                } footer: {
                    Text(useSpecificDumbbells
                         ? "Choose exactly which dumbbell weights are available at your gym."
                         : "Use a weight range with fixed increments.")
                }

                if useSpecificDumbbells {
                    // Specific dumbbell selection
                    Section {
                        dumbbellSelectionGrid
                    } header: {
                        HStack {
                            Text("Available Dumbbells")
                            Spacer()
                            Text("\(selectedDumbbells.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button("Select All Standard Sizes") {
                            selectedDumbbells = Set(standardDumbbells)
                        }

                        Button(weightUnit == .kilograms ? "Select Common Sizes (2 kg increments)" : "Select Common Sizes (5 lb increments)") {
                            let increment: Double = weightUnit == .kilograms ? 2 : 5
                            selectedDumbbells = Set(standardDumbbells.filter { $0.truncatingRemainder(dividingBy: increment) == 0 })
                        }

                        Button("Select Hotel Gym Sizes") {
                            selectedDumbbells = Set(limitedDumbbells)
                        }

                        Button("Clear All", role: .destructive) {
                            selectedDumbbells.removeAll()
                        }
                    } header: {
                        Text("Quick Selection")
                    }
                } else {
                    // Range-based settings
                    Section {
                        Stepper("Increment: \(formatWeight(settings.dumbbellIncrement)) \(weightUnit.abbreviation)",
                                value: $settings.dumbbellIncrement,
                                in: (weightUnit == .kilograms ? 1...5 : 2.5...10),
                                step: (weightUnit == .kilograms ? 1 : 2.5))

                        Stepper("Min Weight: \(formatWeight(settings.dumbbellMinWeight)) \(weightUnit.abbreviation)",
                                value: $settings.dumbbellMinWeight,
                                in: 0...(weightUnit == .kilograms ? 10 : 20),
                                step: (weightUnit == .kilograms ? 2 : 5))

                        Stepper("Max Weight: \(formatWeight(settings.dumbbellMaxWeight)) \(weightUnit.abbreviation)",
                                value: $settings.dumbbellMaxWeight,
                                in: (weightUnit == .kilograms ? 20...90 : 50...200),
                                step: (weightUnit == .kilograms ? 5 : 10))
                    } header: {
                        Text("Weight Range")
                    } footer: {
                        let weights = stride(from: settings.dumbbellMinWeight, through: settings.dumbbellMaxWeight, by: settings.dumbbellIncrement)
                        Text("Available: \(weights.map { formatWeight($0) }.joined(separator: ", ")) \(weightUnit.abbreviation)")
                            .font(.caption)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        let weights = previewWeights
                        if weights.isEmpty {
                            Text("No dumbbells selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(weights.prefix(20).map { formatWeight($0) }.joined(separator: ", ") + (weights.count > 20 ? "..." : "") + " \(weightUnit.abbreviation)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(weights.count) weights available")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Dumbbell Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                        dismiss()
                    }
                    .disabled(useSpecificDumbbells && selectedDumbbells.isEmpty)
                }
            }
        }
    }

    private var previewWeights: [Double] {
        if useSpecificDumbbells {
            return selectedDumbbells.sorted()
        } else {
            return stride(from: settings.dumbbellMinWeight, through: settings.dumbbellMaxWeight, by: settings.dumbbellIncrement).map { $0 }
        }
    }

    private var dumbbellSelectionGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 70), spacing: 8)
        ], spacing: 8) {
            ForEach(standardDumbbells, id: \.self) { weight in
                DumbbellChip(
                    weight: weight,
                    isSelected: selectedDumbbells.contains(weight),
                    onToggle: {
                        if selectedDumbbells.contains(weight) {
                            selectedDumbbells.remove(weight)
                        } else {
                            selectedDumbbells.insert(weight)
                        }
                    }
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func saveConfiguration() {
        if useSpecificDumbbells {
            settings.availableDumbbells = selectedDumbbells
        } else {
            settings.availableDumbbells = nil
        }
    }

    private func formatWeight(_ w: Double) -> String {
        WeightConverter.format(w, unit: weightUnit, includeUnit: false)
    }
}

// MARK: - Dumbbell Chip

struct DumbbellChip: View {
    let weight: Double
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(formatWeight(weight))
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(minWidth: 50)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func formatWeight(_ w: Double) -> String {
        WeightConverter.format(w, unit: .pounds, includeUnit: false)
    }
}
