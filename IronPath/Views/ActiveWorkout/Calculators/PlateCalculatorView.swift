import SwiftUI

// MARK: - Plate Calculator View

/// Calculator for determining which plates to load on a barbell or machine
struct PlateCalculatorView: View {
    let totalWeight: Double
    let equipment: Equipment
    let exerciseName: String
    var previousWeight: Double? = nil  // Previous set weight for comparison

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var showingPlateEditor = false
    @State private var customWeightText: String = ""
    @State private var localMachineWeight: Double = 0
    @State private var localIsSingleSided: Bool = false

    /// Label for the machine/bar weight based on equipment type
    private var machineWeightLabel: String {
        switch equipment {
        case .legPress:
            return "Sled Weight"
        case .smithMachine:
            return "Bar Weight"
        default:
            return "Bar Weight"
        }
    }

    private var equipmentLabel: String {
        switch equipment {
        case .legPress:
            return "Leg Press"
        case .smithMachine:
            return "Smith Machine"
        case .squat:
            return "Squat Rack"
        default:
            return "Barbell"
        }
    }

    /// The weight to load with plates (total minus machine weight)
    private var plateWeight: Double {
        max(0, totalWeight - localMachineWeight)
    }

    /// Weight per side (or total if single-sided)
    private var weightPerSide: Double {
        if localIsSingleSided {
            return plateWeight
        }
        return plateWeight / 2
    }

    private var currentPlates: [AvailablePlate] {
        settings.availablePlates(for: exerciseName)
    }

    private var platesNeeded: [(Double, Int)] {
        var remaining = weightPerSide
        var plates: [(Double, Int)] = []

        for plate in currentPlates {
            var count = Int(remaining / plate.weight)
            // Respect quantity limit if set
            if plate.hasLimit {
                count = min(count, plate.count)
            }
            if count > 0 {
                plates.append((plate.weight, count))
                remaining -= Double(count) * plate.weight
            }
        }

        return plates
    }

