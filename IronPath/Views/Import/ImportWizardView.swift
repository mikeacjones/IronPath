import SwiftUI

// MARK: - Import Wizard View

/// Main container for the 5-step import wizard
struct ImportWizardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(DependencyContainer.self) private var dependencies

    @State private var session = ImportSession()
    @State private var showingError = false
    @State private var errorMessage = ""

    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar

                // Current step content
                TabView(selection: $session.currentStep) {
                    FileSelectionStep(session: session)
                        .tag(0)

                    DataPreviewStep(session: session)
                        .tag(1)

                    ExerciseMappingStep(
                        session: session,
                        exerciseMatcher: dependencies.exerciseMatcher
                    )
                    .tag(2)

                    WorkoutReviewStep(session: session)
                        .tag(3)

                    ImportProgressStep(
                        session: session,
                        importManager: dependencies.importManager,
                        onComplete: { dismiss() }
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Import Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            // Step indicators
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= session.currentStep ? Color.blue : Color(.systemGray4))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Step label
            Text(stepLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    private var stepLabel: String {
        switch session.currentStep {
        case 0: return "Step 1 of 5: Select File"
        case 1: return "Step 2 of 5: Preview Data"
        case 2: return "Step 3 of 5: Map Exercises"
        case 3: return "Step 4 of 5: Review Workouts"
        case 4: return "Step 5 of 5: Import"
        default: return ""
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            if session.currentStep > 0 && session.currentStep < 4 {
                Button {
                    withAnimation {
                        session.currentStep -= 1
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // Next/Import button
            if session.currentStep < 4 {
                Button {
                    withAnimation {
                        session.currentStep += 1
                    }
                } label: {
                    Label(nextButtonLabel, systemImage: nextButtonIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var nextButtonLabel: String {
        switch session.currentStep {
        case 0: return "Continue"
        case 1: return "Continue"
        case 2: return session.allExercisesMapped ? "Continue" : "Skip Unmapped"
        case 3: return "Start Import"
        default: return "Next"
        }
    }

    private var nextButtonIcon: String {
        switch session.currentStep {
        case 3: return "square.and.arrow.down"
        default: return "chevron.right"
        }
    }

    private var canProceed: Bool {
        switch session.currentStep {
        case 0: return !session.parsedWorkouts.isEmpty
        case 1: return !session.selectedWorkouts.isEmpty
        case 2: return true // Can skip unmapped exercises
        case 3: return !session.workoutsToImport.isEmpty
        default: return false
        }
    }
}

// MARK: - Preview

#Preview {
    ImportWizardView()
        .environment(DependencyContainer.shared)
}
