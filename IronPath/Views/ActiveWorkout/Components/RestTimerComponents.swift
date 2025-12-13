import SwiftUI

// MARK: - Rest Time Editor Sheet

/// Sheet for editing rest time duration
struct RestTimeEditorSheet: View {
    @Binding var isPresented: Bool
    let currentDuration: TimeInterval
    let onSetRestTime: (TimeInterval) -> Void

    @State private var minutes: Int
    @State private var seconds: Int

    init(isPresented: Binding<Bool>, currentDuration: TimeInterval, onSetRestTime: @escaping (TimeInterval) -> Void) {
        _isPresented = isPresented
        self.currentDuration = currentDuration
        self.onSetRestTime = onSetRestTime
        _minutes = State(initialValue: Int(currentDuration) / 60)
        _seconds = State(initialValue: Int(currentDuration) % 60)
    }

    private var totalSeconds: TimeInterval {
        TimeInterval(minutes * 60 + seconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Set Rest Time")
                    .font(.headline)

                HStack(spacing: 8) {
                    // Minutes picker
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0...10, id: \.self) { min in
                            Text("\(min)").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text(":")
                        .font(.title)
                        .fontWeight(.bold)

                    // Seconds picker
                    Picker("Seconds", selection: $seconds) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { sec in
                            Text(String(format: "%02d", sec)).tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                }
                .frame(height: 150)

                // Quick presets
                Text("Quick Presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach([60, 90, 120, 180], id: \.self) { preset in
                        Button {
                            minutes = preset / 60
                            seconds = preset % 60
                        } label: {
                            Text(formatDuration(TimeInterval(preset)))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(totalSeconds == TimeInterval(preset) ? Color.blue : Color(.secondarySystemBackground))
                                .foregroundStyle(totalSeconds == TimeInterval(preset) ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        onSetRestTime(totalSeconds)
                        isPresented = false
                    }
                    .disabled(totalSeconds < 5)
                }
            }
        }
        .presentationDetents([.height(350)])
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 && secs > 0 {
            return "\(mins)m \(secs)s"
        } else if mins > 0 {
            return "\(mins) min"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Rest Timer View

/// Inline rest timer displayed after completing a set
struct RestTimerView: View {
    let duration: TimeInterval
    let remainingTime: TimeInterval
    let onComplete: () -> Void
    let onSkip: () -> Void
    var onRestTimeChanged: ((TimeInterval) -> Void)?

    @ObservedObject private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    init(duration: TimeInterval, remainingTime: TimeInterval, onComplete: @escaping () -> Void, onSkip: @escaping () -> Void, onRestTimeChanged: ((TimeInterval) -> Void)? = nil) {
        self.duration = duration
        self.remainingTime = remainingTime
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.onRestTimeChanged = onRestTimeChanged
    }

    var progress: Double {
        guard timerManager.totalDuration > 0 else { return 0 }
        return 1 - (timerManager.remainingTime / timerManager.totalDuration)
    }

    var formattedTime: String {
        let time = timerManager.remainingTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Timer circle - tappable to edit
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

            Spacer()

            // Control buttons
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
}

// MARK: - Group Rest Timer View

/// Rest timer displayed in exercise detail sheet for superset/circuit rest periods
struct GroupRestTimerView: View {
    @ObservedObject private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    var body: some View {
        HStack(spacing: 16) {
            // Timer circle with group type color - tappable
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

            Spacer()

            // Control buttons
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

    private var groupColor: Color {
        timerManager.groupType?.swiftUIColor ?? .blue
    }
}

// MARK: - Rest Timer Container Views

/// Container that isolates rest timer observation from parent view
/// This prevents timer updates from re-rendering the exercise list and closing menus
struct RestTimerBarContainer: View {
    @ObservedObject private var timerManager = RestTimerManager.shared

    var body: some View {
        if timerManager.isActive {
            GlobalRestTimerBar()
        }
    }
}

/// Container that isolates rest completion banner observation from parent view
struct RestCompleteBannerContainer: View {
    @ObservedObject private var timerManager = RestTimerManager.shared

    var body: some View {
        if timerManager.showCompletionBanner {
            RestCompleteBanner()
        }
    }
}

// MARK: - Global Rest Timer Bar

/// Compact rest timer bar shown at the top of the workout overview
struct GlobalRestTimerBar: View {
    @ObservedObject private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    var body: some View {
        HStack(spacing: 12) {
            // Animated timer icon
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(.blue)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)

            // Timer info
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest - \(timerManager.exerciseName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("Set \(timerManager.setNumber) complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Time remaining - tappable
            Button {
                showingRestTimeEditor = true
            } label: {
                HStack(spacing: 4) {
                    Text(timerManager.formattedTime)
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
            .buttonStyle(.plain)

            // Control buttons
            HStack(spacing: 8) {
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
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: geometry.size.width * timerManager.progress, alignment: .leading)
            }
            .allowsHitTesting(false),
            alignment: .leading
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
}

// MARK: - Rest Complete Banner

/// In-app notification banner when rest timer completes
struct RestCompleteBanner: View {
    @ObservedObject private var timerManager = RestTimerManager.shared

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Complete!")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Time for your next set of \(timerManager.exerciseName)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                Button {
                    timerManager.showCompletionBanner = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            )
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: timerManager.showCompletionBanner)
    }
}
