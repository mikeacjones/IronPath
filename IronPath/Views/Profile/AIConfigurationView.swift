import SwiftUI

// MARK: - AI Configuration View

/// Main view for configuring AI providers and models
struct AIConfigurationView: View {
    @ObservedObject private var providerManager = AIProviderManager.shared
    @ObservedObject private var debugManager = APIDebugManager.shared
    @State private var showingDebugLog = false

    var body: some View {
        List {
            // Provider Selection
            Section {
                ForEach(AIProviderType.allCases, id: \.self) { providerType in
                    AIProviderRow(
                        providerType: providerType,
                        isSelected: providerManager.selectedProviderType == providerType,
                        isConfigured: providerManager.isConfigured(providerType)
                    ) {
                        providerManager.selectedProviderType = providerType
                        // Reset to default model for new provider
                        if let defaultModel = providerManager.provider(for: providerType)?.availableModels.first {
                            providerManager.selectModel(defaultModel)
                        }
                    }
                }
            } header: {
                Text("AI Provider")
            } footer: {
                Text("Select which AI service to use for workout generation.")
            }

            // Current Provider Configuration
            Section {
                NavigationLink {
                    AIProviderDetailView(providerType: providerManager.selectedProviderType)
                } label: {
                    HStack {
                        Label("Configure \(providerManager.currentProvider.displayName)", systemImage: "gearshape")
                        Spacer()
                        if providerManager.isConfigured {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Not configured")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Model Selection (quick access)
                if providerManager.isConfigured {
                    Picker("Model", selection: Binding(
                        get: { providerManager.selectedModelId },
                        set: { newId in
                            if let model = providerManager.currentProvider.availableModels.first(where: { $0.id == newId }) {
                                providerManager.selectModel(model)
                            }
                        }
                    )) {
                        ForEach(providerManager.currentProvider.availableModels) { model in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(model.displayName)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(model.costTier.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(model.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            } header: {
                Text("Current Provider")
            }

            // Debug Options
            Section {
                Toggle(isOn: $debugManager.isDebugEnabled) {
                    Label("Debug Mode", systemImage: "ant.fill")
                }

                if debugManager.isDebugEnabled {
                    Button {
                        showingDebugLog = true
                    } label: {
                        HStack {
                            Label("View API Logs", systemImage: "doc.text.magnifyingglass")
                            Spacer()
                            if !debugManager.logs.isEmpty {
                                Text("\(debugManager.logs.count)")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text("Developer Options")
            } footer: {
                Text(debugManager.isDebugEnabled
                    ? "Debug mode enabled. API requests/responses will be logged."
                    : "Enable to log API requests for troubleshooting.")
            }
        }
        .navigationTitle("AI Configuration")
        .sheet(isPresented: $showingDebugLog) {
            APIDebugLogView()
        }
    }
}

// MARK: - AI Provider Row

struct AIProviderRow: View {
    let providerType: AIProviderType
    let isSelected: Bool
    let isConfigured: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: providerType.iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(providerType.displayName)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(.primary)

                    if isConfigured {
                        Text("Configured")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Needs API key")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Provider Detail View

struct AIProviderDetailView: View {
    let providerType: AIProviderType
    @ObservedObject private var providerManager = AIProviderManager.shared
    @State private var apiKey = ""
    @State private var showingAPIKey = false
    @Environment(\.dismiss) var dismiss

    var provider: AIProvider? {
        providerManager.provider(for: providerType)
    }

    var hasAPIKey: Bool {
        providerManager.hasAPIKey(for: providerType)
    }

    var body: some View {
        List {
            // Status Section
            Section {
                HStack {
                    Label("Status", systemImage: "circle.fill")
                    Spacer()
                    if hasAPIKey {
                        Text("Configured")
                            .foregroundStyle(.green)
                    } else {
                        Text("Not configured")
                            .foregroundStyle(.orange)
                    }
                }
            }

            // API Key Section
            Section {
                if hasAPIKey {
                    HStack {
                        Label("API Key", systemImage: "key.fill")
                        Spacer()
                        Text("••••••••")
                            .foregroundStyle(.secondary)
                    }

                    Button("Update API Key") {
                        apiKey = ""
                        showingAPIKey = true
                    }

                    Button("Remove API Key", role: .destructive) {
                        providerManager.clearAPIKey(for: providerType)
                    }
                } else {
                    Button {
                        apiKey = ""
                        showingAPIKey = true
                    } label: {
                        Label("Add API Key", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                Text("Authentication")
            } footer: {
                if let provider = provider {
                    Text(provider.setupInstructions)
                }
            }

            // Get API Key Link
            if let provider = provider, let url = provider.apiKeyURL {
                Section {
                    Link(destination: url) {
                        HStack {
                            Label("Get API Key", systemImage: "arrow.up.right.square")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Available Models
            Section {
                ForEach(provider?.availableModels ?? []) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.displayName)
                                .fontWeight(.medium)
                            Text(model.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(model.costTier.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
            } header: {
                Text("Available Models")
            }
        }
        .navigationTitle(providerType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAPIKey) {
            ProviderAPIKeyInputView(
                providerType: providerType,
                apiKey: $apiKey,
                onSave: {
                    providerManager.saveAPIKey(apiKey, for: providerType)
                    showingAPIKey = false
                    apiKey = ""
                }
            )
        }
    }
}

// MARK: - Provider API Key Input View

struct ProviderAPIKeyInputView: View {
    let providerType: AIProviderType
    @Binding var apiKey: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isKeyFieldFocused: Bool

    var provider: AIProvider? {
        AIProviderManager.shared.provider(for: providerType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .focused($isKeyFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("\(providerType.displayName) API Key")
                } footer: {
                    Text("Your API key is stored securely and synced via iCloud.")
                }

                if let provider = provider, let url = provider.apiKeyURL {
                    Section {
                        Link(destination: url) {
                            HStack {
                                Text("Get your API key")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isKeyFieldFocused = true
            }
        }
    }
}
