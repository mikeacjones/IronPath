import SwiftUI

// MARK: - Free Weights Editor

/// Editor for free weights on a cable machine with count support
/// Allows adding multiple of the same weight (e.g., 3x 5lb plates)
struct FreeWeightsEditor: View {
    @Binding var freeWeights: [CableMachineConfig.FreeWeight]
    @State private var newWeight: String = ""
    @State private var newCount: Int = 1

    /// Common free weight values for quick add
    private let commonWeights: [Double] = [2.5, 5.0, 7.5, 10.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current free weights display
            if freeWeights.isEmpty {
                Text("No free weights configured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach($freeWeights) { $freeWeight in
                        HStack {
                            // Weight display
                            Text("\(formatWeight(freeWeight.weight)) lb")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            // Count stepper
                            HStack(spacing: 8) {
                                Button {
                                    if freeWeight.count > 1 {
                                        freeWeight.count -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(freeWeight.count > 1 ? .blue : .gray)
                                }
                                .buttonStyle(.plain)
                                .disabled(freeWeight.count <= 1)

                                Text("\(freeWeight.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(minWidth: 24)

                                Button {
                                    freeWeight.count += 1
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }

                            // Delete button
                            Button {
                                withAnimation {
                                    freeWeights.removeAll { $0.id == freeWeight.id }
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            Divider()

            // Quick add buttons for common weights
            Text("Quick Add")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(commonWeights.filter { weight in
                        !freeWeights.contains { $0.weight == weight }
                    }, id: \.self) { weight in
                        Button {
                            withAnimation {
                                freeWeights.append(CableMachineConfig.FreeWeight(weight: weight, count: 1))
                            }
                        } label: {
                            Text("\(formatWeight(weight)) lb")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Custom weight entry
            HStack {
                TextField("Weight", text: $newWeight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)

                Text("lb")
                    .foregroundStyle(.secondary)

                Text("×")
                    .foregroundStyle(.secondary)

                Stepper("\(newCount)", value: $newCount, in: 1...10)
                    .labelsHidden()
                    .frame(width: 94)

                Text("\(newCount)")
                    .frame(width: 20)

                Button("Add") {
                    if let weight = Double(newWeight), weight > 0 {
                        // Check if this weight already exists
                        if let existingIndex = freeWeights.firstIndex(where: { $0.weight == weight }) {
                            // Add to existing count
                            freeWeights[existingIndex].count += newCount
                        } else {
                            // Add new free weight
                            withAnimation {
                                freeWeights.append(CableMachineConfig.FreeWeight(weight: weight, count: newCount))
                            }
                        }
                        newWeight = ""
                        newCount = 1
                    }
                }
                .disabled(Double(newWeight) == nil || (Double(newWeight) ?? 0) <= 0)
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Cable Machine Config Editor

struct CableMachineConfigEditor: View {
    @State var config: CableMachineConfig
    let title: String
    let onSave: (CableMachineConfig) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($config.plateTiers) { $tier in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Tier \(config.plateTiers.firstIndex(where: { $0.id == tier.id })! + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TierInputRow(tier: $tier)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                config.plateTiers.removeAll { $0.id == tier.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(config.plateTiers.count <= 1)
                        }
                    }

                    Button {
                        config.plateTiers.append(CableMachineConfig.PlateTier(plateWeight: 10.0, plateCount: 10))
                    } label: {
                        Label("Add Plate Tier", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Plate Stack")
                } footer: {
                    Text("Define your machine's weight stack. Add multiple tiers if plates have different weights (e.g., 6×9lb then 12×12.5lb)")
                }

                Section {
                    FreeWeightsEditor(freeWeights: $config.freeWeights)
                } header: {
                    Text("Free Weights")
                } footer: {
                    if config.freeWeights.isEmpty {
                        Text("Add-on weights that can be attached to the cable (e.g., 2.5lb or 5lb plates). These are optional when selecting a weight.")
                    } else {
                        let totalFreeWeights = config.freeWeights.reduce(0) { $0 + $1.count }
                        Text("This machine has \(totalFreeWeights) free weight plate(s) available.")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview: \(config.stackDescription)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Available weights:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let weights = config.availableWeights
                        let preview = weights.prefix(15).map { "\(formatWeight($0))" }.joined(separator: ", ")
                        Text(preview + (weights.count > 15 ? "... (\(weights.count) total)" : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Max: \(formatWeight(weights.last ?? 0)) lbs")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(config)
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Tier Input Row

/// Helper view for tier input that allows clearing fields
/// Uses string-based editing and converts to numbers on blur/submit
struct TierInputRow: View {
    @Binding var tier: CableMachineConfig.PlateTier
    @State private var countText: String = ""
    @State private var weightText: String = ""
    @FocusState private var countFocused: Bool
    @FocusState private var weightFocused: Bool

    var body: some View {
        HStack {
            TextField("Count", text: $countText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .focused($countFocused)
                .onChange(of: countFocused) { _, focused in
                    if !focused {
                        commitCount()
                    }
                }
                .onSubmit { commitCount() }
            Text("×")
            TextField("Weight", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .focused($weightFocused)
                .onChange(of: weightFocused) { _, focused in
                    if !focused {
                        commitWeight()
                    }
                }
                .onSubmit { commitWeight() }
            Text(GymSettings.shared.preferredWeightUnit.abbreviation)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            countText = String(tier.plateCount)
            weightText = formatWeight(tier.plateWeight)
        }
        .onChange(of: tier.plateCount) { _, newValue in
            if !countFocused {
                countText = String(newValue)
            }
        }
        .onChange(of: tier.plateWeight) { _, newValue in
            if !weightFocused {
                weightText = formatWeight(newValue)
            }
        }
    }

    private func commitCount() {
        if let value = Int(countText), value > 0 {
            tier.plateCount = value
        } else if countText.isEmpty {
            // Keep minimum of 1 if cleared
            tier.plateCount = 1
            countText = "1"
        } else {
            // Reset to current value if invalid
            countText = String(tier.plateCount)
        }
    }

    private func commitWeight() {
        if let value = Double(weightText), value > 0 {
            tier.plateWeight = value
        } else if weightText.isEmpty {
            // Keep minimum of 1 if cleared
            tier.plateWeight = 1.0
            weightText = "1"
        } else {
            // Reset to current value if invalid
            weightText = formatWeight(tier.plateWeight)
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}
