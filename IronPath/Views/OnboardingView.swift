import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @FocusState private var isTextFieldFocused: Bool
    @State private var currentStep = 0
    @State private var name = ""
    @State private var gymName = "My Gym"
    @State private var fitnessLevel: FitnessLevel = .beginner
    @State private var selectedGoals: Set<FitnessGoal> = []
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var selectedMachines: Set<SpecificMachine> = []
    @State private var workoutsPerWeek = 3
    @State private var workoutDuration = 60
    @State private var trainingStyle: TrainingStyle = .hypertrophy
    @State private var workoutSplit: WorkoutSplit = .pushPullLegs
    @State private var showingMachineSelection = false

    // Advanced technique settings
    @State private var allowWarmupSets = true
    @State private var allowDropSets = true
    @State private var allowRestPauseSets = true
    @State private var allowSupersets = true

    private let totalSteps = 9

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .padding(.horizontal)

                TabView(selection: $currentStep) {
                    WelcomeStep()
                        .tag(0)

                    NameStep(name: $name, isFocused: $isTextFieldFocused)
                        .tag(1)

                    FitnessLevelStep(fitnessLevel: $fitnessLevel)
                        .tag(2)

                    GoalsStep(selectedGoals: $selectedGoals)
                        .tag(3)

                    TrainingProgramStep(trainingStyle: $trainingStyle, workoutSplit: $workoutSplit)
                        .tag(4)

                    ScheduleStep(workoutsPerWeek: $workoutsPerWeek, workoutDuration: $workoutDuration)
                        .tag(5)

                    GymNameStep(gymName: $gymName, isFocused: $isTextFieldFocused)
                        .tag(6)

                    EquipmentStep(
                        selectedEquipment: $selectedEquipment,
                        selectedMachines: $selectedMachines,
                        showingMachineSelection: $showingMachineSelection
                    )
                        .tag(7)

                    AdvancedTechniquesStep(
                        allowWarmupSets: $allowWarmupSets,
                        allowDropSets: $allowDropSets,
                        allowRestPauseSets: $allowRestPauseSets,
                        allowSupersets: $allowSupersets
                    )
                        .tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentStep) { _, _ in
                    // Dismiss keyboard when changing steps
                    isTextFieldFocused = false
                }

                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button(currentStep == totalSteps - 1 ? "Get Started" : "Next") {
                        if currentStep == totalSteps - 1 {
                            completeOnboarding()
                        } else {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                }
                .padding()
            }
            .navigationTitle("Welcome to IronPath")
            .sheet(isPresented: $showingMachineSelection) {
                MachineSelectionView(selectedMachines: $selectedMachines)
            }
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return true
        case 1: return !name.isEmpty
        case 2: return true
        case 3: return !selectedGoals.isEmpty
        case 4: return true // Training program always has defaults
        case 5: return true // Schedule always has defaults
        case 6: return !gymName.isEmpty
        case 7: return !selectedEquipment.isEmpty
        case 8: return true // Advanced techniques always has defaults
        default: return false
        }
    }

    private func completeOnboarding() {
        let advancedSettings = AdvancedTechniqueSettings(
            allowWarmupSets: allowWarmupSets,
            allowDropSets: allowDropSets,
            allowRestPauseSets: allowRestPauseSets,
            allowSupersets: allowSupersets
        )

        let profile = UserProfile(
            name: name,
            fitnessLevel: fitnessLevel,
            goals: selectedGoals,
            availableEquipment: selectedEquipment,
            workoutPreferences: WorkoutPreferences(
                preferredWorkoutDuration: workoutDuration,
                workoutsPerWeek: workoutsPerWeek,
                trainingStyle: trainingStyle,
                workoutSplit: workoutSplit,
                advancedTechniqueSettings: advancedSettings
            )
        )
        appState.completeOnboarding(profile: profile)

        // Update the default gym profile with name, equipment, and machines
        if var gymProfile = GymProfileManager.shared.activeProfile {
            gymProfile.name = gymName
            gymProfile.availableEquipment = selectedEquipment
            gymProfile.availableMachines = selectedMachines
            GymProfileManager.shared.updateProfile(gymProfile)
        }
    }
}

