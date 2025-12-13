import SwiftUI

// MARK: - Rest Timer View

/// Inline rest timer displayed after completing a set
struct RestTimerView: View {
    let duration: TimeInterval
    let remainingTime: TimeInterval
    let onComplete: () -> Void
    let onSkip: () -> Void
    var onRestTimeChanged: ((TimeInterval) -> Void)?

    @State private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    init(
        duration: TimeInterval,
        remainingTime: TimeInterval,
        onComplete: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onRestTimeChanged: ((TimeInterval) -> Void)? = nil
    ) {
        self.duration = duration
        self.remainingTime = remainingTime
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.onRestTimeChanged = onRestTimeChanged
    }

    /// Progress from timer manager (dependency tracked via timerTick in manager)
    var progress: Double {
        timerManager.progress
    }

    /// Formatted time from timer manager (dependency tracked via timerTick in manager)
    var formattedTime: String {
        timerManager.formattedTime
    }

    var body: some View {
        HStack(spacing: 16) {
            timerCircle
            timerInfo
            Spacer()
            controlButtons
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .sheet(isPresented: $showingRestTimeEditor) {
            RestTimeEditorSheet(
                isPresented: $showingRestTimeEditor,
                currentDuration: timerManager.totalDuration
            ) { newDuration in
                timerManager.setRestTime(newDuration)
                onRestTimeChanged?(newDuration)
            }
        }
    }

    // MARK: - Subviews

    private var timerCircle: some View {
        Button {
            showingRestTimeEditor = true
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)

                Text(formattedTime)
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }

    private var timerInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("Rest Time")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "pencil.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .onTapGesture {
                showingRestTimeEditor = true
            }

            Text(timerManager.remainingTime > 0 ? "Tap time to edit" : "Ready for next set!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button {
                let newDuration = timerManager.totalDuration + 30
                timerManager.addTime(30)
                onRestTimeChanged?(newDuration)
            } label: {
                Text("+30s")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                onSkip()
            } label: {
                Text("Skip")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

// MARK: - Group Rest Timer View

/// Rest timer displayed in exercise detail sheet for superset/circuit rest periods
struct GroupRestTimerView: View {
    @State private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    private var groupColor: Color {
        timerManager.groupType?.swiftUIColor ?? .blue
    }

    var body: some View {
        HStack(spacing: 16) {
            timerCircle
            timerInfo
            Spacer()
            controlButtons
        }
        .padding()
        .background(groupColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(groupColor.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showingRestTimeEditor) {
            RestTimeEditorSheet(
                isPresented: $showingRestTimeEditor,
                currentDuration: timerManager.totalDuration
            ) { newDuration in
                timerManager.setRestTime(newDuration)
            }
        }
    }

    // MARK: - Subviews

    private var timerCircle: some View {
        Button {
            showingRestTimeEditor = true
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(groupColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timerManager.progress)

                Text(timerManager.formattedTime)
                    .font(.headline)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }

    private var timerInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let groupType = timerManager.groupType {
                    Image(systemName: groupType.iconName)
                        .foregroundStyle(groupColor)
                }
                Text("\(timerManager.groupType?.displayName ?? "Group") Rest")
                    .font(.headline)
                    .foregroundStyle(groupColor)
                Image(systemName: "pencil.circle")
                    .font(.caption)
                    .foregroundStyle(groupColor.opacity(0.7))
            }
            .onTapGesture {
                showingRestTimeEditor = true
            }

            Text("Round \(timerManager.setNumber) complete")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let nextExercise = timerManager.nextExerciseName {
                Text("Next: \(nextExercise)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controlButtons: some View {
        VStack(spacing: 8) {
            Button {
                timerManager.addTime(30)
            } label: {
                Text("+30s")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                timerManager.skipTimer()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(groupColor)
            .controlSize(.small)
        }
    }
}
