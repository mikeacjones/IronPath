import Foundation

// MARK: - AI Provider Manager

/// Manages AI provider selection, configuration, and API key storage
/// This is the central point for all AI provider operations
@Observable
@MainActor
final class AIProviderManager {
    static let shared = AIProviderManager()

    // MARK: - Properties

    var selectedProviderType: AIProviderType {
        didSet {
            UserDefaults.standard.set(selectedProviderType.rawValue, forKey: Keys.selectedProvider)
        }
    }

    var selectedModelId: String {
        didSet {
            UserDefaults.standard.set(selectedModelId, forKey: Keys.selectedModel)
        }
    }

    // MARK: - Private Properties

    private var providers: [AIProviderType: AIProvider] = [:]
    private let defaultProvider: AIProvider = AnthropicProvider()

    private enum Keys {
        static let selectedProvider = "ai_selected_provider"
        static let selectedModel = "ai_selected_model"
        static let anthropicAPIKey = "anthropic_api_key"
        static let openaiAPIKey = "openai_api_key"
    }

    // MARK: - Initialization

    private init() {
        // Load saved provider selection
        if let savedProvider = UserDefaults.standard.string(forKey: Keys.selectedProvider),
           let providerType = AIProviderType(rawValue: savedProvider) {
            self.selectedProviderType = providerType
        } else {
            self.selectedProviderType = .anthropic // Default
        }

        // Load saved model selection
        self.selectedModelId = UserDefaults.standard.string(forKey: Keys.selectedModel) ?? ""

        // Initialize providers
        setupProviders()

        // If no model selected, use default for the provider
        if selectedModelId.isEmpty {
            selectedModelId = currentProvider.availableModels.first?.id ?? ""
        }
    }

    private func setupProviders() {
        providers[.anthropic] = AnthropicProvider()
        providers[.openai] = OpenAIProvider()
    }

    // MARK: - Provider Access

    /// Get the currently selected provider
    var currentProvider: AIProvider {
        providers[selectedProviderType] ?? defaultProvider
    }

    /// Get a specific provider by type
    func provider(for type: AIProviderType) -> AIProvider? {
        providers[type]
    }

    /// Get all available providers
    var allProviders: [AIProvider] {
        AIProviderType.allCases.compactMap { providers[$0] }
    }

    /// Currently selected model
    var selectedModel: AIModel? {
        currentProvider.availableModels.first { $0.id == selectedModelId }
            ?? currentProvider.availableModels.first
    }

    // MARK: - Configuration Status

    /// Check if the current provider is configured
    var isConfigured: Bool {
        currentProvider.isConfigured
    }

    /// Check if a specific provider is configured
    func isConfigured(_ providerType: AIProviderType) -> Bool {
        providers[providerType]?.isConfigured ?? false
    }

    // MARK: - API Key Management

    /// Save API key for a provider
    func saveAPIKey(_ key: String, for providerType: AIProviderType) {
        let storageKey = apiKeyStorageKey(for: providerType)
        CloudSyncManager.shared.saveValue(key, forKey: storageKey)
    }

    /// Get API key for a provider
    func getAPIKey(for providerType: AIProviderType) -> String? {
        let storageKey = apiKeyStorageKey(for: providerType)

        // Try cloud/local storage first
        if let key = CloudSyncManager.shared.loadValue(forKey: storageKey), !key.isEmpty {
            return key
        }

        // Fallback to environment variable
        let envVar = environmentVariable(for: providerType)
        if let envKey = ProcessInfo.processInfo.environment[envVar], !envKey.isEmpty {
            return envKey
        }

        return nil
    }

    /// Check if a provider has an API key
    func hasAPIKey(for providerType: AIProviderType) -> Bool {
        getAPIKey(for: providerType) != nil
    }

    /// Clear API key for a provider
    func clearAPIKey(for providerType: AIProviderType) {
        let storageKey = apiKeyStorageKey(for: providerType)
        CloudSyncManager.shared.saveValue("", forKey: storageKey)
    }

    private func apiKeyStorageKey(for providerType: AIProviderType) -> String {
        switch providerType {
        case .anthropic: return Keys.anthropicAPIKey
        case .openai: return Keys.openaiAPIKey
        }
    }

    private func environmentVariable(for providerType: AIProviderType) -> String {
        switch providerType {
        case .anthropic: return "ANTHROPIC_API_KEY"
        case .openai: return "OPENAI_API_KEY"
        }
    }

    // MARK: - Model Selection

    /// Select a model (validates it belongs to current provider)
    func selectModel(_ model: AIModel) {
        guard model.providerId == selectedProviderType.rawValue else { return }
        selectedModelId = model.id
    }

    /// Get the model ID for API calls
    var currentModelId: String {
        selectedModel?.id ?? currentProvider.availableModels.first?.id ?? ""
    }
}

// MARK: - CloudSyncManager Extension for Generic Key-Value Storage

extension CloudSyncManager {
    func saveValue(_ value: String, forKey key: String) {
        // Use the existing iCloud KV store mechanism
        NSUbiquitousKeyValueStore.default.set(value, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()

        // Also save locally as fallback
        UserDefaults.standard.set(value, forKey: key)
    }

    func loadValue(forKey key: String) -> String? {
        // Try iCloud first
        if let value = NSUbiquitousKeyValueStore.default.string(forKey: key), !value.isEmpty {
            return value
        }

        // Fallback to local
        return UserDefaults.standard.string(forKey: key)
    }
}
