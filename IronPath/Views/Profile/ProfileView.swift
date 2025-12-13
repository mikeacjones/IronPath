import SwiftUI
import UIKit

// MARK: - Profile View

struct ProfileView: View {
    @Environment(AppState.self) var appState
    @State private var gymProfileManager = GymProfileManager.shared
    @State private var providerManager = AIProviderManager.shared
    @State private var appSettings = AppSettings.shared
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
                gymProfilesSection
                activeGymSettingsSection

                if let profile = appState.userProfile {
                    personalInfoSection(profile: profile)
                    goalsSection(profile: profile)
                    trainingProgramSection(profile: profile)
                    preferencesSection(profile: profile)
                    advancedTechniquesSection(profile: profile)
                    editProfileSection
                }

                customEquipmentSection
                aiProviderSection
                appSettingsSection
                notificationsSection
                dataManagementSection
                resetOnboardingSection
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

// MARK: - Profile Sections

private extension ProfileView {
    var gymProfilesSection: some View {
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
    }

    var activeGymSettingsSection: some View {
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
    }

    func personalInfoSection(profile: UserProfile) -> some View {
        Section("Personal Info") {
            LabeledContent("Name", value: profile.name)
            LabeledContent("Fitness Level", value: profile.fitnessLevel.rawValue)
        }
    }

    func goalsSection(profile: UserProfile) -> some View {
        Section("Goals") {
            ForEach(Array(profile.goals), id: \.self) { goal in
                Text(goal.rawValue)
            }
        }
    }

    func trainingProgramSection(profile: UserProfile) -> some View {
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
    }

    func preferencesSection(profile: UserProfile) -> some View {
        Section("Preferences") {
            LabeledContent("Workout Duration", value: "\(profile.workoutPreferences.preferredWorkoutDuration) min")
            LabeledContent("Workouts per Week", value: "\(profile.workoutPreferences.workoutsPerWeek)")
            LabeledContent("Rest Time", value: "\(profile.workoutPreferences.preferredRestTime)s")
        }
    }

    func advancedTechniquesSection(profile: UserProfile) -> some View {
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
    }

    var editProfileSection: some View {
        Section {
            Button("Edit Profile") {
                showingEditProfile = true
            }
        }
    }

    var customEquipmentSection: some View {
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
    }

    var aiProviderSection: some View {
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
    }

    var appSettingsSection: some View {
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
    }

    var notificationsSection: some View {
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
    }

    var dataManagementSection: some View {
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
    }

    var resetOnboardingSection: some View {
        Section {
            Button("Reset Onboarding", role: .destructive) {
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                appState.isOnboarded = false
                appState.userProfile = nil
            }
        }
    }
}
