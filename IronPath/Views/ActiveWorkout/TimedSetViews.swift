import SwiftUI

// MARK: - Timed Set Row

/// Row view for timed sets (e.g., planks, timed ball slams)
/// Layout matches standard sets but with duration input instead of reps
struct TimedSetRow: View {
    let set: ExerciseSet
    let setIndex: Int
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let onDurationChanged: ((Int, TimeInterval) -> Void)?
    let onAddedWeightChanged: ((Int, Double?) -> Void)?
    let suppressRestTimer: Bool
    let isLastSet: Bool
    let onSetCompleted: (() -> Void)?
    let isLiveWorkout: Bool
    let isPendingWorkout: Bool

    @Environment(DependencyContainer.self) private var dependencies
    @State private var addedWeightString: String = ""
    @State private var secondsString: String = ""
    @State private var restTimerManager = RestTimerManager.shared

    private var timedConfig: TimedSetConfig? {
        self.set.timedSetConfig
    }

    private var targetDuration: TimeInterval {
        timedConfig?.targetDuration ?? 30
    }

    private var isCompleted: Bool {
        self.set.isCompleted
    }

    var body: some View {
        HStack(spacing: 12) {
            // Set number with timer icon
            VStack(spacing: 2) {
                Image(systemName: "timer")
                    .foregroundStyle(isCompleted ? .green : .cyan)
                Text("Set \(set.setNumber)")
                    .font(.caption2)
                    .foregroundStyle(isCompleted ? .green : .cyan)
            }
            .frame(width: 50, alignment: .leading)

            if isCompleted {
                // Show completed duration
                completedDurationView
            } else {
                // Show input fields for planning
                AddedWeightInputView(
                    weight: $addedWeightString,
                    onWeightChanged: { newWeight in
                        // Propagate to subsequent sets
                        onAddedWeightChanged?(setIndex, newWeight)

                        var updatedSet = set
                        updatedSet.timedSetConfig?.addedWeight = newWeight
                        onUpdate(updatedSet)
                    }
                )

                DurationInputView(
                    seconds: $secondsString,
                    targetDuration: targetDuration,
                    onDurationChanged: { newDuration in
                        // Propagate to subsequent sets
                        onDurationChanged?(setIndex, newDuration)

                        var updatedSet = set
                        updatedSet.timedSetConfig?.targetDuration = newDuration
                        onUpdate(updatedSet)
                    }
                )
            }

            Spacer()

            // Complete button (for uncompleting)
            if isLiveWorkout && !isPendingWorkout {
                CompleteButton(isCompleted: isCompleted) {
                    uncompleteSet()
                }
            }
        }
        .padding()
        .background(isCompleted || !isLiveWorkout ? Color.green.opacity(0.1) : Color(.systemBackground))
        .onAppear {
            initializeFields()
        }
        .onChange(of: set.timedSetConfig?.targetDuration) { _, newDuration in
            if !isCompleted, let newDuration = newDuration {
                let newDurationString = "\(Int(newDuration))"
                if secondsString != newDurationString {
                    secondsString = newDurationString
                }
            }
        }
        .onChange(of: set.timedSetConfig?.addedWeight) { _, newWeight in
            if !isCompleted {
                let newWeightString = newWeight.map { formatWeight($0) } ?? ""
                if addedWeightString != newWeightString {
                    addedWeightString = newWeightString
                }
            }
        }
    }

    @ViewBuilder
    private var completedDurationView: some View {
        if let config = timedConfig, let actualDuration = config.actualDuration {
            HStack(spacing: 8) {
                // Actual duration
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(actualDuration))s")
                        .font(.body)
                        .fontWeight(.semibold)

                    // Show vs target if they didn't complete full duration
                    if actualDuration < config.targetDuration {
                        Text("of \(Int(config.targetDuration))s")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Added weight if present
                if let weight = config.addedWeight, weight > 0 {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(formatWeight(weight)) lbs")
                        .font(.body)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func initializeFields() {
        if let config = timedConfig {
            if let weight = config.addedWeight {
                addedWeightString = formatWeight(weight)
            }
            secondsString = "\(Int(config.targetDuration))"
        }
    }

    private func uncompleteSet() {
        if isCompleted {
            var updatedSet = set
            updatedSet.completedAt = nil
            updatedSet.timedSetConfig?.actualDuration = nil
            onUpdate(updatedSet)
        }
    }

    func completeSet(withDuration duration: TimeInterval) {
        var updatedSet = set
        updatedSet.timedSetConfig?.actualDuration = duration
        updatedSet.completedAt = Date()
        onUpdate(updatedSet)

        // Start rest timer if applicable
        if isLiveWorkout && !suppressRestTimer && !isLastSet {
            dependencies.restTimerManager.startTimer(
                duration: set.restPeriod,
                exerciseName: exerciseName,
                setNumber: set.setNumber
            )
        }

        // Call completion callback
        onSetCompleted?()
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        } else {
            return String(format: "%.1f", weight)
        }
    }
}

// MARK: - Exercise Timer View

/// Inline exercise timer displayed in active workout view
/// Shows start button, countdown, and running timer (similar to RestTimerView)
struct ExerciseTimerView: View {
    var timerManager: ExerciseTimerManaging
    let exerciseName: String
    let setNumber: Int
    let targetDuration: TimeInterval
    let onTimerComplete: (TimeInterval) -> Void

    @State private var restTimerManager = RestTimerManager.shared

    private var isOverTarget: Bool {
        timerManager.elapsedTime > targetDuration
    }

    private var progressColor: Color {
        if isOverTarget {
            return .orange
        } else if timerManager.progress < 0.2 {  // Less than 20% time remaining
            return .yellow
        } else {
            return .cyan
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            if timerManager.isCountdown {
                // Countdown display
                countdownView
            } else if timerManager.isActive {
                // Running timer
                timerCircle
                timerInfo
                Spacer()
                stopButton
            } else {
                // Start timer button
                startTimerButton
            }
        }
        .padding()
        .background(Color.cyan.opacity(0.1))
    }

    // MARK: - Subviews

    private var startTimerButton: some View {
        Button {
            // Cancel rest timer if it's running (user is starting next set early)
            if restTimerManager.isActive {
                restTimerManager.skipTimer()
            }

            timerManager.startCountdown(
                exerciseName: exerciseName,
                setNumber: setNumber
            ) {
                timerManager.startExerciseTimer(targetDuration: targetDuration) { duration in
                    // Auto-complete when timer finishes
                    onTimerComplete(duration)
                }
            }
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Timer (\(Int(targetDuration))s)")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
    }

    private var countdownView: some View {
        HStack {
            Spacer()
            Text("\(timerManager.countdownRemaining)")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.cyan)
                .transition(.scale.combined(with: .opacity))
                .id(timerManager.countdownRemaining)
            Spacer()

            Button {
                timerManager.skipCountdown()
            } label: {
                Text("Skip")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var timerCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: min(timerManager.progress, 1.0))
                .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: timerManager.progress)

            Text(timerManager.formattedElapsedTime)
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(progressColor)
        }
    }

    private var timerInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Exercise Timer")
                .font(.subheadline)
                .fontWeight(.medium)

            if !isOverTarget {
                Text("Target: \(Int(targetDuration))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Over target!")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var stopButton: some View {
        Button {
            if let finalDuration = timerManager.stopTimer() {
                onTimerComplete(finalDuration)
            }
        } label: {
            Text("Stop")
                .font(.caption)
                .fontWeight(.medium)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.small)
    }
}
