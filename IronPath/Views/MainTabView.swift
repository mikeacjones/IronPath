import SwiftUI
import UIKit
import Combine
import UserNotifications

// MARK: - Rest Timer Manager

/// Manages a global rest timer that persists when navigating away from exercise detail
class RestTimerManager: ObservableObject {
    static let shared = RestTimerManager()

    @Published var isActive: Bool = false
    @Published var remainingTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var exerciseName: String = ""
    @Published var setNumber: Int = 0
    @Published var showCompletionBanner: Bool = false

    private var timer: Timer?

    private init() {
        requestNotificationPermission()
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remainingTime / totalDuration)
    }

    var formattedTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func startTimer(duration: TimeInterval, exerciseName: String, setNumber: Int) {
        stopTimer()

        self.totalDuration = duration
        self.remainingTime = duration
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.isActive = true
        self.showCompletionBanner = false

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                self.timerCompleted()
            }
        }
    }

    func addTime(_ seconds: TimeInterval) {
        remainingTime += seconds
        totalDuration += seconds
    }

    func skipTimer() {
        stopTimer()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }

    private func timerCompleted() {
        stopTimer()
        showCompletionBanner = true
        triggerCompletionNotification()

        // Auto-hide banner after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.showCompletionBanner = false
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func triggerCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Time for your next set of \(exerciseName)!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .tag(1)

            ProgressTabView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(3)
        }
    }
}

// MARK: - Workout Type Selection

enum WorkoutType: String, CaseIterable, Identifiable {
    case fullBody = "Full Body"
    case upperBody = "Upper Body"
    case lowerBody = "Lower Body"
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case chestTriceps = "Chest & Triceps"
    case backBiceps = "Back & Biceps"
    case shoulders = "Shoulders"
    case core = "Core"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fullBody: return "figure.strengthtraining.traditional"
        case .upperBody: return "figure.arms.open"
        case .lowerBody: return "figure.walk"
        case .push: return "arrow.up.forward"
        case .pull: return "arrow.down.backward"
        case .legs: return "figure.walk"
        case .chestTriceps: return "figure.arms.open"
        case .backBiceps: return "arrow.down.to.line"
        case .shoulders: return "figure.boxing"
        case .core: return "figure.core.training"
        case .custom: return "text.bubble"
        }
    }

    var targetMuscleGroups: Set<MuscleGroup> {
        switch self {
        case .fullBody: return Set(MuscleGroup.allCases)
        case .upperBody: return [.chest, .back, .shoulders, .biceps, .triceps, .forearms]
        case .lowerBody: return [.quads, .hamstrings, .glutes, .calves]
        case .push: return [.chest, .shoulders, .triceps]
        case .pull: return [.back, .biceps, .forearms]
        case .legs: return [.quads, .hamstrings, .glutes, .calves]
        case .chestTriceps: return [.chest, .triceps]
        case .backBiceps: return [.back, .biceps]
        case .shoulders: return [.shoulders, .traps]
        case .core: return [.abs, .obliques, .lowerBack]
        case .custom: return []  // No predefined muscles - user describes in prompt
        }
    }

    var requiresCustomPrompt: Bool {
        self == .custom
    }
}

// MARK: - Tab Views

struct WorkoutView: View {
    @EnvironmentObject var appState: AppState
    @State private var isGeneratingWorkout = false
    @State private var generatedWorkout: Workout?
    @State private var activeWorkout: Workout?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showWorkoutSetup = false

    /// Determines what workout to do today based on split and recent history
    private var recommendedWorkoutDay: WorkoutSplitDay? {
        guard let profile = appState.userProfile else { return nil }
        let split = profile.workoutPreferences.workoutSplit
        let rotation = split.workoutRotation
        guard !rotation.isEmpty else { return nil }

        let history = WorkoutDataManager.shared.getWorkoutHistory()

        // Find the most recent workout that matches a split day
        if let lastWorkout = history.first {
            // Try to determine what type of workout was last done
            let lastWorkoutDay = determineWorkoutDay(from: lastWorkout, split: split)

            if let lastDay = lastWorkoutDay,
               let lastIndex = rotation.firstIndex(of: lastDay) {
                // Return the next workout in rotation
                let nextIndex = (lastIndex + 1) % rotation.count
                return rotation[nextIndex]
            }
        }

        // No history or couldn't determine, start from beginning
        return rotation.first
    }

