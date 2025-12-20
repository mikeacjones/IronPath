import SwiftUI

// MARK: - Workout Calendar View

struct WorkoutCalendarView: View {
    @Binding var selectedDate: Date
    let workoutDates: Set<DateComponents>

    @State private var displayedMonth: Date = Date()

    private var daysInMonth: [Date] {
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

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }

    private var isToday: Bool {
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

// MARK: - Workout Stats Summary View

struct WorkoutStatsSummaryView: View {
    let stats: WorkoutStats
    var weightUnit: WeightUnit = GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds

    var body: some View {
        HStack(spacing: 16) {
            StatCard(title: "Total", value: "\(stats.totalWorkouts)", subtitle: "workouts")
            StatCard(title: "This Week", value: "\(stats.workoutsThisWeek)", subtitle: "workouts")
            StatCard(title: "Volume", value: formatVolume(stats.totalVolume), subtitle: "\(weightUnit.abbreviation) lifted")
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
                Label("\(Int(workout.totalVolume)) \(workout.weightUnit.abbreviation)", systemImage: "scalemass")
                if let calories = workout.estimatedCalories {
                    Label("\(calories) cal", systemImage: "flame")
                }
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

                Label("\(Int(workout.totalVolume)) \(workout.weightUnit.abbreviation)", systemImage: "scalemass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
