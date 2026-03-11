import Foundation
import SwiftUI

// MARK: - History ViewModel

/// ViewModel for managing workout history display and operations
@Observable
@MainActor
final class HistoryViewModel {

    // MARK: - State

    /// All workout history
    var workouts: [Workout] = []

    /// Currently selected date for calendar filtering
    var selectedDate: Date = Date()

    /// Whether calendar view is shown
    var showCalendar: Bool = true

    /// Selected workout for detail view
    var selectedWorkout: Workout?

    /// Whether add workout sheet is showing
    var showingAddWorkout: Bool = false

    /// Whether import wizard is showing
    var showingImportWizard: Bool = false

    /// Workout pending deletion confirmation
    var workoutToDelete: Workout?

    /// Whether delete confirmation is showing
    var showingDeleteConfirmation: Bool = false

    // MARK: - Dependencies

    private let workoutDataManager: WorkoutDataManaging

    // MARK: - Computed Properties

    /// Workouts filtered for the selected month
    var workoutsForSelectedMonth: [Workout] {
        let calendar = Calendar.current
        return workouts.filter { workout in
            guard let completedAt = workout.completedAt else { return false }
            return calendar.isDate(completedAt, equalTo: selectedDate, toGranularity: .month)
        }
    }

    /// Set of date components for dates with workouts (for calendar highlighting)
    var workoutDates: Set<DateComponents> {
        Set(workouts.compactMap { workout in
            guard let date = workout.completedAt else { return nil }
            return Calendar.current.dateComponents([.year, .month, .day], from: date)
        })
    }

    /// Workouts to display based on current view mode
    var displayWorkouts: [Workout] {
        let source = showCalendar ? workoutsForSelectedMonth : workouts
        return source.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Display title for workout list section
    var workoutListTitle: String {
        showCalendar ? "Workouts in \(selectedDate.formatted(.dateTime.month(.wide).year()))" : "All Workouts"
    }

    /// Workout statistics
    var stats: WorkoutStats {
        workoutDataManager.getWorkoutStats()
    }

    /// Shared unit across all completed workouts, if one exists
    var statsWeightUnit: WeightUnit? {
        stats.weightUnit
    }

    /// Whether there are any workouts
    var hasWorkouts: Bool {
        !workouts.isEmpty
    }

    /// Whether display workouts is empty
    var isDisplayEmpty: Bool {
        displayWorkouts.isEmpty
    }

    // MARK: - Initialization

    init(workoutDataManager: WorkoutDataManaging? = nil) {
        self.workoutDataManager = workoutDataManager ?? WorkoutDataManager.shared
    }

    // MARK: - Data Operations

    /// Load all workouts from storage
    func loadWorkouts() {
        workouts = workoutDataManager.getWorkoutHistory()
    }

    /// Delete a workout
    func deleteWorkout(_ workout: Workout) {
        workoutDataManager.deleteWorkout(byId: workout.id)
        workoutToDelete = nil
        loadWorkouts()
    }

    /// Confirm deletion of a workout
    func confirmDelete(_ workout: Workout) {
        workoutToDelete = workout
        showingDeleteConfirmation = true
    }

    /// Cancel deletion
    func cancelDelete() {
        workoutToDelete = nil
        showingDeleteConfirmation = false
    }

    /// Select a workout for detail view
    func selectWorkout(_ workout: Workout) {
        selectedWorkout = workout
    }

    /// Handle workout update from detail view
    func handleWorkoutUpdate(_ workout: Workout) {
        loadWorkouts()
    }

    /// Handle workout deletion from detail view
    func handleWorkoutDeletion(_ workout: Workout) {
        deleteWorkout(workout)
        selectedWorkout = nil
    }
}

// MARK: - History Detail ViewModel

/// ViewModel for managing workout history detail view
@Observable
@MainActor
final class HistoryDetailViewModel {

    // MARK: - State

    /// The workout being viewed/edited
    var workout: Workout

    /// Whether delete confirmation is showing
    var showingDeleteConfirmation: Bool = false

    /// Whether edit sheet is showing
    var showingEditSheet: Bool = false

    // MARK: - Dependencies

    private let workoutDataManager: WorkoutDataManaging

    // MARK: - Callbacks

    /// Called when workout is deleted
    var onDelete: (() -> Void)?

    /// Called when workout is updated
    var onUpdate: ((Workout) -> Void)?

    // MARK: - Initialization

    init(
        workout: Workout,
        workoutDataManager: WorkoutDataManaging? = nil,
        onDelete: (() -> Void)? = nil,
        onUpdate: ((Workout) -> Void)? = nil
    ) {
        self.workout = workout
        self.workoutDataManager = workoutDataManager ?? WorkoutDataManager.shared
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    // MARK: - Actions

    /// Update the workout after editing
    func updateWorkout(_ updatedWorkout: Workout) {
        workout = updatedWorkout
        workoutDataManager.updateWorkout(updatedWorkout)
        onUpdate?(updatedWorkout)
    }

    /// Delete the workout
    func deleteWorkout() {
        if let onDelete = onDelete {
            onDelete()
        } else {
            workoutDataManager.deleteWorkout(byId: workout.id)
        }
    }

    /// Request edit sheet
    func requestEdit() {
        showingEditSheet = true
    }

    /// Request delete confirmation
    func requestDelete() {
        showingDeleteConfirmation = true
    }

    // MARK: - Formatting Helpers

    /// Format volume for display
    func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK", volume / 1000)
        }
        return "\(Int(volume))"
    }
}
