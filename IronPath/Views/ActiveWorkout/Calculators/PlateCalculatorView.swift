import SwiftUI

// MARK: - Plate Calculator View

struct PlateCalculatorView: View {
    let totalWeight: Double
    let equipment: Equipment
    let exerciseName: String
    let weightUnitOverride: WeightUnit?
    let previousWeight: Double?

    init(
        totalWeight: Double,
        equipment: Equipment,
        exerciseName: String,
        weightUnitOverride: WeightUnit? = nil,
        previousWeight: Double? = nil
    ) {
        self.totalWeight = totalWeight
        self.equipment = equipment
        self.exerciseName = exerciseName
        self.weightUnitOverride = weightUnitOverride
        self.previousWeight = previousWeight
    }

    @Environment(\.dismiss) var dismiss
    @Environment(DependencyContainer.self) private var dependencies
    @State private var settings = GymSettings.shared
    @State private var showingPlateEditor = false
    @State private var customWeightText: String = ""
    @State private var localMachineWeight: Double = 0
    @State private var localIsSingleSided: Bool = false

    private var weightUnit: WeightUnit {
        if let weightUnitOverride {
            return weightUnitOverride
        }
        // Use active workout unit if available, otherwise use gym profile unit
        if let activeWorkout = dependencies.activeWorkoutManager.activeWorkout {
            return activeWorkout.weightUnit
        }
        return dependencies.gymProfileManager.activeProfile?.preferredWeightUnit ?? .pounds
    }

    private var machineWeightLabel: String {
        switch equipment {
        case .legPress: return "Sled Weight"
        case .smithMachine: return "Bar Weight"
        default: return "Bar Weight"
        }
    }

    private var equipmentLabel: String {
        switch equipment {
        case .legPress: return "Leg Press"
        case .smithMachine: return "Smith Machine"
        case .squat: return "Squat Rack"
        default: return "Barbell"
        }
    }

    private var plateWeight: Double {
        max(0, totalWeight - localMachineWeight)
    }

    private var weightPerSide: Double {
        localIsSingleSided ? plateWeight : plateWeight / 2
    }

    private var currentPlates: [AvailablePlate] {
        settings.availablePlates(for: exerciseName)
    }

    private var platesNeeded: [(Double, Int)] {
        calculatePlatesForWeight(weightPerSide)
    }

    private var isValidWeight: Bool {
        var remaining = weightPerSide
        for plate in currentPlates {
            var count = Int(remaining / plate.weight)
            if plate.hasLimit { count = min(count, plate.count) }
            remaining -= Double(count) * plate.weight
        }
        return remaining < 0.01
    }

    private var hasCustomConfig: Bool {
        settings.hasCustomPlateConfig(for: exerciseName)
    }

    private var hasCustomMachineWeight: Bool {
        settings.hasCustomMachineWeight(for: exerciseName)
    }

    private var previousWeightPerSide: Double? {
        guard let prevWeight = previousWeight, prevWeight > 0 else { return nil }
        let prevPlateWeight = max(0, prevWeight - localMachineWeight)
        return localIsSingleSided ? prevPlateWeight : prevPlateWeight / 2
    }

    private var previousPlatesNeeded: [(Double, Int)]? {
        guard let prevPerSide = previousWeightPerSide else { return nil }
        return calculatePlatesForWeight(prevPerSide)
    }

    private var plateDifference: [(Double, Int)]? {
        guard let prevPlates = previousPlatesNeeded,
              let prevPerSide = previousWeightPerSide,
              previousWeight != totalWeight else { return nil }

        if weightPerSide > prevPerSide {
            let additionalWeightNeeded = weightPerSide - prevPerSide
            let additionalPlates = calculatePlatesForWeight(additionalWeightNeeded)
            let achievedWeight = additionalPlates.reduce(0.0) { $0 + $1.0 * Double($1.1) }
            if abs(achievedWeight - additionalWeightNeeded) < 0.01 {
                return additionalPlates.isEmpty ? nil : additionalPlates
            }
        }

        let currentDict = Dictionary(uniqueKeysWithValues: platesNeeded)
        let prevDict = Dictionary(uniqueKeysWithValues: prevPlates)
        var diff: [(Double, Int)] = []

        let allWeights = Set(currentDict.keys).union(prevDict.keys)
        for weight in allWeights.sorted(by: >) {
            let currentCount = currentDict[weight] ?? 0
            let prevCount = prevDict[weight] ?? 0
            let change = currentCount - prevCount
            if change != 0 {
                diff.append((weight, change))
            }
        }

        return diff.isEmpty ? nil : diff
    }

    private func calculatePlatesForWeight(_ targetWeight: Double) -> [(Double, Int)] {
        var remaining = targetWeight
        var plates: [(Double, Int)] = []

        for plate in currentPlates {
            var count = Int(remaining / plate.weight)
            if plate.hasLimit { count = min(count, plate.count) }
            if count > 0 {
                plates.append((plate.weight, count))
                remaining -= Double(count) * plate.weight
            }
        }

        return plates
    }

