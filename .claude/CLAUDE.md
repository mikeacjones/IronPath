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

---

## Complete File Inventory

### Root
- `IronPathApp.swift` - App entry point, environment injection
- `ContentView.swift` - Root view, onboarding vs main app routing

### Data/
- `ExerciseDatabase.swift` - Built-in exercise library (300+ exercises)

### Models/
- `Workout.swift` - Workout, WorkoutExercise, ExerciseSet, SetType
- `Exercise.swift` - Exercise, MuscleGroup, Equipment enums
- `UserProfile.swift` - UserProfile, WorkoutPreferences, FitnessGoal
- `GymProfile.swift` - GymProfile, equipment availability per gym
- `ExerciseGroup.swift` - Supersets, circuits, giant sets grouping
- `AdvancedSetTypes.swift` - Drop sets, rest-pause, warmup set configs
- `CableMachineConfig.swift` - Cable machine weight stack settings
- `CustomEquipment.swift` - User-defined equipment types
- `ExercisePreference.swift` - Per-exercise user preferences
- `ExerciseSimilarity.swift` - Exercise similarity scoring model
- `MovementPattern.swift` - Movement pattern classifications
- `WorkoutType.swift` - Workout type definitions

### Protocols/
- `DataManagerProtocols.swift` - ALL DI protocols (WorkoutDataManaging, RestTimerManaging, etc.)

### Services/
- `DependencyContainer.swift` - Central DI container
- `WorkoutDataManager.swift` - Workout CRUD, history persistence
- `RestTimerManager.swift` - Global rest timer with timerTick heartbeat
- `ActiveWorkoutManager.swift` - In-progress workout state persistence
- `PendingWorkoutManager.swift` - Generated workout before starting
- `EquipmentManager.swift` - Equipment catalog (standard + custom)
- `GymProfileManager.swift` - Multi-gym profile management (not in file list but referenced)
- `ExercisePreferenceManager.swift` - User exercise preferences
- `CustomEquipmentStore.swift` - Custom equipment persistence
- `CustomExerciseStore.swift` - Custom exercise persistence
- `ExerciseSimilarityService.swift` - Find similar exercises
- `ExerciseSimilarityCalculator.swift` - Similarity scoring logic
- `CloudSyncManager.swift` - iCloud sync
- `HealthKitManager.swift` - HealthKit integration
- `AppSettings.swift` - User app preferences

### Services/AIProviders/
- `AIProviderManager.swift` - AI provider selection/configuration
- `AIProvider.swift` - Protocol for AI providers
- `AnthropicProvider.swift` - Claude API integration
- `OpenAIProvider.swift` - OpenAI API integration
- `AIModels.swift` - AI request/response models
- `AITools.swift` - Tool definitions for AI
- `AIToolParser.swift` - Parse AI tool calls
- `AIProviderHelpers.swift` - Shared AI utilities
- `AgentModels.swift` - Agent-based generation models
- `AgentToolExecutor.swift` - Execute agent tool calls
- `AgentWorkoutBuilder.swift` - Build workouts from agent output
- `WorkoutAgentTools.swift` - Workout-specific agent tools

### Utilities/
- `AppLogger.swift` - OSLog-based logging
- `APIKeyManager.swift` - Secure API key storage
- `APIDebugManager.swift` - API call debugging
- `ModelConfigManager.swift` - AI model configuration

### ViewModels/
- `ActiveWorkoutViewModel.swift` - Live workout logic
- `WorkoutEditorViewModel.swift` - Add/remove/reorder exercises
- `ExerciseDetailViewModel.swift` - Exercise editing in sheet
- `ExerciseReplacementViewModel.swift` - Exercise swap logic
- `HistoryViewModel.swift` - History view logic

### Views/ (Root)
- `MainTabView.swift` - Tab bar navigation
- `OnboardingView.swift` - Onboarding flow container
- `ExerciseLibraryView.swift` - Browse all exercises
- `APIDebugLogView.swift` - Debug API calls

### Views/ActiveWorkout/
- `ActiveWorkoutView.swift` - Main live workout screen
- `AdvancedSetViews.swift` - Advanced set row view
- `StandardWarmupSetViews.swift` - Standard/warmup set UI
- `DropSetViews.swift` - Drop set UI
- `RestPauseSetViews.swift` - Rest-pause set UI
- `SetInputComponents.swift` - Weight/rep input fields

### Views/ActiveWorkout/Components/
- `SetRowView.swift` - Basic set row
- `ExerciseCardComponents.swift` - Exercise card in workout
- `RestTimerComponents.swift` - RestTimerView, GroupRestTimerView
- `RestTimeEditorSheet.swift` - Edit rest duration
- `RestTimerGlobalViews.swift` - GlobalRestTimerBar, RestCompleteBanner, containers
- `WorkoutTimerHeader.swift` - Workout duration header

### Views/ActiveWorkout/Calculators/
- `PlateCalculatorView.swift` - Barbell plate calculator
- `PlateEditorViews.swift` - Edit available plates
- `CableWeightCalculatorView.swift` - Cable stack calculator

### Views/ActiveWorkout/Sheets/
- `WorkoutCompletionSummaryView.swift` - Post-workout summary
- `ExerciseReplacementSheet.swift` - Swap exercise UI

### Views/Components/ (Shared)
- `ExerciseDetailSheet.swift` - Edit exercise sets (used everywhere)
- `ExerciseDetailComponents.swift` - SetTypePicker, ExerciseHistorySection
- `AddExerciseSheet.swift` - Add exercise from library
- `ExerciseBrowserView.swift` - Browse/filter exercises
- `ExerciseCards.swift` - Exercise display cards
- `ReorderableExerciseList.swift` - Drag-to-reorder exercises
- `ExerciseGroupSheets.swift` - Create superset/circuit sheets
- `SupersetGroupViews.swift` - Superset group display
- `EquipmentSelectionComponents.swift` - Equipment picker components
- `SharedComponents.swift` - Misc shared UI

### Views/Equipment/
- `EquipmentManagerView.swift` - Manage custom equipment
- `AddCustomEquipmentView.swift` - Add new equipment
- `ExerciseSelectionView.swift` - Select exercises for equipment

### Views/History/
- `HistoryView.swift` - Main history screen
- `HistoryComponents.swift` - Calendar, stats, cards
- `WorkoutHistoryDetailView.swift` - Single workout detail
- `AddHistoricalWorkoutView.swift` - Log past workout
- `EditHistoricalWorkoutView.swift` - Edit past workout

### Views/Onboarding/
- `OnboardingStepViews.swift` - Welcome, name, goals steps
- `OnboardingEquipmentViews.swift` - Equipment selection
- `OnboardingTrainingViews.swift` - Training preferences

### Views/Profile/
- `ProfileView.swift` - Main profile/settings screen
- `ProfileSettingsComponents.swift` - Settings sections (AI, notifications, data)
- `EditProfileView.swift` - Edit user profile
- `GymProfileViews.swift` - Gym profile list/editor
- `GymEquipmentSettingsView.swift` - Equipment settings
- `CableEquipmentViews.swift` - Cable machine config
- `DumbbellConfigurationView.swift` - Dumbbell availability
- `AIConfigurationView.swift` - AI provider setup

### Views/Progress/
- `ProgressView.swift` - Progress tracking (placeholder)

### Views/Workout/
- `WorkoutView.swift` - Pre-workout options
- `WorkoutSetupView.swift` - Configure workout generation
- `WorkoutDetailView.swift` - Review generated workout
- `WorkoutGenerationLoadingView.swift` - AI generation progress
