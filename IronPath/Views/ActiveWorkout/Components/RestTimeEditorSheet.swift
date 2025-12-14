import SwiftUI

// MARK: - Rest Time Editor Sheet

/// Sheet for editing rest time duration
struct RestTimeEditorSheet: View {
    @Binding var isPresented: Bool
    let currentDuration: TimeInterval
    let onSetRestTime: (TimeInterval) -> Void

    @State private var minutes: Int
    @State private var seconds: Int

    init(isPresented: Binding<Bool>, currentDuration: TimeInterval, onSetRestTime: @escaping (TimeInterval) -> Void) {
        _isPresented = isPresented
        self.currentDuration = currentDuration
        self.onSetRestTime = onSetRestTime
        _minutes = State(initialValue: Int(currentDuration) / 60)
        _seconds = State(initialValue: Int(currentDuration) % 60)
    }

    private var totalSeconds: TimeInterval {
        TimeInterval(minutes * 60 + seconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Set Rest Time")
                    .font(.headline)

                timePicker
                quickPresets

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        onSetRestTime(totalSeconds)
                        isPresented = false
                    }
                    .disabled(totalSeconds < 5)
                }
            }
        }
        .presentationDetents([.height(350)])
    }

    // MARK: - Subviews

    private var timePicker: some View {
        HStack(spacing: 8) {
            Picker("Minutes", selection: $minutes) {
                ForEach(0...10, id: \.self) { min in
                    Text("\(min)").tag(min)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)

            Text(":")
                .font(.title)
                .fontWeight(.bold)

            Picker("Seconds", selection: $seconds) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { sec in
                    Text(String(format: "%02d", sec)).tag(sec)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
        }
        .frame(height: 150)
    }

    private var quickPresets: some View {
        VStack(spacing: 8) {
            Text("Quick Presets")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach([60, 90, 120, 180], id: \.self) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: totalSeconds == TimeInterval(preset),
                        onSelect: {
                            minutes = preset / 60
                            seconds = preset % 60
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Preset Button

private struct PresetButton: View {
    let preset: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(formatDuration(TimeInterval(preset)))
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 && secs > 0 {
            return "\(mins)m \(secs)s"
        } else if mins > 0 {
            return "\(mins) min"
        } else {
            return "\(secs)s"
        }
    }
}
