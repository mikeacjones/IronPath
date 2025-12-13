# IronPath - Claude Code Instructions

## Project Overview

IronPath is a SwiftUI fitness tracking iOS app targeting iOS 17+ using MVVM architecture with Swift concurrency.

**Build & Run:**
```bash
xcodebuild -scheme IronPath -destination 'platform=iOS Simulator,name=iPhone 16' build
```

---

## Swift & SwiftUI Best Practices (iOS 17+ / 2025)

### Architecture: MVVM with Dependency Injection

**ViewModels use `@Observable` macro:**
```swift
@Observable
@MainActor
final class WorkoutViewModel {
    var workout: Workout
    var isLoading = false
    var error: Error?

    private let workoutService: WorkoutServiceProtocol

    init(workout: Workout, workoutService: WorkoutServiceProtocol) {
        self.workout = workout
        self.workoutService = workoutService
    }

    func save() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await workoutService.saveWorkout(workout)
        } catch {
            self.error = error
        }
    }
}
```

**Views consume `@Observable` directly - no property wrapper needed:**
```swift
struct WorkoutView: View {
    var viewModel: WorkoutViewModel

    var body: some View {
        // SwiftUI automatically tracks @Observable changes
        List(viewModel.workout.exercises) { exercise in
            ExerciseRow(exercise: exercise)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}
```

**Use `@State` when the view owns the `@Observable` object:**
```swift
struct WorkoutContainerView: View {
    @State private var viewModel: WorkoutViewModel

    init(workout: Workout, workoutService: WorkoutServiceProtocol) {
        _viewModel = State(initialValue: WorkoutViewModel(
            workout: workout,
            workoutService: workoutService
        ))
    }

    var body: some View {
        WorkoutView(viewModel: viewModel)
    }
}
```

### Dependency Injection via Environment

**Define environment keys for services:**
```swift
extension EnvironmentValues {
    @Entry var workoutService: WorkoutServiceProtocol = WorkoutService()
    @Entry var exerciseService: ExerciseServiceProtocol = ExerciseService()
}
```

**Inject at app root:**
```swift
@main
struct IronPathApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.workoutService, ProductionWorkoutService())
                .environment(\.exerciseService, ProductionExerciseService())
        }
    }
}
```

**Consume in views:**
```swift
struct WorkoutView: View {
    @Environment(\.workoutService) private var workoutService

    var body: some View {
        // Use workoutService here
    }
}
```

### View Composition

**Keep views small and focused (~150 lines max):**
```swift
struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        HStack {
            exerciseInfo
            Spacer()
            exerciseStats
        }
    }

    private var exerciseInfo: some View {
        VStack(alignment: .leading) {
            Text(exercise.name).font(.headline)
            Text(exercise.muscleGroup).font(.caption)
        }
    }

    private var exerciseStats: some View {
        Text("\(exercise.sets) sets")
            .foregroundStyle(.secondary)
    }
}
```

**Use `@ViewBuilder` for conditional content:**
```swift
@ViewBuilder
private var statusView: some View {
    switch viewModel.status {
    case .loading:
        ProgressView()
    case .loaded(let data):
        DataView(data: data)
    case .error(let error):
        ErrorView(error: error)
    }
}
```

### Swift Concurrency

**All UI-updating code must be `@MainActor`:**
```swift
@Observable
@MainActor
final class SyncManager {
    var syncStatus: SyncStatus = .idle

    func sync() async {
        syncStatus = .syncing
        defer { syncStatus = .idle }

        do {
            try await performSync()
            syncStatus = .completed
        } catch {
            syncStatus = .failed(error)
        }
    }
}
```

**Use structured concurrency for parallel operations:**
```swift
func loadData() async throws {
    async let workouts = workoutService.fetchWorkouts()
    async let exercises = exerciseService.fetchExercises()

    let (w, e) = try await (workouts, exercises)
    self.workouts = w
    self.exercises = e
}
```

**Handle notifications with `nonisolated` + Task:**
```swift
@Observable
@MainActor
final class DataManager {
    var data: [Item] = []

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdate),
            name: .dataDidUpdate,
            object: nil
        )
    }

    @objc nonisolated private func handleUpdate(_ notification: Notification) {
        Task { @MainActor in
            await refreshData()
        }
    }
}
```

**Use `.task` modifier for async work in views:**
```swift
struct WorkoutListView: View {
    var viewModel: WorkoutListViewModel

    var body: some View {
        List(viewModel.workouts) { workout in
            WorkoutRow(workout: workout)
        }
        .task {
            await viewModel.loadWorkouts()
        }
        .refreshable {
            await viewModel.loadWorkouts()
        }
    }
}
```

