# IronPath - Claude Code Instructions

## Project Overview

IronPath is a SwiftUI fitness tracking iOS app using MVVM architecture with Swift concurrency patterns.

**Build & Run:**
```bash
xcodebuild -scheme IronPath -destination 'platform=iOS Simulator,name=iPhone 16' build
```

---

## Swift & SwiftUI Best Practices (iOS 17+ / 2025)

### Architecture: MVVM with Dependency Injection

**ViewModels:**
- Use `@Observable` macro (iOS 17+) for ViewModels instead of `ObservableObject`
- Keep Views thin - business logic belongs in ViewModels
- ViewModels should be `@MainActor` isolated when they update UI state
- Inject dependencies via initializer, not singletons

```swift
// PREFERRED: @Observable (iOS 17+)
@Observable
@MainActor
final class WorkoutViewModel {
    var workout: Workout
    var isLoading = false

    private let workoutService: WorkoutServiceProtocol

    init(workout: Workout, workoutService: WorkoutServiceProtocol) {
        self.workout = workout
        self.workoutService = workoutService
    }
}

// In View - no wrapper needed for @Observable
struct WorkoutView: View {
    var viewModel: WorkoutViewModel

    var body: some View {
        // View automatically tracks @Observable changes
    }
}
```

**For shared/singleton managers (legacy pattern in this codebase):**
```swift
// Use @StateObject for singletons owned by the view
@StateObject private var manager = SomeManager.shared  // CORRECT

// NEVER use @ObservedObject for singletons
@ObservedObject private var manager = SomeManager.shared  // WRONG - causes issues
```

### View Composition

**Keep views small and focused:**
- Extract subviews when a view exceeds ~150 lines
- Use `ViewBuilder` functions for conditional content
- Prefer composition over massive switch statements

```swift
// PREFERRED: Small, focused views
struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        HStack {
            exerciseInfo
            Spacer()
            exerciseStats
        }
    }

    private var exerciseInfo: some View { ... }
    private var exerciseStats: some View { ... }
}

// AVOID: Massive views with hundreds of lines
```

**Environment for dependency injection:**
```swift
// Define environment key
private struct WorkoutServiceKey: EnvironmentKey {
    static let defaultValue: WorkoutServiceProtocol = WorkoutService()
}

extension EnvironmentValues {
    var workoutService: WorkoutServiceProtocol {
        get { self[WorkoutServiceKey.self] }
        set { self[WorkoutServiceKey.self] = newValue }
    }
}

// Inject at app root
ContentView()
    .environment(\.workoutService, container.workoutService)

// Consume in views
@Environment(\.workoutService) private var workoutService
```

### Swift Concurrency

**Actor isolation:**
```swift
// Managers that touch UI state should be @MainActor
@MainActor
class CloudSyncManager: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle

    func sync() async {
        syncStatus = .syncing
        // ... async work
        syncStatus = .completed
    }
}

// For @objc notification handlers on @MainActor classes
@objc nonisolated private func handleNotification(_ notification: Notification) {
    Task { @MainActor in
        // Update UI state here
    }
}
```

**Async/await patterns:**
```swift
// PREFERRED: Structured concurrency
func loadData() async throws {
    async let workouts = workoutService.fetchWorkouts()
    async let exercises = exerciseService.fetchExercises()

    let (w, e) = try await (workouts, exercises)
    self.workouts = w
    self.exercises = e
}

// AVOID: DispatchQueue.main.async in async contexts
// Use: Task { @MainActor in } or mark method @MainActor
```

**Task management in views:**
```swift
struct WorkoutView: View {
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        content
            .task {
                await viewModel.loadData()
            }
            .onDisappear {
                loadTask?.cancel()
            }
    }
}
```

### State Management

**Choose the right property wrapper:**

| Wrapper | Use Case |
|---------|----------|
| `@State` | Simple value types owned by the view |
| `@Binding` | Two-way connection to parent's state |
| `@StateObject` | ObservableObject created & owned by this view |
| `@ObservedObject` | ObservableObject passed in from parent |
| `@Environment` | Dependency injection, system values |
| `@Observable` (no wrapper) | iOS 17+ observable objects |

