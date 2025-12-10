import SwiftUI

/// Main Equipment Manager view - hub for managing all equipment
struct EquipmentManagerView: View {
    @ObservedObject private var equipmentManager = EquipmentManager.shared
    @ObservedObject private var customEquipmentStore = CustomEquipmentStore.shared

    @State private var showingAddEquipment = false
    @State private var editingEquipment: CustomEquipment?

    var body: some View {
        List {
            // Standard Equipment Section (read-only)
            Section {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    HStack {
                        Image(systemName: equipmentManager.iconForEquipment(equipment))
                            .foregroundStyle(.blue)
                            .frame(width: 30)
                        Text(equipment.rawValue)
                        Spacer()
                        Text("Standard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Standard Equipment")
            } footer: {
                Text("Built-in equipment types available to all users")
            }

            // Custom Equipment Categories
            Section {
                let customCategories = customEquipmentStore.customEquipment
                    .filter { $0.equipmentType == .equipmentCategory }

                if customCategories.isEmpty {
                    Text("No custom equipment categories")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(customCategories) { equipment in
                        CustomEquipmentRow(
                            equipment: equipment,
                            onEdit: { editingEquipment = equipment }
                        )
                    }
                    .onDelete { indexSet in
                        deleteCustomEquipment(at: indexSet, type: .equipmentCategory)
                    }
                }
            } header: {
                HStack {
                    Text("Custom Equipment Categories")
                    Spacer()
                    Button {
                        showingAddEquipment = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            } footer: {
                Text("General equipment types like barbells, dumbbells, or specialized equipment")
            }

            // Custom Specific Machines
            Section {
                let customMachines = customEquipmentStore.customEquipment
                    .filter { $0.equipmentType == .specificMachine }

                if customMachines.isEmpty {
                    Text("No custom machines")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(customMachines) { equipment in
                        CustomEquipmentRow(
                            equipment: equipment,
                            onEdit: { editingEquipment = equipment }
                        )
                    }
                    .onDelete { indexSet in
                        deleteCustomEquipment(at: indexSet, type: .specificMachine)
                    }
                }
            } header: {
                HStack {
                    Text("Custom Machines")
                    Spacer()
                    Button {
                        showingAddEquipment = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            } footer: {
                Text("Specific gym machines like specialty racks, cable attachments, or unique equipment")
            }
        }
        .navigationTitle("Equipment Manager")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddEquipment = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddEquipment) {
            AddCustomEquipmentView()
        }
        .sheet(item: $editingEquipment) { equipment in
            EditCustomEquipmentView(equipment: equipment)
        }
    }

    private func deleteCustomEquipment(at indexSet: IndexSet, type: CustomEquipment.CustomEquipmentType) {
        let equipmentOfType = customEquipmentStore.customEquipment
            .filter { $0.equipmentType == type }

        for index in indexSet {
            let equipment = equipmentOfType[index]
            customEquipmentStore.deleteEquipment(id: equipment.id)
        }
    }
}

// MARK: - Custom Equipment Row

struct CustomEquipmentRow: View {
    let equipment: CustomEquipment
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Image(systemName: equipment.icon)
                .foregroundStyle(.purple)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(equipment.displayName)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Text(equipment.equipmentType.displayName)

                    Text("•")

                    Image(systemName: equipment.weightConfiguration.iconName)
                        .font(.caption2)
                    Text(equipment.weightConfiguration.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Edit Custom Equipment View

struct EditCustomEquipmentView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var customEquipmentStore = CustomEquipmentStore.shared

    let equipment: CustomEquipment

    @State private var displayName: String
    @State private var selectedIcon: String
    @State private var selectedWeightConfig: CustomEquipment.WeightConfiguration
    @State private var errorMessage: String?

    init(equipment: CustomEquipment) {
        self.equipment = equipment
        _displayName = State(initialValue: equipment.displayName)
        _selectedIcon = State(initialValue: equipment.icon)
        _selectedWeightConfig = State(initialValue: equipment.weightConfiguration)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Equipment Name", text: $displayName)
                } header: {
                    Text("Equipment Details")
                }

                // Weight Configuration Section
                Section {
                    Picker("Weight Type", selection: $selectedWeightConfig) {
                        ForEach(CustomEquipment.WeightConfiguration.allCases, id: \.self) { config in
                            Label(config.displayName, systemImage: config.iconName)
                                .tag(config)
                        }
                    }
                } header: {
                    Text("Weight Configuration")
                } footer: {
                    Text(selectedWeightConfig.description)
                }

                // Icon picker
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 8) {
                        ForEach(EquipmentManager.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Icon")
                }

                Section {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(equipment.equipmentType.displayName)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Equipment type cannot be changed after creation")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        var updated = equipment
        updated.displayName = displayName.trimmingCharacters(in: .whitespaces)
        updated.name = CustomEquipment.normalizeName(displayName)
        updated.icon = selectedIcon
        updated.weightConfiguration = selectedWeightConfig

        do {
            try customEquipmentStore.updateEquipment(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        EquipmentManagerView()
    }
}
