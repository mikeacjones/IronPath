import SwiftUI

/// View for adding new custom equipment with AI-powered exercise generation
struct AddCustomEquipmentView: View {
    @Environment(\.dismiss) var dismiss
    @State private var equipmentManager = EquipmentManager.shared
    @State private var aiProviderManager = AIProviderManager.shared

    @State private var equipmentName = ""
    @State private var selectedType: CustomEquipment.CustomEquipmentType = .equipmentCategory
    @State private var selectedWeightConfig: CustomEquipment.WeightConfiguration = .plateLoaded
    @State private var selectedIcon = "dumbbell"

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var generatedDraft: CustomEquipmentDraft?
    @State private var showingExerciseSelection = false

    private var trimmedName: String {
        equipmentName.trimmingCharacters(in: .whitespaces)
    }

    private var isDuplicate: Bool {
        guard !trimmedName.isEmpty else { return false }
        return equipmentManager.equipmentExists(name: trimmedName)
    }

    private var canGenerate: Bool {
        !trimmedName.isEmpty && !isDuplicate && !isGenerating
    }

    var body: some View {
        NavigationStack {
            Form {
                // Equipment Details Section
                Section {
                    TextField("Equipment Name", text: $equipmentName)
                        .autocorrectionDisabled()

                    if isDuplicate {
                        Label("Equipment with this name already exists", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }

                    Picker("Type", selection: $selectedType) {
                        Text("Equipment Category").tag(CustomEquipment.CustomEquipmentType.equipmentCategory)
                        Text("Specific Machine").tag(CustomEquipment.CustomEquipmentType.specificMachine)
                    }
                } header: {
                    Text("Equipment Details")
                } footer: {
                    Text(selectedType == .equipmentCategory
                        ? "Equipment categories are general types like barbells or dumbbells"
                        : "Specific machines are unique equipment like a particular cable attachment or specialty rack")
                }

                // Weight Configuration Section
                Section {
                    ForEach(CustomEquipment.WeightConfiguration.allCases, id: \.self) { config in
                        Button {
                            selectedWeightConfig = config
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: config.iconName)
                                    .font(.title3)
                                    .foregroundStyle(selectedWeightConfig == config ? .blue : .secondary)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(config.displayName)
                                        .font(.subheadline)
                                        .fontWeight(selectedWeightConfig == config ? .semibold : .regular)
                                        .foregroundStyle(.primary)
                                    Text(config.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if selectedWeightConfig == config {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Weight Configuration")
                } footer: {
                    Text("How weight is added or selected for this equipment")
                }

                // Icon Selection Section
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 8) {
                        ForEach(EquipmentManager.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Icon")
                }

                // Preview Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIcon)
                            .font(.title)
                            .foregroundStyle(.purple)
                            .frame(width: 50)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(trimmedName.isEmpty ? "Equipment Name" : trimmedName)
                                .font(.headline)
                                .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)

                            HStack(spacing: 8) {
                                Text(selectedType.displayName)
                                Text("•")
                                Image(systemName: selectedWeightConfig.iconName)
                                Text(selectedWeightConfig.displayName)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Preview")
                }

                // AI Generation Section
                Section {
                    if !aiProviderManager.isConfigured {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI Provider Not Configured", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("Configure an AI provider in settings to generate exercises automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            generateExercises()
                        } label: {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                    Text("Generating Exercises...")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Generate Exercises with AI")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(!canGenerate)
                    }
                } header: {
                    Text("AI Exercise Generation")
                } footer: {
                    if aiProviderManager.isConfigured {
                        Text("AI will suggest 10-15 exercises for this equipment. You can select and edit them before saving.")
                    }
                }

                // Error Section
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }

                // Manual Save Section (without AI exercises)
                Section {
                    Button {
                        saveWithoutExercises()
                    } label: {
                        Text("Save Without Exercises")
                    }
                    .disabled(trimmedName.isEmpty || isDuplicate)
                } footer: {
                    Text("You can add exercises later from the exercise library.")
                }
            }
            .navigationTitle("Add Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showingExerciseSelection) {
                if let draft = generatedDraft {
                    ExerciseSelectionView(draft: draft) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateExercises() {
        guard canGenerate else { return }

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let provider = aiProviderManager.currentProvider

                // Get existing exercise names to avoid duplicates
                let existingNames = CustomExerciseStore.shared.getAllExerciseNames()

                let exercises = try await provider.generateEquipmentExercises(
                    equipmentName: trimmedName,
                    equipmentType: selectedType,
                    existingExerciseNames: existingNames
                )

                // Create the equipment object
                let equipment = CustomEquipment(
                    id: UUID(),
                    name: CustomEquipment.normalizeName(trimmedName),
                    displayName: trimmedName,
                    icon: selectedIcon,
                    equipmentType: selectedType,
                    weightConfiguration: selectedWeightConfig,
                    createdAt: Date(),
                    updatedAt: Date()
                )

                // Create draft with all exercises selected by default
                let draft = CustomEquipmentDraft(
                    equipment: equipment,
                    suggestedExercises: exercises
                )

                await MainActor.run {
                    generatedDraft = draft
                    showingExerciseSelection = true
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func saveWithoutExercises() {
        let equipment = CustomEquipment(
            id: UUID(),
            name: CustomEquipment.normalizeName(trimmedName),
            displayName: trimmedName,
            icon: selectedIcon,
            equipmentType: selectedType,
            weightConfiguration: selectedWeightConfig,
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            try CustomEquipmentStore.shared.addEquipment(equipment)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddCustomEquipmentView()
}
