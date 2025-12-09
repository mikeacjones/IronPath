import SwiftUI

struct ExerciseLibraryView: View {
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var selectedEquipment: Equipment?
    @State private var selectedExercise: Exercise?

    var filteredExercises: [Exercise] {
        var results = ExerciseDatabase.shared.exercises

        // Apply search filter
        if !searchText.isEmpty {
            results = results.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        // Apply muscle group filter
        if let muscleGroup = selectedMuscleGroup {
            results = results.filter {
                $0.primaryMuscleGroups.contains(muscleGroup) ||
                $0.secondaryMuscleGroups.contains(muscleGroup)
            }
        }

        // Apply equipment filter
        if let equipment = selectedEquipment {
            results = results.filter { $0.equipment == equipment }
        }

        return results.sorted { $0.name < $1.name }
    }

    var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { exercise in
            String(exercise.name.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Muscle group filter
                        Menu {
                            Button("All Muscles") {
                                selectedMuscleGroup = nil
                            }
                            Divider()
                            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                                Button(muscle.rawValue) {
                                    selectedMuscleGroup = muscle
                                }
                            }
                        } label: {
                            FilterChip(
                                title: selectedMuscleGroup?.rawValue ?? "Muscle",
                                isActive: selectedMuscleGroup != nil
                            )
                        }

                        // Equipment filter
                        Menu {
                            Button("All Equipment") {
                                selectedEquipment = nil
                            }
                            Divider()
                            ForEach(Equipment.allCases, id: \.self) { equip in
                                Button(equip.rawValue) {
                                    selectedEquipment = equip
                                }
                            }
                        } label: {
                            FilterChip(
                                title: selectedEquipment?.rawValue ?? "Equipment",
                                isActive: selectedEquipment != nil
                            )
                        }

                        // Clear filters
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
                List {
                    ForEach(groupedExercises, id: \.0) { letter, exercises in
                        Section(header: Text(letter)) {
                            ForEach(exercises) { exercise in
                                ExerciseRowView(exercise: exercise)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedExercise = exercise
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Exercise Library")
            .searchable(text: $searchText, prompt: "Search exercises")
            .sheet(item: $selectedExercise) { exercise in
                ExerciseLibraryDetailView(exercise: exercise)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.blue : Color(.systemGray5))
        .foregroundStyle(isActive ? .white : .primary)
        .cornerRadius(16)
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Muscle indicator
            Circle()
                .fill(muscleGroupColor(exercise.primaryMuscleGroups.first ?? .chest))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label(exercise.equipment.rawValue, systemImage: "dumbbell")
                    Text("•")
                    Text(exercise.difficulty.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }

    func muscleGroupColor(_ muscle: MuscleGroup) -> Color {
        switch muscle {
        case .chest: return .red
        case .back, .lowerBack, .traps: return .blue
        case .shoulders: return .orange
        case .biceps, .triceps, .forearms: return .purple
        case .quads, .hamstrings, .glutes, .calves: return .green
        case .abs, .obliques: return .yellow
        }
    }
}

struct ExerciseLibraryDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var gymSettings = GymSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name)
                            .font(.title)
                            .fontWeight(.bold)

                        HStack(spacing: 16) {
                            Label(exercise.equipment.rawValue, systemImage: "dumbbell")
                            Label(exercise.difficulty.rawValue, systemImage: "speedometer")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Suggestion preference
                    ExercisePreferencePickerView(exerciseName: exercise.name)
                        .padding(.horizontal)

                    // Video demonstration
                    if let videoID = exercise.youtubeVideoID {
                        YouTubeVideoView(videoID: videoID)
                            .padding(.horizontal)
                    }

                    // Muscle groups
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Target Muscles")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Primary:")
                                    .foregroundStyle(.secondary)
                                Text(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                                    .fontWeight(.medium)
                            }

                            if !exercise.secondaryMuscleGroups.isEmpty {
                                HStack {
                                    Text("Secondary:")
                                        .foregroundStyle(.secondary)
                                    Text(exercise.secondaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Instructions
                    if !exercise.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("How to Perform", systemImage: "list.number")
                                .font(.headline)

                            Text(exercise.instructions)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Form tips
                    if !exercise.formTips.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Form Tips", systemImage: "lightbulb")
                                .font(.headline)

                            Text(exercise.formTips)
                                .font(.body)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // History section placeholder
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your History", systemImage: "clock")
                            .font(.headline)

                        Text("Complete workouts with this exercise to see your history and progress here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
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

/// Picker for exercise suggestion preference
struct ExercisePreferencePickerView: View {
    let exerciseName: String
    @ObservedObject private var gymSettings = GymSettings.shared

    private var currentPreference: ExerciseSuggestionPreference {
        gymSettings.suggestionPreference(for: exerciseName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout Suggestions", systemImage: "wand.and.stars")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(ExerciseSuggestionPreference.allCases, id: \.self) { preference in
                    PreferenceButton(
                        preference: preference,
                        isSelected: currentPreference == preference,
                        onTap: {
                            gymSettings.setSuggestionPreference(preference, for: exerciseName)
                        }
                    )
                }
            }

            Text(preferenceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var preferenceDescription: String {
        switch currentPreference {
        case .normal:
            return "This exercise will be suggested based on your workout type and goals."
        case .suggestMore:
            return "Claude will prioritize including this exercise in your workouts."
        case .suggestLess:
            return "Claude will avoid this exercise unless you specifically request it."
        case .never:
            return "This exercise will never be included in generated workouts."
        }
    }
}

struct PreferenceButton: View {
    let preference: ExerciseSuggestionPreference
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: preference.icon)
                    .font(.title3)
                Text(shortLabel)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? preference.color.opacity(0.2) : Color(.systemGray5))
            .foregroundStyle(isSelected ? preference.color : .secondary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? preference.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var shortLabel: String {
        switch preference {
        case .normal: return "Normal"
        case .suggestMore: return "More"
        case .suggestLess: return "Less"
        case .never: return "Never"
        }
    }
}

/// YouTube video thumbnail with link to open in YouTube app/Safari
struct YouTubeVideoView: View {
    let videoID: String
    @Environment(\.openURL) private var openURL

    private var thumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
    }

    private var youtubeAppURL: URL? {
        URL(string: "youtube://watch?v=\(videoID)")
    }

    private var youtubeWebURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(videoID)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Video Demonstration", systemImage: "play.circle")
                .font(.headline)

            Button {
                openYouTube()
            } label: {
                ZStack {
                    // Thumbnail image
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay {
                                    ProgressView()
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "video.slash")
                                            .font(.largeTitle)
                                        Text("Tap to open in YouTube")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }

                    // Play button overlay
                    Circle()
                        .fill(.black.opacity(0.7))
                        .frame(width: 70, height: 70)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .offset(x: 3) // Optical centering
                        }
                }
            }
            .buttonStyle(.plain)

            // Help text
            HStack {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                Text("Opens in YouTube")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func openYouTube() {
        // Try to open in YouTube app first, fall back to web
        if let appURL = youtubeAppURL {
            openURL(appURL) { success in
                if !success, let webURL = youtubeWebURL {
                    openURL(webURL)
                }
            }
        } else if let webURL = youtubeWebURL {
            openURL(webURL)
        }
    }
}

#Preview {
    ExerciseLibraryView()
}
