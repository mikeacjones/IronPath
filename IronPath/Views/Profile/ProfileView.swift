import SwiftUI
import UIKit

// MARK: - Profile View

struct ProfileView: View {
    @Environment(AppState.self) var appState
    @Environment(DependencyContainer.self) private var dependencies
    @State private var gymProfileManager = GymProfileManager.shared
    @State private var showingEditProfile = false
    @State private var showingGymSettings = false
    @State private var showingNewGymProfile = false
    @State private var editingGymProfile: GymProfile?

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

                CustomEquipmentSection()
                AIProviderSection()
                AppSettingsSection()
                NotificationsSection()
                DataManagementSection()
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
                    equipmentManager: dependencies.equipmentManager,
                    onSave: { newProfile in
                        gymProfileManager.addProfile(newProfile)
                        showingNewGymProfile = false
                    }
                )
            }
            .sheet(item: $editingGymProfile) { profile in
                GymProfileEditorView(
                    profile: profile,
                    equipmentManager: dependencies.equipmentManager,
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
        }
    }
}

// MARK: - Gym Sections

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
}

// MARK: - User Profile Sections

private extension ProfileView {
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
