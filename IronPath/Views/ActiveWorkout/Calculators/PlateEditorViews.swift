import SwiftUI

// MARK: - Available Plates Editor

struct AvailablePlatesEditor: View {
    let exerciseName: String

    private let gymSettings: GymSettingsProviding

    @Environment(\.dismiss) var dismiss
    @State private var newPlateWeight: String = ""
    @State private var newPlateCount: String = ""
    @State private var localPlates: [AvailablePlate] = []

    init(exerciseName: String, gymSettings: GymSettingsProviding? = nil) {
        self.exerciseName = exerciseName
        self.gymSettings = gymSettings ?? GymSettings.shared
    }

    private var weightUnit: WeightUnit {
        gymSettings.preferredWeightUnit
    }

    private var hasCustomConfig: Bool {
        gymSettings.hasCustomPlateConfig(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            List {
                exerciseSection
                platesSection
                addPlateSection
                resetSection
            }
            .navigationTitle("Available Plates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                localPlates = gymSettings.availablePlates(for: exerciseName)
            }
        }
    }

    private var exerciseSection: some View {
        Section {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.blue)
                Text(exerciseName)
                    .fontWeight(.medium)
            }
        } header: {
            Text("Exercise")
        } footer: {
            if hasCustomConfig {
                Text("This exercise has custom plate settings")
            } else {
                Text("Using default plate settings")
            }
        }
    }

    private var platesSection: some View {
        Section {
            ForEach(Array(localPlates.enumerated()), id: \.element.weight) { index, _ in
                PlateRowEditor(
                    plate: $localPlates[index],
                    weightUnit: weightUnit,
                    onUpdate: saveChanges
                )
            }
            .onDelete { indexSet in
                localPlates.remove(atOffsets: indexSet)
                saveChanges()
            }
        } header: {
            Text("Available Plates")
        } footer: {
            Text("Swipe left to remove available plates")
        }
    }

    private var addPlateSection: some View {
        Section {
            HStack {
                TextField("Weight", text: $newPlateWeight)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)

                Text(gymSettings.preferredWeightUnit.abbreviation)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("×")
                    .foregroundStyle(.secondary)

                TextField("Qty", text: $newPlateCount)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)

                Button {
                    addPlate()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .disabled(newPlateWeight.isEmpty)
            }
        } header: {
            Text("Add Plate")
        } footer: {
            Text("Enter weight and quantity of plates (leave qty empty for unlimited)")
        }
    }

    private var resetSection: some View {
        Section {
            if hasCustomConfig {
                Button("Use Default Plates") {
                    gymSettings.resetPlateConfig(for: exerciseName)
                    localPlates = gymSettings.defaultAvailablePlates
                }
                .foregroundStyle(.blue)
            }

            Button("Reset to Standard Plates") {
                localPlates = GymSettings.standardPlatesForUnit(weightUnit)
                saveChanges()
            }
            .foregroundStyle(.orange)
        } footer: {
            if weightUnit == .kilograms {
                Text("Standard: 20, 15, 10, 5, 2.5, 1.25 kg (unlimited)")
            } else {
                Text("Standard: 45, 35, 25, 10, 5, 2.5 lbs (unlimited)")
            }
        }
    }

    private func addPlate() {
        guard let weight = Double(newPlateWeight), weight > 0 else { return }

        let count = Int(newPlateCount) ?? 0

        if let existingIndex = localPlates.firstIndex(where: { $0.weight == weight }) {
            localPlates[existingIndex].count = count
        } else {
            localPlates.append(AvailablePlate(weight: weight, count: count))
            localPlates.sort { $0.weight > $1.weight }
        }
        saveChanges()
        newPlateWeight = ""
        newPlateCount = ""
    }

    private func saveChanges() {
        gymSettings.setAvailablePlates(localPlates, for: exerciseName)
    }
}

// MARK: - Plate Row Editor

struct PlateRowEditor: View {
    @Binding var plate: AvailablePlate
    let weightUnit: WeightUnit
    let onUpdate: () -> Void

    @State private var countText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            PlateVisual(weight: plate.weight)
            Text("\(formatWeight(plate.weight)) \(weightUnit.abbreviation)")
                .fontWeight(.medium)

            Spacer()

            Text("×")
                .foregroundStyle(.secondary)

            TextField("∞", text: $countText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(6)
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        plate.count = Int(countText) ?? 0
                        onUpdate()
                    }
                }

            Text("")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            countText = plate.count > 0 ? String(plate.count) : ""
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Plate Visual

struct PlateVisual: View {
    let weight: Double

    private var plateColor: Color {
        switch weight {
        case 100: return .purple
        case 45: return .red
        case 35: return .blue
        case 25: return .green
        case 10: return .yellow
        case 5: return .orange
        case 2.5: return .gray
        default:
            if weight >= 50 { return .purple }
            else if weight >= 30 { return .blue }
            else if weight >= 15 { return .green }
            else if weight >= 7 { return .yellow }
            else { return .orange }
        }
    }

    private var plateHeight: CGFloat {
        let minHeight: CGFloat = 14
        let maxHeight: CGFloat = 44
        let heightRange = maxHeight - minHeight

        let normalizedWeight = min(max(weight, 1), 100)
        let logScale = log10(normalizedWeight) / log10(100)

        return minHeight + (heightRange * logScale)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(plateColor)
            .frame(width: 12, height: plateHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
    }
}
