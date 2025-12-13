import Foundation
import SwiftUI

// MARK: - Exercise Replacement ViewModel

/// ViewModel for managing exercise replacement flow
/// Handles similarity-based suggestions, AI replacement, and quick replacement
@Observable
@MainActor
final class ExerciseReplacementViewModel {

    // MARK: - State

    /// The exercise being replaced
    var exerciseToReplace: WorkoutExercise?

    /// Notes describing why replacement is needed (for AI)
    var replacementNotes: String = ""

    /// Whether an AI replacement request is in progress
    var isLoading: Bool = false

    /// Error message if replacement fails
    var error: String?

    /// Whether to show the error alert
    var showError: Bool = false

    /// Cached similarity suggestions
    private(set) var similaritySuggestions: [(Exercise, Double)] = []

    // MARK: - Dependencies

    private let aiProviderManager: AIProviderManaging
    private let similarityService: ExerciseSimilarityServicing
    private let gymProfileManager: GymProfileManaging
    private let exerciseCountProvider: @MainActor () -> Int
    private var userProfile: UserProfile?

    // MARK: - Context

    /// Current workout exercises (for excluding from suggestions)
    var currentWorkoutExercises: [String] = []

    /// The current workout (needed for AI replacement context)
    var currentWorkout: Workout?

    // MARK: - Callbacks

    /// Called when an exercise is successfully replaced
    var onReplacement: ((WorkoutExercise, WorkoutExercise) -> Void)?

    // MARK: - Initialization

    init(
        aiProviderManager: AIProviderManaging? = nil,
        similarityService: ExerciseSimilarityServicing? = nil,
        gymProfileManager: GymProfileManaging? = nil,
        exerciseCountProvider: (@MainActor () -> Int)? = nil
    ) {
        self.aiProviderManager = aiProviderManager ?? AIProviderManager.shared
        self.similarityService = similarityService ?? ExerciseSimilarityService.shared
        self.gymProfileManager = gymProfileManager ?? GymProfileManager.shared
        self.exerciseCountProvider = exerciseCountProvider ?? {
            ExerciseDatabase.shared.exercises.count + CustomExerciseStore.shared.exercises.count
        }
    }

    // MARK: - Configuration

    func configure(
        userProfile: UserProfile?,
        currentWorkout: Workout?,
        currentWorkoutExercises: [String]
    ) {
        self.userProfile = userProfile
        self.currentWorkout = currentWorkout
        self.currentWorkoutExercises = currentWorkoutExercises
    }

    // MARK: - Replacement Flow

    /// Start the replacement flow for an exercise
    func initiateReplacement(for exercise: WorkoutExercise) {
        replacementNotes = ""
        error = nil
        showError = false
        exerciseToReplace = exercise
        loadSimilaritySuggestions()
    }

    /// Cancel the replacement flow
    func cancelReplacement() {
        exerciseToReplace = nil
        replacementNotes = ""
        similaritySuggestions = []
    }

    // MARK: - Similarity Suggestions

    /// Load similarity-ranked replacement suggestions
    func loadSimilaritySuggestions() {
        guard let exercise = exerciseToReplace else {
            similaritySuggestions = []
            return
        }

        // Get available equipment from gym profile
        let availableEquipment = gymProfileManager.activeProfile?.availableEquipment ?? Set(Equipment.allCases)
        let availableMachines = gymProfileManager.activeProfile?.availableMachines ?? Set(SpecificMachine.allCases)

        similaritySuggestions = similarityService.getReplacementSuggestions(
            for: exercise.exercise,
            excludingWorkoutExercises: currentWorkoutExercises,
            availableEquipment: availableEquipment,
            availableMachines: availableMachines,
            limit: 8
        )
    }

    /// Get the top suggestions (limited for UI display)
    var topSuggestions: [(Exercise, Double)] {
        Array(similaritySuggestions.prefix(5))
    }

    // MARK: - AI Replacement

    /// Request AI to find a replacement exercise
    func requestAIReplacement() async {
        guard let exerciseToReplace = exerciseToReplace,
              let profile = userProfile,
              let workout = currentWorkout else {
            error = "Missing required information for AI replacement"
            showError = true
            return
        }

        isLoading = true
        error = nil

        do {
            let provider = aiProviderManager.currentProvider
            let replacement = try await provider.replaceExercise(
                exercise: exerciseToReplace,
                profile: profile,
                reason: replacementNotes.isEmpty ? nil : replacementNotes,
                currentWorkout: workout
            )

            // Notify of successful replacement
            onReplacement?(exerciseToReplace, replacement)

            // Clear state
            isLoading = false
            self.exerciseToReplace = nil
            replacementNotes = ""
            similaritySuggestions = []

        } catch {
            self.error = error.localizedDescription
            showError = true
            isLoading = false
        }
    }

    // MARK: - Quick Replacement

    /// Quickly replace with a specific exercise (no AI call)
    func quickReplace(with newExercise: Exercise) {
        guard let exerciseToReplace = exerciseToReplace else { return }

        // Create a new WorkoutExercise with the same sets structure but new exercise
        let newSets = exerciseToReplace.sets.map { oldSet in
            ExerciseSet(
                setNumber: oldSet.setNumber,
                targetReps: oldSet.targetReps,
                weight: oldSet.weight,
                restPeriod: oldSet.restPeriod
            )
        }

        let replacement = WorkoutExercise(
            exercise: newExercise,
            sets: newSets,
            orderIndex: exerciseToReplace.orderIndex,
            notes: ""
        )

        // Notify of successful replacement
        onReplacement?(exerciseToReplace, replacement)

        // Clear state
        self.exerciseToReplace = nil
        replacementNotes = ""
        similaritySuggestions = []
    }

    // MARK: - Helpers

    /// Get color based on similarity score
    func similarityColor(for score: Double) -> Color {
        switch score {
        case 0.8...: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .gray
        }
    }

    /// Total number of available exercises
    var totalExerciseCount: Int {
        exerciseCountProvider()
    }
}
