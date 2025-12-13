# Architecture Remediation Plan: Missing MVVM Layer

## Executive Summary

**The #1 Issue:** Despite documentation claiming MVVM architecture, the codebase has **zero ViewModels**. All business logic is embedded directly in SwiftUI Views, creating massive, untestable, and duplicated code.

## Evidence

### The Numbers

| Metric | Value |
|--------|-------|
| ActiveWorkoutView.swift lines | 3,441 |
| @State variables in ActiveWorkoutView | 48 |
| Functions in ActiveWorkoutView | 34 |
| Structs in ActiveWorkoutView | 26 |
| Direct singleton (.shared) accesses | 37 |
| ViewModels directory contents | Empty |

### Code Duplication

These functions are **duplicated** between `ActiveWorkoutView.swift` and `WorkoutDetailView.swift`:

- `addExerciseFromLibrary()` - identical logic
- `addExerciseToGroup()` - identical logic (~30 lines each)
- `removeExercise()` - identical logic (~35 lines each)
- `replaceExercise()` - identical logic

### Direct Singleton Access from Views

Views directly call services throughout:
```swift
WorkoutDataManager.shared.saveWorkout()
WorkoutDataManager.shared.detectWorkoutPRs()
RestTimerManager.shared.startGroupTimer()
ActiveWorkoutManager.shared.updateWorkout()
GymProfileManager.shared.activeProfile
AIProviderManager.shared.currentProvider
ExercisePreferenceManager.shared
// ... 37 total .shared accesses in one file
```

## Impact

| Area | Impact |
|------|--------|
| **Adding Features** | Must touch multiple massive view files; risk of inconsistent implementations |
| **Bug Fixes** | Same logic duplicated in multiple places; fix in one, break another |
| **Unit Testing** | Impossible - business logic trapped in Views with hardcoded singletons |
| **Code Reviews** | 3,441 line files are effectively unreviewable |
| **Onboarding** | New developers overwhelmed by complexity |

## Remediation Plan

### Phase 1: Create Core ViewModels (High Impact)

**1.1 Create `ActiveWorkoutViewModel`**

Extract from `ActiveWorkoutView.swift`:
- All 48 @State variables related to workout state
- Workout lifecycle (start, pause, complete, cancel)
- Exercise completion tracking
- PR detection logic
- Workout persistence

```swift
// IronPath/ViewModels/ActiveWorkoutViewModel.swift
@MainActor
class ActiveWorkoutViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentWorkout: Workout
    @Published var workoutStartTime: Date
    @Published var isFinishing: Bool = false
    @Published var showCompletionSummary: Bool = false
    @Published var completedWorkoutForSummary: Workout?

    // MARK: - Dependencies (injected, not .shared)
    private let workoutDataManager: WorkoutDataManaging
    private let activeWorkoutManager: ActiveWorkoutManaging
    private let restTimerManager: RestTimerManaging

    // MARK: - Computed Properties
    var completedExercisesCount: Int { ... }
    var allExercisesCompleted: Bool { ... }

    // MARK: - Actions
    func finishWorkout() async { ... }
    func cancelWorkout() { ... }
    func persistWorkoutState() { ... }
}
```

**1.2 Create `WorkoutEditorViewModel`**

Shared logic between ActiveWorkoutView and WorkoutDetailView:

```swift
// IronPath/ViewModels/WorkoutEditorViewModel.swift
@MainActor
class WorkoutEditorViewModel: ObservableObject {
    @Published var workout: Workout
    @Published var exerciseToReplace: WorkoutExercise?
    @Published var exerciseToRemove: WorkoutExercise?
    @Published var isReplacingExercise: Bool = false
    @Published var replacementError: String?

    // Shared business logic - single source of truth
    func addExerciseFromLibrary(_ exercise: Exercise) { ... }
    func addExerciseToGroup(_ exercise: Exercise, group: ExerciseGroup) { ... }
    func removeExercise(_ exercise: WorkoutExercise) { ... }
    func replaceExercise(notes: String) async throws { ... }
    func createSuperset(from exercises: [WorkoutExercise]) { ... }
    func removeFromSuperset(_ exercise: WorkoutExercise) { ... }
}
```

**1.3 Create `ExerciseReplacementViewModel`**

```swift
// IronPath/ViewModels/ExerciseReplacementViewModel.swift
@MainActor
class ExerciseReplacementViewModel: ObservableObject {
    @Published var replacementNotes: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var suggestedReplacements: [Exercise] = []

    private let aiProvider: AIProviding
    private let similarityService: ExerciseSimilarityService

    func fetchSimilarExercises(for exercise: Exercise) async { ... }
    func requestAIReplacement(for exercise: WorkoutExercise) async throws -> Exercise { ... }
}
```

### Phase 2: Split ActiveWorkoutView.swift

**Target:** Reduce from 3,441 lines to ~300 lines per file

**2.1 Extract Components**

| New File | Lines | Responsibility |
|----------|-------|----------------|
| `ActiveWorkoutView.swift` | ~300 | Main coordinator view |
| `WorkoutTimerHeader.swift` | ~100 | Timer display |
| `WorkoutCompletionSummaryView.swift` | ~200 | Completion modal |
| `PlateCalculatorView.swift` | ~250 | Plate calculator |
| `CableWeightCalculatorView.swift` | ~200 | Cable calculator |
| `ExerciseReplacementSheet.swift` | ~200 | Replacement UI |
| `RestTimerComponents.swift` | ~150 | Rest timer UI |
| `SupersetGroupCard.swift` | ~200 | Superset display |
| `ExerciseRowView.swift` | ~200 | Exercise row UI |

**2.2 Restructure Directory**

