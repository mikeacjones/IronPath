# IronPath - Claude Code Instructions

## Quick Reference

**Build:** `xcodebuild -scheme IronPath -destination 'platform=iOS Simulator,name=iPhone 17' build`
**Test:** `xcodebuild -scheme IronPath -destination 'platform=iOS Simulator,name=iPhone 17' test`

---

## Architecture Overview

```
IronPath/
├── Models/                    # Data models (Workout, Exercise, UserProfile, etc.)
├── ViewModels/                # @Observable ViewModels
├── Views/
│   ├── ActiveWorkout/         # Live workout tracking
│   │   ├── Components/        # SetRowView, RestTimer*, WorkoutTimerHeader
│   │   ├── Calculators/       # Plate/Cable calculators
│   │   └── Sheets/            # Completion summary, replacement
│   ├── Components/            # Shared: ExerciseDetailSheet, AddExerciseSheet, etc.
│   ├── History/               # Workout history views
│   ├── Profile/               # Settings, gym profiles, AI config
│   ├── Workout/               # Workout generation/setup
│   └── Onboarding/            # Onboarding flow
├── Services/                  # Business logic, managers, persistence
└── Protocols/                 # DataManagerProtocols.swift (all DI protocols)
```

---

## Dependency Injection Pattern

**CRITICAL: This app uses `DependencyContainer`, NOT individual environment keys.**

### DependencyContainer (Services/DependencyContainer.swift)
```swift
@Observable @MainActor
final class DependencyContainer {
    let workoutDataManager: WorkoutDataManaging
    let exercisePreferenceManager: ExercisePreferenceManaging
    let restTimerManager: RestTimerManaging
    let equipmentManager: EquipmentManaging
    let customEquipmentStore: CustomEquipmentStoring
    let customExerciseStore: CustomExerciseStoring
    let exerciseDatabase: ExerciseDatabaseProviding
    // ... other services
}
```

### Injected at App Root (IronPathApp.swift)
```swift
ContentView()
    .environment(dependencies)           // DependencyContainer
    .environment(appState)               // AppState
```

### Access in Views
```swift
struct MyView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @Environment(AppState.self) var appState

    var body: some View {
        // Use: dependencies.workoutDataManager, dependencies.restTimerManager, etc.
    }
}
```

### ViewModels: Pragmatic Pattern
**SwiftUI limitation:** Cannot access `@Environment` in `init()`. ViewModels use optional params with `.shared` fallbacks:

```swift
@Observable @MainActor
final class MyViewModel {
    private let dataManager: WorkoutDataManaging

    init(dataManager: WorkoutDataManaging? = nil) {
        self.dataManager = dataManager ?? WorkoutDataManager.shared
    }
}

// View passes dependency when possible:
struct MyView: View {
    @Environment(DependencyContainer.self) private var dependencies
    @State private var viewModel: MyViewModel

    init() {
        _viewModel = State(initialValue: MyViewModel())
    }

    var body: some View {
        content
            .onAppear {
                // Late injection if needed
                viewModel.configure(dataManager: dependencies.workoutDataManager)
            }
    }
}
```

---

## Key Services & Managers

| Service | File | Purpose |
|---------|------|---------|
| `WorkoutDataManager` | Services/WorkoutDataManager.swift | Workout CRUD, history |
| `RestTimerManager` | Services/RestTimerManager.swift | Global rest timer state |
| `GymProfileManager` | Services/GymProfileManager.swift | Multi-gym equipment profiles |
| `EquipmentManager` | Services/EquipmentManager.swift | Available equipment catalog |
| `ExercisePreferenceManager` | Services/ExercisePreferenceManager.swift | User exercise preferences |
| `AIProviderManager` | Services/AIProviders/AIProviderManager.swift | AI workout generation |
| `CloudSyncManager` | Services/CloudSyncManager.swift | iCloud sync |
| `AppSettings` | Services/AppSettings.swift | User preferences |
| `ActiveWorkoutManager` | Services/ActiveWorkoutManager.swift | In-progress workout persistence |

**All protocols in:** `Protocols/DataManagerProtocols.swift`

---

## View Size Guidelines

**Target: ~150 lines per file. Max: ~300 lines.**

When a view grows large, split into:
1. **Main view file** - Body, navigation, sheets
2. **Components file** - `{Feature}Components.swift` for subviews
3. **Sections file** - For list sections (e.g., `ProfileSettingsComponents.swift`)

Example splits already done:
- `HistoryView.swift` + `HistoryComponents.swift` + `WorkoutHistoryDetailView.swift`
- `ExerciseDetailSheet.swift` + `ExerciseDetailComponents.swift`
- `ProfileView.swift` + `ProfileSettingsComponents.swift`

---

## Common Tasks