    private var isValidWeight: Bool {
        var remaining = weightPerSide
        for plate in currentPlates {
            var count = Int(remaining / plate.weight)
            // Respect quantity limit if set
            if plate.hasLimit {
                count = min(count, plate.count)
            }
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

    /// Previous set weight per side (for comparison)
    private var previousWeightPerSide: Double? {
        guard let prevWeight = previousWeight, prevWeight > 0 else { return nil }
        let prevPlateWeight = max(0, prevWeight - localMachineWeight)
        return localIsSingleSided ? prevPlateWeight : prevPlateWeight / 2
    }

    /// Calculate plates needed for previous weight
    private var previousPlatesNeeded: [(Double, Int)]? {
        guard let prevPerSide = previousWeightPerSide else { return nil }
        var remaining = prevPerSide
        var plates: [(Double, Int)] = []

        for plate in currentPlates {
            var count = Int(remaining / plate.weight)
            if plate.hasLimit {
                count = min(count, plate.count)
            }
            if count > 0 {
                plates.append((plate.weight, count))
                remaining -= Double(count) * plate.weight
            }
        }

        return plates
    }

    /// Calculate plate difference from previous set (positive = add, negative = remove)
    /// Prefers showing only additions when possible - only shows removals when mathematically necessary
    private var plateDifference: [(Double, Int)]? {
        guard let prevPlates = previousPlatesNeeded,
              let prevPerSide = previousWeightPerSide,
              previousWeight != totalWeight else { return nil }

        // If weight is increasing, try to achieve it by only adding plates
        if weightPerSide > prevPerSide {
            let additionalWeightNeeded = weightPerSide - prevPerSide
            let additionalPlates = calculatePlatesForWeight(additionalWeightNeeded)

            // Check if we can make up the exact difference with available plates
            let achievedWeight = additionalPlates.reduce(0.0) { $0 + $1.0 * Double($1.1) }
            if abs(achievedWeight - additionalWeightNeeded) < 0.01 {
                // Success! We can reach the target by just adding plates
                return additionalPlates.isEmpty ? nil : additionalPlates
            }
        }

        // Fall back to full recalculation (for weight decrease or when add-only is impossible)
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

    /// Calculate plates needed for a specific weight using greedy algorithm
    private func calculatePlatesForWeight(_ targetWeight: Double) -> [(Double, Int)] {
        var remaining = targetWeight
        var plates: [(Double, Int)] = []

        for plate in currentPlates {
            var count = Int(remaining / plate.weight)
            if plate.hasLimit {
                count = min(count, plate.count)
            }
            if count > 0 {
                plates.append((plate.weight, count))
                remaining -= Double(count) * plate.weight
            }
        }

        return plates
    }

    /// Whether we're adding or removing plates overall
    private var isAddingPlates: Bool {
        totalWeight > (previousWeight ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Total weight display
                    VStack(spacing: 8) {
                        Text("Total Weight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(totalWeight)) lbs")
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

                    // Machine/Bar/Sled weight selector
                    VStack(spacing: 8) {
                        Text(machineWeightLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Preset weight buttons
                        HStack(spacing: 8) {
                            ForEach([0.0, 20.0, 35.0, 45.0], id: \.self) { weight in
                                Button {
                                    localMachineWeight = weight
                                    saveMachineWeight()
                                } label: {
                                    Text("\(Int(weight))")
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

                        // Custom weight input
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
                            Text("lbs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if hasCustomMachineWeight {
                            Text("Saved for \(exerciseName)")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }

                    // Single-sided toggle
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

                    Divider()

                    // Weight per side (or total plate weight if single-sided)
                    VStack(spacing: 8) {
                        Text(localIsSingleSided ? "Total Plate Weight" : "Each Side")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.1f", weightPerSide)) lbs")
                            .font(.title)
                            .fontWeight(.semibold)
                    }

                    // Plate breakdown
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
                                    Text("\(formatWeight(plate)) lbs")
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

                        // Show plate difference from previous set
                        if let diff = plateDifference {
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
                                        Text("\(formatWeight(plate)) lbs")
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
                    }

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

                    Divider()

                    // Available plates section
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
                                    Text(currentPlates.map { formatWeight($0.weight) }.joined(separator: ", ") + " lbs")
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

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPlateEditor) {
                AvailablePlatesEditor(exerciseName: exerciseName)
            }
            .onAppear {
                // Load saved settings for this exercise
                localMachineWeight = settings.machineWeight(for: exerciseName, equipment: equipment)
                localIsSingleSided = settings.isSingleSided(for: exerciseName)
                // Update custom weight text if not a preset
                if ![0.0, 20.0, 35.0, 45.0].contains(localMachineWeight) {
                    customWeightText = formatWeight(localMachineWeight)
                }
            }
        }
    }

    private func saveMachineWeight() {
        settings.setMachineWeight(localMachineWeight, for: exerciseName)
        // Update text field if it's a preset
        if [0.0, 20.0, 35.0, 45.0].contains(localMachineWeight) {
            customWeightText = ""
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Available Plates Editor

/// Editor for customizing available plate sizes (per-exercise)
struct AvailablePlatesEditor: View {
    let exerciseName: String

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var newPlateWeight: String = ""
    @State private var newPlateCount: String = ""
    @State private var localPlates: [AvailablePlate] = []

    private var hasCustomConfig: Bool {
        settings.hasCustomPlateConfig(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            List {
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

                Section {
                    ForEach(Array(localPlates.enumerated()), id: \.element.weight) { index, plate in
                        PlateRowEditor(
                            plate: $localPlates[index],
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

                Section {
                    HStack {
                        TextField("Weight", text: $newPlateWeight)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)

                        Text("lbs")
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

                Section {
                    if hasCustomConfig {
                        Button("Use Default Plates") {
                            settings.resetPlateConfig(for: exerciseName)
                            localPlates = settings.defaultAvailablePlates
                        }
                        .foregroundStyle(.blue)
                    }

                    Button("Reset to Standard Plates") {
                        localPlates = GymSettings.standardPlates
                        saveChanges()
                    }
                    .foregroundStyle(.orange)
                } footer: {
                    Text("Standard: 45, 35, 25, 10, 5, 2.5 lbs (unlimited)")
                }
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
                localPlates = settings.availablePlates(for: exerciseName)
            }
        }
    }

    private func addPlate() {
        guard let weight = Double(newPlateWeight), weight > 0 else { return }

        let count = Int(newPlateCount) ?? 0

        // Check if plate already exists
        if let existingIndex = localPlates.firstIndex(where: { $0.weight == weight }) {
            // Update existing plate's count
            localPlates[existingIndex].count = count
        } else {
            // Add new plate
            localPlates.append(AvailablePlate(weight: weight, count: count))
            localPlates.sort { $0.weight > $1.weight }
        }
        saveChanges()
        newPlateWeight = ""
        newPlateCount = ""
    }

    private func saveChanges() {
        settings.setAvailablePlates(localPlates, for: exerciseName)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Plate Row Editor

/// Row editor for a single plate with quantity
struct PlateRowEditor: View {
    @Binding var plate: AvailablePlate
    let onUpdate: () -> Void

    @State private var countText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            PlateVisual(weight: plate.weight)
            Text("\(formatWeight(plate.weight)) lbs")
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
                        // Save when focus is lost
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

/// Visual representation of a weight plate with size and color
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
            // Custom plates get a color based on weight range
            if weight >= 50 { return .purple }
            else if weight >= 30 { return .blue }
            else if weight >= 15 { return .green }
            else if weight >= 7 { return .yellow }
            else { return .orange }
        }
    }

    private var plateHeight: CGFloat {
        // Scale height based on weight
        let minHeight: CGFloat = 14
        let maxHeight: CGFloat = 44
        let heightRange = maxHeight - minHeight

        // Log scale for better visual representation
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