**Avoid state duplication:**
```swift
// WRONG: Duplicating state
@State private var localWorkout: Workout  // Copy of viewModel.workout

// RIGHT: Single source of truth
var body: some View {
    WorkoutRow(workout: viewModel.workout)
}
```

### Error Handling

```swift
// Use Result type or throws for service methods
protocol WorkoutServiceProtocol {
    func saveWorkout(_ workout: Workout) async throws
    func fetchWorkouts() async throws -> [Workout]
}

// Handle errors at the ViewModel level
@Observable
@MainActor
final class WorkoutViewModel {
    var error: Error?
    var showError = false

    func save() async {
        do {
            try await workoutService.saveWorkout(workout)
        } catch {
            self.error = error
            self.showError = true
        }
    }
}
```

### Testing Considerations

**Design for testability:**
```swift
// Protocol-based dependencies
protocol WorkoutDataManaging {
    func saveWorkout(_ workout: Workout) async throws
    func fetchWorkouts() async throws -> [Workout]
}

// Easy to mock in tests
class MockWorkoutDataManager: WorkoutDataManaging {
    var savedWorkouts: [Workout] = []
    var workoutsToReturn: [Workout] = []

    func saveWorkout(_ workout: Workout) async throws {
        savedWorkouts.append(workout)
    }

    func fetchWorkouts() async throws -> [Workout] {
        workoutsToReturn
    }
}
```

---

## Project-Specific Conventions

### File Organization
```
IronPath/
├── Models/           # Data models, Codable structs
├── ViewModels/       # @Observable ViewModels
├── Views/
│   ├── Components/   # Reusable UI components
│   ├── ActiveWorkout/
│   └── Profile/
├── Services/         # Business logic, API calls, persistence
└── Protocols/        # Protocol definitions for DI
```

### Naming Conventions
- ViewModels: `{Feature}ViewModel` (e.g., `ActiveWorkoutViewModel`)
- Views: `{Feature}View` (e.g., `ActiveWorkoutView`)
- Services: `{Domain}Service` or `{Domain}Manager`
- Protocols: `{Name}Protocol` or `{Name}ing` (e.g., `WorkoutDataManaging`)

### Common Patterns in This Codebase

**Singleton managers** (being migrated to DI):
- `WorkoutDataManager.shared`
- `RestTimerManager.shared`
- `GymSettings.shared`
- `CloudSyncManager.shared`

When using these, always use `@StateObject`:
```swift
@StateObject private var settings = GymSettings.shared
```

**DependencyContainer:**
```swift
@EnvironmentObject private var dependencies: DependencyContainer
```

---

## Common Pitfalls to Avoid

1. **@ObservedObject for singletons** - Causes re-creation issues. Use @StateObject.

2. **Blocking main thread** - Always use `async/await` for I/O operations.

3. **Massive view files** - Extract components when files exceed 300 lines.

4. **State in multiple places** - Single source of truth. Don't duplicate model data.

5. **Force unwrapping** - Use `guard let`, `if let`, or nil coalescing.

6. **Ignoring task cancellation** - Check `Task.isCancelled` in long operations.

7. **Missing @MainActor** - UI updates must happen on main actor.

8. **Hardcoded strings** - Use constants or localization keys.

---

## Code Review Checklist

Before committing SwiftUI code, verify:

- [ ] ViewModels use `@Observable` or `ObservableObject` with proper isolation
- [ ] No `@ObservedObject` for singleton `.shared` instances
- [ ] Async operations use structured concurrency
- [ ] Dependencies are injected, not accessed via `.shared` in new code
- [ ] Views are focused (<300 lines) with extracted subviews
- [ ] Error states are handled and displayed to user
- [ ] No force unwraps without clear safety guarantees
- [ ] `@MainActor` used for UI-updating code
