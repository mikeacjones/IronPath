import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @Environment(DependencyContainer.self) private var dependencies
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

    @State private var warmupSetMode: TechniqueRequirementMode = .allowed
    @State private var dropSetMode: TechniqueRequirementMode = .allowed
    @State private var restPauseSetMode: TechniqueRequirementMode = .allowed
    @State private var supersetMode: TechniqueRequirementMode = .allowed

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
                        showingMachineSelection: $showingMachineSelection,
                        equipmentManager: dependencies.equipmentManager
                    )
                        .tag(7)

                    AdvancedTechniquesStep(
                        warmupSetMode: $warmupSetMode,
                        dropSetMode: $dropSetMode,
                        restPauseSetMode: $restPauseSetMode,
                        supersetMode: $supersetMode
                    )
                        .tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentStep) { _, _ in
                    isTextFieldFocused = false
                }

                navigationButtons
            }
            .navigationTitle("Welcome to IronPath")
            .sheet(isPresented: $showingMachineSelection) {
                MachineSelectionSheet(
                    selectedMachines: $selectedMachines,
                    includeCustomMachines: false,
                    equipmentManager: dependencies.equipmentManager
                )
            }
        }
    }

    private var navigationButtons: some View {
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

    private var canProceed: Bool {
        switch currentStep {
        case 0: return true
        case 1: return !name.isEmpty
        case 2: return true
        case 3: return !selectedGoals.isEmpty
        case 4: return true
        case 5: return true
        case 6: return !gymName.isEmpty
        case 7: return !selectedEquipment.isEmpty
        case 8: return true
        default: return false
        }
    }

    private func completeOnboarding() {
        let advancedSettings = AdvancedTechniqueSettings(
            warmupSetMode: warmupSetMode,
            dropSetMode: dropSetMode,
            restPauseSetMode: restPauseSetMode,
            supersetMode: supersetMode
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

        if var gymProfile = GymProfileManager.shared.activeProfile {
            gymProfile.name = gymName
            gymProfile.availableEquipment = selectedEquipment
            gymProfile.availableMachines = selectedMachines
            GymProfileManager.shared.updateProfile(gymProfile)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .environment(DependencyContainer.shared)
}
