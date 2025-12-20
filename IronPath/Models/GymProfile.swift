import Foundation

// MARK: - Available Plate with Quantity

/// Represents a plate with its weight and available quantity (per side)
struct AvailablePlate: Codable, Hashable, Identifiable {
    var id: Double { weight }
    var weight: Double
    var count: Int  // Number available per side (nil/0 means unlimited)

    init(weight: Double, count: Int = 0) {
        self.weight = weight
        self.count = count
    }

    /// Check if this plate has a quantity limit
    var hasLimit: Bool {
        count > 0
    }
}

// Standard plate sizes - defined here to avoid circular dependencies during initialization
private let kStandardPlates: [Double] = [45, 35, 25, 10, 5, 2.5]
private let kStandardAvailablePlates: [AvailablePlate] = kStandardPlates.map { AvailablePlate(weight: $0, count: 0) }

// Standard kg plate sizes
private let kStandardKgPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
private let kStandardKgAvailablePlates: [AvailablePlate] = kStandardKgPlates.map { AvailablePlate(weight: $0, count: 0) }

// MARK: - Gym Profile

/// Represents a gym location with specific equipment and settings
struct GymProfile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var icon: String = "dumbbell.fill"
    var availableEquipment: Set<Equipment>

    // Weight unit preference (lbs vs kg)
    var preferredWeightUnit: WeightUnit = .pounds

    // Specific machines (Other Machines submenu)
    var availableMachines: Set<SpecificMachine> = []

    // Cable machine settings
    var defaultCableConfig: CableMachineConfig
    var cableMachineConfigs: [String: CableMachineConfig] = [:]

    // Dumbbell settings
    var dumbbellIncrement: Double = 5.0
    var dumbbellMinWeight: Double = 5.0
    var dumbbellMaxWeight: Double = 120.0
    var availableDumbbells: Set<Double>? = nil  // nil = use range mode, Set = use specific dumbbells

    // Plate settings
    var defaultAvailablePlates: [AvailablePlate] = kStandardAvailablePlates
    var exercisePlateConfigs: [String: [AvailablePlate]] = [:]
    var selectedBarWeight: Double = 45.0
    var customBarWeight: Double = 0.0  // Used when selectedBarWeight is set to custom (-1)

    // Per-exercise machine/sled weight (for leg press, smith machine, etc.)
    var exerciseMachineWeights: [String: Double] = [:]
    // Per-exercise single-sided flag (for T-bar row, landmine exercises, etc.)
    var exerciseSingleSided: [String: Bool] = [:]

    // Explicit memberwise initializer (required since we have custom Decodable init)
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "dumbbell.fill",
        availableEquipment: Set<Equipment>,
        preferredWeightUnit: WeightUnit = .pounds,
        availableMachines: Set<SpecificMachine> = [],
        defaultCableConfig: CableMachineConfig,
        cableMachineConfigs: [String: CableMachineConfig] = [:],
        dumbbellIncrement: Double = 5.0,
        dumbbellMinWeight: Double = 5.0,
        dumbbellMaxWeight: Double = 120.0,
        availableDumbbells: Set<Double>? = nil,
        defaultAvailablePlates: [AvailablePlate] = kStandardAvailablePlates,
        exercisePlateConfigs: [String: [AvailablePlate]] = [:],
        selectedBarWeight: Double = 45.0,
        customBarWeight: Double = 0.0,
        exerciseMachineWeights: [String: Double] = [:],
        exerciseSingleSided: [String: Bool] = [:]
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.availableEquipment = availableEquipment
        self.preferredWeightUnit = preferredWeightUnit
        self.availableMachines = availableMachines
        self.defaultCableConfig = defaultCableConfig
        self.cableMachineConfigs = cableMachineConfigs
        self.dumbbellIncrement = dumbbellIncrement
        self.dumbbellMinWeight = dumbbellMinWeight
        self.dumbbellMaxWeight = dumbbellMaxWeight
        self.availableDumbbells = availableDumbbells
        self.defaultAvailablePlates = defaultAvailablePlates
        self.exercisePlateConfigs = exercisePlateConfigs
        self.selectedBarWeight = selectedBarWeight
        self.customBarWeight = customBarWeight
        self.exerciseMachineWeights = exerciseMachineWeights
        self.exerciseSingleSided = exerciseSingleSided
    }

    static var defaultProfile: GymProfile {
        GymProfile(
            name: "My Gym",
            icon: "dumbbell.fill",
            availableEquipment: Set(Equipment.allCases),
            availableMachines: Set(SpecificMachine.allCases),
            defaultCableConfig: .defaultConfig
        )
    }

    static var hotelProfile: GymProfile {
        GymProfile(
            name: "Hotel Gym",
            icon: "building.2.fill",
            availableEquipment: [.dumbbells, .bodyweightOnly, .resistanceBands],
            availableMachines: [],
            defaultCableConfig: .defaultConfig,
            dumbbellMaxWeight: 50.0
        )
    }

    static func == (lhs: GymProfile, rhs: GymProfile) -> Bool {
        lhs.id == rhs.id
    }

    // Custom decoder to handle migration from older saved data without new properties
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "dumbbell.fill"
        availableEquipment = try container.decode(Set<Equipment>.self, forKey: .availableEquipment)
        preferredWeightUnit = try container.decodeIfPresent(WeightUnit.self, forKey: .preferredWeightUnit) ?? .pounds
        availableMachines = try container.decodeIfPresent(Set<SpecificMachine>.self, forKey: .availableMachines) ?? []
        defaultCableConfig = try container.decode(CableMachineConfig.self, forKey: .defaultCableConfig)
        cableMachineConfigs = try container.decodeIfPresent([String: CableMachineConfig].self, forKey: .cableMachineConfigs) ?? [:]
        dumbbellIncrement = try container.decodeIfPresent(Double.self, forKey: .dumbbellIncrement) ?? 5.0
        dumbbellMinWeight = try container.decodeIfPresent(Double.self, forKey: .dumbbellMinWeight) ?? 5.0
        dumbbellMaxWeight = try container.decodeIfPresent(Double.self, forKey: .dumbbellMaxWeight) ?? 120.0
        availableDumbbells = try container.decodeIfPresent(Set<Double>.self, forKey: .availableDumbbells)

        // Migration: Try new format first, fall back to old format [Double]
        do {
            if let newPlates = try container.decodeIfPresent([AvailablePlate].self, forKey: .defaultAvailablePlates) {
                defaultAvailablePlates = newPlates
            } else {
                defaultAvailablePlates = kStandardAvailablePlates
            }
        } catch {
            // Failed to decode as new format, try old format
            if let oldPlates = try? container.decodeIfPresent([Double].self, forKey: .defaultAvailablePlates) {
                defaultAvailablePlates = (oldPlates ?? kStandardPlates).map { AvailablePlate(weight: $0, count: 0) }
            } else {
                defaultAvailablePlates = kStandardAvailablePlates
            }
        }

        // Migration: Try new format first, fall back to old format [String: [Double]]
        do {
            if let newConfigs = try container.decodeIfPresent([String: [AvailablePlate]].self, forKey: .exercisePlateConfigs) {
                exercisePlateConfigs = newConfigs
            } else {
                exercisePlateConfigs = [:]
            }
        } catch {
            // Failed to decode as new format, try old format
            if let oldConfigs = try? container.decodeIfPresent([String: [Double]].self, forKey: .exercisePlateConfigs) {
                exercisePlateConfigs = (oldConfigs ?? [:]).mapValues { plates in
                    plates.map { AvailablePlate(weight: $0, count: 0) }
                }
            } else {
                exercisePlateConfigs = [:]
            }
        }

        selectedBarWeight = try container.decodeIfPresent(Double.self, forKey: .selectedBarWeight) ?? 45.0
        customBarWeight = try container.decodeIfPresent(Double.self, forKey: .customBarWeight) ?? 0.0
        exerciseMachineWeights = try container.decodeIfPresent([String: Double].self, forKey: .exerciseMachineWeights) ?? [:]
        exerciseSingleSided = try container.decodeIfPresent([String: Bool].self, forKey: .exerciseSingleSided) ?? [:]
    }
}

