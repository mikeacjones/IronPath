import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var gymProfileManager = GymProfileManager.shared
    @ObservedObject private var providerManager = AIProviderManager.shared
    @ObservedObject private var appSettings = AppSettings.shared
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
                        ProfileTechniqueModePicker(
                            title: "Warmup Sets",
                            description: "Lighter weight sets before working sets",
                            icon: "flame",
                            iconColor: .orange,
                            selection: Binding(
                                get: { profile.workoutPreferences.advancedTechniqueSettings.warmupSetMode },
                                set: { newValue in
                                    var updated = profile
                                    updated.workoutPreferences.advancedTechniqueSettings.warmupSetMode = newValue
                                    appState.userProfile = updated
                                }
                            )
                        )

                        ProfileTechniqueModePicker(
                            title: "Drop Sets",
                            description: "Reduce weight and continue after failure",
                            icon: "arrow.down.circle.fill",
                            iconColor: .purple,
                            selection: Binding(
                                get: { profile.workoutPreferences.advancedTechniqueSettings.dropSetMode },
                                set: { newValue in
                                    var updated = profile
                                    updated.workoutPreferences.advancedTechniqueSettings.dropSetMode = newValue
                                    appState.userProfile = updated
                                }
                            )
                        )

                        ProfileTechniqueModePicker(
                            title: "Rest-Pause Sets",
                            description: "Brief rest then continue same weight",
                            icon: "pause.circle.fill",
                            iconColor: .green,
                            selection: Binding(
                                get: { profile.workoutPreferences.advancedTechniqueSettings.restPauseSetMode },
                                set: { newValue in
                                    var updated = profile
                                    updated.workoutPreferences.advancedTechniqueSettings.restPauseSetMode = newValue
                                    appState.userProfile = updated
                                }
                            )
                        )

                        ProfileTechniqueModePicker(
                            title: "Supersets & Circuits",
                            description: "Group exercises with minimal rest between",
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: .blue,
                            selection: Binding(
                                get: { profile.workoutPreferences.advancedTechniqueSettings.supersetMode },
                                set: { newValue in
                                    var updated = profile
                                    updated.workoutPreferences.advancedTechniqueSettings.supersetMode = newValue
                                    appState.userProfile = updated
                                }
                            )
                        )
                    } header: {
                        Text("Advanced Training Techniques")
                    } footer: {
                        Text("Required: Always include. Allowed: AI decides. Disabled: Never include.")
                    }

                    Section {
                        Button("Edit Profile") {
                            showingEditProfile = true
                        }
                    }
                }

                Section {
                    NavigationLink {
                        EquipmentManagerView()
                    } label: {
                        Label("Equipment Manager", systemImage: "wrench.and.screwdriver")
                    }
                } header: {
                    Text("Custom Equipment")
                } footer: {
                    Text("Add custom equipment and machines to your library")
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
                    Toggle(isOn: $appSettings.showYouTubeVideos) {
                        Label("Show Exercise Videos", systemImage: "play.rectangle")
                    }

                    Toggle(isOn: $appSettings.showFormTips) {
                        Label("Show Form Tips", systemImage: "lightbulb")
                    }

                    Toggle(isOn: $appSettings.showAIWorkoutSummary) {
                        Label("AI Workout Summary", systemImage: "text.bubble")
                    }
                } header: {
                    Text("App Settings")
                } footer: {
                    Text("Control what's displayed in the exercise detail view and workout completion screen.")
                }

                Section {
                    Picker(selection: $appSettings.restNotificationSound) {
                        ForEach(RestNotificationSound.allCases, id: \.self) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    } label: {
                        Label("Rest Timer Sound", systemImage: "speaker.wave.2")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Volume", systemImage: appSettings.restNotificationVolume > 0.7 ? "speaker.wave.3" : (appSettings.restNotificationVolume > 0.3 ? "speaker.wave.2" : "speaker.wave.1"))
                            Spacer()
                            Text("\(Int(appSettings.restNotificationVolume * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $appSettings.restNotificationVolume, in: 0.1...1.0, step: 0.1)
                    }
                    .disabled(appSettings.restNotificationSound == .none)

                    Button {
                        appSettings.restNotificationSound.playSound()
                    } label: {
                        Label("Preview Sound", systemImage: "play.circle")
                    }
                    .disabled(appSettings.restNotificationSound == .none)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Choose the sound that plays when your rest timer completes. Higher volume settings include vibration. The sound will play whether the app is in the foreground or background.")
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
                        Label("Clear All Data", systemImage: "trash")
                    }
                    .alert("Clear All Data?", isPresented: $showingResetConfirmation) {
                        Button("Clear All Data", role: .destructive) {
                            Task {
                                await CloudSyncManager.shared.clearAllData()
                                // Reset app state after clearing data
                                await MainActor.run {
                                    appState.isOnboarded = false
                                    appState.userProfile = nil
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete ALL app data including workout history, profile, gym settings, and API keys from this device and iCloud. This action cannot be undone.")
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export your workout history or clear all data to start fresh")
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
struct GymEquipmentSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var showingDefaultCableEditor = false
    @State private var showingDumbbellConfig = false

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
                    Text("Configure plate stacks and free weights for your cable machines. Custom configs can be set per-exercise when logging sets.")
                }

                Section {
                    Button {
                        showingDumbbellConfig = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Configure Dumbbells")
                                    .foregroundStyle(.primary)
                                Text(dumbbellSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Dumbbells", systemImage: "dumbbell")
                } footer: {
                    Text("Configure the dumbbell weights available at your gym. You can select specific weights or use a range.")
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
            .sheet(isPresented: $showingDumbbellConfig) {
                DumbbellConfigurationView()
            }
        }
    }

    private var dumbbellSummary: String {
        if let dumbbells = settings.availableDumbbells {
            let sorted = dumbbells.sorted()
            if sorted.count <= 5 {
                return sorted.map { formatWeight($0) }.joined(separator: ", ") + " lbs"
            } else {
                return "\(sorted.count) weights: \(formatWeight(sorted.first ?? 0))-\(formatWeight(sorted.last ?? 0)) lbs"
            }
        } else {
            return "\(formatWeight(settings.dumbbellMinWeight))-\(formatWeight(settings.dumbbellMaxWeight)) lbs (\(formatWeight(settings.dumbbellIncrement)) lb increments)"
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

/// A simple flow layout that wraps content to new lines
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (height: CGFloat, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (y + rowHeight, positions)
    }
}

// MARK: - Free Weights Editor

/// Editor for free weights on a cable machine with count support
/// Allows adding multiple of the same weight (e.g., 3x 5lb plates)
struct FreeWeightsEditor: View {
    @Binding var freeWeights: [CableMachineConfig.FreeWeight]
    @State private var newWeight: String = ""
    @State private var newCount: Int = 1

    /// Common free weight values for quick add
    private let commonWeights: [Double] = [2.5, 5.0, 7.5, 10.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current free weights display
            if freeWeights.isEmpty {
                Text("No free weights configured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach($freeWeights) { $freeWeight in
                        HStack {
                            // Weight display
                            Text("\(formatWeight(freeWeight.weight)) lb")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            // Count stepper
                            HStack(spacing: 8) {
                                Button {
                                    if freeWeight.count > 1 {
                                        freeWeight.count -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(freeWeight.count > 1 ? .blue : .gray)
                                }
                                .disabled(freeWeight.count <= 1)

                                Text("\(freeWeight.count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(minWidth: 24)

                                Button {
                                    freeWeight.count += 1
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }

                            // Delete button
                            Button {
                                withAnimation {
                                    freeWeights.removeAll { $0.id == freeWeight.id }
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            Divider()

            // Quick add buttons for common weights
            Text("Quick Add")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(commonWeights.filter { weight in
                        !freeWeights.contains { $0.weight == weight }
                    }, id: \.self) { weight in
                        Button {
                            withAnimation {
                                freeWeights.append(CableMachineConfig.FreeWeight(weight: weight, count: 1))
                            }
                        } label: {
                            Text("\(formatWeight(weight)) lb")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Custom weight entry
            HStack {
                TextField("Weight", text: $newWeight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)

                Text("lb")
                    .foregroundStyle(.secondary)

                Text("×")
                    .foregroundStyle(.secondary)

                Stepper("\(newCount)", value: $newCount, in: 1...10)
                    .labelsHidden()
                    .frame(width: 94)

                Text("\(newCount)")
                    .frame(width: 20)

                Button("Add") {
                    if let weight = Double(newWeight), weight > 0 {
                        // Check if this weight already exists
                        if let existingIndex = freeWeights.firstIndex(where: { $0.weight == weight }) {
                            // Add to existing count
                            freeWeights[existingIndex].count += newCount
                        } else {
                            // Add new free weight
                            withAnimation {
                                freeWeights.append(CableMachineConfig.FreeWeight(weight: weight, count: newCount))
                            }
                        }
                        newWeight = ""
                        newCount = 1
                    }
                }
                .disabled(Double(newWeight) == nil || (Double(newWeight) ?? 0) <= 0)
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
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

                                TierInputRow(tier: $tier)
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
                    FreeWeightsEditor(freeWeights: $config.freeWeights)
                } header: {
                    Text("Free Weights")
                } footer: {
                    if config.freeWeights.isEmpty {
                        Text("Add-on weights that can be attached to the cable (e.g., 2.5lb or 5lb plates). These are optional when selecting a weight.")
                    } else {
                        let totalFreeWeights = config.freeWeights.reduce(0) { $0 + $1.count }
                        Text("This machine has \(totalFreeWeights) free weight plate(s) available.")
                    }
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

/// Helper view for tier input that allows clearing fields
/// Uses string-based editing and converts to numbers on blur/submit
struct TierInputRow: View {
    @Binding var tier: CableMachineConfig.PlateTier
    @State private var countText: String = ""
    @State private var weightText: String = ""
    @FocusState private var countFocused: Bool
    @FocusState private var weightFocused: Bool

    var body: some View {
        HStack {
            TextField("Count", text: $countText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .focused($countFocused)
                .onChange(of: countFocused) { _, focused in
                    if !focused {
                        commitCount()
                    }
                }
                .onSubmit { commitCount() }
            Text("×")
            TextField("Weight", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .focused($weightFocused)
                .onChange(of: weightFocused) { _, focused in
                    if !focused {
                        commitWeight()
                    }
                }
                .onSubmit { commitWeight() }
            Text("lbs")
                .foregroundStyle(.secondary)
        }
        .onAppear {
            countText = String(tier.plateCount)
            weightText = formatWeight(tier.plateWeight)
        }
        .onChange(of: tier.plateCount) { _, newValue in
            if !countFocused {
                countText = String(newValue)
            }
        }
        .onChange(of: tier.plateWeight) { _, newValue in
            if !weightFocused {
                weightText = formatWeight(newValue)
            }
        }
    }

    private func commitCount() {
        if let value = Int(countText), value > 0 {
            tier.plateCount = value
        } else if countText.isEmpty {
            // Keep minimum of 1 if cleared
            tier.plateCount = 1
            countText = "1"
        } else {
            // Reset to current value if invalid
            countText = String(tier.plateCount)
        }
    }

    private func commitWeight() {
        if let value = Double(weightText), value > 0 {
            tier.plateWeight = value
        } else if weightText.isEmpty {
            // Keep minimum of 1 if cleared
            tier.plateWeight = 1.0
            weightText = "1"
        } else {
            // Reset to current value if invalid
            weightText = formatWeight(tier.plateWeight)
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Dumbbell Configuration View

struct DumbbellConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared

    @State private var useSpecificDumbbells: Bool
    @State private var selectedDumbbells: Set<Double>

    init() {
        let settings = GymSettings.shared
        let hasSpecific = settings.availableDumbbells != nil
        _useSpecificDumbbells = State(initialValue: hasSpecific)
        _selectedDumbbells = State(initialValue: settings.availableDumbbells ?? Set(GymSettings.standardDumbbells.filter { $0 <= settings.dumbbellMaxWeight }))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Select Specific Dumbbells", isOn: $useSpecificDumbbells)
                } footer: {
                    Text(useSpecificDumbbells
                         ? "Choose exactly which dumbbell weights are available at your gym."
                         : "Use a weight range with fixed increments.")
                }

                if useSpecificDumbbells {
                    // Specific dumbbell selection
                    Section {
                        dumbbellSelectionGrid
                    } header: {
                        HStack {
                            Text("Available Dumbbells")
                            Spacer()
                            Text("\(selectedDumbbells.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button("Select All Standard Sizes") {
                            selectedDumbbells = Set(GymSettings.standardDumbbells)
                        }

                        Button("Select Common Sizes (5 lb increments)") {
                            selectedDumbbells = Set(GymSettings.standardDumbbells.filter { $0.truncatingRemainder(dividingBy: 5) == 0 })
                        }

                        Button("Select Hotel Gym Sizes") {
                            selectedDumbbells = Set(GymSettings.limitedDumbbells)
                        }

                        Button("Clear All", role: .destructive) {
                            selectedDumbbells.removeAll()
                        }
                    } header: {
                        Text("Quick Selection")
                    }
                } else {
                    // Range-based settings
                    Section {
                        Stepper("Increment: \(formatWeight(settings.dumbbellIncrement)) lbs",
                                value: $settings.dumbbellIncrement,
                                in: 2.5...10,
                                step: 2.5)

                        Stepper("Min Weight: \(formatWeight(settings.dumbbellMinWeight)) lbs",
                                value: $settings.dumbbellMinWeight,
                                in: 0...20,
                                step: 5)

                        Stepper("Max Weight: \(formatWeight(settings.dumbbellMaxWeight)) lbs",
                                value: $settings.dumbbellMaxWeight,
                                in: 50...200,
                                step: 10)
                    } header: {
                        Text("Weight Range")
                    } footer: {
                        let weights = stride(from: settings.dumbbellMinWeight, through: settings.dumbbellMaxWeight, by: settings.dumbbellIncrement)
                        Text("Available: \(weights.map { formatWeight($0) }.joined(separator: ", ")) lbs")
                            .font(.caption)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        let weights = previewWeights
                        if weights.isEmpty {
                            Text("No dumbbells selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(weights.prefix(20).map { formatWeight($0) }.joined(separator: ", ") + (weights.count > 20 ? "..." : "") + " lbs")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(weights.count) weights available")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Dumbbell Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                        dismiss()
                    }
                    .disabled(useSpecificDumbbells && selectedDumbbells.isEmpty)
                }
            }
        }
    }

    private var previewWeights: [Double] {
        if useSpecificDumbbells {
            return selectedDumbbells.sorted()
        } else {
            return stride(from: settings.dumbbellMinWeight, through: settings.dumbbellMaxWeight, by: settings.dumbbellIncrement).map { $0 }
        }
    }

    private var dumbbellSelectionGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 70), spacing: 8)
        ], spacing: 8) {
            ForEach(GymSettings.standardDumbbells, id: \.self) { weight in
                DumbbellChip(
                    weight: weight,
                    isSelected: selectedDumbbells.contains(weight),
                    onToggle: {
                        if selectedDumbbells.contains(weight) {
                            selectedDumbbells.remove(weight)
                        } else {
                            selectedDumbbells.insert(weight)
                        }
                    }
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func saveConfiguration() {
        if useSpecificDumbbells {
            settings.availableDumbbells = selectedDumbbells
        } else {
            settings.availableDumbbells = nil
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

struct DumbbellChip: View {
    let weight: Double
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(formatWeight(weight))
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(minWidth: 50)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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

// MARK: - Profile Technique Mode Picker

/// A picker row for selecting technique requirement mode in profile settings
struct ProfileTechniqueModePicker: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    @Binding var selection: TechniqueRequirementMode

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $selection) {
                ForEach(TechniqueRequirementMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}
