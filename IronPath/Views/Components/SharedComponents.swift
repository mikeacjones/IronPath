import SwiftUI
import UIKit

// MARK: - Weight Formatting

/// Formats a weight value, showing decimals only when needed
/// - Parameter weight: The weight value to format
/// - Returns: A string representation (e.g., "45" for 45.0, "42.5" for 42.5)
func formatWeight(_ weight: Double) -> String {
    weight.truncatingRemainder(dividingBy: 1) == 0
        ? String(Int(weight))
        : String(format: "%.1f", weight)
}

// MARK: - Export Data

struct ExportData: Identifiable {
    let id = UUID()
    let content: String
    let filename: String

    var temporaryFileURL: URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write export file: \(error)")
            return nil
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
