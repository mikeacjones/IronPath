import Foundation

/// Centralized manager for all equipment (standard + custom)
/// Provides a single source of truth for equipment access across the app
@Observable
@MainActor
final class EquipmentManager {
    static let shared = EquipmentManager()

    private(set) var allEquipmentOptions: [EquipmentOption] = []
    private(set) var allMachineOptions: [MachineOption] = []

    private init() {
        refreshAllOptions()
    }

    // MARK: - Option Types

    /// Unified equipment option (standard or custom)
    struct EquipmentOption: Identifiable, Hashable {
        let id: String
        let displayName: String
        let icon: String
        let isCustom: Bool
        let standardEquipment: Equipment?
        let customEquipmentId: UUID?

        var isStandard: Bool { !isCustom }
    }

    /// Unified machine option (standard or custom)
    struct MachineOption: Identifiable, Hashable {
        let id: String
        let displayName: String
        let icon: String
        let isCustom: Bool
        let standardMachine: SpecificMachine?
        let customEquipmentId: UUID?

        var isStandard: Bool { !isCustom }
    }

    // MARK: - Equipment Access

    /// Get all equipment options (standard + optional custom)
    func getEquipmentOptions(includeCustom: Bool = true) -> [EquipmentOption] {
        var options = Equipment.allCases.map { equipment in
            EquipmentOption(
                id: equipment.rawValue,
                displayName: equipment.rawValue,
                icon: iconForEquipment(equipment),
                isCustom: false,
                standardEquipment: equipment,
                customEquipmentId: nil
            )
        }

        if includeCustom {
            let customCategories = CustomEquipmentStore.shared.customEquipment
                .filter { $0.equipmentType == .equipmentCategory }
                .map { custom in
                    EquipmentOption(
                        id: "custom_\(custom.id.uuidString)",
                        displayName: custom.displayName,
                        icon: custom.icon,
                        isCustom: true,
                        standardEquipment: nil,
                        customEquipmentId: custom.id
                    )
                }
            options.append(contentsOf: customCategories)
        }

        return options
    }

    /// Get all machine options (standard + optional custom)
    func getMachineOptions(includeCustom: Bool = true) -> [MachineOption] {
        var options = SpecificMachine.allCases.map { machine in
            MachineOption(
                id: machine.rawValue,
                displayName: machine.rawValue,
                icon: "gearshape.2",
                isCustom: false,
                standardMachine: machine,
                customEquipmentId: nil
            )
        }

        if includeCustom {
            let customMachines = CustomEquipmentStore.shared.customEquipment
                .filter { $0.equipmentType == .specificMachine }
                .map { custom in
                    MachineOption(
                        id: "custom_\(custom.id.uuidString)",
                        displayName: custom.displayName,
                        icon: custom.icon,
                        isCustom: true,
                        standardMachine: nil,
                        customEquipmentId: custom.id
                    )
                }
            options.append(contentsOf: customMachines)
        }

        return options
    }

    /// Get only standard equipment options
    func getStandardEquipmentOptions() -> [EquipmentOption] {
        getEquipmentOptions(includeCustom: false)
    }

    /// Get only custom equipment options
    func getCustomEquipmentOptions() -> [EquipmentOption] {
        CustomEquipmentStore.shared.customEquipment
            .filter { $0.equipmentType == .equipmentCategory }
            .map { custom in
                EquipmentOption(
                    id: "custom_\(custom.id.uuidString)",
                    displayName: custom.displayName,
                    icon: custom.icon,
                    isCustom: true,
                    standardEquipment: nil,
                    customEquipmentId: custom.id
                )
            }
    }

    /// Get only custom machine options
    func getCustomMachineOptions() -> [MachineOption] {
        CustomEquipmentStore.shared.customEquipment
            .filter { $0.equipmentType == .specificMachine }
            .map { custom in
                MachineOption(
                    id: "custom_\(custom.id.uuidString)",
                    displayName: custom.displayName,
                    icon: custom.icon,
                    isCustom: true,
                    standardMachine: nil,
                    customEquipmentId: custom.id
                )
            }
    }

    // MARK: - Duplicate Checking

    /// Check if equipment with the given name exists (standard or custom)
    func equipmentExists(name: String) -> Bool {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Check standard equipment
        if Equipment.allCases.contains(where: { $0.rawValue.lowercased() == normalizedName }) {
            return true
        }

        // Check standard machines
        if SpecificMachine.allCases.contains(where: { $0.rawValue.lowercased() == normalizedName }) {
            return true
        }

        // Check custom equipment
        if CustomEquipmentStore.shared.exists(name: name) {
            return true
        }

        return false
    }

    /// Check if an exercise with the given name exists
    func exerciseExists(name: String) -> Bool {
        CustomExerciseStore.shared.exerciseExists(name: name)
    }

    // MARK: - Icon Helpers

    func iconForEquipment(_ equipment: Equipment) -> String {
        switch equipment {
        case .barbell:
            return "figure.strengthtraining.traditional"
        case .trapBar:
            return "figure.strengthtraining.traditional"
        case .dumbbells:
            return "dumbbell"
        case .kettlebells:
            return "scalemass"
        case .resistanceBands:
            return "lines.measurement.horizontal"
        case .pullUpBar:
            return "figure.climbing"
        case .bench:
            return "bed.double"
        case .squat:
            return "square.stack.3d.up"
        case .cables:
            return "cable.connector"
        case .legPress:
            return "figure.walk"
        case .smithMachine:
            return "square.grid.3x3"
        case .bodyweightOnly:
            return "figure.stand"
        }
    }

    // MARK: - Available Icons for Custom Equipment

    static let availableIcons = [
        "dumbbell",
        "figure.strengthtraining.traditional",
        "scalemass",
        "cable.connector",
        "figure.stand",
        "figure.walk",
        "gearshape.2",
        "square.grid.2x2",
        "rectangle.3.group",
        "wrench.and.screwdriver",
        "hammer",
        "cylinder",
        "cube.box",
        "chair.lounge"
    ]

    // MARK: - Private

    func refreshAllOptions() {
        allEquipmentOptions = getEquipmentOptions()
        allMachineOptions = getMachineOptions()
    }
}
