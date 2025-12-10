import SwiftUI

// MARK: - History View

struct HistoryView: View {
    @State private var workouts: [Workout] = []
    @State private var selectedDate: Date = Date()
    @State private var showCalendar = true
    @State private var selectedWorkout: Workout?
    @State private var showingAddWorkout = false
    @State private var workoutToDelete: Workout?
    @State private var showingDeleteConfirmation = false

    var workoutsForSelectedMonth: [Workout] {
        let calendar = Calendar.current
        return workouts.filter { workout in
            guard let completedAt = workout.completedAt else { return false }
            return calendar.isDate(completedAt, equalTo: selectedDate, toGranularity: .month)
        }
    }

    var workoutDates: Set<DateComponents> {
        Set(workouts.compactMap { workout in
            guard let date = workout.completedAt else { return nil }
            return Calendar.current.dateComponents([.year, .month, .day], from: date)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Calendar toggle
                    HStack {
                        Text("Calendar View")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $showCalendar)
                            .labelsHidden()
                    }
                    .padding(.horizontal)

                    if showCalendar {
                        // Calendar
                        WorkoutCalendarView(
                            selectedDate: $selectedDate,
                            workoutDates: workoutDates
                        )
                        .padding(.horizontal)
                    }

                    // Stats summary
                    if !workouts.isEmpty {
                        WorkoutStatsSummary(workouts: workouts)
                            .padding(.horizontal)
                    }

                    // Workout list
                    VStack(alignment: .leading, spacing: 12) {
                        Text(showCalendar ? "Workouts in \(selectedDate.formatted(.dateTime.month(.wide).year()))" : "All Workouts")
                            .font(.headline)
                            .padding(.horizontal)

                        let displayWorkouts = showCalendar ? workoutsForSelectedMonth : workouts
                        if displayWorkouts.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("No workouts this month")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(displayWorkouts.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) { workout in
                                Button {
                                    selectedWorkout = workout
                                } label: {
                                    WorkoutHistoryCard(workout: workout)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("workout_history_row_\(workout.id.uuidString)")
                                .contextMenu {
                                    Button(role: .destructive) {
                                        workoutToDelete = workout
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete Workout", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        workoutToDelete = workout
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("add_historical_workout_button")
                }
            }
            .navigationDestination(item: $selectedWorkout) { workout in
                WorkoutHistoryDetailView(
                    workout: workout,
                    onDelete: {
                        deleteWorkout(workout)
                        selectedWorkout = nil
                    },
                    onUpdate: { _ in
                        // Reload workouts to reflect changes
                        loadWorkouts()
                    }
                )
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddHistoricalWorkoutView {
                    loadWorkouts()
                }
            }
            .alert("Delete Workout?", isPresented: $showingDeleteConfirmation, presenting: workoutToDelete) { workout in
                Button("Cancel", role: .cancel) {
                    workoutToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteWorkout(workout)
                }
            } message: { workout in
                Text("Are you sure you want to delete \"\(workout.name)\"? This action cannot be undone.")
            }
            .onAppear {
                loadWorkouts()
            }
        }
    }

    private func loadWorkouts() {
        workouts = WorkoutDataManager.shared.getWorkoutHistory()
    }

    private func deleteWorkout(_ workout: Workout) {
        WorkoutDataManager.shared.deleteWorkout(byId: workout.id)
        workoutToDelete = nil
        loadWorkouts()
    }
}

// MARK: - Workout History Detail View

struct WorkoutHistoryDetailView: View {
    @State private var workout: Workout
    var onDelete: (() -> Void)?
    var onUpdate: ((Workout) -> Void)?
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    @Environment(\.dismiss) var dismiss

    init(workout: Workout, onDelete: (() -> Void)? = nil, onUpdate: ((Workout) -> Void)? = nil) {
        _workout = State(initialValue: workout)
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Deload banner if applicable
                if workout.isDeload {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.heart.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Deload Workout")
                                .font(.headline)
                            Text("This workout used lighter weights for recovery and won't affect progressive overload tracking.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .cornerRadius(12)
                }

                // Workout summary header
                VStack(alignment: .leading, spacing: 8) {
                    if let completedAt = workout.completedAt {
                        Text(completedAt.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 20) {
                        HistoryStatBadge(
                            icon: "figure.strengthtraining.traditional",
                            value: "\(workout.exercises.count)",
                            label: "Exercises"
                        )

                        if let duration = workout.duration {
                            HistoryStatBadge(
                                icon: "clock",
                                value: "\(Int(duration / 60))",
                                label: "Minutes"
                            )
                        }

                        HistoryStatBadge(
                            icon: "scalemass",
                            value: formatVolume(workout.totalVolume),
                            label: "Volume"
                        )
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Exercises
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises")
                        .font(.headline)

                    ForEach(workout.exercises) { exercise in
                        WorkoutHistoryExerciseCard(exercise: exercise)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("Edit")
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHistoricalWorkoutView(workout: workout) { updatedWorkout in
                // Update local state
                workout = updatedWorkout
                // Save to persistent storage
                WorkoutDataManager.shared.updateWorkout(updatedWorkout)
                // Notify parent if callback provided
                onUpdate?(updatedWorkout)
            }
        }
        .alert("Delete Workout?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let onDelete = onDelete {
                    onDelete()
                } else {
                    // Fallback if no callback provided
                    WorkoutDataManager.shared.deleteWorkout(byId: workout.id)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(workout.name)\"? This action cannot be undone.")
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK", volume / 1000)
        }
        return "\(Int(volume))"
    }
}

// MARK: - History Stat Badge

struct HistoryStatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workout History Exercise Card

struct WorkoutHistoryExerciseCard: View {
    let exercise: WorkoutExercise

    var completedSets: [ExerciseSet] {
        exercise.sets.filter { $0.completedAt != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exercise.name)
                        .font(.headline)
                    Text(exercise.exercise.equipment.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Completion status
                Text("\(completedSets.count)/\(exercise.sets.count)")
                    .font(.subheadline)
                    .foregroundStyle(completedSets.count == exercise.sets.count ? .green : .orange)
            }

            // Sets table
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Set")
                        .frame(width: 40, alignment: .leading)
                    Text("Target")
                        .frame(width: 60, alignment: .center)
                    Text("Actual")
                        .frame(width: 60, alignment: .center)
                    Text("Weight")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

                Divider()

                // Sets
                ForEach(exercise.sets) { set in
                    HStack {
                        Text("\(set.setNumber)")
                            .frame(width: 40, alignment: .leading)
                            .foregroundStyle(set.completedAt != nil ? .primary : .secondary)

                        Text("\(set.targetReps)")
                            .frame(width: 60, alignment: .center)
                            .foregroundStyle(.secondary)

                        if let actualReps = set.actualReps {
                            Text("\(actualReps)")
                                .frame(width: 60, alignment: .center)
                                .foregroundStyle(actualReps >= set.targetReps ? .green : .orange)
                        } else {
                            Text("-")
                                .frame(width: 60, alignment: .center)
                                .foregroundStyle(.secondary)
                        }

                        if let weight = set.weight {
                            Text("\(formatWeight(weight)) lbs")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .fontWeight(.medium)
                        } else {
                            Text("-")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .padding(.vertical, 8)

                    if set.id != exercise.sets.last?.id {
                        Divider()
                    }
                }
            }

            // Notes if any
            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Workout Calendar View

struct WorkoutCalendarView: View {
    @Binding var selectedDate: Date
    let workoutDates: Set<DateComponents>

    @State private var displayedMonth: Date = Date()

    var daysInMonth: [Date] {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth)!
        let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)!
        let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1)!

        var days: [Date] = []
        var current = monthFirstWeek.start
        while current < monthLastWeek.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            // Day headers
            HStack {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        displayedMonth: displayedMonth,
                        hasWorkout: hasWorkout(on: date),
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        onTap: {
                            selectedDate = date
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onChange(of: selectedDate) { _, newValue in
            // Update displayed month when selection changes
            if !Calendar.current.isDate(newValue, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = newValue
            }
        }
    }

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newDate
            selectedDate = newDate
        }
    }

    private func hasWorkout(on date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return workoutDates.contains(components)
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let displayedMonth: Date
    let hasWorkout: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                }

                if hasWorkout && !isSelected {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                }

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(
                        isSelected ? Color.white :
                        isCurrentMonth ? Color.primary : Color.gray.opacity(0.5)
                    )
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout Stats Summary

struct WorkoutStatsSummary: View {
    let workouts: [Workout]

    var stats: WorkoutStats {
        WorkoutDataManager.shared.getWorkoutStats()
    }

    var body: some View {
        HStack(spacing: 16) {
            StatCard(title: "Total", value: "\(stats.totalWorkouts)", subtitle: "workouts")
            StatCard(title: "This Week", value: "\(stats.workoutsThisWeek)", subtitle: "workouts")
            StatCard(title: "Volume", value: formatVolume(stats.totalVolume), subtitle: "lbs lifted")
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000000 {
            return String(format: "%.1fM", volume / 1000000)
        } else if volume >= 1000 {
            return String(format: "%.0fK", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Workout History Card

struct WorkoutHistoryCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(workout.name)
                            .font(.headline)

                        if workout.isDeload {
                            DeloadBadge()
                        }
                    }

                    if let completedAt = workout.completedAt {
                        Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if workout.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 16) {
                Label("\(workout.exercises.count) exercises", systemImage: "figure.strengthtraining.traditional")
                if let duration = workout.duration {
                    Label("\(Int(duration / 60)) min", systemImage: "clock")
                }
                Label("\(Int(workout.totalVolume)) lbs", systemImage: "scalemass")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Exercise summary
            Text(workout.exercises.prefix(3).map { $0.exercise.name }.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Deload Badge

/// Badge to indicate a deload/recovery workout
struct DeloadBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.heart")
                .font(.caption2)
            Text("Deload")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.green.opacity(0.15))
        .foregroundStyle(.green)
        .clipShape(Capsule())
    }
}

// MARK: - Workout History Row

struct WorkoutHistoryRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.name)
                    .font(.headline)

                Spacer()

                if let completedAt = workout.completedAt {
                    Text(completedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label("\(workout.exercises.count) exercises", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let duration = workout.duration {
                    Label("\(Int(duration / 60)) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label("\(Int(workout.totalVolume)) lbs", systemImage: "scalemass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
