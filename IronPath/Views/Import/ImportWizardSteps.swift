import SwiftUI
import UniformTypeIdentifiers

// MARK: - Step 1: File Selection

struct FileSelectionStep: View {
    @Bindable var session: ImportSession
    @State private var showingFilePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            // Title
            Text("Import from FitBod")
                .font(.title2)
                .fontWeight(.bold)

            // Description
            Text("Select your FitBod CSV export file to import your workout history.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // File picker button
            Button {
                showingFilePicker = true
            } label: {
                Label("Select CSV File", systemImage: "folder")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Loading indicator
            if isLoading {
                ProgressView("Parsing file...")
                    .padding()
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // File info
            if !session.parsedWorkouts.isEmpty {
                VStack(spacing: 8) {
                    Label("\(session.parsedWorkouts.count) workouts found", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)

                    if let range = session.dateRange {
                        Text(formatDateRange(range))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            Spacer()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let url = try result.get().first else {
                    throw WorkoutImportError.emptyFile(source: "FitBod")
                }

                // Read file
                guard url.startAccessingSecurityScopedResource() else {
                    throw WorkoutImportError.invalidFormat(source: "FitBod", details: "Cannot access file")
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let csvData = try String(contentsOf: url, encoding: .utf8)

                // Parse using FitBod importer
                let importer = FitBodCSVImporter()
                let workouts = try await importer.parse(csvData)

                // Detect weight unit
                if let detectedUnit = importer.detectWeightUnit(csvData) {
                    session.sourceUnit = detectedUnit
                }

                // Update session
                session.parsedWorkouts = workouts
                session.selectAllWorkouts()

                // Extract unmapped exercises
                await extractUnmappedExercises()

                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func extractUnmappedExercises() async {
        let exerciseMatcher = ExerciseMatcher()
        var unmappedMap: [String: Int] = [:]

        // Find all unique exercise names and auto-map exact matches
        // Only process selected workouts
        for workoutIndex in session.parsedWorkouts.indices {
            let workout = session.parsedWorkouts[workoutIndex]

            // Skip workouts that aren't selected
            guard session.selectedWorkouts.contains(workout.id) else {
                continue
            }

            for exerciseIndex in session.parsedWorkouts[workoutIndex].exercises.indices {
                let exercise = session.parsedWorkouts[workoutIndex].exercises[exerciseIndex]

                // Try to find exact match
                if let matched = exerciseMatcher.exactMatch(for: exercise.name) {
                    // Auto-map exact matches
                    session.parsedWorkouts[workoutIndex].exercises[exerciseIndex] = ParsedExercise(
                        id: exercise.id,
                        name: exercise.name,
                        sets: exercise.sets,
                        matchedExercise: matched
                    )
                    session.exerciseMappings[exercise.name] = matched
                } else {
                    // Track unmapped exercises (only from selected workouts)
                    unmappedMap[exercise.name, default: 0] += 1
                }
            }
        }

        // Convert to UnmappedExercise objects
        session.unmappedExercises = unmappedMap.map { name, count in
            UnmappedExercise(name: name, count: count)
        }
        .sorted { $0.count > $1.count } // Most common first
    }

    private func formatDateRange(_ range: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }
}

// MARK: - Step 2: Data Preview

struct DataPreviewStep: View {
    @Bindable var session: ImportSession

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            summaryHeader

            Divider()

            // Workout list
            List {
                ForEach(session.parsedWorkouts) { workout in
                    WorkoutPreviewRow(
                        workout: workout,
                        isSelected: session.selectedWorkouts.contains(workout.id),
                        onToggle: { session.toggleWorkout(workout.id) }
                    )
                }
            }
            .listStyle(.plain)
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            Text("Found \(session.parsedWorkouts.count) Workouts")
                .font(.headline)

            HStack(spacing: 20) {
                VStack {
                    Text("\(session.totalExerciseCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("\(session.totalSetCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text(session.sourceUnit.abbreviation)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Unit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Selection controls
            HStack(spacing: 16) {
                Button("Select All") {
                    session.selectAllWorkouts()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Deselect All") {
                    session.deselectAllWorkouts()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct WorkoutPreviewRow: View {
    let workout: ParsedWorkout
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(workout.exercises.count) exercises, \(totalSets) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formatDate(workout.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Step 3: Exercise Mapping

struct ExerciseMappingStep: View {
    @Bindable var session: ImportSession
    let exerciseMatcher: ExerciseMatching

    var body: some View {
        VStack(spacing: 0) {
            // Header
            mappingHeader

            Divider()

            // Unmapped exercises list
            if session.unmappedExercises.isEmpty {
                allMappedView
            } else {
                List {
                    ForEach(session.unmappedExercises) { unmapped in
                        ExerciseMappingRow(
                            unmappedExercise: unmapped,
                            session: session,
                            exerciseMatcher: exerciseMatcher
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var mappingHeader: some View {
        VStack(spacing: 12) {
            if session.allExercisesMapped {
                Label("All Exercises Mapped", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                Text("Map Exercises")
                    .font(.headline)

                Text("\(session.exercisesNeedingMapping.count) exercises need mapping")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Match imported exercise names to your exercise database.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var allMappedView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("All exercises mapped!")
                .font(.title3)
                .fontWeight(.semibold)

            Text("All imported exercises have been matched to your exercise database.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }
}

// MARK: - Step 4: Workout Review

struct WorkoutReviewStep: View {
    @Bindable var session: ImportSession

    var body: some View {
        VStack(spacing: 0) {
            // Header
            reviewHeader

            Divider()

            // Workouts list
            List {
                ForEach(session.workoutsToImport) { workout in
                    WorkoutReviewRow(workout: workout, unit: session.sourceUnit)
                }
            }
            .listStyle(.plain)
        }
    }

    private var reviewHeader: some View {
        VStack(spacing: 12) {
            Text("Ready to Import")
                .font(.headline)

            Text("\(session.workoutsToImport.count) workouts will be imported")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !session.exercisesNeedingMapping.isEmpty {
                Label("\(session.exercisesNeedingMapping.count) unmapped exercises will be skipped", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct WorkoutReviewRow: View {
    let workout: ParsedWorkout
    let unit: WeightUnit
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(workout.exercises) { exercise in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.matchedExercise?.name ?? exercise.name)
                            .font(.subheadline)

                        Text("\(exercise.sets.count) sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if exercise.matchedExercise == nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .imageScale(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)

                    Text("\(workout.exercises.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formatDate(workout.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Step 5: Import Progress

struct ImportProgressStep: View {
    @Bindable var session: ImportSession
    let importManager: ImportManaging
    let onComplete: () -> Void

    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @State private var progress: Double = 0.0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if isImporting {
                importingView
            } else if let result = importResult {
                resultView(result)
            } else {
                readyView
            }

            Spacer()
        }
        .onAppear {
            startImport()
        }
    }

    private var importingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text("Importing workouts...")
                .font(.headline)

            Text("\(Int(progress * Double(session.workoutsToImport.count))) of \(session.workoutsToImport.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func resultView(_ result: ImportResult) -> some View {
        VStack(spacing: 16) {
            Image(systemName: result.hasFailures ? "checkmark.circle" : "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(result.hasFailures ? .orange : .green)

            Text("Import Complete")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Label("\(result.successCount) workouts imported", systemImage: "checkmark")
                    .foregroundStyle(.green)

                if result.hasFailures {
                    Label("\(result.failedWorkouts.count) workouts failed", systemImage: "xmark")
                        .foregroundStyle(.red)
                }
            }
            .font(.subheadline)

            Button("Done") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var readyView: some View {
        VStack(spacing: 16) {
            ProgressView()

            Text("Preparing import...")
                .font(.headline)
        }
    }

    private func startImport() {
        guard !isImporting, importResult == nil else { return }

        isImporting = true
        progress = 0.0

        Task {
            do {
                let result = try await importManager.importWorkouts(session)
                await MainActor.run {
                    importResult = result
                    isImporting = false
                    progress = 1.0
                }
            } catch {
                await MainActor.run {
                    importResult = ImportResult(
                        successCount: 0,
                        failedWorkouts: session.workoutsToImport.map { ($0, error) }
                    )
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Step 1") {
    NavigationStack {
        FileSelectionStep(session: ImportSession())
    }
}

#Preview("Step 2") {
    let session = ImportSession()
    session.parsedWorkouts = [
        ParsedWorkout(date: Date(), name: "Workout 1", exercises: []),
        ParsedWorkout(date: Date().addingTimeInterval(-86400), name: "Workout 2", exercises: [])
    ]
    session.selectAllWorkouts()

    return NavigationStack {
        DataPreviewStep(session: session)
    }
}
