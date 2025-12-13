import SwiftUI

// MARK: - Equipment Step

struct EquipmentStep: View {
    @Binding var selectedEquipment: Set<Equipment>
    @Binding var selectedMachines: Set<SpecificMachine>
    @Binding var showingMachineSelection: Bool
    let equipmentManager: EquipmentManaging

    var body: some View {
        VStack(spacing: 20) {
            Text("What equipment do you have?")
                .font(.title)
                .fontWeight(.bold)

            Text("Select all that apply")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 12) {
                    // Use reusable equipment selection cards (standard equipment only for onboarding)
                    EquipmentSelectionCards(
                        selectedEquipment: $selectedEquipment,
                        equipmentManager: equipmentManager
                    )

                    // Use reusable machine selection button
                    MachineSelectionButton(
                        selectedMachines: $selectedMachines,
                        showingMachineSelection: $showingMachineSelection
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
}

// Note: MachineSelectionView has been replaced by the reusable MachineSelectionSheet
// in EquipmentSelectionComponents.swift