### State Management

**Property wrapper guide for iOS 17+:**

| Wrapper | Use Case |
|---------|----------|
| `@State` | Value types OR `@Observable` objects owned by the view |
| `@Binding` | Two-way connection to parent's state |
| `@Environment` | Dependency injection, system values |
| `@Bindable` | Create bindings to `@Observable` object properties |
| No wrapper | `@Observable` objects passed from parent |

**Create bindings with `@Bindable`:**
```swift
struct WorkoutEditorView: View {
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        TextField("Workout Name", text: $viewModel.workout.name)
        Toggle("Completed", isOn: $viewModel.workout.isCompleted)
    }
}
```

### Error Handling

**Use typed errors and handle at ViewModel level:**
```swift
enum WorkoutError: LocalizedError {
    case saveFailed
    case loadFailed
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .saveFailed: "Failed to save workout"
        case .loadFailed: "Failed to load workouts"
        case .networkUnavailable: "Network unavailable"
        }
    }
}

@Observable
@MainActor
final class WorkoutViewModel {
    var error: WorkoutError?

    func save() async {
        do {
            try await workoutService.saveWorkout(workout)
        } catch {
            self.error = .saveFailed
        }
    }
}
```

**Display errors with `.alert`:**
```swift
struct WorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.error = nil } }
                ),
                presenting: viewModel.error
            ) { _ in
                Button("OK") { viewModel.error = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}
```

### Testing

**Protocol-based dependencies for testability:**
```swift
protocol WorkoutServiceProtocol: Sendable {
    func saveWorkout(_ workout: Workout) async throws
    func fetchWorkouts() async throws -> [Workout]
}

// Production implementation
final class WorkoutService: WorkoutServiceProtocol {
    func saveWorkout(_ workout: Workout) async throws { ... }
    func fetchWorkouts() async throws -> [Workout] { ... }
}

// Test mock
final class MockWorkoutService: WorkoutServiceProtocol {
    var savedWorkouts: [Workout] = []
    var workoutsToReturn: [Workout] = []
    var shouldThrow = false

    func saveWorkout(_ workout: Workout) async throws {
        if shouldThrow { throw WorkoutError.saveFailed }
        savedWorkouts.append(workout)
    }

    func fetchWorkouts() async throws -> [Workout] {
        if shouldThrow { throw WorkoutError.loadFailed }
        return workoutsToReturn
    }
}
```

**Test ViewModels directly:**
```swift
@MainActor
final class WorkoutViewModelTests: XCTestCase {
    func testSaveWorkout() async {
        let mockService = MockWorkoutService()
        let viewModel = WorkoutViewModel(
            workout: .sample,
            workoutService: mockService
        )

        await viewModel.save()

        XCTAssertEqual(mockService.savedWorkouts.count, 1)
        XCTAssertNil(viewModel.error)
    }

    func testSaveWorkoutFailure() async {
        let mockService = MockWorkoutService()
        mockService.shouldThrow = true
        let viewModel = WorkoutViewModel(
            workout: .sample,
            workoutService: mockService
        )

        await viewModel.save()

        XCTAssertEqual(viewModel.error, .saveFailed)
    }
}
```

---

## Project Conventions

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
- Services: `{Domain}Service` (e.g., `WorkoutService`)
- Protocols: `{Name}Protocol` or `{Name}Providing` (e.g., `WorkoutServiceProtocol`)

---

## Patterns to Avoid

1. **`ObservableObject` / `@Published`** - Use `@Observable` macro instead

2. **`@StateObject` / `@ObservedObject`** - Use `@State` for owned objects, no wrapper for passed objects

3. **Singletons (`.shared`)** - Use environment-based dependency injection

4. **`DispatchQueue.main.async`** - Use `@MainActor` or `Task { @MainActor in }`

5. **Massive view files** - Extract components when files exceed 150 lines

6. **Force unwrapping** - Use `guard let`, `if let`, or nil coalescing

7. **Unstructured concurrency** - Use `async let`, `TaskGroup` for parallel work

8. **Blocking operations on main thread** - All I/O must be `async`

---

## Code Review Checklist

Before committing, verify:

- [ ] ViewModels use `@Observable` macro with `@MainActor`
- [ ] Dependencies injected via Environment, not singletons
- [ ] All async operations use structured concurrency
- [ ] Views are focused (<150 lines) with extracted subviews
- [ ] `@Bindable` used for creating bindings to `@Observable` properties
- [ ] Error states handled and displayed to user
- [ ] No force unwraps without clear safety guarantees
- [ ] Services conform to `Sendable` for safe concurrency
