import SwiftUI

// MARK: - Gym Profile Row

struct GymProfileRow: View {
    let profile: GymProfile
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Button {
                onSelect()
            } label: {
                HStack {
                    Image(systemName: profile.icon)
                        .font(.title2)
                        .foregroundStyle(isActive ? .blue : .secondary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .fontWeight(isActive ? .semibold : .regular)
                        Text("\(profile.availableEquipment.count) equipment types")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Gym Profile Editor

struct GymProfileEditorView: View {
    let profile: GymProfile?
    let onSave: (GymProfile) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "dumbbell.fill"
    @State private var selectedEquipment: Set<Equipment> = Set(Equipment.allCases)
    @State private var selectedMachines: Set<SpecificMachine> = Set(SpecificMachine.allCases)
    @State private var dumbbellMaxWeight: Double = 120.0
    @State private var showingDeleteConfirmation = false
    @State private var showingMachineSelection = false

    private let icons = [
        "dumbbell.fill",
        "building.2.fill",
        "house.fill",
        "figure.strengthtraining.traditional",
        "building.columns.fill",
        "briefcase.fill"
    ]

    private var isEditing: Bool {
        profile != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Info") {
                    TextField("Profile Name", text: $name)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Toggle(equipment.rawValue, isOn: Binding(
                            get: { selectedEquipment.contains(equipment) },
                            set: { isOn in
                                if isOn {
                                    selectedEquipment.insert(equipment)
                                } else {
                                    selectedEquipment.remove(equipment)
                                }
                            }
                        ))
                    }
                } header: {
                    Text("Available Equipment")
                } footer: {
                    Text("Select all equipment available at this gym")
                }

                Section {
                    Button {
                        showingMachineSelection = true
                    } label: {
                        HStack {
                            Text("Other Machines")
                            Spacer()
                            Text("\(selectedMachines.count) selected")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Other Machines")
                } footer: {
                    Text("Select specific gym machines available (pec deck, hack squat, etc.)")
                }

                Section("Quick Settings") {
                    Stepper("Max Dumbbell: \(Int(dumbbellMaxWeight)) lbs", value: $dumbbellMaxWeight, in: 10...200, step: 10)
                }

                if isEditing && onDelete != nil {
                    Section {
                        Button("Delete Profile", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Gym Profile" : "New Gym Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let profile = profile {
                    name = profile.name
                    selectedIcon = profile.icon
                    selectedEquipment = profile.availableEquipment
                    selectedMachines = profile.availableMachines
                    dumbbellMaxWeight = profile.dumbbellMaxWeight
                }
            }
            .sheet(isPresented: $showingMachineSelection) {
                GymMachineSelectionView(selectedMachines: $selectedMachines)
            }
            .alert("Delete Profile?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this gym profile and its settings.")
            }
        }
    }

    private func saveProfile() {
        var updatedProfile = profile ?? GymProfile(
            name: name,
            icon: selectedIcon,
            availableEquipment: selectedEquipment,
            availableMachines: selectedMachines,
            defaultCableConfig: .defaultConfig
        )

        updatedProfile.name = name
        updatedProfile.icon = selectedIcon
        updatedProfile.availableEquipment = selectedEquipment
        updatedProfile.availableMachines = selectedMachines
        updatedProfile.dumbbellMaxWeight = dumbbellMaxWeight

        onSave(updatedProfile)
        dismiss()
    }
}

// MARK: - Gym Machine Selection View

struct GymMachineSelectionView: View {
    @Binding var selectedMachines: Set<SpecificMachine>
    @Environment(\.dismiss) var dismiss

    var allSelected: Bool {
        selectedMachines.count == SpecificMachine.allCases.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if allSelected {
                            selectedMachines.removeAll()
                        } else {
                            selectedMachines = Set(SpecificMachine.allCases)
                        }
                    } label: {
                        HStack {
                            Text(allSelected ? "Deselect All" : "Select All")
                                .fontWeight(.medium)
                            Spacer()
                            if allSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                Section {
                    ForEach(SpecificMachine.allCases, id: \.self) { machine in
                        Button {
                            if selectedMachines.contains(machine) {
                                selectedMachines.remove(machine)
                            } else {
                                selectedMachines.insert(machine)
                            }
                        } label: {
                            HStack {
                                Text(machine.rawValue)
                                Spacer()
                                if selectedMachines.contains(machine) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
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
}
