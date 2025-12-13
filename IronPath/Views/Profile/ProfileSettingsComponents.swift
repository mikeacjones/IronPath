import SwiftUI

// MARK: - AI Provider Section

struct AIProviderSection: View {
    @State private var providerManager = AIProviderManager.shared

    var body: some View {
        Section {
            NavigationLink {
                AIConfigurationView()
            } label: {
                HStack {
                    Label("AI Configuration", systemImage: "cpu")
                    Spacer()
                    providerStatus
                    providerStatusIcon
                }
            }
        } header: {
            Text("AI Provider")
        } footer: {
            Text(footerText)
        }
    }

    private var providerStatus: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(providerManager.currentProvider.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            if providerManager.isConfigured {
                Text(providerManager.selectedModel?.displayName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var providerStatusIcon: some View {
        if providerManager.isConfigured {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var footerText: String {
        if providerManager.isConfigured {
            return "Using \(providerManager.currentProvider.displayName) for workout generation."
        } else {
            return "Configure an AI provider to generate personalized workouts."
        }
    }
}

// MARK: - App Settings Section

struct AppSettingsSection: View {
    @State private var appSettings = AppSettings.shared

    var body: some View {
        Section {
            Toggle(isOn: $appSettings.showYouTubeVideos) {
                Label("Show Exercise Videos", systemImage: "play.rectangle")
            }

            Toggle(isOn: $appSettings.showFormTips) {
                Label("Show Form Tips", systemImage: "lightbulb")
            }

            Toggle(isOn: $appSettings.showAIWorkoutSummary) {
                Label("AI Workout Summary", systemImage: "text.bubble")
            }
        } header: {
            Text("App Settings")
        } footer: {
            Text("Control what's displayed in the exercise detail view and workout completion screen.")
        }
    }
}

// MARK: - Notifications Section

struct NotificationsSection: View {
    @State private var appSettings = AppSettings.shared

    var body: some View {
        Section {
            soundPicker
            volumeControl
            previewButton
        } header: {
            Text("Notifications")
        } footer: {
            Text("Choose the sound that plays when your rest timer completes. Higher volume settings include vibration. The sound will play whether the app is in the foreground or background.")
        }
    }

    private var soundPicker: some View {
        Picker(selection: $appSettings.restNotificationSound) {
            ForEach(RestNotificationSound.allCases, id: \.self) { sound in
                Text(sound.displayName).tag(sound)
            }
        } label: {
            Label("Rest Timer Sound", systemImage: "speaker.wave.2")
        }
    }

    private var volumeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Volume", systemImage: volumeIcon)
                Spacer()
                Text("\(Int(appSettings.restNotificationVolume * 100))%")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $appSettings.restNotificationVolume, in: 0.1...1.0, step: 0.1)
        }
        .disabled(appSettings.restNotificationSound == .none)
    }

    private var previewButton: some View {
        Button {
            appSettings.restNotificationSound.playSound()
        } label: {
            Label("Preview Sound", systemImage: "play.circle")
        }
        .disabled(appSettings.restNotificationSound == .none)
    }

    private var volumeIcon: String {
        if appSettings.restNotificationVolume > 0.7 {
            return "speaker.wave.3"
        } else if appSettings.restNotificationVolume > 0.3 {
            return "speaker.wave.2"
        } else {
            return "speaker.wave.1"
        }
    }
}

// MARK: - Data Management Section

struct DataManagementSection: View {
    @Environment(AppState.self) var appState
    @State private var showingExportOptions = false
    @State private var showingResetConfirmation = false
    @State private var exportData: ExportData?

    var body: some View {
        Section {
            exportButton
            clearDataButton
        } header: {
            Text("Data Management")
        } footer: {
            Text("Export your workout history or clear all data to start fresh")
        }
        .sheet(item: $exportData) { data in
            ShareSheet(items: [data.temporaryFileURL].compactMap { $0 })
        }
    }

    private var exportButton: some View {
        Button {
            showingExportOptions = true
        } label: {
            Label("Export Workout Data", systemImage: "square.and.arrow.up")
        }
        .confirmationDialog("Export Workout Data", isPresented: $showingExportOptions, titleVisibility: .visible) {
            Button("Export as JSON") {
                if let data = WorkoutDataManager.shared.exportHistoryAsJSON(),
                   let string = String(data: data, encoding: .utf8) {
                    exportData = ExportData(content: string, filename: "workout_history.json")
                }
            }
            Button("Export as CSV") {
                let csv = WorkoutDataManager.shared.exportHistoryAsCSV()
                exportData = ExportData(content: csv, filename: "workout_history.csv")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a format for your workout data export")
        }
    }

    private var clearDataButton: some View {
        Button(role: .destructive) {
            showingResetConfirmation = true
        } label: {
            Label("Clear All Data", systemImage: "trash")
        }
        .alert("Clear All Data?", isPresented: $showingResetConfirmation) {
            Button("Clear All Data", role: .destructive) {
                Task {
                    await CloudSyncManager.shared.clearAllData()
                    await MainActor.run {
                        appState.isOnboarded = false
                        appState.userProfile = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete ALL app data including workout history, profile, gym settings, and API keys from this device and iCloud. This action cannot be undone.")
        }
    }
}

// MARK: - Custom Equipment Section

struct CustomEquipmentSection: View {
    var body: some View {
        Section {
            NavigationLink {
                EquipmentManagerView()
            } label: {
                Label("Equipment Manager", systemImage: "wrench.and.screwdriver")
            }
        } header: {
            Text("Custom Equipment")
        } footer: {
            Text("Add custom equipment and machines to your library")
        }
    }
}

