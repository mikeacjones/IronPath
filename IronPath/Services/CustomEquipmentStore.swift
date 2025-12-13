import Foundation

/// Manages custom equipment created by the user
@Observable
@MainActor
final class CustomEquipmentStore {
    static let shared = CustomEquipmentStore()

    var customEquipment: [CustomEquipment] = [] {
        didSet { save() }
    }

    private let storageKey = "customEquipment"

    private init() {
        load()
    }

    // MARK: - CRUD Operations

    /// Add new custom equipment
    /// - Throws: EquipmentError.duplicateEquipment if equipment with same name exists
    func addEquipment(_ equipment: CustomEquipment) throws {
        guard !equipment.displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw EquipmentError.invalidEquipmentName
        }

        if exists(name: equipment.displayName) {
            throw EquipmentError.duplicateEquipment(name: equipment.displayName)
        }

        customEquipment.append(equipment)
    }

    /// Update existing custom equipment
    func updateEquipment(_ equipment: CustomEquipment) throws {
        guard let index = customEquipment.firstIndex(where: { $0.id == equipment.id }) else {
            throw EquipmentError.equipmentNotFound(id: equipment.id)
        }

        // Check for duplicate name (excluding current equipment)
        let otherEquipment = customEquipment.filter { $0.id != equipment.id }
        let normalizedName = equipment.displayName.lowercased().trimmingCharacters(in: .whitespaces)
        if otherEquipment.contains(where: { $0.displayName.lowercased() == normalizedName }) {
            throw EquipmentError.duplicateEquipment(name: equipment.displayName)
        }

        var updated = equipment
        updated.updatedAt = Date()
        customEquipment[index] = updated
    }

    /// Delete custom equipment by ID
    func deleteEquipment(id: UUID) {
        customEquipment.removeAll { $0.id == id }
    }

    /// Get custom equipment by ID
    func getEquipment(id: UUID) -> CustomEquipment? {
        customEquipment.first { $0.id == id }
    }

    /// Get all equipment of a specific type
    func getEquipment(ofType type: CustomEquipment.CustomEquipmentType) -> [CustomEquipment] {
        customEquipment.filter { $0.equipmentType == type }
    }

    // MARK: - Duplicate Checking

    /// Check if equipment with the given name already exists
    func exists(name: String) -> Bool {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespaces)
        return customEquipment.contains {
            $0.name.lowercased() == normalizedName ||
            $0.displayName.lowercased() == normalizedName
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(customEquipment) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([CustomEquipment].self, from: data) {
            customEquipment = saved
        }
    }
}
