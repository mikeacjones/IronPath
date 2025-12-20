# IronPath/

## Files

| File | What | When to read |
| ---- | ---- | ------------ |
| `IronPathApp.swift` | App entry point, environment injection | Modifying app startup, adding environment objects |
| `ContentView.swift` | Root view, onboarding vs main app routing | Changing app navigation structure |
| `IronPath.entitlements` | App capabilities (iCloud, HealthKit) | Adding new entitlements |

## Subdirectories

| Directory | What | When to read |
| --------- | ---- | ------------ |
| `Models/` | Data models (Workout, Exercise, UserProfile) | Adding/modifying domain types |
| `ViewModels/` | @Observable ViewModels for views | Adding business logic, state management |
| `Views/` | SwiftUI views organized by feature | Building UI, modifying screens |
| `Services/` | Business logic, managers, persistence | Data operations, API calls, sync |
| `Protocols/` | DI protocols (DataManagerProtocols.swift) | Adding new service protocols |
| `Data/` | Static data (ExerciseDatabase) | Modifying built-in exercises |
| `Utilities/` | Logging, API key management, config | Debugging, adding utilities |
| `Assets.xcassets/` | App icons, colors, images | Modifying visual assets |
| `Resources/` | Additional resources | - |