    /// Try to determine what split day a workout was based on the exercises
    private func determineWorkoutDay(from workout: Workout, split: WorkoutSplit) -> WorkoutSplitDay? {
        // Get all primary muscle groups from the workout
        var workoutMuscles = Set<MuscleGroup>()
        for exercise in workout.exercises {
            workoutMuscles.formUnion(exercise.exercise.primaryMuscleGroups)
        }

        // Find the best matching split day
        var bestMatch: WorkoutSplitDay?
        var bestScore = 0

        for day in split.workoutRotation {
            let targetMuscles = day.targetMuscleGroups
            let overlap = workoutMuscles.intersection(targetMuscles).count
            if overlap > bestScore {
                bestScore = overlap
                bestMatch = day
            }
        }

        return bestMatch
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isGeneratingWorkout {
                    WorkoutGenerationLoadingView()
                } else if let workout = generatedWorkout {
                    WorkoutDetailView(workout: workout, onStartWorkout: {
                        startWorkout(workout)
                    }, onRegenerate: {
                        generatedWorkout = nil
                    })
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)

                        Text("Ready to workout?")
                            .font(.title)
                            .fontWeight(.bold)

                        if let recommended = recommendedWorkoutDay,
                           let profile = appState.userProfile {
                            VStack(spacing: 8) {
                                Text("Recommended: \(recommended.rawValue)")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                Text("Based on your \(profile.workoutPreferences.workoutSplit.rawValue) split")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Let Claude generate a personalized workout based on your profile and goals")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            // Auto-generate button (uses split recommendation)
                            if let recommended = recommendedWorkoutDay {
                                Button {
                                    autoGenerateWorkout(for: recommended)
                                } label: {
                                    HStack {
                                        Image(systemName: "sparkles")
                                        Text("Auto Generate \(recommended.rawValue)")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }

                            // Manual selection button
                            Button {
                                showWorkoutSetup = true
                            } label: {
                                Text("Choose Workout Type")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(item: $activeWorkout) { workout in
                ActiveWorkoutView(workout: workout, userProfile: appState.userProfile, onComplete: { completedWorkout in
                    activeWorkout = nil
                    generatedWorkout = nil
                }, onCancel: {
                    activeWorkout = nil
                })
            }
            .sheet(isPresented: $showWorkoutSetup) {
                WorkoutSetupView(
                    isGenerating: $isGeneratingWorkout,
                    onGenerate: { workoutType, notes, isDeload in
                        generateWorkout(workoutType: workoutType, notes: notes, isDeload: isDeload)
                    }
                )
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func startWorkout(_ workout: Workout) {
        var startedWorkout = workout
        startedWorkout.startedAt = Date()
        activeWorkout = startedWorkout
    }

    /// Auto-generate a workout based on the recommended split day
    private func autoGenerateWorkout(for splitDay: WorkoutSplitDay) {
        guard let profile = appState.userProfile else {
            errorMessage = "Please complete onboarding first"
            showError = true
            return
        }

        guard APIKeyManager.shared.hasAPIKey else {
            errorMessage = "Please add your Anthropic API key in the Profile tab before generating workouts"
            showError = true
            return
        }

        isGeneratingWorkout = true

        // Build context notes based on training style
        let trainingStyle = profile.workoutPreferences.trainingStyle
        let styleNotes = "Training style: \(trainingStyle.rawValue) - Target rep range: \(trainingStyle.typicalRepRange), Rest: \(trainingStyle.typicalRestSeconds)s between sets"

        Task {
            do {
                let recentWorkouts = Array(WorkoutDataManager.shared.getWorkoutHistory().suffix(5))

                let workout = try await AnthropicService.shared.generateWorkout(
                    profile: profile,
                    targetMuscleGroups: splitDay.targetMuscleGroups,
                    workoutHistory: recentWorkouts,
                    workoutType: splitDay.rawValue,
                    userNotes: styleNotes
                )
                await MainActor.run {
                    generatedWorkout = workout
                    isGeneratingWorkout = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGeneratingWorkout = false
                }
            }
        }
    }

    private func generateWorkout(workoutType: WorkoutType, notes: String, isDeload: Bool = false) {
        guard let profile = appState.userProfile else {
            errorMessage = "Please complete onboarding first"
            showError = true
            return
        }

        guard APIKeyManager.shared.hasAPIKey else {
            errorMessage = "Please add your Anthropic API key in the Profile tab before generating workouts"
            showError = true
            return
        }

        isGeneratingWorkout = true

        Task {
            do {
                let recentWorkouts = Array(WorkoutDataManager.shared.getWorkoutHistory().suffix(5))

                var workout = try await AnthropicService.shared.generateWorkout(
                    profile: profile,
                    targetMuscleGroups: workoutType.targetMuscleGroups,
                    workoutHistory: recentWorkouts,
                    workoutType: workoutType.rawValue,
                    userNotes: notes.isEmpty ? nil : notes,
                    isDeload: isDeload
                )
                workout.isDeload = isDeload
                await MainActor.run {
                    generatedWorkout = workout
                    isGeneratingWorkout = false
                    showWorkoutSetup = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGeneratingWorkout = false
                }
            }
        }
    }
}

// MARK: - Workout Setup View

struct WorkoutSetupView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isGenerating: Bool
    let onGenerate: (WorkoutType, String, Bool) -> Void // (workoutType, notes, isDeload)

    @State private var selectedWorkoutType: WorkoutType = .fullBody
    @State private var workoutNotes: String = ""
    @State private var isDeload: Bool = false

    private var isCustomWorkout: Bool {
        selectedWorkoutType == .custom
    }

    private var canGenerate: Bool {
        // Custom workouts require a prompt
        if isCustomWorkout {
            return !workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private var promptPlaceholder: String {
        if isCustomWorkout {
            return "Describe what kind of workout you want..."
        }
        return "Any notes for today's workout?"
    }

    private var promptFooter: String {
        if isCustomWorkout {
            return "Example: \"A quick 20-minute arm workout\" or \"Heavy compound lifts focusing on strength\""
        }
        return "Example: \"My shoulder hurts so avoid overhead pressing\" or \"The cable machine is broken\""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(WorkoutType.allCases) { type in
                                WorkoutTypeCard(
                                    type: type,
                                    isSelected: selectedWorkoutType == type,
                                    onTap: { selectedWorkoutType = type }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Workout Type")
                    }

                    Section {
                        Toggle(isOn: $isDeload) {
                            HStack {
                                Image(systemName: "arrow.down.heart")
                                    .foregroundStyle(.green)
                                Text("Deload Week")
                            }
                        }
                    } header: {
                        Text("Recovery Options")
                    } footer: {
                        Text("Deload workouts use lighter weights (50-70%) and won't affect your progressive overload tracking.")
                    }

                    Section {
                        TextField(promptPlaceholder, text: $workoutNotes, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        if isCustomWorkout {
                            HStack {
                                Text("Custom Workout Prompt")
                                Text("(Required)")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        } else {
                            Text("Notes for Claude")
                        }
                    } footer: {
                        Text(promptFooter)
                    }
                }
                .disabled(isGenerating)
                .blur(radius: isGenerating ? 3 : 0)

                // Loading overlay with fun messages
                if isGenerating {
                    WorkoutGenerationLoadingView()
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onGenerate(selectedWorkoutType, workoutNotes, isDeload)
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Generate")
                        }
                    }
                    .disabled(isGenerating || !canGenerate)
                }
            }
        }
    }
}

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

    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

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
        .onReceive(timer) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                currentMessageIndex = (currentMessageIndex + 1) % messages.count
                withAnimation(.easeIn(duration: 0.2)) {
                    opacity = 1
                }
            }
        }
    }
}

struct WorkoutTypeCard: View {
    let type: WorkoutType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    let onStartWorkout: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(workout.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                ForEach(workout.exercises) { workoutExercise in
                    ExerciseCard(workoutExercise: workoutExercise)
                }

                VStack(spacing: 12) {
                    Button {
                        onStartWorkout()
                    } label: {
                        Text("Start Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        onRegenerate()
                    } label: {
                        Text("Generate Different Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
        }
    }
}

struct ExerciseCard: View {
    let workoutExercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(workoutExercise.exercise.name)
                .font(.headline)

            HStack {
                Label("\(workoutExercise.sets.count) sets", systemImage: "repeat")
                Spacer()
                Label("\(workoutExercise.sets.first?.targetReps ?? 0) reps", systemImage: "number")
                Spacer()
                Label("\(Int(workoutExercise.sets.first?.restPeriod ?? 0))s rest", systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !workoutExercise.notes.isEmpty {
                Text(workoutExercise.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct HistoryView: View {
    @State private var workouts: [Workout] = []
    @State private var selectedDate: Date = Date()
    @State private var showCalendar = true
    @State private var selectedWorkout: Workout?
    @State private var showingAddWorkout = false

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
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $selectedWorkout) { workout in
                WorkoutHistoryDetailView(workout: workout)
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddHistoricalWorkoutView {
                    loadWorkouts()
                }
            }
            .onAppear {
                loadWorkouts()
            }
        }
    }

    private func loadWorkouts() {
        workouts = WorkoutDataManager.shared.getWorkoutHistory()
    }
}

// MARK: - Workout History Detail View

struct WorkoutHistoryDetailView: View {
    let workout: Workout

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
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fK", volume / 1000)
        }
        return "\(Int(volume))"
    }
}

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
                            Text("\(Int(weight)) lbs")
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

struct ProgressTabView: View {
    @State private var workouts: [Workout] = []
    @State private var personalRecords: [PersonalRecord] = []
    @State private var selectedExercise: String?

    var exerciseNames: [String] {
        var names = Set<String>()
        for workout in workouts {
            for exercise in workout.exercises {
                names.insert(exercise.exercise.name)
            }
        }
        return names.sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if workouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("Track your progress")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("Complete workouts to see your progress charts and analytics")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 100)
                } else {
                    VStack(spacing: 20) {
                        // Volume chart
                        VolumeChartView(workouts: workouts)
                            .padding(.horizontal)

                        // Personal Records
                        PRSectionView(records: personalRecords)
                            .padding(.horizontal)

                        // Exercise picker for specific progress
                        if !exerciseNames.isEmpty {
                            ExerciseProgressSection(
                                exerciseNames: exerciseNames,
                                selectedExercise: $selectedExercise,
                                workouts: workouts
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        workouts = WorkoutDataManager.shared.getWorkoutHistory()
        personalRecords = calculatePRs()
    }

    private func calculatePRs() -> [PersonalRecord] {
        var prs: [String: PersonalRecord] = [:]

        for workout in workouts {
            for workoutExercise in workout.exercises {
                let exerciseName = workoutExercise.exercise.name

                for set in workoutExercise.sets {
                    guard let weight = set.weight,
                          let reps = set.actualReps,
                          set.isCompleted else { continue }

                    let currentPR = prs[exerciseName]

                    // Check if this is a new max weight
                    if currentPR == nil || weight > currentPR!.weight {
                        prs[exerciseName] = PersonalRecord(
                            exerciseName: exerciseName,
                            weight: weight,
                            reps: reps,
                            date: set.completedAt ?? workout.completedAt ?? Date()
                        )
                    }
                }
            }
        }

        return prs.values.sorted { $0.weight > $1.weight }
    }
}

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
}

struct VolumeChartView: View {
    let workouts: [Workout]

    var weeklyVolume: [(week: String, volume: Double)] {
        let calendar = Calendar.current
        var volumeByWeek: [Date: Double] = [:]

        for workout in workouts {
            guard let completedAt = workout.completedAt else { continue }
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: completedAt))!
            volumeByWeek[weekStart, default: 0] += workout.totalVolume
        }

        let sorted = volumeByWeek.sorted { $0.key < $1.key }.suffix(8)
        return sorted.map { (week: formatWeek($0.key), volume: $0.value) }
    }

    var maxVolume: Double {
        weeklyVolume.map { $0.volume }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume")
                .font(.headline)

            if weeklyVolume.isEmpty {
                Text("Complete workouts to see your volume trend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weeklyVolume, id: \.week) { data in
                        VStack(spacing: 4) {
                            Text(formatVolume(data.volume))
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.gradient)
                                .frame(height: max(20, CGFloat(data.volume / maxVolume) * 120))

                            Text(data.week)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 160)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0fK", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }
}

struct PRSectionView: View {
    let records: [PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Personal Records", systemImage: "trophy.fill")
                    .font(.headline)
                Spacer()
                Text("\(records.count) PRs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if records.isEmpty {
                Text("Complete workouts to set personal records")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(records.prefix(5)) { record in
                    PRRowView(record: record)
                }

                if records.count > 5 {
                    Text("+ \(records.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PRRowView: View {
    let record: PersonalRecord

    var body: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
                .font(.caption)

            Text(record.exerciseName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(record.weight)) lbs × \(record.reps)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExerciseProgressSection: View {
    let exerciseNames: [String]
    @Binding var selectedExercise: String?
    let workouts: [Workout]

    var exerciseHistory: [(date: Date, weight: Double, reps: Int)] {
        guard let exerciseName = selectedExercise else { return [] }

        var history: [(date: Date, weight: Double, reps: Int)] = []

        for workout in workouts.sorted(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }) {
            for workoutExercise in workout.exercises where workoutExercise.exercise.name == exerciseName {
                for set in workoutExercise.sets {
                    guard let weight = set.weight,
                          let reps = set.actualReps,
                          set.isCompleted,
                          let date = set.completedAt ?? workout.completedAt else { continue }

                    history.append((date: date, weight: weight, reps: reps))
                }
            }
        }

        return history
    }

    var maxWeight: Double {
        exerciseHistory.map { $0.weight }.max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Progress")
                .font(.headline)

            // Exercise picker
            Menu {
                Button("Select Exercise") {
                    selectedExercise = nil
                }
                Divider()
                ForEach(exerciseNames, id: \.self) { name in
                    Button(name) {
                        selectedExercise = name
                    }
                }
            } label: {
                HStack {
                    Text(selectedExercise ?? "Select an exercise")
                        .foregroundStyle(selectedExercise == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }

            if let exerciseName = selectedExercise {
                if exerciseHistory.isEmpty {
                    Text("No data for \(exerciseName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    // Simple progress visualization
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Weight:")
                                .foregroundStyle(.secondary)
                            Text("\(Int(maxWeight)) lbs")
                                .fontWeight(.bold)
                        }
                        .font(.subheadline)

                        Text("Recent Sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(exerciseHistory.suffix(5).reversed(), id: \.date) { entry in
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(entry.weight)) lbs × \(entry.reps)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var gymProfileManager = GymProfileManager.shared
    @State private var showingAPIKeySheet = false
    @State private var showingEditProfile = false
    @State private var showingGymSettings = false
    @State private var showingGymProfileEditor = false
    @State private var showingNewGymProfile = false
    @State private var editingGymProfile: GymProfile?
    @State private var apiKey = ""
    @State private var hasAPIKey = APIKeyManager.shared.hasAPIKey
    @State private var showingResetConfirmation = false
    @State private var showingExportOptions = false
    @State private var exportData: ExportData?

    var body: some View {
        NavigationStack {
            List {
                // Gym Profile Section (at the top for quick switching)
                Section {
                    ForEach(gymProfileManager.profiles) { profile in
                        GymProfileRow(
                            profile: profile,
                            isActive: profile.id == gymProfileManager.activeProfileId,
                            onSelect: {
                                gymProfileManager.switchToProfile(profile)
                            },
                            onEdit: {
                                editingGymProfile = profile
                            }
                        )
                    }

                    Button {
                        showingNewGymProfile = true
                    } label: {
                        Label("Add Gym Profile", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Gym Profiles")
                } footer: {
                    Text("Create profiles for different gyms (e.g., home gym, hotel, work gym)")
                }

                Section {
                    Button {
                        showingGymSettings = true
                    } label: {
                        HStack {
                            Label("Equipment Settings", systemImage: "gearshape.fill")
                            Spacer()
                            if let profile = gymProfileManager.activeProfile {
                                Text(profile.name)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Active Gym Settings")
                } footer: {
                    Text("Configure cable machines, dumbbells, and plates for the selected gym")
                }

                if let profile = appState.userProfile {
                    Section("Personal Info") {
                        LabeledContent("Name", value: profile.name)
                        LabeledContent("Fitness Level", value: profile.fitnessLevel.rawValue)
                    }

                    Section("Goals") {
                        ForEach(Array(profile.goals), id: \.self) { goal in
                            Text(goal.rawValue)
                        }
                    }

                    Section {
                        Picker("Training Style", selection: Binding(
                            get: { profile.workoutPreferences.trainingStyle },
                            set: { newValue in
                                var updated = profile
                                updated.workoutPreferences.trainingStyle = newValue
                                appState.userProfile = updated
                            }
                        )) {
                            ForEach(TrainingStyle.allCases, id: \.self) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }

                        Picker("Workout Split", selection: Binding(
                            get: { profile.workoutPreferences.workoutSplit },
                            set: { newValue in
                                var updated = profile
                                updated.workoutPreferences.workoutSplit = newValue
                                appState.userProfile = updated
                            }
                        )) {
                            ForEach(WorkoutSplit.allCases, id: \.self) { split in
                                Text(split.rawValue).tag(split)
                            }
                        }
                    } header: {
                        Text("Training Program")
                    } footer: {
                        Text("\(profile.workoutPreferences.trainingStyle.description)\n\(profile.workoutPreferences.workoutSplit.description)")
                    }

                    Section("Preferences") {
                        LabeledContent("Workout Duration", value: "\(profile.workoutPreferences.preferredWorkoutDuration) min")
                        LabeledContent("Workouts per Week", value: "\(profile.workoutPreferences.workoutsPerWeek)")
                        LabeledContent("Rest Time", value: "\(profile.workoutPreferences.preferredRestTime)s")
                    }

                    Section {
                        Button("Edit Profile") {
                            showingEditProfile = true
                        }
                    }
                }

                Section {
                    HStack {
                        Label("Anthropic API Key", systemImage: "key.fill")
                        Spacer()
                        if hasAPIKey {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    Button(hasAPIKey ? "Update API Key" : "Add API Key") {
                        showingAPIKeySheet = true
                    }

                    if hasAPIKey {
                        Button("Remove API Key", role: .destructive) {
                            APIKeyManager.shared.clearAPIKey()
                            hasAPIKey = false
                        }
                    }
                } header: {
                    Text("AI Configuration")
                } footer: {
                    Text("Required for generating personalized workouts with Claude AI. Get your API key from console.anthropic.com")
                }

                Section {
                    Button {
                        showingExportOptions = true
                    } label: {
                        Label("Export Workout Data", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset All Workout Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export your workout history or reset all data to start fresh")
                }

                Section {
                    Button("Reset Onboarding", role: .destructive) {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        appState.isOnboarded = false
                        appState.userProfile = nil
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeyInputView(apiKey: $apiKey, onSave: {
                    APIKeyManager.shared.saveAPIKey(apiKey)
                    hasAPIKey = true
                    showingAPIKeySheet = false
                    apiKey = ""
                })
            }
            .sheet(isPresented: $showingEditProfile) {
                if let profile = appState.userProfile {
                    EditProfileView(profile: profile, onSave: { updatedProfile in
                        appState.userProfile = updatedProfile
                        showingEditProfile = false
                    })
                }
            }
            .sheet(isPresented: $showingGymSettings) {
                GymEquipmentSettingsView()
            }
            .sheet(isPresented: $showingNewGymProfile) {
                GymProfileEditorView(
                    profile: nil,
                    onSave: { newProfile in
                        gymProfileManager.addProfile(newProfile)
                        showingNewGymProfile = false
                    }
                )
            }
            .sheet(item: $editingGymProfile) { profile in
                GymProfileEditorView(
                    profile: profile,
                    onSave: { updatedProfile in
                        gymProfileManager.updateProfile(updatedProfile)
                        editingGymProfile = nil
                    },
                    onDelete: gymProfileManager.profiles.count > 1 ? {
                        gymProfileManager.deleteProfile(profile)
                        editingGymProfile = nil
                    } : nil
                )
            }
            .confirmationDialog("Reset Workout Data", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Reset All Data", role: .destructive) {
                    WorkoutDataManager.shared.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your workout history. This action cannot be undone.")
            }
            .confirmationDialog("Export Workout Data", isPresented: $showingExportOptions, titleVisibility: .visible) {
                Button("Export as JSON") {
                    if let data = WorkoutDataManager.shared.exportHistoryAsJSON(),
                       let string = String(data: data, encoding: .utf8) {
                        exportData = ExportData(content: string, filename: "workout_history.json")
                    }
                }
                Button("Export as CSV") {
                    let csv = WorkoutDataManager.shared.exportHistoryAsCSV()
                    exportData = ExportData(content: csv, filename: "workout_history.csv")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose a format for your workout data export")
            }
            .sheet(item: $exportData) { data in
                ShareSheet(items: [data.temporaryFileURL].compactMap { $0 })
            }
        }
    }
}

// MARK: - Gym Profile Row

struct GymProfileRow: View {
    let profile: GymProfile
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Button {
                onSelect()
            } label: {
                HStack {
                    Image(systemName: profile.icon)
                        .font(.title2)
                        .foregroundStyle(isActive ? .blue : .secondary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .fontWeight(isActive ? .semibold : .regular)
                        Text("\(profile.availableEquipment.count) equipment types")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Gym Profile Editor

struct GymProfileEditorView: View {
    let profile: GymProfile?
    let onSave: (GymProfile) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "dumbbell.fill"
    @State private var selectedEquipment: Set<Equipment> = Set(Equipment.allCases)
    @State private var selectedMachines: Set<SpecificMachine> = Set(SpecificMachine.allCases)
    @State private var dumbbellMaxWeight: Double = 120.0
    @State private var showingDeleteConfirmation = false
    @State private var showingMachineSelection = false

    private let icons = [
        "dumbbell.fill",
        "building.2.fill",
        "house.fill",
        "figure.strengthtraining.traditional",
        "building.columns.fill",
        "briefcase.fill"
    ]

    private var isEditing: Bool {
        profile != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Info") {
                    TextField("Profile Name", text: $name)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Toggle(equipment.rawValue, isOn: Binding(
                            get: { selectedEquipment.contains(equipment) },
                            set: { isOn in
                                if isOn {
                                    selectedEquipment.insert(equipment)
                                } else {
                                    selectedEquipment.remove(equipment)
                                }
                            }
                        ))
                    }
                } header: {
                    Text("Available Equipment")
                } footer: {
                    Text("Select all equipment available at this gym")
                }

                Section {
                    Button {
                        showingMachineSelection = true
                    } label: {
                        HStack {
                            Text("Other Machines")
                            Spacer()
                            Text("\(selectedMachines.count) selected")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Other Machines")
                } footer: {
                    Text("Select specific gym machines available (pec deck, hack squat, etc.)")
                }

                Section("Quick Settings") {
                    Stepper("Max Dumbbell: \(Int(dumbbellMaxWeight)) lbs", value: $dumbbellMaxWeight, in: 10...200, step: 10)
                }

                if isEditing && onDelete != nil {
                    Section {
                        Button("Delete Profile", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Gym Profile" : "New Gym Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let profile = profile {
                    name = profile.name
                    selectedIcon = profile.icon
                    selectedEquipment = profile.availableEquipment
                    selectedMachines = profile.availableMachines
                    dumbbellMaxWeight = profile.dumbbellMaxWeight
                }
            }
            .sheet(isPresented: $showingMachineSelection) {
                GymMachineSelectionView(selectedMachines: $selectedMachines)
            }
            .confirmationDialog("Delete Profile?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this gym profile and its settings.")
            }
        }
    }

    private func saveProfile() {
        var updatedProfile = profile ?? GymProfile(
            name: name,
            icon: selectedIcon,
            availableEquipment: selectedEquipment,
            availableMachines: selectedMachines,
            defaultCableConfig: .defaultConfig
        )

        updatedProfile.name = name
        updatedProfile.icon = selectedIcon
        updatedProfile.availableEquipment = selectedEquipment
        updatedProfile.availableMachines = selectedMachines
        updatedProfile.dumbbellMaxWeight = dumbbellMaxWeight

        onSave(updatedProfile)
        dismiss()
    }
}

// MARK: - Gym Machine Selection View

struct GymMachineSelectionView: View {
    @Binding var selectedMachines: Set<SpecificMachine>
    @Environment(\.dismiss) var dismiss

    var allSelected: Bool {
        selectedMachines.count == SpecificMachine.allCases.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if allSelected {
                            selectedMachines.removeAll()
                        } else {
                            selectedMachines = Set(SpecificMachine.allCases)
                        }
                    } label: {
                        HStack {
                            Text(allSelected ? "Deselect All" : "Select All")
                                .fontWeight(.medium)
                            Spacer()
                            if allSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                Section {
                    ForEach(SpecificMachine.allCases, id: \.self) { machine in
                        Button {
                            if selectedMachines.contains(machine) {
                                selectedMachines.remove(machine)
                            } else {
                                selectedMachines.insert(machine)
                            }
                        } label: {
                            HStack {
                                Text(machine.rawValue)
                                Spacer()
                                if selectedMachines.contains(machine) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Available Machines")
                }
            }
            .navigationTitle("Other Machines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Gym Equipment Settings

/// Represents a cable machine's weight stack configuration
struct CableMachineConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String  // e.g., "Lat Pulldown", "Cable Crossover"
    var plateTiers: [PlateTier]  // Different plate tiers with their own weights

    struct PlateTier: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var plateWeight: Double  // Weight per plate in this tier
        var plateCount: Int      // Number of plates in this tier
    }

    /// Calculate all available weights for this machine
    var availableWeights: [Double] {
        var weights: [Double] = [0]
        var currentWeight: Double = 0

        for tier in plateTiers {
            for _ in 0..<tier.plateCount {
                currentWeight += tier.plateWeight
                weights.append(currentWeight)
            }
        }

        return weights.sorted()
    }

    /// Find the nearest available weight
    func nearestWeight(to target: Double) -> Double {
        let weights = availableWeights
        guard !weights.isEmpty else { return target }
        return weights.min(by: { abs($0 - target) < abs($1 - target) }) ?? target
    }

    /// Get weights near target for selection UI
    func weightsNear(_ target: Double, count: Int = 5) -> [Double] {
        let weights = availableWeights
        guard let nearestIndex = weights.firstIndex(where: { $0 >= target }) else {
            return Array(weights.suffix(count))
        }

        let startIndex = max(0, nearestIndex - count/2)
        let endIndex = min(weights.count, startIndex + count)
        return Array(weights[startIndex..<endIndex])
    }

    /// Default cable machine config (simple 5lb increments)
    static var defaultConfig: CableMachineConfig {
        CableMachineConfig(
            name: "Default Cable Machine",
            plateTiers: [PlateTier(plateWeight: 5.0, plateCount: 40)]
        )
    }

    /// Example: Lat pulldown with 6x9lb then 12.5lb plates
    static var latPulldownExample: CableMachineConfig {
        CableMachineConfig(
            name: "Lat Pulldown",
            plateTiers: [
                PlateTier(plateWeight: 9.0, plateCount: 6),
                PlateTier(plateWeight: 12.5, plateCount: 12)
            ]
        )
    }

    /// Human-readable description of the weight stack
    var stackDescription: String {
        plateTiers.map { "\($0.plateCount)×\(formatWeight($0.plateWeight))lb" }.joined(separator: " + ")
    }

    /// Check if a specific weight is achievable with this configuration
    func isValidWeight(_ weight: Double) -> Bool {
        availableWeights.contains(weight)
    }

    /// Get the pin location (plate number) for a given weight
    /// Returns nil if the weight is not achievable
    func pinLocation(for weight: Double) -> Int? {
        guard weight > 0 else { return nil }

        var currentWeight: Double = 0
        var plateNumber = 0

        for tier in plateTiers {
            for _ in 0..<tier.plateCount {
                plateNumber += 1
                currentWeight += tier.plateWeight
                if abs(currentWeight - weight) < 0.01 {
                    return plateNumber
                }
            }
        }

        return nil
    }

    /// Get detailed pin info including which tier
    func pinInfo(for weight: Double) -> (pinNumber: Int, tierDescription: String)? {
        guard weight > 0 else { return nil }

        var currentWeight: Double = 0
        var plateNumber = 0
        var tierIndex = 0
        var platesInCurrentTier = 0

        for tier in plateTiers {
            for plateInTier in 0..<tier.plateCount {
                plateNumber += 1
                platesInCurrentTier = plateInTier + 1
                currentWeight += tier.plateWeight
                if abs(currentWeight - weight) < 0.01 {
                    let tierDesc = "Plate \(platesInCurrentTier) of \(tier.plateCount) @ \(formatWeight(tier.plateWeight))lb"
                    return (plateNumber, tierDesc)
                }
            }
            tierIndex += 1
            platesInCurrentTier = 0
        }

        return nil
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

/// Manages gym equipment settings like cable machine increments
/// Preference for how often an exercise should be suggested
enum ExerciseSuggestionPreference: String, Codable, CaseIterable {
    case normal = "Normal"
    case suggestMore = "Suggest More"
    case suggestLess = "Suggest Less"
    case never = "Don't Suggest"

    var icon: String {
        switch self {
        case .normal: return "equal.circle"
        case .suggestMore: return "arrow.up.circle.fill"
        case .suggestLess: return "arrow.down.circle.fill"
        case .never: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .normal: return .secondary
        case .suggestMore: return .green
        case .suggestLess: return .orange
        case .never: return .red
        }
    }

    var claudeInstruction: String {
        switch self {
        case .normal: return ""
        case .suggestMore: return "PRIORITIZE including this exercise"
        case .suggestLess: return "AVOID unless specifically requested"
        case .never: return "NEVER include this exercise"
        }
    }
}

// MARK: - Gym Equipment Settings View

struct GymEquipmentSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var showingDefaultCableEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingDefaultCableEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Default Cable Machine")
                                    .foregroundStyle(.primary)
                                Text(settings.defaultCableConfig.stackDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !settings.cableMachineConfigs.isEmpty {
                        ForEach(Array(settings.cableMachineConfigs.keys.sorted()), id: \.self) { exercise in
                            if let config = settings.cableMachineConfigs[exercise] {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(exercise)
                                        Text(config.stackDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Custom")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let keys = Array(settings.cableMachineConfigs.keys.sorted())
                            for index in indexSet {
                                settings.cableMachineConfigs.removeValue(forKey: keys[index])
                            }
                        }
                    }
                } header: {
                    Label("Cable Machines", systemImage: "cable.connector")
                } footer: {
                    Text("Configure plate stacks for your cable machines. Custom configs can be set per-exercise when logging sets.")
                }

                Section {
                    Stepper("Increment: \(Int(settings.dumbbellIncrement)) lbs",
                            value: $settings.dumbbellIncrement,
                            in: 2.5...10,
                            step: 2.5)

                    Stepper("Min Weight: \(Int(settings.dumbbellMinWeight)) lbs",
                            value: $settings.dumbbellMinWeight,
                            in: 0...20,
                            step: 5)

                    Stepper("Max Weight: \(Int(settings.dumbbellMaxWeight)) lbs",
                            value: $settings.dumbbellMaxWeight,
                            in: 50...200,
                            step: 10)
                } header: {
                    Label("Dumbbells", systemImage: "dumbbell")
                } footer: {
                    Text("Set the dumbbell range available at your gym")
                }

                Section {
                    Text("These settings are sent to Claude when generating workouts to ensure only achievable weights are suggested.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Gym Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDefaultCableEditor) {
                CableMachineConfigEditor(
                    config: settings.defaultCableConfig,
                    title: "Default Cable Machine",
                    onSave: { newConfig in
                        settings.defaultCableConfig = newConfig
                    }
                )
            }
        }
    }
}

// MARK: - Cable Machine Config Editor

struct CableMachineConfigEditor: View {
    @State var config: CableMachineConfig
    let title: String
    let onSave: (CableMachineConfig) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($config.plateTiers) { $tier in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Tier \(config.plateTiers.firstIndex(where: { $0.id == tier.id })! + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    TextField("Count", value: $tier.plateCount, format: .number)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                    Text("×")
                                    TextField("Weight", value: $tier.plateWeight, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 70)
                                    Text("lbs")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                config.plateTiers.removeAll { $0.id == tier.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(config.plateTiers.count <= 1)
                        }
                    }

                    Button {
                        config.plateTiers.append(CableMachineConfig.PlateTier(plateWeight: 10.0, plateCount: 10))
                    } label: {
                        Label("Add Plate Tier", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Plate Stack")
                } footer: {
                    Text("Define your machine's weight stack. Add multiple tiers if plates have different weights (e.g., 6×9lb then 12×12.5lb)")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview: \(config.stackDescription)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Available weights:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let weights = config.availableWeights
                        let preview = weights.prefix(15).map { "\(formatWeight($0))" }.joined(separator: ", ")
                        Text(preview + (weights.count > 15 ? "... (\(weights.count) total)" : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Max: \(formatWeight(weights.last ?? 0)) lbs")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(config)
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

struct APIKeyInputView: View {
    @Binding var apiKey: String
    @Environment(\.dismiss) var dismiss
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Enter your API key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your API key is stored locally on your device and is only used to communicate with Anthropic's Claude API.")

                        Link("Get an API key from console.anthropic.com", destination: URL(string: "https://console.anthropic.com")!)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
        }
    }
}

struct EditProfileView: View {
    let profile: UserProfile
    let onSave: (UserProfile) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var fitnessLevel: FitnessLevel
    @State private var selectedGoals: Set<FitnessGoal>
    @State private var selectedEquipment: Set<Equipment>
    @State private var workoutDuration: Int
    @State private var workoutsPerWeek: Int
    @State private var restTime: Int

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave

        _name = State(initialValue: profile.name)
        _fitnessLevel = State(initialValue: profile.fitnessLevel)
        _selectedGoals = State(initialValue: profile.goals)
        _selectedEquipment = State(initialValue: profile.availableEquipment)
        _workoutDuration = State(initialValue: profile.workoutPreferences.preferredWorkoutDuration)
        _workoutsPerWeek = State(initialValue: profile.workoutPreferences.workoutsPerWeek)
        _restTime = State(initialValue: profile.workoutPreferences.preferredRestTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Info") {
                    TextField("Name", text: $name)

                    Picker("Fitness Level", selection: $fitnessLevel) {
                        ForEach(FitnessLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section("Goals") {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        Toggle(goal.rawValue, isOn: Binding(
                            get: { selectedGoals.contains(goal) },
                            set: { isSelected in
                                if isSelected {
                                    selectedGoals.insert(goal)
                                } else {
                                    selectedGoals.remove(goal)
                                }
                            }
                        ))
                    }
                }

                Section("Equipment") {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Toggle(equipment.rawValue, isOn: Binding(
                            get: { selectedEquipment.contains(equipment) },
                            set: { isSelected in
                                if isSelected {
                                    selectedEquipment.insert(equipment)
                                } else {
                                    selectedEquipment.remove(equipment)
                                }
                            }
                        ))
                    }
                }

                Section("Workout Preferences") {
                    Stepper("Duration: \(workoutDuration) min", value: $workoutDuration, in: 15...120, step: 5)
                    Stepper("Per Week: \(workoutsPerWeek)", value: $workoutsPerWeek, in: 1...7)
                    Stepper("Rest Time: \(restTime)s", value: $restTime, in: 30...180, step: 15)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || selectedGoals.isEmpty || selectedEquipment.isEmpty)
                }
            }
        }
    }

    private func saveProfile() {
        let updatedProfile = UserProfile(
            id: profile.id,
            name: name,
            fitnessLevel: fitnessLevel,
            goals: selectedGoals,
            availableEquipment: selectedEquipment,
            workoutPreferences: WorkoutPreferences(
                preferredWorkoutDuration: workoutDuration,
                workoutsPerWeek: workoutsPerWeek,
                preferredRestTime: restTime,
                avoidInjuries: profile.workoutPreferences.avoidInjuries
            ),
            createdAt: profile.createdAt,
            updatedAt: Date()
        )
        onSave(updatedProfile)
    }
}

struct ActiveWorkoutView: View {
    let workout: Workout
    let userProfile: UserProfile?
    let onComplete: (Workout) -> Void
    let onCancel: () -> Void

    @State private var currentWorkout: Workout
    @State private var showCancelConfirmation = false
    @State private var selectedExercise: WorkoutExercise?
    @State private var workoutStartTime: Date
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    // Exercise replacement state
    @State private var exerciseToReplace: WorkoutExercise?
    @State private var showReplacementSheet = false
    @State private var replacementNotes: String = ""
    @State private var isReplacingExercise = false
    @State private var replacementError: String?
    @State private var showReplacementError = false

    // Add exercise state
    @State private var showAddExerciseSheet = false

    init(workout: Workout, userProfile: UserProfile?, onComplete: @escaping (Workout) -> Void, onCancel: @escaping () -> Void) {
        self.workout = workout
        self.userProfile = userProfile
        self.onComplete = onComplete
        self.onCancel = onCancel
        _currentWorkout = State(initialValue: workout)
        _workoutStartTime = State(initialValue: workout.startedAt ?? Date())
    }

    var completedExercisesCount: Int {
        currentWorkout.exercises.filter { $0.isCompleted }.count
    }

    var allExercisesCompleted: Bool {
        currentWorkout.exercises.allSatisfy { $0.isCompleted }
    }

    @ObservedObject private var restTimerManager = RestTimerManager.shared

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Timer header
                WorkoutTimerHeader(
                    elapsedTime: elapsedTime,
                    completedCount: completedExercisesCount,
                    totalCount: currentWorkout.exercises.count
                )

                // Global rest timer (visible when timer is active)
                if restTimerManager.isActive {
                    GlobalRestTimerBar()
                }

                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(currentWorkout.exercises.indices, id: \.self) { index in
                            ActiveExerciseCard(
                                exercise: currentWorkout.exercises[index],
                                onTap: {
                                    selectedExercise = currentWorkout.exercises[index]
                                },
                                onReplace: {
                                    exerciseToReplace = currentWorkout.exercises[index]
                                    replacementNotes = ""
                                    showReplacementSheet = true
                                }
                            )
                        }

                        // Add Exercise button
                        Button {
                            showAddExerciseSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Add Exercise")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundStyle(.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }

                // Finish button
                VStack {
                    Button {
                        finishWorkout()
                    } label: {
                        HStack {
                            Image(systemName: allExercisesCompleted ? "checkmark.circle.fill" : "flag.checkered")
                            Text(allExercisesCompleted ? "Complete Workout" : "Finish Early")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(allExercisesCompleted ? .green : .blue)
                }
                .padding()
                .background(Color(.systemBackground))
            }

            // Rest complete banner overlay
            if restTimerManager.showCompletionBanner {
                RestCompleteBanner()
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showCancelConfirmation = true
                }
                .foregroundStyle(.red)
            }
        }
        .confirmationDialog("Cancel Workout?", isPresented: $showCancelConfirmation) {
            Button("Cancel Workout", role: .destructive) {
                stopTimer()
                onCancel()
            }
            Button("Keep Going", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel this workout? Your progress will be lost.")
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailSheet(
                exercise: exercise,
                onUpdate: { updatedExercise in
                    updateExercise(updatedExercise)
                }
            )
        }
        .sheet(isPresented: $showReplacementSheet) {
            ExerciseReplacementSheet(
                exercise: exerciseToReplace,
                notes: $replacementNotes,
                isLoading: $isReplacingExercise,
                onReplace: {
                    replaceExercise()
                },
                onCancel: {
                    showReplacementSheet = false
                    exerciseToReplace = nil
                }
            )
        }
        .alert("Replacement Error", isPresented: $showReplacementError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(replacementError ?? "Failed to replace exercise")
        }
        .sheet(isPresented: $showAddExerciseSheet) {
            AddExerciseSheet(
                existingExercises: currentWorkout.exercises.map { $0.exercise.name },
                userProfile: userProfile,
                onAdd: { newExercise in
                    addExercise(newExercise)
                }
            )
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func addExercise(_ exercise: WorkoutExercise) {
        var newExercise = exercise
        newExercise.orderIndex = currentWorkout.exercises.count
        currentWorkout.exercises.append(newExercise)
    }

    private func startTimer() {
        elapsedTime = Date().timeIntervalSince(workoutStartTime)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(workoutStartTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateExercise(_ updatedExercise: WorkoutExercise) {
        if let index = currentWorkout.exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            currentWorkout.exercises[index] = updatedExercise
        }
        selectedExercise = nil
    }

    private func replaceExercise() {
        guard let exerciseToReplace = exerciseToReplace,
              let profile = userProfile else { return }

        isReplacingExercise = true

        Task {
            do {
                let replacement = try await AnthropicService.shared.replaceExercise(
                    exercise: exerciseToReplace,
                    profile: profile,
                    reason: replacementNotes.isEmpty ? nil : replacementNotes,
                    currentWorkout: currentWorkout
                )

                await MainActor.run {
                    if let index = currentWorkout.exercises.firstIndex(where: { $0.id == exerciseToReplace.id }) {
                        currentWorkout.exercises[index] = replacement
                    }
                    isReplacingExercise = false
                    showReplacementSheet = false
                    self.exerciseToReplace = nil
                }
            } catch {
                await MainActor.run {
                    replacementError = error.localizedDescription
                    showReplacementError = true
                    isReplacingExercise = false
                }
            }
        }
    }

    private func finishWorkout() {
        stopTimer()
        var completedWorkout = currentWorkout
        completedWorkout.completedAt = Date()
        WorkoutDataManager.shared.saveWorkout(completedWorkout)
        onComplete(completedWorkout)
    }
}

// MARK: - Workout Timer Header

struct WorkoutTimerHeader: View {
    let elapsedTime: TimeInterval
    let completedCount: Int
    let totalCount: Int

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
    }
}

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    let exercise: WorkoutExercise
    let onTap: () -> Void
    let onReplace: () -> Void

    var completedSetsCount: Int {
        exercise.sets.filter { $0.isCompleted }.count
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Completion indicator
                ZStack {
                    Circle()
                        .stroke(exercise.isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)

                    if exercise.isCompleted {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .fontWeight(.bold)
                    } else {
                        Text("\(completedSetsCount)/\(exercise.sets.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exercise.name)
                        .font(.headline)
                        .foregroundStyle(exercise.isCompleted ? .secondary : .primary)

                    HStack {
                        Label("\(exercise.sets.count) sets", systemImage: "repeat")
                        Text("•")
                        Label("\(exercise.sets.first?.targetReps ?? 0) reps", systemImage: "number")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Replace button
                Menu {
                    Button {
                        onReplace()
                    } label: {
                        Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(exercise.isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(exercise.isCompleted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Detail Sheet

struct ExerciseDetailSheet: View {
    let exercise: WorkoutExercise
    let onUpdate: (WorkoutExercise) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var updatedExercise: WorkoutExercise

    init(exercise: WorkoutExercise, onUpdate: @escaping (WorkoutExercise) -> Void) {
        self.exercise = exercise
        self.onUpdate = onUpdate
        _updatedExercise = State(initialValue: exercise)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Exercise header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.exercise.name)
                            .font(.title)
                            .fontWeight(.bold)

                        if !exercise.exercise.primaryMuscleGroups.isEmpty {
                            Text(exercise.exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Video demonstration
                    if let videoID = exercise.exercise.youtubeVideoID {
                        YouTubeVideoView(videoID: videoID)
                            .padding(.horizontal)
                    }

                    // Form tips if available
                    if !exercise.exercise.formTips.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Form Tips", systemImage: "lightbulb")
                                .font(.headline)
                            Text(exercise.exercise.formTips)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Sets
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Sets")
                                .font(.headline)
                            Spacer()
                            Text("Set 1 changes apply to all sets")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        ForEach(updatedExercise.sets.indices, id: \.self) { setIndex in
                            HStack(alignment: .top, spacing: 8) {
                                SetRowView(
                                    set: updatedExercise.sets[setIndex],
                                    exerciseName: exercise.exercise.name,
                                    equipment: exercise.exercise.equipment,
                                    onUpdate: { updatedSet in
                                        updatedExercise.sets[setIndex] = updatedSet
                                    },
                                    onWeightChanged: setIndex == 0 ? { newWeight in
                                        // Propagate weight to all subsequent sets that haven't been completed
                                        for i in 1..<updatedExercise.sets.count {
                                            if !updatedExercise.sets[i].isCompleted {
                                                updatedExercise.sets[i].weight = newWeight
                                            }
                                        }
                                    } : nil,
                                    onRepsChanged: setIndex == 0 ? { newReps in
                                        // Propagate reps to all subsequent sets that haven't been completed
                                        for i in 1..<updatedExercise.sets.count {
                                            if !updatedExercise.sets[i].isCompleted {
                                                updatedExercise.sets[i].actualReps = newReps
                                            }
                                        }
                                    } : nil
                                )

                                // Delete set button (only show if more than 1 set)
                                if updatedExercise.sets.count > 1 {
                                    Button {
                                        removeSet(at: setIndex)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.title3)
                                    }
                                    .padding(.top, 12)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Add set button
                        Button {
                            addSet()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Set")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }

                    // Notes
                    if !exercise.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "note.text")
                                .font(.headline)
                            Text(exercise.notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Log Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onUpdate(updatedExercise)
                        dismiss()
                    }
                }
            }
        }
    }

    private func addSet() {
        // Create a new set based on the last set's values
        let lastSet = updatedExercise.sets.last
        let newSetNumber = updatedExercise.sets.count + 1
        let newSet = ExerciseSet(
            setNumber: newSetNumber,
            targetReps: lastSet?.targetReps ?? 10,
            actualReps: nil,
            weight: lastSet?.weight,
            restPeriod: lastSet?.restPeriod ?? 90
        )
        updatedExercise.sets.append(newSet)
    }

    private func removeSet(at index: Int) {
        guard updatedExercise.sets.count > 1 else { return }
        updatedExercise.sets.remove(at: index)
        // Renumber the remaining sets
        for i in 0..<updatedExercise.sets.count {
            updatedExercise.sets[i].setNumber = i + 1
        }
    }
}

// MARK: - Exercise Replacement Sheet

struct ExerciseReplacementSheet: View {
    let exercise: WorkoutExercise?
    @Binding var notes: String
    @Binding var isLoading: Bool
    let onReplace: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let exercise = exercise {
                    Section {
                        HStack {
                            Text("Current Exercise")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(exercise.exercise.name)
                                .fontWeight(.medium)
                        }
                    }
                }

                Section {
                    TextField("Why do you need a replacement?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Reason (Optional)")
                } footer: {
                    Text("Examples:\n• \"My shoulder hurts\"\n• \"The machine is being used\"\n• \"I want something easier/harder\"")
                }
            }
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onReplace()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Replace")
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseSheet: View {
    let existingExercises: [String]
    let userProfile: UserProfile?
    let onAdd: (WorkoutExercise) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var selectedEquipment: Equipment?

    // Custom exercise state
    @State private var customPrompt = ""
    @State private var isGenerating = false
    @State private var generationError: String?

    @ObservedObject private var customExercises = CustomExerciseStore.shared

    var filteredExercises: [Exercise] {
        var results = ExerciseDatabase.shared.exercises + customExercises.exercises

        // Filter out exercises already in workout
        results = results.filter { !existingExercises.contains($0.name) }

        if !searchText.isEmpty {
            results = results.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        if let muscleGroup = selectedMuscleGroup {
            results = results.filter {
                $0.primaryMuscleGroups.contains(muscleGroup) ||
                $0.secondaryMuscleGroups.contains(muscleGroup)
            }
        }

        if let equipment = selectedEquipment {
            results = results.filter { $0.equipment == equipment }
        }

        return results.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Source", selection: $selectedTab) {
                    Text("Library").tag(0)
                    Text("Custom").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    // Exercise Library
                    VStack(spacing: 0) {
                        // Filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Menu {
                                    Button("All Muscles") { selectedMuscleGroup = nil }
                                    Divider()
                                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                                        Button(muscle.rawValue) { selectedMuscleGroup = muscle }
                                    }
                                } label: {
                                    FilterChip(
                                        title: selectedMuscleGroup?.rawValue ?? "Muscle",
                                        isActive: selectedMuscleGroup != nil
                                    )
                                }

                                Menu {
                                    Button("All Equipment") { selectedEquipment = nil }
                                    Divider()
                                    ForEach(Equipment.allCases, id: \.self) { equip in
                                        Button(equip.rawValue) { selectedEquipment = equip }
                                    }
                                } label: {
                                    FilterChip(
                                        title: selectedEquipment?.rawValue ?? "Equipment",
                                        isActive: selectedEquipment != nil
                                    )
                                }

                                if selectedMuscleGroup != nil || selectedEquipment != nil {
                                    Button {
                                        selectedMuscleGroup = nil
                                        selectedEquipment = nil
                                    } label: {
                                        Text("Clear")
                                            .font(.subheadline)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .background(Color(.systemGroupedBackground))

                        // Exercise list
                        List(filteredExercises) { exercise in
                            Button {
                                addExerciseFromLibrary(exercise)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(exercise.name)
                                                .fontWeight(.medium)
                                            if exercise.isCustom {
                                                Text("Custom")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple)
                                                    .foregroundStyle(.white)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Text("\(exercise.equipment.rawValue) • \(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title2)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                        .listStyle(.plain)
                    }
                    .searchable(text: $searchText, prompt: "Search exercises")
                } else {
                    // Custom exercise generator
                    Form {
                        Section {
                            TextField("Describe the exercise you want...", text: $customPrompt, axis: .vertical)
                                .lineLimit(3...6)
                        } header: {
                            Text("Describe Your Exercise")
                        } footer: {
                            Text("Examples:\n• \"A chest exercise using only resistance bands\"\n• \"An ab exercise I can do at home\"\n• \"A rear delt exercise on the cable machine\"")
                        }

                        Section {
                            Button {
                                generateCustomExercise()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isGenerating {
                                        ProgressView()
                                            .padding(.trailing, 8)
                                        Text("Generating...")
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("Generate with Claude")
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(customPrompt.isEmpty || isGenerating)
                        }

                        if let error = generationError {
                            Section {
                                Text(error)
                                    .foregroundStyle(.red)
                            }
                        }

                        // Show custom exercises
                        if !customExercises.exercises.isEmpty {
                            Section {
                                ForEach(customExercises.exercises) { exercise in
                                    Button {
                                        addExerciseFromLibrary(exercise)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(exercise.name)
                                                    .fontWeight(.medium)
                                                Text(exercise.equipment.rawValue)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.title2)
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                                .onDelete { indexSet in
                                    customExercises.exercises.remove(atOffsets: indexSet)
                                }
                            } header: {
                                Text("Your Custom Exercises")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addExerciseFromLibrary(_ exercise: Exercise) {
        let sets = (1...3).map { setNum in
            ExerciseSet(
                setNumber: setNum,
                targetReps: 10,
                restPeriod: 90
            )
        }

        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            sets: sets,
            orderIndex: 0,
            notes: ""
        )

        onAdd(workoutExercise)
        dismiss()
    }

    private func generateCustomExercise() {
        guard !customPrompt.isEmpty else { return }

        isGenerating = true
        generationError = nil

        // Use active gym profile's equipment if available
        let availableEquipment: Set<Equipment>
        if let gymProfile = GymProfileManager.shared.activeProfile {
            availableEquipment = gymProfile.availableEquipment
        } else {
            availableEquipment = userProfile?.availableEquipment ?? Set(Equipment.allCases)
        }

        Task {
            do {
                let exercise = try await AnthropicService.shared.generateCustomExercise(
                    prompt: customPrompt,
                    availableEquipment: availableEquipment
                )

                await MainActor.run {
                    customExercises.addExercise(exercise)
                    addExerciseFromLibrary(exercise)
                }
            } catch {
                await MainActor.run {
                    generationError = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Custom Exercise Store

class CustomExerciseStore: ObservableObject {
    static let shared = CustomExerciseStore()

    @Published var exercises: [Exercise] = [] {
        didSet { save() }
    }

    private init() {
        load()
    }

    func addExercise(_ exercise: Exercise) {
        var customExercise = exercise
        customExercise.isCustom = true
        exercises.append(customExercise)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: "customExercises")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "customExercises"),
           let saved = try? JSONDecoder().decode([Exercise].self, from: data) {
            exercises = saved
        }
    }
}

struct SetRowView: View {
    let set: ExerciseSet
    let exerciseName: String
    let equipment: Equipment
    let onUpdate: (ExerciseSet) -> Void
    let onWeightChanged: ((Double) -> Void)?  // Callback when weight changes on set 1
    let onRepsChanged: ((Int) -> Void)?  // Callback when reps change on set 1

    @State private var weight: String
    @State private var reps: String
    @State private var isCompleted: Bool
    @State private var showPlateCalculator: Bool = false
    @ObservedObject private var restTimerManager = RestTimerManager.shared

    init(
        set: ExerciseSet,
        exerciseName: String,
        equipment: Equipment = .dumbbells,
        onUpdate: @escaping (ExerciseSet) -> Void,
        onWeightChanged: ((Double) -> Void)? = nil,
        onRepsChanged: ((Int) -> Void)? = nil
    ) {
        self.set = set
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.onUpdate = onUpdate
        self.onWeightChanged = onWeightChanged
        self.onRepsChanged = onRepsChanged

        // Get suggested weight from history if available
        let suggestedWeight = WorkoutDataManager.shared.getSuggestedWeight(
            for: exerciseName,
            targetReps: set.targetReps
        )

        _weight = State(initialValue: set.weight.map { String(format: "%.0f", $0) } ?? suggestedWeight.map { String(format: "%.0f", $0) } ?? "")
        _reps = State(initialValue: set.actualReps.map { String($0) } ?? String(set.targetReps))
        _isCompleted = State(initialValue: set.isCompleted)
    }

    /// Check if rest timer is active for THIS specific set
    private var isRestTimerActiveForThisSet: Bool {
        restTimerManager.isActive &&
        restTimerManager.exerciseName == exerciseName &&
        restTimerManager.setNumber == set.setNumber
    }

    private var showPlateCalcButton: Bool {
        switch equipment {
        case .barbell, .squat, .legPress, .smithMachine:
            return true  // Plate-loaded equipment
        case .cables:
            return true  // Cable machine weight selector
        default:
            return false
        }
    }

    /// Whether this equipment uses standard plates (vs cable weight stack)
    private var usesPlates: Bool {
        switch equipment {
        case .barbell, .squat, .legPress, .smithMachine:
            return true
        default:
            return false
        }
    }

    /// Check if current weight is valid for cable machine
    private var isInvalidCableWeight: Bool {
        guard equipment == .cables, let weightValue = Double(weight), weightValue > 0 else {
            return false
        }
        let config = GymSettings.shared.cableConfig(for: exerciseName)
        return !config.isValidWeight(weightValue)
    }

    /// Get pin location for current weight (cable machines only)
    private var currentPinLocation: Int? {
        guard equipment == .cables, let weightValue = Double(weight), weightValue > 0 else {
            return nil
        }
        let config = GymSettings.shared.cableConfig(for: exerciseName)
        return config.pinLocation(for: weightValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Set number
                Text("Set \(set.setNumber)")
                    .font(.headline)
                    .frame(width: 50, alignment: .leading)

                // Weight input
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isInvalidCableWeight ? Color.orange : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: weight) { _, newValue in
                                if let weightValue = Double(newValue), set.setNumber == 1 {
                                    onWeightChanged?(weightValue)
                                }
                            }
                        Text("lbs")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Plate calculator button for plate-loaded and cable exercises
                        if showPlateCalcButton {
                            Button {
                                showPlateCalculator = true
                            } label: {
                                Image(systemName: usesPlates ? "circle.grid.2x2" : "slider.horizontal.3")
                                    .font(.caption)
                                    .foregroundStyle(isInvalidCableWeight ? .orange : .blue)
                            }
                        }
                    }

                    // Show pin location for valid cable weights
                    if let pin = currentPinLocation {
                        HStack(spacing: 2) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                            Text("Pin \(pin)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.blue)
                    }

                    // Show invalid weight warning for cables
                    if isInvalidCableWeight {
                        Button {
                            showPlateCalculator = true
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text("Invalid weight - tap to fix")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.orange)
                        }
                    }

                    // Show if this is a suggested weight from history
                    if let suggestedWeight = WorkoutDataManager.shared.getSuggestedWeight(
                        for: exerciseName,
                        targetReps: set.targetReps
                    ), !weight.isEmpty, Double(weight) == suggestedWeight {
                        Text("↑ +2.5%")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                // Reps input
                HStack(spacing: 4) {
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .onChange(of: reps) { _, newValue in
                            if let repsValue = Int(newValue), set.setNumber == 1 {
                                onRepsChanged?(repsValue)
                            }
                        }
                    Text("× \(set.targetReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Complete button
                Button {
                    markComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isCompleted ? .green : .gray)
                }
            }
            .padding()
            .background(isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground))

            // Rest timer appears inline after completing a set (only for this specific set)
            if isRestTimerActiveForThisSet {
                RestTimerView(
                    duration: restTimerManager.remainingTime,
                    onComplete: {
                        // Handled by RestTimerManager
                    },
                    onSkip: {
                        restTimerManager.skipTimer()
                    }
                )
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRestTimerActiveForThisSet ? Color.blue : (isCompleted ? Color.green : Color.gray.opacity(0.3)), lineWidth: isRestTimerActiveForThisSet ? 2 : 1)
        )
        .sheet(isPresented: $showPlateCalculator) {
            if usesPlates {
                PlateCalculatorView(
                    totalWeight: Double(weight) ?? 0,
                    equipment: equipment,
                    exerciseName: exerciseName
                )
            } else {
                CableWeightCalculatorView(
                    targetWeight: Double(weight) ?? 0,
                    exerciseName: exerciseName,
                    onSelectWeight: { selectedWeight in
                        weight = String(format: "%.0f", selectedWeight)
                        showPlateCalculator = false
                    }
                )
            }
        }
        .onChange(of: set.weight) { _, newWeight in
            // Update local state when external weight changes (propagation from set 1)
            if let newWeight = newWeight {
                weight = String(format: "%.0f", newWeight)
            }
        }
        .onChange(of: set.actualReps) { _, newReps in
            // Update local state when external reps changes (propagation from set 1)
            if let newReps = newReps {
                reps = String(newReps)
            }
        }
    }

    private func markComplete() {
        var updatedSet = set

        if !isCompleted {
            // Mark as complete
            if let weightValue = Double(weight) {
                updatedSet.weight = weightValue
            }
            if let repsValue = Int(reps) {
                updatedSet.actualReps = repsValue
            }
            updatedSet.completedAt = Date()

            // Start global rest timer
            restTimerManager.startTimer(
                duration: set.restPeriod,
                exerciseName: exerciseName,
                setNumber: set.setNumber
            )
        } else {
            // Unmark
            updatedSet.completedAt = nil
            // Stop rest timer if it was for this set
            if isRestTimerActiveForThisSet {
                restTimerManager.stopTimer()
            }
        }

        isCompleted.toggle()
        onUpdate(updatedSet)
    }
}

// MARK: - Plate Calculator View

struct PlateCalculatorView: View {
    let totalWeight: Double
    let equipment: Equipment
    let exerciseName: String

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var showingPlateEditor = false

    /// Whether this equipment has a bar (vs leg press sled)
    private var hasBar: Bool {
        switch equipment {
        case .legPress:
            return false
        default:
            return true
        }
    }

    private var barWeight: Double {
        hasBar ? settings.selectedBarWeight : 0
    }

    private var equipmentLabel: String {
        switch equipment {
        case .legPress:
            return "Leg Press"
        case .smithMachine:
            return "Smith Machine"
        case .squat:
            return "Squat Rack"
        default:
            return "Barbell"
        }
    }

    private var weightPerSide: Double {
        max(0, (totalWeight - barWeight) / 2)
    }

    private var currentPlates: [Double] {
        settings.availablePlates(for: exerciseName)
    }

    private var platesNeeded: [(Double, Int)] {
        var remaining = weightPerSide
        var plates: [(Double, Int)] = []

        for plateSize in currentPlates {
            let count = Int(remaining / plateSize)
            if count > 0 {
                plates.append((plateSize, count))
                remaining -= Double(count) * plateSize
            }
        }

        return plates
    }

    private var isValidWeight: Bool {
        var remaining = weightPerSide
        for plateSize in currentPlates {
            let count = Int(remaining / plateSize)
            remaining -= Double(count) * plateSize
        }
        return remaining < 0.01
    }

    private var hasCustomConfig: Bool {
        settings.hasCustomPlateConfig(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Total weight display
                    VStack(spacing: 8) {
                        Text("Total Weight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(totalWeight)) lbs")
                            .font(.system(size: 48, weight: .bold))

                        Text(equipmentLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if hasCustomConfig {
                            Text("Custom plates for \(exerciseName)")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.top)

                    // Bar weight selector (only for barbell exercises)
                    if hasBar {
                        VStack(spacing: 8) {
                            Text("Bar Weight")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Picker("Bar Weight", selection: $settings.selectedBarWeight) {
                                Text("45 lbs").tag(45.0)
                                Text("35 lbs").tag(35.0)
                                Text("20 lbs").tag(20.0)
                                Text("15 lbs").tag(15.0)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }
                    }

                    Divider()

                    // Weight per side
                    VStack(spacing: 8) {
                        Text("Each Side")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.1f", weightPerSide)) lbs")
                            .font(.title)
                            .fontWeight(.semibold)
                    }

                    // Plate breakdown
                    if weightPerSide == 0 {
                        Text(hasBar ? "Bar only - no plates needed" : "No plates needed")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Plates per side:")
                                .font(.headline)

                            ForEach(platesNeeded, id: \.0) { plate, count in
                                HStack {
                                    PlateVisual(weight: plate)
                                    Spacer()
                                    Text("\(formatWeight(plate)) lbs")
                                        .fontWeight(.medium)
                                    Text("× \(count)")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    if !isValidWeight && weightPerSide > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Cannot achieve exact weight with available plates")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // Available plates section
                    Button {
                        showingPlateEditor = true
                    } label: {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Available Plates")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if hasCustomConfig {
                                            Text("(Custom)")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    Text(currentPlates.map { formatWeight($0) }.joined(separator: ", ") + " lbs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }

                            Text("Tap to customize plates for this exercise")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPlateEditor) {
                AvailablePlatesEditor(exerciseName: exerciseName)
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

/// Editor for customizing available plate sizes (per-exercise)
struct AvailablePlatesEditor: View {
    let exerciseName: String

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var newPlateWeight: String = ""
    @State private var localPlates: [Double] = []

    private var hasCustomConfig: Bool {
        settings.hasCustomPlateConfig(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(.blue)
                        Text(exerciseName)
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("Exercise")
                } footer: {
                    if hasCustomConfig {
                        Text("This exercise has custom plate settings")
                    } else {
                        Text("Using default plate settings")
                    }
                }

                Section {
                    ForEach(localPlates, id: \.self) { plate in
                        HStack {
                            PlateVisual(weight: plate)
                            Text("\(formatWeight(plate)) lbs")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        localPlates.remove(atOffsets: indexSet)
                        saveChanges()
                    }
                } header: {
                    Text("Available Plates")
                } footer: {
                    Text("Swipe left to remove a plate size")
                }

                Section {
                    HStack {
                        TextField("Weight (lbs)", text: $newPlateWeight)
                            .keyboardType(.decimalPad)

                        Button {
                            addPlate()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                        .disabled(newPlateWeight.isEmpty)
                    }
                } header: {
                    Text("Add Plate")
                } footer: {
                    Text("Add custom plate sizes available for this exercise (e.g., 100, 35)")
                }

                Section {
                    if hasCustomConfig {
                        Button("Use Default Plates") {
                            settings.resetPlateConfig(for: exerciseName)
                            localPlates = settings.defaultAvailablePlates
                        }
                        .foregroundStyle(.blue)
                    }

                    Button("Reset to Standard Plates") {
                        localPlates = GymSettings.standardPlates
                        saveChanges()
                    }
                    .foregroundStyle(.orange)
                } footer: {
                    Text("Standard: 45, 35, 25, 10, 5, 2.5 lbs")
                }
            }
            .navigationTitle("Available Plates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                localPlates = settings.availablePlates(for: exerciseName)
            }
        }
    }

    private func addPlate() {
        guard let weight = Double(newPlateWeight), weight > 0 else { return }

        if !localPlates.contains(weight) {
            localPlates.append(weight)
            localPlates.sort(by: >)
            saveChanges()
        }
        newPlateWeight = ""
    }

    private func saveChanges() {
        settings.setAvailablePlates(localPlates, for: exerciseName)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

struct PlateVisual: View {
    let weight: Double

    private var plateColor: Color {
        switch weight {
        case 100: return .purple
        case 45: return .red
        case 35: return .blue
        case 25: return .green
        case 10: return .yellow
        case 5: return .orange
        case 2.5: return .gray
        default:
            // Custom plates get a color based on weight range
            if weight >= 50 { return .purple }
            else if weight >= 30 { return .blue }
            else if weight >= 15 { return .green }
            else if weight >= 7 { return .yellow }
            else { return .orange }
        }
    }

    private var plateHeight: CGFloat {
        // Scale height based on weight
        let minHeight: CGFloat = 14
        let maxHeight: CGFloat = 44
        let heightRange = maxHeight - minHeight

        // Log scale for better visual representation
        let normalizedWeight = min(max(weight, 1), 100)
        let logScale = log10(normalizedWeight) / log10(100)

        return minHeight + (heightRange * logScale)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(plateColor)
            .frame(width: 12, height: plateHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Cable Weight Calculator View

struct CableWeightCalculatorView: View {
    let targetWeight: Double
    let exerciseName: String
    let onSelectWeight: (Double) -> Void
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = GymSettings.shared
    @State private var showingConfigEditor = false

    private var config: CableMachineConfig {
        settings.cableConfig(for: exerciseName)
    }

    private var availableWeights: [Double] {
        config.availableWeights
    }

    private var nearestWeight: Double {
        config.nearestWeight(to: targetWeight)
    }

    private var weightsNearTarget: [Double] {
        config.weightsNear(targetWeight, count: 7)
    }

    private var hasCustomConfig: Bool {
        settings.cableMachineConfigs[exerciseName] != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current target
                    VStack(spacing: 4) {
                        Text("Target Weight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Int(targetWeight)) lbs")
                            .font(.system(size: 48, weight: .bold))
                    }
                    .padding(.top)

                    // Cable machine config info
                    Button {
                        showingConfigEditor = true
                    } label: {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(hasCustomConfig ? exerciseName : "Default Cable Machine")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if hasCustomConfig {
                                            Text("Custom")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue)
                                                .foregroundStyle(.white)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(config.stackDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }

                            Text("Tap to configure plate stack for this exercise")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Divider()

                    // Available weights grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Weight")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(weightsNearTarget, id: \.self) { weight in
                                Button {
                                    onSelectWeight(weight)
                                } label: {
                                    CableWeightButton(
                                        weight: weight,
                                        pinNumber: config.pinLocation(for: weight),
                                        isSelected: weight == nearestWeight
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)

                        // Show more weights option
                        if availableWeights.count > 7 {
                            DisclosureGroup("All available weights (\(availableWeights.count))") {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(availableWeights, id: \.self) { weight in
                                        Button {
                                            onSelectWeight(weight)
                                        } label: {
                                            Text("\(formatWeight(weight))")
                                                .font(.caption)
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Cable Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingConfigEditor) {
                CableMachineConfigEditor(
                    config: config,
                    title: exerciseName,
                    onSave: { newConfig in
                        settings.setCableConfig(newConfig, for: exerciseName)
                    }
                )
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

/// Button showing weight with pin location indicator
struct CableWeightButton: View {
    let weight: Double
    let pinNumber: Int?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(formatWeight(weight))")
                .font(.title3)
                .fontWeight(.semibold)
            Text("lbs")
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)

            // Pin location indicator
            if let pin = pinNumber {
                HStack(spacing: 2) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                    Text("Pin \(pin)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .blue)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isSelected ? Color.blue : Color(.systemGray6))
        .foregroundStyle(isSelected ? .white : .primary)
        .cornerRadius(12)
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

struct WeightOptionRow: View {
    let weight: Double
    let label: String
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(Int(weight)) lbs")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.gray)
                    .font(.title2)
            }
        }
        .padding()
        .background(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Rest Timer View

struct RestTimerView: View {
    let duration: TimeInterval
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var remainingTime: TimeInterval
    @State private var timer: Timer?
    @State private var isRunning: Bool = true

    init(duration: TimeInterval, onComplete: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.duration = duration
        self.onComplete = onComplete
        self.onSkip = onSkip
        _remainingTime = State(initialValue: duration)
    }

    var progress: Double {
        1 - (remainingTime / duration)
    }

    var formattedTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Timer circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(formattedTime)
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest Time")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(remainingTime > 0 ? "Take a breather..." : "Ready for next set!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Control buttons
            HStack(spacing: 12) {
                Button {
                    addTime(30)
                } label: {
                    Text("+30s")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    skipTimer()
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
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                stopTimer()
                onComplete()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func addTime(_ seconds: TimeInterval) {
        remainingTime += seconds
    }

    private func skipTimer() {
        stopTimer()
        onSkip()
    }
}

// MARK: - Global Rest Timer Bar

/// Compact rest timer bar shown at the top of the workout overview
struct GlobalRestTimerBar: View {
    @ObservedObject private var timerManager = RestTimerManager.shared

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

            // Time remaining
            Text(timerManager.formattedTime)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(.blue)

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
                    .frame(width: geometry.size.width * timerManager.progress)
            }
            .allowsHitTesting(false)
        )
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

// MARK: - Export Data Helper

struct ExportData: Identifiable {
    let id = UUID()
    let content: String
    let filename: String

    var temporaryFileURL: URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write export file: \(error)")
            return nil
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Add Historical Workout View

struct AddHistoricalWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    var onSave: () -> Void

    @State private var workoutName = ""
    @State private var workoutDate = Date()
    @State private var workoutDuration: TimeInterval = 3600 // 1 hour default
    @State private var exercises: [WorkoutExercise] = []
    @State private var notes = ""
    @State private var isDeload = false
    @State private var showingExerciseSelector = false
    @State private var editingExerciseIndex: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $workoutName)

                    DatePicker("Date", selection: $workoutDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("", selection: $workoutDuration) {
                            Text("30 min").tag(TimeInterval(1800))
                            Text("45 min").tag(TimeInterval(2700))
                            Text("1 hour").tag(TimeInterval(3600))
                            Text("1.5 hours").tag(TimeInterval(5400))
                            Text("2 hours").tag(TimeInterval(7200))
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle(isOn: $isDeload) {
                        HStack {
                            Image(systemName: "arrow.down.heart")
                                .foregroundStyle(.green)
                            Text("Deload Workout")
                        }
                    }
                }

                Section {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            editingExerciseIndex = index
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.exercise.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    let completedSets = exercise.sets.filter { $0.actualReps != nil }
                                    if completedSets.isEmpty {
                                        Text("No sets recorded")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(completedSets.map { set in
                                            if let weight = set.weight {
                                                return "\(Int(weight))x\(set.actualReps ?? set.targetReps)"
                                            } else {
                                                return "\(set.actualReps ?? set.targetReps) reps"
                                            }
                                        }.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteExercise)
                    .onMove(perform: moveExercise)

                    Button {
                        showingExerciseSelector = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    if exercises.isEmpty {
                        Text("Add exercises to record your workout")
                    }
                }

                Section("Notes") {
                    TextField("Optional notes about this workout", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .disabled(workoutName.isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingExerciseSelector) {
                ExerciseSelectorView { exercise in
                    let workoutExercise = WorkoutExercise(
                        exercise: exercise,
                        sets: [
                            ExerciseSet(setNumber: 1, targetReps: 10),
                            ExerciseSet(setNumber: 2, targetReps: 10),
                            ExerciseSet(setNumber: 3, targetReps: 10)
                        ],
                        orderIndex: exercises.count
                    )
                    exercises.append(workoutExercise)
                    editingExerciseIndex = exercises.count - 1
                }
            }
            .sheet(item: $editingExerciseIndex) { index in
                EditHistoricalExerciseView(exercise: $exercises[index])
            }
        }
    }

    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        // Update order indices
        for i in 0..<exercises.count {
            exercises[i].orderIndex = i
        }
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
        // Update order indices
        for i in 0..<exercises.count {
            exercises[i].orderIndex = i
        }
    }

    private func saveWorkout() {
        let startTime = workoutDate.addingTimeInterval(-workoutDuration)

        // Mark all sets as completed
        var completedExercises = exercises
        for i in 0..<completedExercises.count {
            for j in 0..<completedExercises[i].sets.count {
                if completedExercises[i].sets[j].actualReps == nil {
                    completedExercises[i].sets[j].actualReps = completedExercises[i].sets[j].targetReps
                }
                completedExercises[i].sets[j].completedAt = workoutDate
            }
        }

        let workout = Workout(
            name: workoutName,
            exercises: completedExercises,
            createdAt: workoutDate,
            startedAt: startTime,
            completedAt: workoutDate,
            notes: notes,
            isDeload: isDeload
        )

        WorkoutDataManager.shared.saveWorkout(workout)
        onSave()
        dismiss()
    }
}

// MARK: - Exercise Selector View

struct ExerciseSelectorView: View {
    @Environment(\.dismiss) var dismiss
    var onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?

    var filteredExercises: [Exercise] {
        var exercises = ExerciseDatabase.shared.exercises

        if let muscleGroup = selectedMuscleGroup {
            exercises = exercises.filter { $0.primaryMuscleGroups.contains(muscleGroup) }
        }

        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return exercises.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Muscle group filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedMuscleGroup = nil
                        } label: {
                            Text("All")
                                .font(.subheadline)
                                .fontWeight(selectedMuscleGroup == nil ? .semibold : .regular)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedMuscleGroup == nil ? Color.blue : Color(.systemGray5))
                                .foregroundStyle(selectedMuscleGroup == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }

                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Button {
                                selectedMuscleGroup = group
                            } label: {
                                Text(group.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedMuscleGroup == group ? .semibold : .regular)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedMuscleGroup == group ? Color.blue : Color(.systemGray5))
                                    .foregroundStyle(selectedMuscleGroup == group ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                List(filteredExercises) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            HStack {
                                Text(exercise.equipment.rawValue)
                                Text("•")
                                Text(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Historical Exercise View

struct EditHistoricalExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var exercise: WorkoutExercise

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(exercise.exercise.name)
                            .font(.headline)
                        Spacer()
                        Text(exercise.exercise.equipment.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sets") {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        HistoricalSetRow(
                            setNumber: set.setNumber,
                            weight: Binding(
                                get: { exercise.sets[index].weight },
                                set: { exercise.sets[index].weight = $0 }
                            ),
                            reps: Binding(
                                get: { exercise.sets[index].actualReps ?? exercise.sets[index].targetReps },
                                set: { exercise.sets[index].actualReps = $0 }
                            )
                        )
                    }
                    .onDelete(perform: deleteSet)

                    Button {
                        addSet()
                    } label: {
                        Label("Add Set", systemImage: "plus.circle")
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: Binding(
                        get: { exercise.notes },
                        set: { exercise.notes = $0 }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func deleteSet(at offsets: IndexSet) {
        exercise.sets.remove(atOffsets: offsets)
        // Renumber sets
        for i in 0..<exercise.sets.count {
            exercise.sets[i].setNumber = i + 1
        }
    }

    private func addSet() {
        let newSetNumber = exercise.sets.count + 1
        let lastSet = exercise.sets.last
        let newSet = ExerciseSet(
            setNumber: newSetNumber,
            targetReps: lastSet?.targetReps ?? 10,
            actualReps: lastSet?.actualReps,
            weight: lastSet?.weight
        )
        exercise.sets.append(newSet)
    }
}

struct HistoricalSetRow: View {
    let setNumber: Int
    @Binding var weight: Double?
    @Binding var reps: Int

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: weightText) { _, newValue in
                        weight = Double(newValue)
                    }
                Text("lbs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("x")
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: repsText) { _, newValue in
                        reps = Int(newValue) ?? reps
                    }
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let w = weight {
                weightText = w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
            }
            repsText = "\(reps)"
        }
    }
}

// Extension to make Int? conform to Identifiable for sheet presentation
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
