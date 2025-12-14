import SwiftUI

// MARK: - Workout Generation Loading View

/// Loading overlay with fun rotating messages during workout generation
struct WorkoutGenerationLoadingView: View {
    @State private var currentMessageIndex = 0
    @State private var opacity: Double = 1.0

    private let messages = [
        ("Warming up the AI...", "figure.walk"),
        ("Analyzing your gains potential...", "chart.line.uptrend.xyaxis"),
        ("Consulting the iron gods...", "dumbbell.fill"),
        ("Calculating optimal pump...", "function"),
        ("Crafting your perfect workout...", "hammer.fill"),
        ("Loading protein synthesis algorithms...", "atom"),
        ("Flexing neural networks...", "brain.head.profile"),
        ("Preparing to crush it...", "flame.fill"),
        ("Summoning workout wisdom...", "sparkles"),
        ("Almost there, stay hydrated...", "drop.fill")
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Animated dumbbell
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)

            // Current message
            VStack(spacing: 8) {
                Image(systemName: messages[currentMessageIndex].1)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text(messages[currentMessageIndex].0)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.3), value: opacity)

            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 8)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 10)
        .task {
            await rotateMessages()
        }
    }

    private func rotateMessages() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 0
            }

            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            currentMessageIndex = (currentMessageIndex + 1) % messages.count
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 1
            }
        }
    }
}