### Adding a New View
1. Create in appropriate `Views/` subfolder
2. If >150 lines, split into `{Name}View.swift` + `{Name}Components.swift`
3. Use `@Environment(DependencyContainer.self)` for services
4. Use `@State private var viewModel` if view owns the ViewModel

### Adding a New Service
1. Add protocol to `Protocols/DataManagerProtocols.swift`
2. Create service in `Services/`
3. Add to `DependencyContainer` (both init methods)
4. Add `.shared` static for fallback pattern

### Adding a ViewModel
1. Create in `ViewModels/`
2. Use `@Observable @MainActor final class`
3. Accept dependencies as optional params with `.shared` fallbacks
4. Keep UI state (sheets, alerts) in ViewModel, not View

### Modifying Existing Features
1. **Check ViewModels/** first for business logic
2. **Check Services/** for data operations
3. **Check existing components** before creating new ones
4. **Search for similar patterns** - likely already implemented somewhere

---

## @Observable + SwiftUI Patterns

### Timer/Continuous Updates (RestTimerManager pattern)
```swift
@Observable @MainActor
final class TimerManager {
    var remainingTime: TimeInterval = 0
    private(set) var timerTick: UInt64 = 0  // Heartbeat for SwiftUI updates

    private func tick() {
        remainingTime -= 1
        timerTick &+= 1  // Forces @Observable to notify
    }
}
```

### View Owns ViewModel
```swift
struct MyView: View {
    @State private var viewModel: MyViewModel

    init(data: SomeData) {
        _viewModel = State(initialValue: MyViewModel(data: data))
    }
}
```

### View Receives ViewModel (no wrapper)
```swift
struct ChildView: View {
    var viewModel: MyViewModel  // No @State, no @Bindable
    var body: some View { ... }
}
```

### Creating Bindings
```swift
struct EditorView: View {
    @Bindable var viewModel: MyViewModel
    var body: some View {
        TextField("Name", text: $viewModel.name)
    }
}
```

---

## Anti-Patterns to AVOID

| Don't | Do Instead |
|-------|------------|
| `ObservableObject`/`@Published` | `@Observable` macro |
| `@StateObject`/`@ObservedObject` | `@State` for owned, plain var for passed |
| New singleton without protocol | Add to `DependencyContainer` with protocol |
| View files >300 lines | Split into components |
| `DispatchQueue.main.async` | `@MainActor` or `Task { @MainActor in }` |
| Force unwraps `!` | `guard let`, `if let`, `??` |
| Duplicate components | Search existing, reuse or extract shared |

---

## Existing Reusable Components

**Before creating new UI, check these:**

| Component | Location | Purpose |
|-----------|----------|---------|
| `ExerciseDetailSheet` | Views/Components/ | Edit exercise sets |
| `AddExerciseSheet` | Views/Components/ | Browse/add exercises |
| `SetRowView` | Views/ActiveWorkout/Components/ | Single set input |
| `AdvancedSetRowView` | Views/ActiveWorkout/ | Set with all features |
| `RestTimerView` | Views/ActiveWorkout/Components/ | Inline timer |
| `GlobalRestTimerBar` | Views/ActiveWorkout/Components/ | Top timer bar |
| `WorkoutHistoryCard` | Views/History/ | History list item |
| `ExerciseHistorySection` | Views/Components/ | Past performance |
| `GymProfileRow` | Views/Profile/ | Gym profile item |
| `ProfileTechniqueModePicker` | Views/Profile/EditProfileView.swift | Technique toggles |

---

## File Search Hints

| Looking for... | Search/Check |
|----------------|--------------|
| Workout models | `Models/Workout.swift` |
| Exercise definitions | `Models/Exercise.swift`, `Data/ExerciseDatabase.swift` |
| User settings | `Models/UserProfile.swift`, `Services/AppSettings.swift` |
| Data persistence | `Services/WorkoutDataManager.swift`, `Services/CloudSyncManager.swift` |
| AI/LLM code | `Services/AIProviders/` folder |
| Gym equipment | `Models/GymProfile.swift`, `Services/EquipmentManager.swift` |
| Rest timer | `Services/RestTimerManager.swift`, `Views/ActiveWorkout/Components/RestTimer*.swift` |

---

## Code Style

- **MARK comments:** `// MARK: - Section Name`
- **Private subviews:** Use computed properties: `private var headerView: some View { ... }`
- **Modifiers:** Chain on new lines for readability
- **Error handling:** ViewModel holds errors, View displays via `.alert`
- **Async in views:** Use `.task { }` modifier, not `onAppear` with Task

---

## Testing

- Tests in `IronPathTests/`
- ViewModels testable via protocol injection
- Use `MockWorkoutDataManager`, etc. from test files
- Run: `xcodebuild test -scheme IronPath -destination 'platform=iOS Simulator,name=iPhone 17'`
