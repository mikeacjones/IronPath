import Foundation

// MARK: - FitBod CSV Importer

/// Parses FitBod CSV export format into ParsedWorkout objects
@MainActor
final class FitBodCSVImporter: WorkoutImporter {
    // MARK: - WorkoutImporter Protocol

    var sourceName: String { "FitBod" }
    var supportedFileExtensions: [String] { ["csv"] }

    func detectWeightUnit(_ data: String) -> WeightUnit? {
        // FitBod CSV headers include "Weight(kg)" or "Weight(lbs)"
        if data.contains("Weight(kg)") || data.contains("Weight (kg)") {
            return .kilograms
        } else if data.contains("Weight(lbs)") || data.contains("Weight (lbs)") {
            return .pounds
        }
        return nil // Cannot determine, user must specify
    }

    // MARK: - CSV Column Indices

    private struct ColumnIndices {
        let date: Int
        let exercise: Int
        let reps: Int
        let weight: Int
        let isWarmup: Int
        let note: Int
        let multiplier: Int

        static func parse(from headers: [String], source: String) throws -> ColumnIndices {
            guard let dateIdx = headers.firstIndex(where: { $0.lowercased() == "date" }),
                  let exerciseIdx = headers.firstIndex(where: { $0.lowercased() == "exercise" }),
                  let repsIdx = headers.firstIndex(where: { $0.lowercased() == "reps" }),
                  let weightIdx = headers.firstIndex(where: { $0.lowercased().contains("weight") }) else {
                throw WorkoutImportError.missingRequiredData(source: source, field: "date, exercise, reps, or weight")
            }

            let isWarmupIdx = headers.firstIndex(where: { $0.lowercased() == "iswarmup" }) ?? -1
            let noteIdx = headers.firstIndex(where: { $0.lowercased() == "note" }) ?? -1
            let multiplierIdx = headers.firstIndex(where: { $0.lowercased() == "multiplier" }) ?? -1

            return ColumnIndices(
                date: dateIdx,
                exercise: exerciseIdx,
                reps: repsIdx,
                weight: weightIdx,
                isWarmup: isWarmupIdx,
                note: noteIdx,
                multiplier: multiplierIdx
            )
        }
    }

    // MARK: - Intermediate Types

    private struct ParsedRow {
        let date: Date
        let exerciseName: String
        let set: ParsedSet
    }

    // MARK: - Date Formatters

    private let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm:ss Z",      // FitBod format: 2025-05-03 13:30:00 +0000
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // Handle UTC offsets
            return formatter
        }
    }()

    // MARK: - WorkoutImporter Implementation

    /// Parse CSV data into ParsedWorkout objects
    func parse(_ csvData: String) async throws -> [ParsedWorkout] {
        // Remove UTF-8 BOM if present
        let cleanedData = csvData.replacingOccurrences(of: "\u{FEFF}", with: "")

        // Split into lines
        let lines = cleanedData.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw WorkoutImportError.emptyFile(source: sourceName)
        }

        // Parse header
        guard let headerLine = lines.first else {
            throw WorkoutImportError.missingRequiredData(source: sourceName, field: "headers")
        }

        let headers = parseCSVLine(headerLine)
        let columnIndices = try ColumnIndices.parse(from: headers, source: sourceName)

        // Parse data rows
        var rows: [ParsedRow] = []
        for (index, line) in lines.dropFirst().enumerated() {
            do {
                let row = try parseRow(line, columns: columnIndices, lineNumber: index + 2)
                rows.append(row)
            } catch {
                // Log error but continue parsing other rows
                print("Warning: Skipping line \(index + 2): \(error.localizedDescription)")
            }
        }

        guard !rows.isEmpty else {
            throw WorkoutImportError.invalidFormat(source: sourceName, details: "No valid data rows found")
        }

        // Group rows into workouts
        let workouts = groupIntoWorkouts(rows)

        return workouts
    }

    // MARK: - Private Methods

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        // Add last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    private func parseRow(_ line: String, columns: ColumnIndices, lineNumber: Int) throws -> ParsedRow {
        let fields = parseCSVLine(line)

        // Extract date
        guard fields.count > columns.date else {
            throw WorkoutImportError.invalidFormat(source: sourceName, details: "Line \(lineNumber): missing date field")
        }
        let dateString = fields[columns.date]
        guard let date = parseDate(dateString) else {
            throw WorkoutImportError.invalidDate(source: sourceName, value: dateString)
        }

        // Extract exercise name
        guard fields.count > columns.exercise else {
            throw WorkoutImportError.invalidFormat(source: sourceName, details: "Line \(lineNumber): missing exercise field")
        }
        let exerciseName = fields[columns.exercise]

        // Extract reps
        guard fields.count > columns.reps else {
            throw WorkoutImportError.invalidFormat(source: sourceName, details: "Line \(lineNumber): missing reps field")
        }
        let repsString = fields[columns.reps]
        guard let reps = Int(repsString) else {
            throw WorkoutImportError.invalidNumber(source: sourceName, field: "reps", value: repsString)
        }

        // Extract weight
        guard fields.count > columns.weight else {
            throw WorkoutImportError.invalidFormat(source: sourceName, details: "Line \(lineNumber): missing weight field")
        }
        let weightString = fields[columns.weight]
        guard let weight = Double(weightString) else {
            throw WorkoutImportError.invalidNumber(source: sourceName, field: "weight", value: weightString)
        }

        // Extract optional fields
        let isWarmup = columns.isWarmup >= 0 && fields.count > columns.isWarmup
            ? (fields[columns.isWarmup].lowercased() == "true" || fields[columns.isWarmup] == "1")
            : false

        let note = columns.note >= 0 && fields.count > columns.note
            ? fields[columns.note]
            : ""

        let multiplier = columns.multiplier >= 0 && fields.count > columns.multiplier
            ? (Double(fields[columns.multiplier]) ?? 1.0)
            : 1.0

        let set = ParsedSet(
            reps: reps,
            weight: weight,
            isWarmup: isWarmup,
            note: note,
            multiplier: multiplier
        )

        return ParsedRow(date: date, exerciseName: exerciseName, set: set)
    }

    private func parseDate(_ dateString: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }

    private func groupIntoWorkouts(_ rows: [ParsedRow]) -> [ParsedWorkout] {
        // Group rows by date (ignoring time)
        let calendar = Calendar.current
        var workoutsByDate: [Date: [ParsedRow]] = [:]

        for row in rows {
            let dateOnly = calendar.startOfDay(for: row.date)
            workoutsByDate[dateOnly, default: []].append(row)
        }

        // Convert to ParsedWorkout objects
        return workoutsByDate.map { date, rows in
            // Group rows by exercise
            var exerciseMap: [String: [ParsedSet]] = [:]
            for row in rows {
                exerciseMap[row.exerciseName, default: []].append(row.set)
            }

            // Create ParsedExercise objects
            let exercises = exerciseMap.map { name, sets in
                ParsedExercise(name: name, sets: sets)
            }

            // Generate workout name from date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            let workoutName = "Workout - " + formatter.string(from: date)

            return ParsedWorkout(
                date: date,
                name: workoutName,
                exercises: exercises
            )
        }
        .sorted { $0.date < $1.date } // Sort by date ascending
    }
}
