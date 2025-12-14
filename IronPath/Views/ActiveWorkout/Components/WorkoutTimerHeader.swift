import SwiftUI

// MARK: - Workout Timer Header

/// Displays workout duration timer and progress count
struct WorkoutTimerHeader: View {
    let startTime: Date
    let completedCount: Int
    let totalCount: Int

    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formattedTime)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(completedCount)/\(totalCount)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .onAppear {
            elapsedTime = Date().timeIntervalSince(startTime)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