// MARK: - Gym Profile Manager

/// Manages multiple gym profiles
@Observable
@MainActor
final class GymProfileManager {
    static let shared = GymProfileManager()

    private var isInitializing = true  // Prevent circular dependency during init

    var profiles: [GymProfile] = [] {
        didSet {
            if !isInitializing { saveProfiles() }
        }
    }

    var activeProfileId: UUID? {
        didSet {
            guard !isInitializing else { return }
            // Save to both local and cloud
            CloudSyncManager.shared.saveActiveGymProfileId(activeProfileId)
            // Notify GymSettings to reload
            GymSettings.shared.loadFromActiveProfile()
        }
    }

    var activeProfile: GymProfile? {
        get {
            guard let id = activeProfileId else { return profiles.first }
            return profiles.first { $0.id == id } ?? profiles.first
        }
        set {
            if let profile = newValue {
                activeProfileId = profile.id
            }
        }
    }

    private init() {
        loadProfiles()
        isInitializing = false
        // Now that initialization is complete, save the profiles if needed
        saveProfiles()

        // Listen for iCloud sync changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudSync),
            name: .cloudDataDidSync,
            object: nil
        )
    }

    @objc nonisolated private func handleCloudSync() {
        Task { @MainActor in
            // Reload profiles from cloud/local storage
            isInitializing = true
            loadProfiles()
            isInitializing = false
            GymSettings.shared.loadFromActiveProfile()
        }
    }

    private func loadProfiles() {
        // Try to load from local storage (CloudKit syncs in background and updates UserDefaults)
        if let data = UserDefaults.standard.data(forKey: "gymProfiles"),
           let decoded = try? JSONDecoder().decode([GymProfile].self, from: data) {
            self.profiles = decoded
        } else {
            // Create default profile on first launch
            self.profiles = [GymProfile.defaultProfile]
        }

        // Load active profile ID - try cloud first, then local
        if let cloudId = CloudSyncManager.shared.loadActiveGymProfileId(),
           profiles.contains(where: { $0.id == cloudId }) {
            self.activeProfileId = cloudId
        } else if let idString = UserDefaults.standard.string(forKey: "activeGymProfileId"),
           let id = UUID(uuidString: idString),
           profiles.contains(where: { $0.id == id }) {
            self.activeProfileId = id
        } else {
            self.activeProfileId = profiles.first?.id
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "gymProfiles")
            // Sync to CloudKit - use saveGymProfiles which properly handles timestamps
            CloudSyncManager.shared.saveGymProfiles(data)
        }
    }

    func addProfile(_ profile: GymProfile) {
        profiles.append(profile)
    }

    func updateProfile(_ profile: GymProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            // If updating active profile, reload settings
            if profile.id == activeProfileId {
                GymSettings.shared.loadFromActiveProfile()
            }
        }
    }

    func deleteProfile(_ profile: GymProfile) {
        // Don't allow deleting the last profile
        guard profiles.count > 1 else { return }

        profiles.removeAll { $0.id == profile.id }

        // If deleted active profile, switch to first available
        if profile.id == activeProfileId {
            activeProfileId = profiles.first?.id
        }
    }

    func switchToProfile(_ profile: GymProfile) {
        activeProfileId = profile.id
    }

    /// Save current GymSettings state back to the active profile
    func saveCurrentSettingsToActiveProfile() {
        guard !isInitializing else { return }  // Don't save during initialization
        guard var profile = activeProfile else { return }

        let settings = GymSettings.shared
        profile.defaultCableConfig = settings.defaultCableConfig
        profile.cableMachineConfigs = settings.cableMachineConfigs
        profile.dumbbellIncrement = settings.dumbbellIncrement
        profile.dumbbellMinWeight = settings.dumbbellMinWeight
        profile.dumbbellMaxWeight = settings.dumbbellMaxWeight
        profile.availableDumbbells = settings.availableDumbbells
        profile.defaultAvailablePlates = settings.defaultAvailablePlates
        profile.exercisePlateConfigs = settings.exercisePlateConfigs
        profile.selectedBarWeight = settings.selectedBarWeight
        profile.customBarWeight = settings.customBarWeight
        profile.exerciseMachineWeights = settings.exerciseMachineWeights
        profile.exerciseSingleSided = settings.exerciseSingleSided

        updateProfile(profile)
    }
}

