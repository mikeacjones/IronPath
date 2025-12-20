import SwiftUI

// MARK: - Set Type Picker View

struct SetTypePickerView: View {
    let onSelect: (SetType) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SetTypeButton(
                        icon: "number.circle",
                        iconColor: .blue,
                        title: "Standard Set",
                        subtitle: "Regular working set"
                    ) {
                        onSelect(.standard)
                        dismiss()
                    }

                    SetTypeButton(
                        icon: "flame",
                        iconColor: .orange,
                        title: "Warmup Set",
                        subtitle: "Light weight to prepare muscles"
                    ) {
                        onSelect(.warmup)
                        dismiss()
                    }

                    SetTypeButton(
                        icon: "arrow.down.right",
                        iconColor: .purple,
                        title: "Drop Set",
                        subtitle: "Reduce weight and continue without rest"
                    ) {
                        onSelect(.dropSet)
                        dismiss()
                    }

                    SetTypeButton(
                        icon: "pause.circle",
                        iconColor: .green,
                        title: "Rest-Pause Set",
                        subtitle: "Brief pauses to extend the set"
                    ) {
                        onSelect(.restPause)
                        dismiss()
                    }
                } header: {
                    Text("Select Set Type")
                }
            }
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Set Type Button

private struct SetTypeButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 30)
                VStack(alignment: .leading) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Exercise History Section

struct ExerciseHistorySection: View {
    let history: [(date: Date, sets: [ExerciseSet])]
    @Binding var isExpanded: Bool
    let weightUnit: WeightUnit

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            historyHeader

            if isExpanded {
                historyContent
            }
        }
    }

    private var historyHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(history.count) session\(history.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(isExpanded ? 12 : 12, corners: isExpanded ? [.topLeft, .topRight] : .allCorners)
        }
        .buttonStyle(.plain)
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(history.enumerated()), id: \.offset) { index, session in
                HistorySessionRow(
                    session: session,
                    dateFormatter: dateFormatter,
                    weightUnit: weightUnit
                )

                if index < history.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
    }
}

// MARK: - History Session Row

private struct HistorySessionRow: View {
    let session: (date: Date, sets: [ExerciseSet])
    let dateFormatter: DateFormatter
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateFormatter.string(from: session.date))
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 16) {
                if let maxWeight = session.sets.compactMap({ $0.weight }).max() {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(formatWeight(maxWeight)) \(weightUnit.abbreviation)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sets")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(setsBreakdown(session.sets))
                        .font(.subheadline)
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    /// Format sets as "3×10 @ 135" style
    private func setsBreakdown(_ sets: [ExerciseSet]) -> String {
        var breakdown: [String] = []

        for set in sets {
            let reps = set.actualReps ?? set.targetReps
            if let weight = set.weight {
                breakdown.append("\(reps)×\(formatWeight(weight))")
            } else {
                breakdown.append("\(reps) reps")
            }
        }

        let uniqueBreakdowns = Set(breakdown)
        if uniqueBreakdowns.count == 1, let first = breakdown.first, sets.count > 1 {
            return "\(sets.count)×\(first.components(separatedBy: "×").last ?? first)"
        }

        return breakdown.joined(separator: ", ")
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
