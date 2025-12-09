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

    // Plate settings
    var defaultAvailablePlates: [Double] = GymSettings.standardPlates
    var exercisePlateConfigs: [String: [Double]] = [:]
    var selectedBarWeight: Double = 45.0

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
            UserDefaults.standard.set(activeProfileId?.uuidString, forKey: "activeGymProfileId")
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
        // Try to load from local storage (CloudKit syncs in background)
        if let data = UserDefaults.standard.data(forKey: "gymProfiles"),
           let decoded = try? JSONDecoder().decode([GymProfile].self, from: data) {
            self.profiles = decoded
        } else {
            // Create default profile on first launch
            self.profiles = [GymProfile.defaultProfile]
        }

        // Load active profile ID
        if let idString = UserDefaults.standard.string(forKey: "activeGymProfileId"),
           let id = UUID(uuidString: idString) {
            self.activeProfileId = id
        } else {
            self.activeProfileId = profiles.first?.id
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "gymProfiles")
            // Sync to CloudKit via GymSettings wrapper
            CloudSyncManager.shared.saveGymSettings(GymSettings.shared)
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
        profile.defaultAvailablePlates = settings.defaultAvailablePlates
        profile.exercisePlateConfigs = settings.exercisePlateConfigs
        profile.selectedBarWeight = settings.selectedBarWeight

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

    /// Standard plate sizes (without 100lb - not common in most areas)
    static let standardPlates: [Double] = [45, 35, 25, 10, 5, 2.5]

    private var isLoading = false  // Prevent save during load

    private init() {
        // Set defaults first
        self.dumbbellIncrement = 5.0
        self.dumbbellMinWeight = 5.0
        self.dumbbellMaxWeight = 120.0
        self.defaultCableConfig = .defaultConfig
        self.cableMachineConfigs = [:]
        self.defaultAvailablePlates = GymSettings.standardPlates
        self.exercisePlateConfigs = [:]
        self.selectedBarWeight = 45.0
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
            self.defaultAvailablePlates = profile.defaultAvailablePlates
            self.exercisePlateConfigs = profile.exercisePlateConfigs
            self.selectedBarWeight = profile.selectedBarWeight
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

    /// Generate a summary of gym equipment for Claude
    func equipmentSummaryForClaude() -> String {
        var summary = "GYM EQUIPMENT CONSTRAINTS:\n"

        // Dumbbells
        summary += "- Dumbbells: \(Int(dumbbellMinWeight))-\(Int(dumbbellMaxWeight)) lbs in \(Int(dumbbellIncrement)) lb increments\n"

        // Default cable machine
        summary += "- Default cable machine: \(defaultCableConfig.stackDescription)\n"
        summary += "  Available weights: \(defaultCableConfig.availableWeights.prefix(10).map { "\(Int($0))" }.joined(separator: ", "))...\(Int(defaultCableConfig.availableWeights.last ?? 0)) lbs\n"

        // Per-exercise cable configs
        if !cableMachineConfigs.isEmpty {
            summary += "- Exercise-specific cable machines:\n"
            for (exercise, config) in cableMachineConfigs {
                summary += "  • \(exercise): \(config.stackDescription) (max: \(Int(config.availableWeights.last ?? 0)) lbs)\n"
            }
        }

        summary += "\nIMPORTANT: Only suggest weights that are achievable with the above equipment. For cable exercises, suggest weights from the available weight list."

        return summary
    }
}
