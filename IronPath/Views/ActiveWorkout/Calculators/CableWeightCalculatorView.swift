import SwiftUI

// MARK: - Cable Weight Calculator View

/// Calculator for selecting the correct pin position and weights on a cable machine
struct CableWeightCalculatorView: View {
    let targetWeight: Double
    let exerciseName: String
    let onSelectWeight: (Double) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var settings = GymSettings.shared
    @State private var showingConfigEditor = false

    private var config: CableMachineConfig {
        settings.cableConfig(for: exerciseName)
    }

    private var availableWeights: [Double] {
        config.availableWeights
    }

    private var nearestWeight: Double {
        config.nearestWeight(to: targetWeight)
    }

    private var weightsNearTarget: [Double] {
        config.weightsNear(targetWeight, count: 7)
    }

    private var hasCustomConfig: Bool {
        settings.cableMachineConfigs[exerciseName] != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current target
                    VStack(spacing: 4) {
                        Text("Target Weight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(targetWeight)) lbs")
                            .font(.system(size: 48, weight: .bold))
                    }
                    .padding(.top)

                    // Cable machine config info
                    Button {
                        showingConfigEditor = true
                    } label: {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(hasCustomConfig ? exerciseName : "Default Cable Machine")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if hasCustomConfig {
                                            Text("Custom")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue)
                                                .foregroundStyle(.white)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(config.stackDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }

                            Text("Tap to configure plate stack for this exercise")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Divider()

                    // Available weights grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Weight")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(weightsNearTarget, id: \.self) { weight in
                                let breakdown = config.weightBreakdown(for: weight)
                                Button {
                                    onSelectWeight(weight)
                                } label: {
                                    CableWeightButton(
                                        weight: weight,
                                        pinNumber: breakdown?.pin,
                                        freeWeight: breakdown?.freeWeight ?? 0,
                                        isSelected: weight == nearestWeight
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)

                        // Show more weights option
                        if availableWeights.count > 7 {
                            DisclosureGroup("All available weights (\(availableWeights.count))") {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(availableWeights, id: \.self) { weight in
                                        let breakdown = config.weightBreakdown(for: weight)
                                        Button {
                                            onSelectWeight(weight)
                                        } label: {
                                            VStack(spacing: 2) {
                                                Text("\(formatWeight(weight))")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                if let bd = breakdown {
                                                    if bd.pin > 0 && bd.freeWeight > 0 {
                                                        Text("Pin \(bd.pin)+\(formatWeight(bd.freeWeight))")
                                                            .font(.system(size: 9))
                                                            .foregroundStyle(.blue)
                                                    } else if bd.pin > 0 {
                                                        Text("Pin \(bd.pin)")
                                                            .font(.system(size: 9))
                                                            .foregroundStyle(.blue)
                                                    } else if bd.freeWeight > 0 {
                                                        Text("\(formatWeight(bd.freeWeight))lb free")
                                                            .font(.system(size: 9))
                                                            .foregroundStyle(.orange)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Cable Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingConfigEditor) {
                CableMachineConfigEditor(
                    config: config,
                    title: exerciseName,
                    onSave: { newConfig in
                        settings.setCableConfig(newConfig, for: exerciseName)
                    }
                )
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Cable Weight Button

/// Button showing weight with pin location indicator
struct CableWeightButton: View {
    let weight: Double
    let pinNumber: Int?
    let freeWeight: Double
    let isSelected: Bool

    init(weight: Double, pinNumber: Int?, freeWeight: Double = 0, isSelected: Bool) {
        self.weight = weight
        self.pinNumber = pinNumber
        self.freeWeight = freeWeight
        self.isSelected = isSelected
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(formatWeight(weight))")
                .font(.title3)
                .fontWeight(.semibold)
            Text("lbs")
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)

            // Pin location indicator with free weight info
            if let pin = pinNumber, pin > 0 {
                VStack(spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                        Text("Pin \(pin)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    if freeWeight > 0 {
                        Text("+ \(formatWeight(freeWeight))lb")
                            .font(.system(size: 9))
                    }
                }
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .blue)
                .padding(.top, 2)
            } else if freeWeight > 0 {
                // Only free weights, no pin
                Text("\(formatWeight(freeWeight))lb free")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .orange)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isSelected ? Color.blue : Color(.systemGray6))
        .foregroundStyle(isSelected ? .white : .primary)
        .cornerRadius(12)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Weight Option Row

/// A row showing a weight option with selection indicator
struct WeightOptionRow: View {
    let weight: Double
    let label: String
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(formatWeight(weight)) lbs")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.gray)
                    .font(.title2)
            }
        }
        .padding()
        .background(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}
