import SwiftUI

// MARK: - Weight Input Field

/// Reusable weight input field that shows weight with unit and optional multiplier hint
struct WeightInputField: View {
    @Binding var weight: Double?
    let unit: WeightUnit
    let multiplier: Double
    let placeholder: String
    let exerciseName: String?

    @FocusState private var isFocused: Bool
    @State private var textValue: String

    init(
        weight: Binding<Double?>,
        unit: WeightUnit,
        multiplier: Double = 1.0,
        placeholder: String = "Weight",
        exerciseName: String? = nil
    ) {
        self._weight = weight
        self.unit = unit
        self.multiplier = multiplier
        self.placeholder = placeholder
        self.exerciseName = exerciseName

        // Initialize text value from weight
        if let weightValue = weight.wrappedValue {
            _textValue = State(initialValue: WeightConverter.format(weightValue, unit: unit, includeUnit: false))
        } else {
            _textValue = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField(placeholder, text: $textValue)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .onChange(of: textValue) { _, newValue in
                        updateWeight(from: newValue)
                    }
                    .frame(minWidth: 50)

                Text(unit.abbreviation)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            // Show multiplier hint if applicable
            if multiplier > 1.0 {
                Text("\(unit.abbreviation) per arm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            // Sync text value with weight on appear
            if let weightValue = weight {
                textValue = formatWeightForDisplay(weightValue)
            }
        }
        .onChange(of: weight) { _, newValue in
            // Update text when weight changes externally
            if !isFocused {
                if let weightValue = newValue {
                    textValue = formatWeightForDisplay(weightValue)
                } else {
                    textValue = ""
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func updateWeight(from text: String) {
        if text.isEmpty {
            weight = nil
        } else if let value = Double(text), value >= 0 {
            weight = value
        }
    }

    private func formatWeightForDisplay(_ weight: Double) -> String {
        WeightConverter.format(weight, unit: unit, includeUnit: false)
    }
}

// MARK: - Weight Display (Read-Only)

/// Read-only weight display with unit
struct WeightDisplay: View {
    let weight: Double?
    let unit: WeightUnit
    let multiplier: Double
    let showMultiplierHint: Bool

    init(
        weight: Double?,
        unit: WeightUnit,
        multiplier: Double = 1.0,
        showMultiplierHint: Bool = false
    ) {
        self.weight = weight
        self.unit = unit
        self.multiplier = multiplier
        self.showMultiplierHint = showMultiplierHint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let weight = weight {
                Text(WeightConverter.format(weight, unit: unit))
                    .font(.body)

                if showMultiplierHint && multiplier > 1.0 {
                    Text("per arm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Weight Input") {
    VStack(spacing: 20) {
        WeightInputField(
            weight: .constant(100),
            unit: .pounds,
            multiplier: 1.0,
            placeholder: "Weight"
        )

        WeightInputField(
            weight: .constant(20),
            unit: .pounds,
            multiplier: 2.0,
            placeholder: "Weight",
            exerciseName: "Dumbbell Shoulder Press"
        )

        WeightInputField(
            weight: .constant(45.5),
            unit: .kilograms,
            multiplier: 1.0,
            placeholder: "Weight"
        )
    }
    .padding()
}

#Preview("Weight Display") {
    VStack(spacing: 20) {
        WeightDisplay(weight: 100, unit: .pounds)
        WeightDisplay(weight: 20, unit: .pounds, multiplier: 2.0, showMultiplierHint: true)
        WeightDisplay(weight: 45.5, unit: .kilograms)
        WeightDisplay(weight: nil, unit: .pounds)
    }
    .padding()
}
