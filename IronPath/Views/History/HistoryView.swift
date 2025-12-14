import SwiftUI

// MARK: - History View

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    calendarToggle

                    if viewModel.showCalendar {
                        WorkoutCalendarView(
                            selectedDate: $viewModel.selectedDate,
                            workoutDates: viewModel.workoutDates
                        )
                        .padding(.horizontal)
                    }

                    if viewModel.hasWorkouts {
                        WorkoutStatsSummaryView(stats: viewModel.stats)
                            .padding(.horizontal)
                    }

                    workoutList
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            viewModel.showingAddWorkout = true
                        } label: {
                            Label("Add Workout", systemImage: "plus")
                        }

                        Button {
                            viewModel.showingImportWizard = true
                        } label: {
                            Label("Import from FitBod", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("add_workout_menu")
                }
            }
            .navigationDestination(item: $viewModel.selectedWorkout) { workout in
                WorkoutHistoryDetailView(
                    workout: workout,
                    onDelete: {
                        viewModel.handleWorkoutDeletion(workout)
                    },
                    onUpdate: { updatedWorkout in
                        viewModel.handleWorkoutUpdate(updatedWorkout)
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingAddWorkout) {
                AddHistoricalWorkoutView {
                    viewModel.loadWorkouts()
                }
            }
            .sheet(isPresented: $viewModel.showingImportWizard) {
                ImportWizardView()
            }
            .alert("Delete Workout?", isPresented: $viewModel.showingDeleteConfirmation, presenting: viewModel.workoutToDelete) { workout in
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("Delete", role: .destructive) {
                    viewModel.deleteWorkout(workout)
                }
            } message: { workout in
                Text("Are you sure you want to delete \"\(workout.name)\"? This action cannot be undone.")
            }
            .onAppear {
                viewModel.loadWorkouts()
            }
        }
    }

    // MARK: - Subviews

    private var calendarToggle: some View {
        HStack {
            Text("Calendar View")
                .font(.headline)
            Spacer()
            Toggle("", isOn: $viewModel.showCalendar)
                .labelsHidden()
        }
        .padding(.horizontal)
    }

    private var workoutList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.workoutListTitle)
                .font(.headline)
                .padding(.horizontal)

            if viewModel.isDisplayEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.displayWorkouts) { workout in
                    workoutRow(for: workout)
                }
            }
        }
        .padding(.vertical)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No workouts this month")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func workoutRow(for workout: Workout) -> some View {
        Button {
            viewModel.selectWorkout(workout)
        } label: {
            WorkoutHistoryCard(workout: workout)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout_history_row_\(workout.id.uuidString)")
        .contextMenu {
            Button(role: .destructive) {
                viewModel.confirmDelete(workout)
            } label: {
                Label("Delete Workout", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.confirmDelete(workout)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(.horizontal)
    }
}