```
Views/
  ActiveWorkout/
    ActiveWorkoutView.swift          # Main view (~300 lines)
    Components/
      WorkoutTimerHeader.swift
      ExerciseRowView.swift
      SupersetGroupCard.swift
      RestTimerComponents.swift
    Sheets/
      WorkoutCompletionSummaryView.swift
      ExerciseReplacementSheet.swift
    Calculators/
      PlateCalculatorView.swift
      CableWeightCalculatorView.swift
```

### Phase 3: Dependency Injection

**3.1 Create Protocols for All Managers**

```swift
// IronPath/Protocols/DataManagerProtocols.swift (extend existing)
protocol WorkoutDataManaging {
    func saveWorkout(_ workout: Workout)
    func detectWorkoutPRs(for workout: Workout) -> [PersonalRecord]
    func getSuggestedWeight(for exercise: Exercise) -> Double?
}

protocol ActiveWorkoutManaging {
    var activeWorkout: Workout? { get }
    var workoutStartTime: Date? { get }
    func updateWorkout(_ workout: Workout)
    func clearActiveWorkout()
}

protocol RestTimerManaging {
    func startGroupTimer(duration: TimeInterval, groupId: UUID)
    func cancelTimer()
}
```

**3.2 Create DI Container**

```swift
// IronPath/Services/DependencyContainer.swift
@MainActor
class DependencyContainer {
    static let shared = DependencyContainer()

    // Production dependencies
    lazy var workoutDataManager: WorkoutDataManaging = WorkoutDataManager.shared
    lazy var activeWorkoutManager: ActiveWorkoutManaging = ActiveWorkoutManager.shared
    lazy var restTimerManager: RestTimerManaging = RestTimerManager.shared

    // Factory methods for ViewModels
    func makeActiveWorkoutViewModel(workout: Workout) -> ActiveWorkoutViewModel {
        ActiveWorkoutViewModel(
            workout: workout,
            workoutDataManager: workoutDataManager,
            activeWorkoutManager: activeWorkoutManager,
            restTimerManager: restTimerManager
        )
    }
}
```

**3.3 Update Views to Use Injected Dependencies**

Before:
```swift
struct ActiveWorkoutView: View {
    @ObservedObject private var activeWorkoutManager = ActiveWorkoutManager.shared
    // ... 48 @State variables

    private func finishWorkout() {
        WorkoutDataManager.shared.saveWorkout(currentWorkout)
    }
}
```

After:
```swift
struct ActiveWorkoutView: View {
    @StateObject private var viewModel: ActiveWorkoutViewModel

    init(workout: Workout, container: DependencyContainer = .shared) {
        _viewModel = StateObject(wrappedValue: container.makeActiveWorkoutViewModel(workout: workout))
    }

    var body: some View {
        // View only handles UI, delegates to viewModel
    }
}
```

### Phase 4: Enable Testing

**4.1 Create Mock Implementations**

```swift
// IronPathTests/Mocks/MockWorkoutDataManager.swift
class MockWorkoutDataManager: WorkoutDataManaging {
    var savedWorkouts: [Workout] = []
    var mockPRs: [PersonalRecord] = []

    func saveWorkout(_ workout: Workout) {
        savedWorkouts.append(workout)
    }

    func detectWorkoutPRs(for workout: Workout) -> [PersonalRecord] {
        return mockPRs
    }
}
```

**4.2 Add ViewModel Tests**

```swift
// IronPathTests/ViewModels/ActiveWorkoutViewModelTests.swift
@MainActor
final class ActiveWorkoutViewModelTests: XCTestCase {
    var mockWorkoutManager: MockWorkoutDataManager!
    var viewModel: ActiveWorkoutViewModel!

    override func setUp() {
        mockWorkoutManager = MockWorkoutDataManager()
        viewModel = ActiveWorkoutViewModel(
            workout: TestFixtures.sampleWorkout,
            workoutDataManager: mockWorkoutManager
        )
    }

    func testFinishWorkoutSavesWorkout() async {
        await viewModel.finishWorkout()
        XCTAssertEqual(mockWorkoutManager.savedWorkouts.count, 1)
    }

    func testAllExercisesCompletedWhenAllDone() {
        // Test computed property logic
    }
}
```

## Implementation Order

| Order | Task | Impact | Effort |
|-------|------|--------|--------|
| 1 | Create `WorkoutEditorViewModel` | Eliminates duplication | Medium |
| 2 | Create `ActiveWorkoutViewModel` | Reduces largest file | High |
| 3 | Extract UI components from ActiveWorkoutView | Improves readability | Medium |
| 4 | Add protocols for dependency injection | Enables testing | Low |
| 5 | Create DI container | Clean architecture | Low |
| 6 | Add ViewModel unit tests | Quality assurance | Medium |

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Largest view file | 3,441 lines | < 400 lines |
| @State variables per view | 48 | < 10 |
| ViewModel coverage | 0% | 100% of business logic |
| Unit test coverage | Models/Services only | + ViewModels |
| Code duplication | Multiple instances | Single source of truth |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Regression during refactor | Add characterization tests before refactoring |
| SwiftUI state management complexity | Use `@StateObject` for owned VMs, `@ObservedObject` for passed VMs |
| Breaking existing functionality | Incremental extraction with continuous testing |

## Conclusion

The missing ViewModel layer is the single biggest architectural debt in this codebase. Fixing it will:

1. **Eliminate code duplication** - shared logic in ViewModels
2. **Enable unit testing** - testable business logic
3. **Improve maintainability** - smaller, focused files
4. **Speed up development** - changes in one place, not many
5. **Reduce bugs** - single source of truth for business rules

The recommended approach is incremental: start with `WorkoutEditorViewModel` to eliminate the most obvious duplication, then tackle `ActiveWorkoutViewModel` to break up the largest file.