    private var isAddingPlates: Bool {
        totalWeight > (previousWeight ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    weightHeaderSection
                    machineWeightSection
                    singleSidedToggle
                    Divider()
                    weightPerSideSection
                    platesBreakdownSection
                    validationWarning
                    Divider()
                    availablePlatesButton
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPlateEditor) {
                AvailablePlatesEditor(exerciseName: exerciseName)
            }
            .onAppear {
                localMachineWeight = settings.machineWeight(for: exerciseName, equipment: equipment)
                localIsSingleSided = settings.isSingleSided(for: exerciseName)
                if ![0.0, 20.0, 35.0, 45.0].contains(localMachineWeight) {
                    customWeightText = formatWeight(localMachineWeight)
                }
            }
        }
    }

    private var weightHeaderSection: some View {
        VStack(spacing: 8) {
            Text("Total Weight")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(formatWeight(totalWeight)) \(weightUnit.abbreviation)")
                .font(.system(size: 48, weight: .bold))
            Text(equipmentLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            if hasCustomConfig || hasCustomMachineWeight {
                Text("Custom settings for \(exerciseName)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.top)
    }

    private var machineWeightSection: some View {
        VStack(spacing: 8) {
            Text(machineWeightLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach([0.0, 20.0, 35.0, 45.0], id: \.self) { weight in
                    Button {
                        localMachineWeight = weight
                        saveMachineWeight()
                    } label: {
                        Text("\(formatWeight(weight))")
                            .font(.subheadline)
                            .fontWeight(localMachineWeight == weight ? .bold : .regular)
                            .frame(minWidth: 44)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(localMachineWeight == weight ? Color.blue : Color(.systemGray5))
                            .foregroundStyle(localMachineWeight == weight ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }

            HStack {
                Text("Custom:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $customWeightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onChange(of: customWeightText) { _, newValue in
                        if let weight = Double(newValue) {
                            localMachineWeight = weight
                            saveMachineWeight()
                        }
                    }
                Text(weightUnit.abbreviation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hasCustomMachineWeight {
                Text("Saved for \(exerciseName)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
    }

    private var singleSidedToggle: some View {
        VStack(spacing: 4) {
            Toggle(isOn: $localIsSingleSided) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Single-sided")
                        .font(.subheadline)
                    Text("Plates on one side only (e.g., T-Bar Row)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: localIsSingleSided) { _, newValue in
                settings.setSingleSided(newValue, for: exerciseName)
            }
        }
        .padding(.horizontal)
    }

    private var weightPerSideSection: some View {
        VStack(spacing: 8) {
            Text(localIsSingleSided ? "Total Plate Weight" : "Each Side")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(WeightConverter.format(weightPerSide, unit: weightUnit, includeUnit: false)) \(weightUnit.abbreviation)")
                .font(.title)
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private var platesBreakdownSection: some View {
        if weightPerSide == 0 {
            Text(localMachineWeight > 0 ? "\(machineWeightLabel) only - no plates needed" : "No plates needed")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(localIsSingleSided ? "Plates needed:" : "Plates per side:")
                    .font(.headline)

                ForEach(platesNeeded, id: \.0) { plate, count in
                    HStack {
                        PlateVisual(weight: plate)
                        Spacer()
                        Text("\(formatWeight(plate)) \(weightUnit.abbreviation)")
                            .fontWeight(.medium)
                        Text("× \(count)")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            if let diff = plateDifference {
                plateDifferenceSection(diff: diff)
            }
        }
    }

    private func plateDifferenceSection(diff: [(Double, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: isAddingPlates ? "plus.circle.fill" : "minus.circle.fill")
                    .foregroundStyle(isAddingPlates ? .green : .orange)
                Text("From previous set:")
                    .font(.headline)
            }

            ForEach(diff, id: \.0) { plate, change in
                HStack {
                    PlateVisual(weight: plate)
                    Spacer()
                    Text("\(formatWeight(plate)) \(weightUnit.abbreviation)")
                        .fontWeight(.medium)
                    Text(change > 0 ? "+ \(change)" : "- \(abs(change))")
                        .foregroundStyle(change > 0 ? .green : .orange)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(isAddingPlates ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var validationWarning: some View {
        if !isValidWeight && weightPerSide > 0 {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Cannot achieve exact weight with available plates")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private var availablePlatesButton: some View {
        Button {
            showingPlateEditor = true
        } label: {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Available Plates")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if hasCustomConfig {
                                Text("(Custom)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        Text(currentPlates.map { formatWeight($0.weight) }.joined(separator: ", ") + " \(weightUnit.abbreviation)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }

                Text("Tap to customize plates for this exercise")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func saveMachineWeight() {
        settings.setMachineWeight(localMachineWeight, for: exerciseName)
        if [0.0, 20.0, 35.0, 45.0].contains(localMachineWeight) {
            customWeightText = ""
        }
    }

    private func formatWeight(_ w: Double) -> String {
        WeightConverter.format(w, unit: weightUnit, includeUnit: false)
    }
}
