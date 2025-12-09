import Foundation

/// Manages storage and retrieval of the Anthropic API key
class APIKeyManager {
    static let shared = APIKeyManager()

    private let apiKeyKey = "anthropic_api_key"

    private init() {}

    /// Save the API key securely
    func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: apiKeyKey)
    }

    /// Retrieve the stored API key
    func getAPIKey() -> String? {
        // First check UserDefaults
        if let storedKey = UserDefaults.standard.string(forKey: apiKeyKey), !storedKey.isEmpty {
            return storedKey
        }

        // Fallback to environment variable
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        return nil
    }

    /// Check if an API key is configured
    var hasAPIKey: Bool {
        return getAPIKey() != nil
    }

    /// Clear the stored API key
    func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: apiKeyKey)
    }
}
