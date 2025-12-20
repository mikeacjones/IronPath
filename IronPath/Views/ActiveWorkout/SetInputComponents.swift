import SwiftUI

// MARK: - Shared Set Input Components

struct WeightInputView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Binding var weight: String
    let equipment: Equipment
    let exerciseName: String
    @Binding var showPlateCalculator: Bool
    let onWeightChanged: (Double) -> Void

    private var weightUnit: WeightUnit {
        // Use active workout unit if available, otherwise use gym profile unit
        if let activeWorkout = dependencies.activeWorkoutManager.activeWorkout {
            return activeWorkout.weightUnit
        }
        return dependencies.gymProfileManager.activeProfile?.preferredWeightUnit ?? .pounds
    }

    private var showCalcButton: Bool {
        switch equipment {
        case .barbell, .squat, .legPress, .smithMachine, .cables:
            return true
        default:
            return false
        }
    }

    private var calcButtonIcon: String {
        equipment == .cables ? "slider.horizontal.3" : "circle.grid.2x2"
    }

    private var isInvalidCableWeight: Bool {
        guard equipment == .cables, let weightValue = Double(weight), weightValue > 0 else {
            return false
        }
        let config = GymSettings.shared.cableConfig(for: exerciseName)
        return !config.isValidWeight(weightValue)
    }

    private var currentWeightBreakdown: (pin: Int, freeWeight: Double)? {
        guard equipment == .cables, let weightValue = Double(weight), weightValue > 0 else {
            return nil
        }
        let config = GymSettings.shared.cableConfig(for: exerciseName)
        if let breakdown = config.weightBreakdown(for: weightValue) {
            return (breakdown.pin, breakdown.freeWeight)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                TextField("Weight", text: $weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isInvalidCableWeight ? Color.orange : Color.clear, lineWidth: 2)
                    )
                    .onChange(of: weight) { _, newValue in
                        if let weightValue = Double(newValue) {
                            onWeightChanged(weightValue)
                        }
                    }
                Text(weightUnit.abbreviation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showCalcButton {
                    Button {
                        showPlateCalculator = true
                    } label: {
                        Image(systemName: calcButtonIcon)
                            .font(.caption)
                            .foregroundStyle(isInvalidCableWeight ? .orange : .blue)
                    }
                }
            }

            if let breakdown = currentWeightBreakdown {
                HStack(spacing: 2) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                    if breakdown.freeWeight > 0 {
                        Text("Pin \(breakdown.pin) + \(formatWeight(breakdown.freeWeight))\(weightUnit.abbreviation)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    } else {
                        Text("Pin \(breakdown.pin)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .foregroundStyle(.blue)
            }
        }
    }
}

struct RepsInputView: View {
    @Binding var reps: String
    let targetReps: Int
    let onRepsChanged: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            TextField("Reps", text: $reps)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .onChange(of: reps) { _, newValue in
                    if let repsValue = Int(newValue) {
                        onRepsChanged(repsValue)
                    }
                }
            Text("× \(targetReps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CompleteButton: View {
    let isCompleted: Bool
    let action: () -> Void
    var accessibilityId: String = "complete_set_button"

    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isCompleted ? .green : .gray)
        }
        .accessibilityIdentifier(accessibilityId)
    }
}

// MARK: - Timed Exercise Input Components

struct AddedWeightInputView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Binding var weight: String
    let onWeightChanged: (Double?) -> Void

    private var weightUnit: WeightUnit {
        // Use active workout unit if available, otherwise use gym profile unit
        if let activeWorkout = dependencies.activeWorkoutManager.activeWorkout {
            return activeWorkout.weightUnit
        }
        return dependencies.gymProfileManager.activeProfile?.preferredWeightUnit ?? .pounds
    }

    var body: some View {
        HStack(spacing: 4) {
            TextField("Weight", text: $weight)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .onChange(of: weight) { _, newValue in
                    if newValue.isEmpty {
                        onWeightChanged(nil)
                    } else if let weightValue = Double(newValue) {
                        onWeightChanged(weightValue)
                    }
                }
            Text(weightUnit.abbreviation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DurationInputView: View {
    @Binding var seconds: String
    let targetDuration: TimeInterval
    let onDurationChanged: (TimeInterval) -> Void

    var body: some View {
        HStack(spacing: 4) {
            TextField("Seconds", text: $seconds)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .onChange(of: seconds) { _, newValue in
                    if let sec = Double(newValue) {
                        onDurationChanged(sec)
                    }
                }
            Text("sec")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
