import SwiftUI

// MARK: - Equipment Selection List

/// Reusable equipment selection component
/// Uses EquipmentManager as single source of truth
struct EquipmentSelectionList: View {
    @Binding var selectedEquipment: Set<Equipment>
    let includeCustomEquipment: Bool
    let equipmentManager: EquipmentManaging

    /// Equipment options based on whether custom equipment should be shown
    private var equipmentOptions: [EquipmentManager.EquipmentOption] {
        includeCustomEquipment
            ? equipmentManager.allEquipmentOptions
            : equipmentManager.standardEquipmentOptions
    }

    var body: some View {
        ForEach(equipmentOptions) { option in
            equipmentToggle(for: option)
        }
    }

    @ViewBuilder
    private func equipmentToggle(for option: EquipmentManager.EquipmentOption) -> some View {
        if let standardEquipment = option.standardEquipment {
            Toggle(option.displayName, isOn: Binding(
                get: { selectedEquipment.contains(standardEquipment) },
                set: { isOn in
                    if isOn {
                        selectedEquipment.insert(standardEquipment)
                    } else {
                        selectedEquipment.remove(standardEquipment)
                    }
                }
            ))
        }
        // Custom equipment toggle would go here in future implementation
    }
}

// MARK: - Equipment Selection Grid (Card Style)

/// Card-style equipment selection for onboarding flow
struct EquipmentSelectionCards: View {
    @Binding var selectedEquipment: Set<Equipment>
    let equipmentManager: EquipmentManaging

    var body: some View {
        ForEach(equipmentManager.standardEquipmentOptions) { option in
            if let standardEquipment = option.standardEquipment {
                Button {
                    toggleSelection(standardEquipment)
                } label: {
                    HStack {
                        Image(systemName: option.icon)
                            .font(.title2)
                            .frame(width: 32)
                            .foregroundStyle(selectedEquipment.contains(standardEquipment) ? .blue : .secondary)

                        Text(option.displayName)
                            .font(.headline)

                        Spacer()

                        if selectedEquipment.contains(standardEquipment) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(selectedEquipment.contains(standardEquipment) ? Color.blue.opacity(0.2) : Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleSelection(_ equipment: Equipment) {
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
    }
}

// MARK: - Machine Selection Sheet

/// Reusable machine selection sheet
/// Uses EquipmentManager as single source of truth
struct MachineSelectionSheet: View {
    @Binding var selectedMachines: Set<SpecificMachine>
    let includeCustomMachines: Bool
    let equipmentManager: EquipmentManaging
    @Environment(\.dismiss) private var dismiss

    /// Machine options based on whether custom machines should be shown
    private var machineOptions: [EquipmentManager.MachineOption] {
        includeCustomMachines
            ? equipmentManager.allMachineOptions
            : equipmentManager.standardMachineOptions
    }

    private var allStandardSelected: Bool {
        let standardMachines = Set(SpecificMachine.allCases)
        return standardMachines.isSubset(of: selectedMachines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        toggleSelectAll()
                    } label: {
                        HStack {
                            Text(allStandardSelected ? "Deselect All" : "Select All")
                                .fontWeight(.medium)
                            Spacer()
                            if allStandardSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                Section {
                    ForEach(machineOptions) { option in
                        machineRow(for: option)
                    }
                } header: {
                    Text("Available Machines")
                }
            }
            .navigationTitle("Other Machines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func machineRow(for option: EquipmentManager.MachineOption) -> some View {
        if let standardMachine = option.standardMachine {
            Button {
                toggleSelection(standardMachine)
            } label: {
                HStack {
                    Text(option.displayName)
                    Spacer()
                    if selectedMachines.contains(standardMachine) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        // Custom machine row would go here in future implementation
    }

    private func toggleSelection(_ machine: SpecificMachine) {
        if selectedMachines.contains(machine) {
            selectedMachines.remove(machine)
        } else {
            selectedMachines.insert(machine)
        }
    }

    private func toggleSelectAll() {
        if allStandardSelected {
            // Remove all standard machines
            for machine in SpecificMachine.allCases {
                selectedMachines.remove(machine)
            }
        } else {
            // Add all standard machines
            selectedMachines.formUnion(SpecificMachine.allCases)
        }
    }
}

// MARK: - Machine Selection Button

/// Button that opens the machine selection sheet
struct MachineSelectionButton: View {
    @Binding var selectedMachines: Set<SpecificMachine>
    @Binding var showingMachineSelection: Bool

    var body: some View {
        Button {
            showingMachineSelection = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Other Machines")
                        .font(.headline)
                    if !selectedMachines.isEmpty {
                        Text("\(selectedMachines.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(!selectedMachines.isEmpty ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
