import SwiftUI

// MARK: - Rest Timer Container Views

/// Container that isolates rest timer observation from parent view
/// This prevents timer updates from re-rendering the exercise list and closing menus
struct RestTimerBarContainer: View {
    @State private var timerManager = RestTimerManager.shared

    var body: some View {
        if timerManager.isActive {
            GlobalRestTimerBar()
        }
    }
}

/// Container that isolates rest completion banner observation from parent view
struct RestCompleteBannerContainer: View {
    @State private var timerManager = RestTimerManager.shared

    var body: some View {
        if timerManager.showCompletionBanner {
            RestCompleteBanner()
        }
    }
}

// MARK: - Global Rest Timer Bar

/// Compact rest timer bar shown at the top of the workout overview
struct GlobalRestTimerBar: View {
    @State private var timerManager = RestTimerManager.shared
    @State private var showingRestTimeEditor = false

    var body: some View {
        HStack(spacing: 12) {
            timerIcon
            timerInfo
            Spacer()
            timeDisplay
            controlButtons
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(timerBackground)
        .overlay(progressOverlay, alignment: .leading)
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

    private var timerIcon: some View {
        Image(systemName: "timer")
            .font(.title3)
            .foregroundStyle(.blue)
            .symbolEffect(.pulse.wholeSymbol, options: .repeating)
    }

    private var timerInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Rest - \(timerManager.exerciseName)")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text("Set \(timerManager.setNumber) complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timeDisplay: some View {
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
    }

    private var controlButtons: some View {
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

    private var timerBackground: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var progressOverlay: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: geometry.size.width * timerManager.progress, alignment: .leading)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Rest Complete Banner

/// In-app notification banner when rest timer completes
struct RestCompleteBanner: View {
    @State private var timerManager = RestTimerManager.shared

    var body: some View {
        VStack {
            bannerContent
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: timerManager.showCompletionBanner)
    }

    private var bannerContent: some View {
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
    }
}
