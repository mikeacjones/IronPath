import Foundation
import SwiftUI
import Combine

// MARK: - Dependency Container

/// Central dependency injection container for the application
/// Provides factory methods for ViewModels with all dependencies injected
/// Enables easy testing by allowing mock implementations to be injected
@MainActor
class DependencyContainer: ObservableObject {
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

    // MARK: - Observation Forwarding

    /// Cancellables for forwarding objectWillChange from managers
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Create container with production dependencies (default)
    init() {
        self.workoutDataManager = WorkoutDataManager.shared
        self.activeWorkoutManager = ActiveWorkoutManager.shared
        self.pendingWorkoutManager = PendingWorkoutManager.shared
        self.restTimerManager = RestTimerManager.shared
        self.gymProfileManager = GymProfileManager.shared
        self.aiProviderManager = AIProviderManager.shared
        self.similarityService = ExerciseSimilarityService.shared
        self.exercisePreferenceManager = ExercisePreferenceManager.shared
        self.appSettings = AppSettings.shared
        self.gymSettings = GymSettings.shared

        setupObservationForwarding()
    }

    /// Create container with custom dependencies (for testing)
    init(
        workoutDataManager: WorkoutDataManaging,
        activeWorkoutManager: ActiveWorkoutManaging,
        pendingWorkoutManager: PendingWorkoutManaging,
        restTimerManager: RestTimerManaging,
        gymProfileManager: GymProfileManaging,
        aiProviderManager: AIProviderManaging,
        similarityService: ExerciseSimilarityServicing,
        exercisePreferenceManager: ExercisePreferenceManaging,
        appSettings: AppSettingsProviding,
        gymSettings: GymSettingsProviding
    ) {
        self.workoutDataManager = workoutDataManager
        self.activeWorkoutManager = activeWorkoutManager
        self.pendingWorkoutManager = pendingWorkoutManager
        self.restTimerManager = restTimerManager
        self.gymProfileManager = gymProfileManager
        self.aiProviderManager = aiProviderManager
        self.similarityService = similarityService
        self.exercisePreferenceManager = exercisePreferenceManager
        self.appSettings = appSettings
        self.gymSettings = gymSettings

        setupObservationForwarding()
    }

    /// Forward objectWillChange from observable managers to this container
    /// This allows views observing the container to react to manager state changes
    private func setupObservationForwarding() {
        // Forward from ActiveWorkoutManager
        if let manager = activeWorkoutManager as? ActiveWorkoutManager {
            manager.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // Forward from PendingWorkoutManager
        if let manager = pendingWorkoutManager as? PendingWorkoutManager {
            manager.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // Forward from RestTimerManager
        if let manager = restTimerManager as? RestTimerManager {
            manager.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // Forward from GymProfileManager
        if let manager = gymProfileManager as? GymProfileManager {
            manager.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // Forward from ExercisePreferenceManager
        if let manager = exercisePreferenceManager as? ExercisePreferenceManager {
            manager.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // Forward from AppSettings
        if let settings = appSettings as? AppSettings {
            settings.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }

        // Forward from GymSettings
        if let settings = gymSettings as? GymSettings {
            settings.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
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
