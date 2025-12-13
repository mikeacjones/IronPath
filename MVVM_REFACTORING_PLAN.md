# MVVM Refactoring Plan - IronPath

This document tracks the MVVM refactoring effort to clean up architecture violations in the codebase.

## Status Legend
- [ ] Not started
- [x] Completed
- [~] In progress

---

## Phase 1: ExerciseDetailSheet Refactoring (High Priority) ✅ COMPLETED

The `ExerciseDetailSheet.swift` (699 lines) has the most violations and was involved in a recent bug fix.

### Tasks:
- [x] **1.1** Create `ExerciseDetailViewModel.swift` in `/IronPath/ViewModels/`
- [x] **1.2** Move `exerciseHistory` computation from View to ViewModel
- [x] **1.3** Move `addSet()` and `removeSet()` logic to ViewModel
- [x] **1.4** Move weight/reps propagation callbacks to ViewModel methods
- [x] **1.5** Replace direct singleton access (`RestTimerManager.shared`, `AppSettings.shared`, `WorkoutDataManager.shared`) with injected dependencies
- [x] **1.6** Move `shouldShowVideos` and `shouldShowFormTips` computed properties to ViewModel
- [x] **1.7** Update `ExerciseDetailSheet.swift` to use the new ViewModel
- [x] **1.8** Verify build succeeds

---

## Phase 2: HistoryView Refactoring ✅ COMPLETED

`HistoryView.swift` directly calls `WorkoutDataManager.shared` for loading and deleting workouts.

### Tasks:
- [x] **2.1** Create `HistoryViewModel.swift` in `/IronPath/ViewModels/`
- [x] **2.2** Move `loadWorkouts()` and `deleteWorkout()` to ViewModel
- [x] **2.3** Move `workoutsForSelectedMonth` and `workoutDates` computed properties to ViewModel
- [x] **2.4** Inject `WorkoutDataManager` as dependency
- [x] **2.5** Update `HistoryView.swift` to use the new ViewModel
- [x] **2.5.1** Also created `HistoryDetailViewModel` for `WorkoutHistoryDetailView`
- [x] **2.5.2** Also updated `WorkoutStatsSummary` to `WorkoutStatsSummaryView` accepting stats directly
- [x] **2.6** Verify build succeeds

---

## Phase 3: ActiveWorkoutView Coordinator

`ActiveWorkoutView.swift` manually coordinates 3 ViewModels with complex `onAppear` logic.

### Tasks:
- [ ] **3.1** Consolidate `WorkoutEditorViewModel` functionality into `ActiveWorkoutViewModel`
- [ ] **3.2** Move `ExerciseReplacementViewModel` coordination into `ActiveWorkoutViewModel`
- [ ] **3.3** Remove manual ViewModel synchronization from View's `onAppear`
- [ ] **3.4** Move `preferenceManager` access through ViewModel
- [ ] **3.5** Update `ActiveWorkoutView.swift` to use consolidated ViewModel
- [ ] **3.6** Verify build succeeds

---

## Phase 4: WorkoutDetailView Refactoring

`WorkoutDetailView.swift` contains `convertToNormalWorkout()` with business logic.

### Tasks:
- [ ] **4.1** Create `WorkoutDetailViewModel.swift` in `/IronPath/ViewModels/`
- [ ] **4.2** Move `convertToNormalWorkout()` logic to ViewModel
- [ ] **4.3** Move progressive overload calculation to ViewModel
- [ ] **4.4** Replace direct `WorkoutDataManager.shared` and `GymSettings.shared` access
- [ ] **4.5** Update `WorkoutDetailView.swift` to use the new ViewModel
- [ ] **4.6** Verify build succeeds

---

## Phase 5: WorkoutCompletionSummaryView Refactoring

This view has 11+ direct singleton accesses for PR detection, AI summaries, and HealthKit.

### Tasks:
- [ ] **5.1** Create `WorkoutCompletionViewModel.swift` in `/IronPath/ViewModels/`
- [ ] **5.2** Move PR detection logic to ViewModel
- [ ] **5.3** Move AI summary generation to ViewModel
- [ ] **5.4** Move HealthKit integration to ViewModel
- [ ] **5.5** Move calorie estimation logic to ViewModel
- [ ] **5.6** Inject all managers as dependencies
- [ ] **5.7** Update `WorkoutCompletionSummaryView.swift` to use the new ViewModel
- [ ] **5.8** Verify build succeeds

---

## Phase 6: SetRowView Refactoring

`SetRowView.swift` has 5+ complex computed properties and direct singleton access.

### Tasks:
- [ ] **6.1** Create `SetRowViewModel.swift` in `/IronPath/ViewModels/`
- [ ] **6.2** Move cable weight validation logic to ViewModel
- [ ] **6.3** Move plate calculation display logic to ViewModel
- [ ] **6.4** Move rest timer state observation through ViewModel
- [ ] **6.5** Move suggested weight logic to ViewModel
- [ ] **6.6** Update `SetRowView.swift` to use the new ViewModel
- [ ] **6.7** Verify build succeeds

---

## Phase 7: WorkoutView Refactoring

`WorkoutView.swift` directly accesses multiple managers for workout generation.

### Tasks:
- [ ] **7.1** Create `WorkoutViewModel.swift` in `/IronPath/ViewModels/`
- [ ] **7.2** Move workout generation coordination to ViewModel
- [ ] **7.3** Move AI provider checks to ViewModel
- [ ] **7.4** Replace direct `PendingWorkoutManager` and `ActiveWorkoutManager` access
- [ ] **7.5** Update `WorkoutView.swift` to use the new ViewModel
- [ ] **7.6** Verify build succeeds

---

## Completed Refactoring Log

| Date | Task | Notes |
|------|------|-------|
| 2024-12-13 | Bug fix | Added `handleExerciseUpdateFromSheet()` to `ActiveWorkoutViewModel` to fix superset navigation dismissal |
| 2024-12-13 | Phase 1 | Created `ExerciseDetailViewModel` - moved exercise history, set manipulation, settings access from View |
| 2024-12-13 | Phase 2 | Created `HistoryViewModel` and `HistoryDetailViewModel` - moved workout loading/deletion from Views |
| 2024-12-13 | Protocol | Added `updateWorkout()` to `WorkoutDataManaging` protocol |
| 2024-12-13 | Protocol | Added `AppSettingsProviding` protocol for settings access |

---

## Architecture Notes

### Dependency Injection Pattern
All ViewModels should accept dependencies via initializer with defaults:
```swift
init(
    workoutDataManager: WorkoutDataManaging = WorkoutDataManager.shared,
    restTimerManager: RestTimerManaging = RestTimerManager.shared
) {
    self.workoutDataManager = workoutDataManager
    self.restTimerManager = restTimerManager
}
```

### Existing Protocols (in DataManagerProtocols.swift)
- `WorkoutDataManaging`
- `ActiveWorkoutManaging`
- `RestTimerManaging`

New protocols may need to be created for:
- `AppSettingsProviding`
- `GymSettingsProviding`
- `HealthKitManaging`
- `AIProviderManaging`
