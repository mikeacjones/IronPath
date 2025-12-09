import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var name = ""
    @State private var fitnessLevel: FitnessLevel = .beginner
    @State private var selectedGoals: Set<FitnessGoal> = []
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var selectedMachines: Set<SpecificMachine> = []
    @State private var workoutsPerWeek = 3
    @State private var workoutDuration = 60
    @State private var trainingStyle: TrainingStyle = .hypertrophy
    @State private var workoutSplit: WorkoutSplit = .pushPullLegs
    @State private var showingMachineSelection = false

    private let totalSteps = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .padding(.horizontal)

                TabView(selection: $currentStep) {
                    WelcomeStep()
                        .tag(0)

                    NameStep(name: $name)
                        .tag(1)

                    FitnessLevelStep(fitnessLevel: $fitnessLevel)
                        .tag(2)

                    GoalsStep(selectedGoals: $selectedGoals)
                        .tag(3)

                    TrainingProgramStep(trainingStyle: $trainingStyle, workoutSplit: $workoutSplit)
                        .tag(4)

                    EquipmentStep(
                        selectedEquipment: $selectedEquipment,
                        selectedMachines: $selectedMachines,
                        showingMachineSelection: $showingMachineSelection
                    )
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

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
        case 5: return !selectedEquipment.isEmpty
        default: return false
        }
    }

    private func completeOnboarding() {
        let profile = UserProfile(
            name: name,
            fitnessLevel: fitnessLevel,
            goals: selectedGoals,
            availableEquipment: selectedEquipment,
            workoutPreferences: WorkoutPreferences(
                preferredWorkoutDuration: workoutDuration,
                workoutsPerWeek: workoutsPerWeek,
                trainingStyle: trainingStyle,
                workoutSplit: workoutSplit
            )
        )
        appState.completeOnboarding(profile: profile)

        // Update the default gym profile with selected machines
        if var gymProfile = GymProfileManager.shared.activeProfile {
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

    var body: some View {
        VStack(spacing: 30) {
            Text("What's your name?")
                .font(.title)
                .fontWeight(.bold)

            TextField("Enter your name", text: $name)
                .textFieldStyle(.roundedBorder)
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

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
