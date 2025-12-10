import Foundation

/// Represents user-defined equipment that extends the standard Equipment enum
struct CustomEquipment: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String  // Internal identifier (lowercase, underscored)
    var displayName: String  // User-facing name
    var icon: String  // SF Symbol name
    var equipmentType: CustomEquipmentType
    var weightConfiguration: WeightConfiguration
    var createdAt: Date
    var updatedAt: Date

    /// The type of custom equipment being added
    enum CustomEquipmentType: String, Codable, CaseIterable {
        case equipmentCategory  // Like "Barbell" - general equipment category
        case specificMachine    // Like "Pec Deck" - specific gym machine

        var displayName: String {
            switch self {
            case .equipmentCategory:
                return "Equipment Category"
            case .specificMachine:
                return "Specific Machine"
            }
        }

        var description: String {
            switch self {
            case .equipmentCategory:
                return "A general type of equipment like barbells, dumbbells, or resistance bands"
            case .specificMachine:
                return "A specific gym machine like a pec deck, hack squat, or leg curl machine"
            }
        }
    }

    /// How weight is configured/displayed for this equipment
    enum WeightConfiguration: String, Codable, CaseIterable {
        case plateLoaded    // User adds plates (barbell, leg press, etc.)
        case pinSelector    // Pin-selected weight stack (cable machines, most gym machines)
        case fixedWeight    // Equipment has a fixed weight (EZ-bar, fixed dumbbells)
        case bodyweight     // No external weight (pull-up bar, dip station)

        var displayName: String {
            switch self {
            case .plateLoaded:
                return "Plate Loaded"
            case .pinSelector:
                return "Pin Selector"
            case .fixedWeight:
                return "Fixed Weight"
            case .bodyweight:
                return "Bodyweight"
            }
        }

        var description: String {
            switch self {
            case .plateLoaded:
                return "Add weight plates to the equipment (e.g., barbell, leg press, hack squat)"
            case .pinSelector:
                return "Weight selected via pin in a weight stack (e.g., cable machines, most gym machines)"
            case .fixedWeight:
                return "Equipment has a set weight (e.g., EZ-bar, fixed dumbbells, kettlebells)"
            case .bodyweight:
                return "No external weight - uses body weight only"
            }
        }

        var iconName: String {
            switch self {
            case .plateLoaded:
                return "circle.grid.2x1"
            case .pinSelector:
                return "list.bullet.rectangle"
            case .fixedWeight:
                return "scalemass"
            case .bodyweight:
                return "figure.stand"
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        icon: String = "dumbbell",
        equipmentType: CustomEquipmentType,
        weightConfiguration: WeightConfiguration = .plateLoaded,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.icon = icon
        self.equipmentType = equipmentType
        self.weightConfiguration = weightConfiguration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Creates a normalized name from display name for internal use
    static func normalizeName(_ displayName: String) -> String {
        displayName
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}

// MARK: - Draft Models for Pre-Save Editing

/// A draft exercise that can be edited before saving to the database
struct ExerciseDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var primaryMuscleGroups: Set<MuscleGroup>
    var secondaryMuscleGroups: Set<MuscleGroup>
    var equipmentName: String  // References equipment by name
    var difficulty: ExerciseDifficulty
    var instructions: String
    var formTips: String

    init(
        id: UUID = UUID(),
        name: String,
        primaryMuscleGroups: Set<MuscleGroup> = [],
        secondaryMuscleGroups: Set<MuscleGroup> = [],
        equipmentName: String,
        difficulty: ExerciseDifficulty = .intermediate,
        instructions: String = "",
        formTips: String = ""
    ) {
        self.id = id
        self.name = name
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipmentName = equipmentName
        self.difficulty = difficulty
        self.instructions = instructions
        self.formTips = formTips
    }

    /// Converts this draft to a full Exercise model
    func toExercise(
        equipment: Equipment = .bodyweightOnly,
        customEquipmentId: UUID? = nil
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            primaryMuscleGroups: primaryMuscleGroups,
            secondaryMuscleGroups: secondaryMuscleGroups,
            equipment: equipment,
            difficulty: difficulty,
            instructions: instructions,
            formTips: formTips,
            isCustom: true,
            customEquipmentId: customEquipmentId
        )
    }
}

/// Represents a pending custom equipment submission with AI-generated exercises
struct CustomEquipmentDraft: Identifiable {
    let id: UUID
    var equipment: CustomEquipment
    var suggestedExercises: [ExerciseDraft]
    var selectedExerciseIds: Set<UUID>

    init(
        id: UUID = UUID(),
        equipment: CustomEquipment,
        suggestedExercises: [ExerciseDraft] = []
    ) {
        self.id = id
        self.equipment = equipment
        self.suggestedExercises = suggestedExercises
        // Select all by default
        self.selectedExerciseIds = Set(suggestedExercises.map { $0.id })
    }

    /// Returns only the exercises that are selected
    var selectedExercises: [ExerciseDraft] {
        suggestedExercises.filter { selectedExerciseIds.contains($0.id) }
    }

    /// Toggle selection for an exercise
    mutating func toggleSelection(for exerciseId: UUID) {
        if selectedExerciseIds.contains(exerciseId) {
            selectedExerciseIds.remove(exerciseId)
        } else {
            selectedExerciseIds.insert(exerciseId)
        }
    }

    /// Select all exercises
    mutating func selectAll() {
        selectedExerciseIds = Set(suggestedExercises.map { $0.id })
    }

    /// Deselect all exercises
    mutating func deselectAll() {
        selectedExerciseIds.removeAll()
    }
}

// MARK: - Equipment Errors

enum EquipmentError: LocalizedError {
    case duplicateEquipment(name: String)
    case duplicateExercise(name: String)
    case invalidEquipmentName
    case equipmentNotFound(id: UUID)

    var errorDescription: String? {
        switch self {
        case .duplicateEquipment(let name):
            return "Equipment '\(name)' already exists"
        case .duplicateExercise(let name):
            return "Exercise '\(name)' already exists"
        case .invalidEquipmentName:
            return "Equipment name cannot be empty"
        case .equipmentNotFound(let id):
            return "Equipment with id \(id) not found"
        }
    }
}
