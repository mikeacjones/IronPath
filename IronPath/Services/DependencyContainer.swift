import Foundation
import SwiftUI

// MARK: - Dependency Container

/// Central dependency injection container for the application
/// Provides factory methods for ViewModels with all dependencies injected
/// Enables easy testing by allowing mock implementations to be injected
@Observable
@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    // MARK: - Dependencies

    /// Workout data persistence
    let workoutDataManager: WorkoutDataManaging

    /// Active workout session management
    let activeWorkoutManager: ActiveWorkoutManaging

    /// Pending workout storage
    let pendingWorkoutManager: PendingWorkoutManaging

    /// Rest timer management
    let restTimerManager: RestTimerManaging

    /// Exercise timer management (for timed exercises like planks)
    let exerciseTimerManager: ExerciseTimerManaging

    /// Gym profile management
    let gymProfileManager: GymProfileManaging

    /// AI provider management
    let aiProviderManager: AIProviderManaging

    /// Exercise similarity calculations
    let similarityService: ExerciseSimilarityServicing

    /// Exercise preference management
    let exercisePreferenceManager: ExercisePreferenceManaging

    /// App settings
    let appSettings: AppSettingsProviding

    /// Gym settings
    let gymSettings: GymSettingsProviding

    /// Equipment manager
    let equipmentManager: EquipmentManaging

    /// Custom equipment storage
    let customEquipmentStore: CustomEquipmentStoring

    /// Custom exercise storage
    let customExerciseStore: CustomExerciseStoring

    /// Exercise database
    let exerciseDatabase: ExerciseDatabaseProviding

    // MARK: - Initialization

    /// Create container with production dependencies (default)
    init() {
        self.workoutDataManager = WorkoutDataManager.shared
        self.activeWorkoutManager = ActiveWorkoutManager.shared
        self.pendingWorkoutManager = PendingWorkoutManager.shared
        self.restTimerManager = RestTimerManager.shared
        self.exerciseTimerManager = ExerciseTimerManager.shared
        self.gymProfileManager = GymProfileManager.shared
        self.aiProviderManager = AIProviderManager.shared
        self.similarityService = ExerciseSimilarityService.shared
        self.exercisePreferenceManager = ExercisePreferenceManager.shared
        self.appSettings = AppSettings.shared
        self.gymSettings = GymSettings.shared
        self.equipmentManager = EquipmentManager.shared
        self.customEquipmentStore = CustomEquipmentStore.shared
        self.customExerciseStore = CustomExerciseStore.shared
        self.exerciseDatabase = ExerciseDatabase.shared
    }

    /// Create container with custom dependencies (for testing)
    init(
        workoutDataManager: WorkoutDataManaging,
        activeWorkoutManager: ActiveWorkoutManaging,
        pendingWorkoutManager: PendingWorkoutManaging,
        restTimerManager: RestTimerManaging,
        exerciseTimerManager: ExerciseTimerManaging,
        gymProfileManager: GymProfileManaging,
        aiProviderManager: AIProviderManaging,
        similarityService: ExerciseSimilarityServicing,
        exercisePreferenceManager: ExercisePreferenceManaging,
        appSettings: AppSettingsProviding,
        gymSettings: GymSettingsProviding,
        equipmentManager: EquipmentManaging,
        customEquipmentStore: CustomEquipmentStoring,
        customExerciseStore: CustomExerciseStoring,
        exerciseDatabase: ExerciseDatabaseProviding
    ) {
        self.workoutDataManager = workoutDataManager
        self.activeWorkoutManager = activeWorkoutManager
        self.pendingWorkoutManager = pendingWorkoutManager
        self.restTimerManager = restTimerManager
        self.exerciseTimerManager = exerciseTimerManager
        self.gymProfileManager = gymProfileManager
        self.aiProviderManager = aiProviderManager
        self.similarityService = similarityService
        self.exercisePreferenceManager = exercisePreferenceManager
        self.appSettings = appSettings
        self.gymSettings = gymSettings
        self.equipmentManager = equipmentManager
        self.customEquipmentStore = customEquipmentStore
        self.customExerciseStore = customExerciseStore
        self.exerciseDatabase = exerciseDatabase
    }

    // MARK: - ViewModel Factory Methods

    /// Create an ActiveWorkoutViewModel with all dependencies
    func makeActiveWorkoutViewModel(
        workout: Workout,
        userProfile: UserProfile?
    ) -> ActiveWorkoutViewModel {
        ActiveWorkoutViewModel(
            workout: workout,
            userProfile: userProfile,
            activeWorkoutManager: activeWorkoutManager,
            workoutDataManager: workoutDataManager,
            restTimerManager: restTimerManager
        )
    }

    /// Create a WorkoutEditorViewModel
    func makeWorkoutEditorViewModel(
        workout: Workout,
        userProfile: UserProfile? = nil
    ) -> WorkoutEditorViewModel {
        WorkoutEditorViewModel(
            workout: workout,
            userProfile: userProfile
        )
    }

    /// Create an ExerciseReplacementViewModel with all dependencies
    func makeExerciseReplacementViewModel() -> ExerciseReplacementViewModel {
        ExerciseReplacementViewModel(
            aiProviderManager: aiProviderManager,
            similarityService: similarityService,
            gymProfileManager: gymProfileManager
        )
    }
}

// MARK: - Environment Key

/// Environment key for accessing the dependency container
private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

extension View {
    /// Inject a custom dependency container into the view hierarchy
    func dependencyContainer(_ container: DependencyContainer) -> some View {
        environment(\.dependencyContainer, container)
    }
}
