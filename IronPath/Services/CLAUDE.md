# Services/

## Files

| File | What | When to read |
| ---- | ---- | ------------ |
| `DependencyContainer.swift` | Central DI container for all services | Adding new services, understanding DI |
| `WorkoutDataManager.swift` | Workout CRUD, history persistence | Saving/loading workouts, history queries |
| `RestTimerManager.swift` | Global rest timer with timerTick heartbeat | Rest timer functionality, timer UI |
| `ActiveWorkoutManager.swift` | In-progress workout state persistence | Workout session recovery |
| `PendingWorkoutManager.swift` | Generated workout before starting | Workout generation flow |
| `EquipmentManager.swift` | Equipment catalog (standard + custom) | Adding equipment types |
| `ExercisePreferenceManager.swift` | User exercise preferences | Exercise customization |
| `CustomEquipmentStore.swift` | Custom equipment persistence | Custom equipment CRUD |
| `CustomExerciseStore.swift` | Custom exercise persistence | Custom exercise CRUD |
| `ExerciseSimilarityService.swift` | Find similar exercises | Exercise replacement suggestions |
| `ExerciseSimilarityCalculator.swift` | Similarity scoring logic | Tuning similarity algorithm |
| `ExerciseTimerManager.swift` | Timed exercise countdown | Timed set functionality |
| `CloudSyncManager.swift` | iCloud sync | Sync issues, CloudKit |
| `HealthKitManager.swift` | HealthKit integration | Health data, calorie tracking |
| `AppSettings.swift` | User app preferences | App-wide settings |

## Subdirectories

| Directory | What | When to read |
| --------- | ---- | ------------ |
| `AIProviders/` | AI workout generation (Claude, OpenAI) | AI features, prompt engineering |
| `Import/` | Workout import from external sources | Import feature |
