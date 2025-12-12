import Foundation
import Combine

// MARK: - Gym Profile

/// Represents a gym location with specific equipment and settings
struct GymProfile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var icon: String = "dumbbell.fill"
    var availableEquipment: Set<Equipment>

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
    var defaultAvailablePlates: [Double] = GymSettings.standardPlates
    var exercisePlateConfigs: [String: [Double]] = [:]
    var selectedBarWeight: Double = 45.0
    var customBarWeight: Double = 0.0  // Used when selectedBarWeight is set to custom (-1)

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
}

// MARK: - Gym Profile Manager

/// Manages multiple gym profiles
class GymProfileManager: ObservableObject {
    static let shared = GymProfileManager()

    private var isInitializing = true  // Prevent circular dependency during init

    @Published var profiles: [GymProfile] = [] {
        didSet {
            if !isInitializing { saveProfiles() }
        }
    }

    @Published var activeProfileId: UUID? {
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

    @objc private func handleCloudSync() {
        // Reload profiles from cloud/local storage
        isInitializing = true
        loadProfiles()
        isInitializing = false
        GymSettings.shared.loadFromActiveProfile()
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

        updateProfile(profile)
    }
}

// MARK: - Gym Settings

/// Current gym settings loaded from the active profile
class GymSettings: ObservableObject {
    static let shared = GymSettings()

    // Cable machine configurations per exercise
    @Published var cableMachineConfigs: [String: CableMachineConfig] = [:] {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    // Default cable config for exercises without specific config
    @Published var defaultCableConfig: CableMachineConfig {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    // Dumbbell settings
    @Published var dumbbellIncrement: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    @Published var dumbbellMinWeight: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    @Published var dumbbellMaxWeight: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    @Published var availableDumbbells: Set<Double>? {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    // Plate settings - per exercise
    @Published var exercisePlateConfigs: [String: [Double]] = [:] {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    @Published var defaultAvailablePlates: [Double] {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    @Published var selectedBarWeight: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }
    @Published var customBarWeight: Double {
        didSet { if !isLoading { GymProfileManager.shared.saveCurrentSettingsToActiveProfile() } }
    }

    /// Constant to indicate custom bar weight is selected
    static let customBarWeightTag: Double = -1.0

    /// Standard plate sizes (without 100lb - not common in most areas)
    static let standardPlates: [Double] = [45, 35, 25, 10, 5, 2.5]

    /// Standard dumbbell sizes commonly found in gyms (in lbs)
    static let standardDumbbells: [Double] = [
        2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 22.5, 25,
        27.5, 30, 32.5, 35, 37.5, 40, 42.5, 45, 47.5, 50,
        52.5, 55, 57.5, 60, 65, 70, 75, 80, 85, 90,
        95, 100, 105, 110, 115, 120, 125, 130, 135, 140,
        145, 150
    ]

    /// Common dumbbell sizes for hotel/limited gyms (in lbs)
    static let limitedDumbbells: [Double] = [
        5, 10, 15, 20, 25, 30, 35, 40, 45, 50
    ]

    private var isLoading = false  // Prevent save during load

    private init() {
        // Set defaults first
        self.dumbbellIncrement = 5.0
        self.dumbbellMinWeight = 5.0
        self.dumbbellMaxWeight = 120.0
        self.availableDumbbells = nil  // nil means use range mode
        self.defaultCableConfig = .defaultConfig
        self.cableMachineConfigs = [:]
        self.defaultAvailablePlates = GymSettings.standardPlates
        self.exercisePlateConfigs = [:]
        self.selectedBarWeight = 45.0
        self.customBarWeight = 0.0
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
        }

        isLoading = false
    }

    /// Get available plates for a specific exercise
    func availablePlates(for exerciseName: String) -> [Double] {
        exercisePlateConfigs[exerciseName] ?? defaultAvailablePlates
    }

    /// Set available plates for a specific exercise
    func setAvailablePlates(_ plates: [Double], for exerciseName: String) {
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
        var summary = "GYM EQUIPMENT CONSTRAINTS:\n\n"

        // Dumbbells - be explicit about ALL available weights
        summary += "DUMBBELLS:\n"
        if let specificDumbbells = availableDumbbells {
            let sortedDumbbells = specificDumbbells.sorted()
            let dumbbellList = sortedDumbbells.map { formatWeight($0) }.joined(separator: ", ")
            summary += "Available weights (ONLY use these exact values): \(dumbbellList) lbs\n"

            // Highlight warmup-appropriate weights
            let warmupWeights = sortedDumbbells.filter { $0 <= 30 }
            if !warmupWeights.isEmpty {
                summary += "For warmup sets, use one of: \(warmupWeights.map { formatWeight($0) }.joined(separator: ", ")) lbs\n"
            }
        } else {
            // Generate explicit list from range
            let allWeights = stride(from: dumbbellMinWeight, through: dumbbellMaxWeight, by: dumbbellIncrement).map { formatWeight($0) }
            summary += "Available weights: \(allWeights.joined(separator: ", ")) lbs\n"

            // Highlight warmup-appropriate weights (first 6 or up to 30 lbs)
            let warmupWeights = stride(from: dumbbellMinWeight, through: min(30, dumbbellMaxWeight), by: dumbbellIncrement)
                .prefix(6)
                .map { formatWeight($0) }
            summary += "For warmup sets, use one of: \(warmupWeights.joined(separator: ", ")) lbs\n"
        }

        summary += "\n"

        // Cable machines - show all available weights
        summary += "CABLE MACHINES:\n"
        let cableWeights = defaultCableConfig.availableWeights.map { "\(Int($0))" }
        summary += "Default machine weights: \(cableWeights.joined(separator: ", ")) lbs\n"

        // Per-exercise cable configs
        if !cableMachineConfigs.isEmpty {
            summary += "Exercise-specific cable machines:\n"
            for (exercise, config) in cableMachineConfigs {
                let weights = config.availableWeights.map { "\(Int($0))" }.joined(separator: ", ")
                summary += "  \(exercise): \(weights) lbs\n"
            }
        }

        summary += "\n"

        // Barbells and plate-loaded
        summary += "BARBELLS & PLATE-LOADED:\n"
        let effectiveBarWeight = selectedBarWeight == GymSettings.customBarWeightTag ? customBarWeight : selectedBarWeight
        summary += "Bar weight: \(Int(effectiveBarWeight)) lbs\n"
        summary += "Weight increments: Use 5 lb increments (e.g., 95, 100, 105, 110...)\n"

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
