import SwiftUI

// MARK: - API Key Input View

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

// MARK: - Edit Profile View

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