// MARK: - Gym Settings

/// Current gym settings loaded from the active profile
@Observable
@MainActor
final class GymSettings {
    static let shared = GymSettings()

    // Cable machine configurations per exercise
    var cableMachineConfigs: [String: CableMachineConfig] = [:] {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    // Default cable config for exercises without specific config
    var defaultCableConfig: CableMachineConfig {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    // Dumbbell settings
    var dumbbellIncrement: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    var dumbbellMinWeight: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    var dumbbellMaxWeight: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    var availableDumbbells: Set<Double>? {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    // Plate settings - per exercise
    var exercisePlateConfigs: [String: [AvailablePlate]] = [:] {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    var defaultAvailablePlates: [AvailablePlate] {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    var selectedBarWeight: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    var customBarWeight: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    // Per-exercise machine/sled weight
    var exerciseMachineWeights: [String: Double] = [:] {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    // Per-exercise single-sided flag
    var exerciseSingleSided: [String: Bool] = [:] {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    /// Constant to indicate custom bar weight is selected
    static let customBarWeightTag: Double = -1.0

    /// Standard plate sizes (without 100lb - not common in most areas)
    static let standardPlates: [AvailablePlate] = kStandardAvailablePlates

    /// Standard kg plate sizes
    static let standardPlatesKg: [AvailablePlate] = kStandardKgAvailablePlates

    /// Standard dumbbell sizes commonly found in gyms (in lbs)
    static let standardDumbbells: [Double] = [
        2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 22.5, 25,
        27.5, 30, 32.5, 35, 37.5, 40, 42.5, 45, 47.5, 50,
        52.5, 55, 57.5, 60, 65, 70, 75, 80, 85, 90,
        95, 100, 105, 110, 115, 120, 125, 130, 135, 140,
        145, 150
    ]

    /// Standard dumbbell sizes commonly found in kg gyms
    static let standardDumbbellsKg: [Double] = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        12, 14, 16, 18, 20, 22, 24, 26, 28, 30,
        32, 34, 36, 38, 40, 42, 44, 46, 48, 50,
        52, 54, 56, 58, 60, 65, 70
    ]

    /// Common dumbbell sizes for hotel/limited gyms (in lbs)
    static let limitedDumbbells: [Double] = [
        5, 10, 15, 20, 25, 30, 35, 40, 45, 50
    ]

    /// Common dumbbell sizes for hotel/limited kg gyms
    static let limitedDumbbellsKg: [Double] = [
        2, 4, 6, 8, 10, 12, 14, 16, 18, 20
    ]

    private var isLoading = true  // Start true to prevent didSet triggers during init

    private init() {
        // Set defaults first (isLoading is true, so didSet won't trigger saves)
        self.dumbbellIncrement = 5.0
        self.dumbbellMinWeight = 5.0
        self.dumbbellMaxWeight = 120.0
        self.availableDumbbells = nil  // nil means use range mode
        self.defaultCableConfig = .defaultConfig
        self.cableMachineConfigs = [:]
        self.defaultAvailablePlates = kStandardAvailablePlates
        self.exercisePlateConfigs = [:]
        self.selectedBarWeight = 45.0
        self.customBarWeight = 0.0
        self.exerciseMachineWeights = [:]
        self.exerciseSingleSided = [:]

        // Now safe to allow saves
        self.isLoading = false
    }

    /// Load settings from the active gym profile
    func loadFromActiveProfile() {
        isLoading = true

        if let profile = GymProfileManager.shared.activeProfile {
            self.defaultCableConfig = profile.defaultCableConfig
            self.cableMachineConfigs = profile.cableMachineConfigs
            self.dumbbellIncrement = profile.dumbbellIncrement
            self.dumbbellMinWeight = profile.dumbbellMinWeight
            self.dumbbellMaxWeight = profile.dumbbellMaxWeight
            self.availableDumbbells = profile.availableDumbbells
            self.defaultAvailablePlates = profile.defaultAvailablePlates
            self.exercisePlateConfigs = profile.exercisePlateConfigs
            self.selectedBarWeight = profile.selectedBarWeight
            self.customBarWeight = profile.customBarWeight
            self.exerciseMachineWeights = profile.exerciseMachineWeights
            self.exerciseSingleSided = profile.exerciseSingleSided
        }

        isLoading = false
    }

    /// Get available plates for a specific exercise
    func availablePlates(for exerciseName: String) -> [AvailablePlate] {
        exercisePlateConfigs[exerciseName] ?? defaultAvailablePlates
    }

    /// Set available plates for a specific exercise
    func setAvailablePlates(_ plates: [AvailablePlate], for exerciseName: String) {
        exercisePlateConfigs[exerciseName] = plates
    }

    /// Check if exercise has custom plate config
    func hasCustomPlateConfig(for exerciseName: String) -> Bool {
        exercisePlateConfigs[exerciseName] != nil
    }

    /// Reset exercise to use default plates
    func resetPlateConfig(for exerciseName: String) {
        exercisePlateConfigs.removeValue(forKey: exerciseName)
    }

    /// Get machine/sled weight for a specific exercise and equipment type
    func machineWeight(for exerciseName: String, equipment: Equipment) -> Double {
        // Return exercise-specific weight if set
        if let weight = exerciseMachineWeights[exerciseName] {
            return weight
        }
        // Otherwise return default based on equipment type
        switch equipment {
        case .barbell, .squat, .trapBar:
            return selectedBarWeight == GymSettings.customBarWeightTag ? customBarWeight : selectedBarWeight
        case .legPress:
            return 0  // Default to 0 for leg press, user can set sled weight
        case .smithMachine:
            return 20  // Smith machine bars typically 15-25 lbs
        default:
            return 0
        }
    }

    /// Set machine/sled weight for a specific exercise
    func setMachineWeight(_ weight: Double, for exerciseName: String) {
        exerciseMachineWeights[exerciseName] = weight
    }

    /// Check if exercise has custom machine weight
    func hasCustomMachineWeight(for exerciseName: String) -> Bool {
        exerciseMachineWeights[exerciseName] != nil
    }

    /// Reset exercise to use default machine weight
    func resetMachineWeight(for exerciseName: String) {
        exerciseMachineWeights.removeValue(forKey: exerciseName)
    }

    /// Check if exercise is single-sided (plates on one side only)
    func isSingleSided(for exerciseName: String) -> Bool {
        exerciseSingleSided[exerciseName] ?? false
    }

    /// Set single-sided flag for a specific exercise
    func setSingleSided(_ value: Bool, for exerciseName: String) {
        if value {
            exerciseSingleSided[exerciseName] = true
        } else {
            exerciseSingleSided.removeValue(forKey: exerciseName)
        }
    }

    /// The preferred weight unit from the active gym profile
    var preferredWeightUnit: WeightUnit {
        GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds
    }

    /// Get cable config for specific exercise, or default if none set
    func cableConfig(for exerciseName: String) -> CableMachineConfig {
        cableMachineConfigs[exerciseName] ?? defaultCableConfig
    }

    /// Set cable config for specific exercise
    func setCableConfig(_ config: CableMachineConfig, for exerciseName: String) {
        cableMachineConfigs[exerciseName] = config
    }

    /// Get valid weights for equipment type
    func validWeights(for equipment: Equipment, exerciseName: String? = nil) -> [Double] {
        switch equipment {
        case .cables:
            if let name = exerciseName {
                return cableConfig(for: name).availableWeights
            }
            return defaultCableConfig.availableWeights
        case .dumbbells:
            // Use specific dumbbells if configured, otherwise use range
            if let specificDumbbells = availableDumbbells {
                return specificDumbbells.sorted()
            }
            return stride(from: dumbbellMinWeight, through: dumbbellMaxWeight, by: dumbbellIncrement).map { $0 }
        case .barbell, .squat:
            return stride(from: 45.0, through: 500.0, by: 5.0).map { $0 }
        default:
            return []
        }
    }

    /// Round weight to nearest valid for equipment
    func roundToValidWeight(_ weight: Double, for equipment: Equipment, exerciseName: String? = nil) -> Double {
        let validWeights = validWeights(for: equipment, exerciseName: exerciseName)
        guard !validWeights.isEmpty else { return weight }
        return validWeights.min(by: { abs($0 - weight) < abs($1 - weight) }) ?? weight
    }

    /// Get next weight up from current weight
    func nextWeightUp(from weight: Double, for equipment: Equipment, exerciseName: String? = nil) -> Double {
        let validWeights = validWeights(for: equipment, exerciseName: exerciseName)
        return validWeights.first { $0 > weight } ?? weight
    }

    /// Generate a summary of gym equipment for LLM prompts
    func equipmentSummaryForLLM() -> String {
        let weightUnit = GymProfileManager.shared.activeProfile?.preferredWeightUnit ?? .pounds
        let unit = weightUnit.rawValue

        // Warmup weight threshold varies by unit (30 lbs ≈ 14 kg)
        let warmupThreshold: Double = weightUnit == .kilograms ? 14.0 : 30.0

        var summary = "GYM EQUIPMENT CONSTRAINTS:\n\n"

        // Dumbbells - be explicit about ALL available weights
        summary += "DUMBBELLS:\n"
        if let specificDumbbells = availableDumbbells {
            let sortedDumbbells = specificDumbbells.sorted()
            let dumbbellList = sortedDumbbells.map { formatWeight($0) }.joined(separator: ", ")
            summary += "Available weights (ONLY use these exact values): \(dumbbellList) \(unit)\n"

            // Highlight warmup-appropriate weights
            let warmupWeights = sortedDumbbells.filter { $0 <= warmupThreshold }
            if !warmupWeights.isEmpty {
                summary += "For warmup sets, use one of: \(warmupWeights.map { formatWeight($0) }.joined(separator: ", ")) \(unit)\n"
            }
        } else {
            // Generate explicit list from range
            let allWeights = stride(from: dumbbellMinWeight, through: dumbbellMaxWeight, by: dumbbellIncrement).map { formatWeight($0) }
            summary += "Available weights: \(allWeights.joined(separator: ", ")) \(unit)\n"

            // Highlight warmup-appropriate weights (first 6 or up to threshold)
            let warmupWeights = stride(from: dumbbellMinWeight, through: min(warmupThreshold, dumbbellMaxWeight), by: dumbbellIncrement)
                .prefix(6)
                .map { formatWeight($0) }
            summary += "For warmup sets, use one of: \(warmupWeights.joined(separator: ", ")) \(unit)\n"
        }

        summary += "\n"

        // Cable machines - show all available weights
        summary += "CABLE MACHINES:\n"
        let cableWeights = defaultCableConfig.availableWeights.map { formatWeight($0) }
        summary += "Default machine weights: \(cableWeights.joined(separator: ", ")) \(unit)\n"

        // Per-exercise cable configs
        if !cableMachineConfigs.isEmpty {
            summary += "Exercise-specific cable machines:\n"
            for (exercise, config) in cableMachineConfigs {
                let weights = config.availableWeights.map { formatWeight($0) }.joined(separator: ", ")
                summary += "  \(exercise): \(weights) \(unit)\n"
            }
        }

        summary += "\n"

        // Barbells and plate-loaded
        summary += "BARBELLS & PLATE-LOADED:\n"
        let effectiveBarWeight = selectedBarWeight == GymSettings.customBarWeightTag ? customBarWeight : selectedBarWeight
        summary += "Bar weight: \(formatWeight(effectiveBarWeight)) \(unit)\n"

        // Increment varies by unit (5 lbs = 2.5 kg typically)
        let increment = weightUnit == .kilograms ? "2.5" : "5"
        let exampleWeights = weightUnit == .kilograms ? "42.5, 45, 47.5, 50" : "95, 100, 105, 110"
        summary += "Weight increments: Use \(increment) \(unit) increments (e.g., \(exampleWeights)...)\n"

        summary += "\n"
        summary += "⚠️ CRITICAL: When suggesting weights, ONLY use values that exactly match the available weights listed above. "
        summary += "Do NOT use arbitrary values like 65, 85, or 95 for dumbbells unless those exact weights are listed.\n"

        return summary
    }

    /// Format weight for display (removes .0 for whole numbers)
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        } else {
            return String(format: "%.1f", weight)
        }
    }
}