// MARK: - Onboarding Steps

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Welcome to IronPath")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("AI-powered personalized workouts tailored to your goals, equipment, and fitness level")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct NameStep: View {
    @Binding var name: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 30) {
            Text("What's your name?")
                .font(.title)
                .fontWeight(.bold)

            TextField("Enter your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused(isFocused)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct FitnessLevelStep: View {
    @Binding var fitnessLevel: FitnessLevel

    var body: some View {
        VStack(spacing: 30) {
            Text("What's your fitness level?")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 15) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    Button {
                        fitnessLevel = level
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(level.rawValue)
                                .font(.headline)
                            Text(level.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(fitnessLevel == level ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct GoalsStep: View {
    @Binding var selectedGoals: Set<FitnessGoal>

    var body: some View {
        VStack(spacing: 30) {
            Text("What are your goals?")
                .font(.title)
                .fontWeight(.bold)

            Text("Select all that apply")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    Button {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    } label: {
                        HStack {
                            Text(goal.rawValue)
                                .font(.headline)
                            Spacer()
                            if selectedGoals.contains(goal) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(selectedGoals.contains(goal) ? Color.blue.opacity(0.2) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct TrainingProgramStep: View {
    @Binding var trainingStyle: TrainingStyle
    @Binding var workoutSplit: WorkoutSplit

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Choose your training program")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Training Style")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        ForEach(TrainingStyle.allCases, id: \.self) { style in
                            Button {
                                trainingStyle = style
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(style.rawValue)
                                            .font(.headline)
                                        Spacer()
                                        if trainingStyle == style {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    Text(style.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(trainingStyle == style ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    Text("Workout Split")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 10)

                    VStack(spacing: 12) {
                        ForEach(WorkoutSplit.allCases, id: \.self) { split in
                            Button {
                                workoutSplit = split
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(split.rawValue)
                                            .font(.headline)
                                        Spacer()
                                        if workoutSplit == split {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    Text(split.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(workoutSplit == split ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct EquipmentStep: View {
    @Binding var selectedEquipment: Set<Equipment>
    @Binding var selectedMachines: Set<SpecificMachine>
    @Binding var showingMachineSelection: Bool

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
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Button {
                            if selectedEquipment.contains(equipment) {
                                selectedEquipment.remove(equipment)
                            } else {
                                selectedEquipment.insert(equipment)
                            }
                        } label: {
                            HStack {
                                Text(equipment.rawValue)
                                    .font(.headline)
                                Spacer()
                                if selectedEquipment.contains(equipment) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding()
                            .background(selectedEquipment.contains(equipment) ? Color.blue.opacity(0.2) : Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    // Other Machines section
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
                .padding(.horizontal)
            }
        }
        .padding()
    }
}

struct MachineSelectionView: View {
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

struct ScheduleStep: View {
    @Binding var workoutsPerWeek: Int
    @Binding var workoutDuration: Int

    var body: some View {
        VStack(spacing: 30) {
            Text("Your workout schedule")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workouts per week")
                        .font(.headline)

                    HStack(spacing: 8) {
                        ForEach([2, 3, 4, 5, 6], id: \.self) { count in
                            Button {
                                workoutsPerWeek = count
                            } label: {
                                Text("\(count)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .frame(width: 50, height: 50)
                                    .background(workoutsPerWeek == count ? Color.blue : Color(.systemGray6))
                                    .foregroundStyle(workoutsPerWeek == count ? .white : .primary)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Workout duration")
                        .font(.headline)

                    VStack(spacing: 8) {
                        ForEach([30, 45, 60, 75, 90], id: \.self) { duration in
                            Button {
                                workoutDuration = duration
                            } label: {
                                HStack {
                                    Text("\(duration) minutes")
                                        .font(.headline)
                                    Spacer()
                                    if workoutDuration == duration {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding()
                                .background(workoutDuration == duration ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct GymNameStep: View {
    @Binding var gymName: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Name your gym")
                .font(.title)
                .fontWeight(.bold)

            Text("You can add more gym profiles later for different locations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("My Gym", text: $gymName)
                .textFieldStyle(.roundedBorder)
                .focused(isFocused)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct AdvancedTechniquesStep: View {
    @Binding var allowWarmupSets: Bool
    @Binding var allowDropSets: Bool
    @Binding var allowRestPauseSets: Bool
    @Binding var allowSupersets: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Advanced techniques")
                .font(.title)
                .fontWeight(.bold)

            Text("Enable or disable advanced training techniques for AI-generated workouts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    AdvancedTechniqueToggle(
                        title: "Warmup Sets",
                        description: "Light sets to prepare muscles before working sets",
                        icon: "flame",
                        color: .orange,
                        isEnabled: $allowWarmupSets
                    )

                    AdvancedTechniqueToggle(
                        title: "Drop Sets",
                        description: "Continue with reduced weight after reaching failure",
                        icon: "arrow.down.circle",
                        color: .red,
                        isEnabled: $allowDropSets
                    )

                    AdvancedTechniqueToggle(
                        title: "Rest-Pause Sets",
                        description: "Brief rest then continue reps within the same set",
                        icon: "pause.circle",
                        color: .blue,
                        isEnabled: $allowRestPauseSets
                    )

                    AdvancedTechniqueToggle(
                        title: "Supersets & Circuits",
                        description: "Multiple exercises performed back-to-back",
                        icon: "arrow.triangle.2.circlepath",
                        color: .purple,
                        isEnabled: $allowSupersets
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct AdvancedTechniqueToggle: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
