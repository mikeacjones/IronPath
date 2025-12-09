import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var gymProfileManager = GymProfileManager.shared
    @ObservedObject private var providerManager = AIProviderManager.shared
    @State private var showingEditProfile = false
    @State private var showingGymSettings = false
    @State private var showingGymProfileEditor = false
    @State private var showingNewGymProfile = false
    @State private var editingGymProfile: GymProfile?
    @State private var showingResetConfirmation = false
    @State private var showingExportOptions = false
    @State private var exportData: ExportData?

    var body: some View {
        NavigationStack {
            List {
                // Gym Profile Section (at the top for quick switching)
                Section {
                    ForEach(gymProfileManager.profiles) { profile in
                        GymProfileRow(
                            profile: profile,
                            isActive: profile.id == gymProfileManager.activeProfileId,
                            onSelect: {
                                gymProfileManager.switchToProfile(profile)
                            },
                            onEdit: {
                                editingGymProfile = profile
                            }
                        )
                    }

                    Button {
                        showingNewGymProfile = true
                    } label: {
                        Label("Add Gym Profile", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Gym Profiles")
                } footer: {
                    Text("Create profiles for different gyms (e.g., home gym, hotel, work gym)")
                }

                Section {
                    Button {
                        showingGymSettings = true
                    } label: {
                        HStack {
                            Label("Equipment Settings", systemImage: "gearshape.fill")
                            Spacer()
                            if let profile = gymProfileManager.activeProfile {
                                Text(profile.name)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Active Gym Settings")
                } footer: {
                    Text("Configure cable machines, dumbbells, and plates for the selected gym")
                }

                if let profile = appState.userProfile {
                    Section("Personal Info") {
                        LabeledContent("Name", value: profile.name)
                        LabeledContent("Fitness Level", value: profile.fitnessLevel.rawValue)
                    }

                    Section("Goals") {
                        ForEach(Array(profile.goals), id: \.self) { goal in
                            Text(goal.rawValue)
                        }
                    }

                    Section {
                        Picker("Training Style", selection: Binding(
                            get: { profile.workoutPreferences.trainingStyle },
                            set: { newValue in
                                var updated = profile
                                updated.workoutPreferences.trainingStyle = newValue
                                appState.userProfile = updated
                            }
                        )) {
                            ForEach(TrainingStyle.allCases, id: \.self) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }

                        Picker("Workout Split", selection: Binding(
                            get: { profile.workoutPreferences.workoutSplit },
                            set: { newValue in
                                var updated = profile
                                updated.workoutPreferences.workoutSplit = newValue
                                appState.userProfile = updated
                            }
                        )) {
                            ForEach(WorkoutSplit.allCases, id: \.self) { split in
                                Text(split.rawValue).tag(split)
                            }
                        }
                    } header: {
                        Text("Training Program")
                    } footer: {
                        Text("\(profile.workoutPreferences.trainingStyle.description)\n\(profile.workoutPreferences.workoutSplit.description)")
                    }

                    Section("Preferences") {
                        LabeledContent("Workout Duration", value: "\(profile.workoutPreferences.preferredWorkoutDuration) min")
                        LabeledContent("Workouts per Week", value: "\(profile.workoutPreferences.workoutsPerWeek)")
                        LabeledContent("Rest Time", value: "\(profile.workoutPreferences.preferredRestTime)s")
                    }

                    // Advanced Training Techniques Global Settings
                    Section {
                        Toggle(isOn: Binding(
                            get: { profile.workoutPreferences.advancedTechniqueSettings.allowWarmupSets },
                            set: { newValue in
                                var updated = profile
                                updated.workoutPreferences.advancedTechniqueSettings.allowWarmupSets = newValue
                                appState.userProfile = updated
                            }
                        )) {
                            HStack {
                                Image(systemName: "flame")
                                    .foregroundStyle(.orange)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text("Warmup Sets")
                                    Text("Lighter weight sets before working sets")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { profile.workoutPreferences.advancedTechniqueSettings.allowDropSets },
                            set: { newValue in
                                var updated = profile
                                updated.workoutPreferences.advancedTechniqueSettings.allowDropSets = newValue
                                appState.userProfile = updated
                            }
                        )) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.purple)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text("Drop Sets")
                                    Text("Reduce weight and continue after failure")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { profile.workoutPreferences.advancedTechniqueSettings.allowRestPauseSets },
                            set: { newValue in
                                var updated = profile
                                updated.workoutPreferences.advancedTechniqueSettings.allowRestPauseSets = newValue
                                appState.userProfile = updated
                            }
                        )) {
                            HStack {
                                Image(systemName: "pause.circle.fill")
                                    .foregroundStyle(.green)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text("Rest-Pause Sets")
                                    Text("Brief rest then continue same weight")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { profile.workoutPreferences.advancedTechniqueSettings.allowSupersets },
                            set: { newValue in
                                var updated = profile
                                updated.workoutPreferences.advancedTechniqueSettings.allowSupersets = newValue
                                appState.userProfile = updated
                            }
                        )) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text("Supersets & Circuits")
                                    Text("Group exercises with minimal rest between")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Advanced Training Techniques")
                    } footer: {
                        Text("Enable or disable advanced techniques globally. When enabled, you can choose to require them for individual workouts.")
                    }

                    Section {
                        Button("Edit Profile") {
                            showingEditProfile = true
                        }
                    }
                }

                Section {
                    NavigationLink {
                        AIConfigurationView()
                    } label: {
                        HStack {
                            Label("AI Configuration", systemImage: "cpu")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(providerManager.currentProvider.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if providerManager.isConfigured {
                                    Text(providerManager.selectedModel?.displayName ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            if providerManager.isConfigured {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    if providerManager.isConfigured {
                        Text("Using \(providerManager.currentProvider.displayName) for workout generation.")
                    } else {
                        Text("Configure an AI provider to generate personalized workouts.")
                    }
                }

                Section {
                    Button {
                        showingExportOptions = true
                    } label: {
                        Label("Export Workout Data", systemImage: "square.and.arrow.up")
                    }
                    .confirmationDialog("Export Workout Data", isPresented: $showingExportOptions, titleVisibility: .visible) {
                        Button("Export as JSON") {
                            if let data = WorkoutDataManager.shared.exportHistoryAsJSON(),
                               let string = String(data: data, encoding: .utf8) {
                                exportData = ExportData(content: string, filename: "workout_history.json")
                            }
                        }
                        Button("Export as CSV") {
                            let csv = WorkoutDataManager.shared.exportHistoryAsCSV()
                            exportData = ExportData(content: csv, filename: "workout_history.csv")
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Choose a format for your workout data export")
                    }

                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset All Workout Data", systemImage: "trash")
                    }
                    .confirmationDialog("Reset Workout Data", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                        Button("Reset All Data", role: .destructive) {
                            WorkoutDataManager.shared.clearHistory()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all your workout history. This action cannot be undone.")
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export your workout history or reset all data to start fresh")
                }

                Section {
                    Button("Reset Onboarding", role: .destructive) {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        appState.isOnboarded = false
                        appState.userProfile = nil
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditProfile) {
                if let profile = appState.userProfile {
                    EditProfileView(profile: profile, onSave: { updatedProfile in
                        appState.userProfile = updatedProfile
                        showingEditProfile = false
                    })
                }
            }
            .sheet(isPresented: $showingGymSettings) {
                GymEquipmentSettingsView()
            }
            .sheet(isPresented: $showingNewGymProfile) {
                GymProfileEditorView(
                    profile: nil,
                    onSave: { newProfile in
                        gymProfileManager.addProfile(newProfile)
                        showingNewGymProfile = false
                    }
                )
            }
            .sheet(item: $editingGymProfile) { profile in
                GymProfileEditorView(
                    profile: profile,
                    onSave: { updatedProfile in
                        gymProfileManager.updateProfile(updatedProfile)
                        editingGymProfile = nil
                    },
                    onDelete: gymProfileManager.profiles.count > 1 ? {
                        gymProfileManager.deleteProfile(profile)
                        editingGymProfile = nil
                    } : nil
                )
            }
            .sheet(item: $exportData) { data in
                ShareSheet(items: [data.temporaryFileURL].compactMap { $0 })
            }
        }
    }
}

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
            .confirmationDialog("Delete Profile?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
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
struct GymEquipmentSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var showingDefaultCableEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingDefaultCableEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Default Cable Machine")
                                    .foregroundStyle(.primary)
                                Text(settings.defaultCableConfig.stackDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !settings.cableMachineConfigs.isEmpty {
                        ForEach(Array(settings.cableMachineConfigs.keys.sorted()), id: \.self) { exercise in
                            if let config = settings.cableMachineConfigs[exercise] {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(exercise)
                                        Text(config.stackDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Custom")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let keys = Array(settings.cableMachineConfigs.keys.sorted())
                            for index in indexSet {
                                settings.cableMachineConfigs.removeValue(forKey: keys[index])
                            }
                        }
                    }
                } header: {
                    Label("Cable Machines", systemImage: "cable.connector")
                } footer: {
                    Text("Configure plate stacks for your cable machines. Custom configs can be set per-exercise when logging sets.")
                }

                Section {
                    Stepper("Increment: \(Int(settings.dumbbellIncrement)) lbs",
                            value: $settings.dumbbellIncrement,
                            in: 2.5...10,
                            step: 2.5)

                    Stepper("Min Weight: \(Int(settings.dumbbellMinWeight)) lbs",
                            value: $settings.dumbbellMinWeight,
                            in: 0...20,
                            step: 5)

                    Stepper("Max Weight: \(Int(settings.dumbbellMaxWeight)) lbs",
                            value: $settings.dumbbellMaxWeight,
                            in: 50...200,
                            step: 10)
                } header: {
                    Label("Dumbbells", systemImage: "dumbbell")
                } footer: {
                    Text("Set the dumbbell range available at your gym")
                }

                Section {
                    Text("These settings are sent to Claude when generating workouts to ensure only achievable weights are suggested.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Gym Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDefaultCableEditor) {
                CableMachineConfigEditor(
                    config: settings.defaultCableConfig,
                    title: "Default Cable Machine",
                    onSave: { newConfig in
                        settings.defaultCableConfig = newConfig
                    }
                )
            }
        }
    }
}

// MARK: - Cable Machine Config Editor

struct CableMachineConfigEditor: View {
    @State var config: CableMachineConfig
    let title: String
    let onSave: (CableMachineConfig) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($config.plateTiers) { $tier in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Tier \(config.plateTiers.firstIndex(where: { $0.id == tier.id })! + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    TextField("Count", value: $tier.plateCount, format: .number)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                    Text("×")
                                    TextField("Weight", value: $tier.plateWeight, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 70)
                                    Text("lbs")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                config.plateTiers.removeAll { $0.id == tier.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(config.plateTiers.count <= 1)
                        }
                    }

                    Button {
                        config.plateTiers.append(CableMachineConfig.PlateTier(plateWeight: 10.0, plateCount: 10))
                    } label: {
                        Label("Add Plate Tier", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Plate Stack")
                } footer: {
                    Text("Define your machine's weight stack. Add multiple tiers if plates have different weights (e.g., 6×9lb then 12×12.5lb)")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview: \(config.stackDescription)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Available weights:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let weights = config.availableWeights
                        let preview = weights.prefix(15).map { "\(formatWeight($0))" }.joined(separator: ", ")
                        Text(preview + (weights.count > 15 ? "... (\(weights.count) total)" : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Max: \(formatWeight(weights.last ?? 0)) lbs")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(config)
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

struct APIKeyInputView: View {
    @Binding var apiKey: String
    @Environment(\.dismiss) var dismiss
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Enter your API key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your API key is stored locally on your device and is only used to communicate with Anthropic's Claude API.")

                        Link("Get an API key from console.anthropic.com", destination: URL(string: "https://console.anthropic.com")!)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
        }
    }
}

struct EditProfileView: View {
    let profile: UserProfile
    let onSave: (UserProfile) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var fitnessLevel: FitnessLevel
    @State private var selectedGoals: Set<FitnessGoal>
    @State private var selectedEquipment: Set<Equipment>
    @State private var workoutDuration: Int
    @State private var workoutsPerWeek: Int
    @State private var restTime: Int

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave

        _name = State(initialValue: profile.name)
        _fitnessLevel = State(initialValue: profile.fitnessLevel)
        _selectedGoals = State(initialValue: profile.goals)
        _selectedEquipment = State(initialValue: profile.availableEquipment)
        _workoutDuration = State(initialValue: profile.workoutPreferences.preferredWorkoutDuration)
        _workoutsPerWeek = State(initialValue: profile.workoutPreferences.workoutsPerWeek)
        _restTime = State(initialValue: profile.workoutPreferences.preferredRestTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Info") {
                    TextField("Name", text: $name)

                    Picker("Fitness Level", selection: $fitnessLevel) {
                        ForEach(FitnessLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section("Goals") {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        Toggle(goal.rawValue, isOn: Binding(
                            get: { selectedGoals.contains(goal) },
                            set: { isSelected in
                                if isSelected {
                                    selectedGoals.insert(goal)
                                } else {
                                    selectedGoals.remove(goal)
                                }
                            }
                        ))
                    }
                }

                Section("Equipment") {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Toggle(equipment.rawValue, isOn: Binding(
                            get: { selectedEquipment.contains(equipment) },
                            set: { isSelected in
                                if isSelected {
                                    selectedEquipment.insert(equipment)
                                } else {
                                    selectedEquipment.remove(equipment)
                                }
                            }
                        ))
                    }
                }

                Section("Workout Preferences") {
                    Stepper("Duration: \(workoutDuration) min", value: $workoutDuration, in: 15...120, step: 5)
                    Stepper("Per Week: \(workoutsPerWeek)", value: $workoutsPerWeek, in: 1...7)
                    Stepper("Rest Time: \(restTime)s", value: $restTime, in: 30...180, step: 15)
                }
            }
            .navigationTitle("Edit Profile")
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
                    .disabled(name.isEmpty || selectedGoals.isEmpty || selectedEquipment.isEmpty)
                }
            }
        }
    }

    private func saveProfile() {
        let updatedProfile = UserProfile(
            id: profile.id,
            name: name,
            fitnessLevel: fitnessLevel,
            goals: selectedGoals,
            availableEquipment: selectedEquipment,
            workoutPreferences: WorkoutPreferences(
                preferredWorkoutDuration: workoutDuration,
                workoutsPerWeek: workoutsPerWeek,
                preferredRestTime: restTime,
                avoidInjuries: profile.workoutPreferences.avoidInjuries
            ),
            createdAt: profile.createdAt,
            updatedAt: Date()
        )
        onSave(updatedProfile)
    }
}
