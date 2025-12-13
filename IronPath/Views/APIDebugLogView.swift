import SwiftUI

/// View for displaying API debug logs
struct APIDebugLogView: View {
    @StateObject private var debugManager = APIDebugManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedEntry: APILogEntry?
    @State private var showingExportSheet = false
    @State private var showingClearConfirmation = false
    @State private var exportText = ""

    var body: some View {
        NavigationStack {
            Group {
                if debugManager.logs.isEmpty {
                    ContentUnavailableView(
                        "No API Logs",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("API requests will appear here when debug mode is enabled.")
                    )
                } else {
                    List {
                        ForEach(debugManager.logs) { entry in
                            APILogRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                        }
                    }
                }
            }
            .navigationTitle("API Debug Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            exportText = debugManager.exportLogs()
                            showingExportSheet = true
                        } label: {
                            Label("Export Logs", systemImage: "square.and.arrow.up")
                        }
                        .disabled(debugManager.logs.isEmpty)

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                        .disabled(debugManager.logs.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                APILogDetailView(entry: entry)
            }
            .sheet(isPresented: $showingExportSheet) {
                DebugShareSheet(items: [exportText])
            }
            .alert("Clear All Logs?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    debugManager.clearLogs()
                }
            } message: {
                Text("This will remove all API debug logs. This action cannot be undone.")
            }
        }
    }
}

/// Row view for a single log entry
struct APILogRow: View {
    let entry: APILogEntry

    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(entry.isSuccess ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.endpoint.replacingOccurrences(of: "https://api.anthropic.com/v1/", with: ""))
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(entry.formattedTimestamp)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let code = entry.responseStatusCode {
                        Text("\(code)")
                            .font(.caption)
                            .foregroundStyle(entry.isSuccess ? .green : .red)
                    }

                    Text(String(format: "%.2fs", entry.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Detail view for a single log entry
struct APILogDetailView: View {
    let entry: APILogEntry
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status header
                HStack {
                    Circle()
                        .fill(entry.isSuccess ? Color.green : Color.red)
                        .frame(width: 12, height: 12)

                    Text(entry.isSuccess ? "Success" : "Error")
                        .font(.headline)

                    Spacer()

                    if let code = entry.responseStatusCode {
                        Text("HTTP \(code)")
                            .font(.subheadline)
                            .foregroundStyle(entry.isSuccess ? .green : .red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // Info row
                HStack {
                    VStack(alignment: .leading) {
                        Text("Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.formattedTimestamp)
                            .font(.subheadline)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2fs", entry.duration))
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Tab picker
                Picker("View", selection: $selectedTab) {
                    Text("Request").tag(0)
                    Text("Response").tag(1)
                    if entry.error != nil {
                        Text("Error").tag(2)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                ScrollView {
                    switch selectedTab {
                    case 0:
                        RequestView(entry: entry)
                    case 1:
                        ResponseView(entry: entry)
                    case 2:
                        ErrorView(entry: entry)
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: formatEntryForExport(entry)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func formatEntryForExport(_ entry: APILogEntry) -> String {
        var output = "[\(entry.formattedTimestamp)] \(entry.method) \(entry.endpoint)\n"
        output += "Duration: \(String(format: "%.2f", entry.duration))s\n"

        if let code = entry.responseStatusCode {
            output += "Status: \(code)\n"
        }

        output += "\n--- REQUEST ---\n"
        output += formatJSON(entry.requestBody) + "\n"

        if let response = entry.responseBody {
            output += "\n--- RESPONSE ---\n"
            output += formatJSON(response) + "\n"
        }

        if let error = entry.error {
            output += "\n--- ERROR ---\n"
            output += error + "\n"
        }

        return output
    }

    private func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
}

/// Request tab content
struct RequestView: View {
    let entry: APILogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Endpoint
            VStack(alignment: .leading, spacing: 4) {
                Text("Endpoint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.endpoint)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(.horizontal)

            // Headers
            VStack(alignment: .leading, spacing: 4) {
                Text("Headers")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(entry.requestHeaders.keys.sorted()), id: \.self) { key in
                    HStack(alignment: .top) {
                        Text(key + ":")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if key.lowercased() == "x-api-key" {
                            Text("****" + (entry.requestHeaders[key]?.suffix(4) ?? ""))
                                .font(.system(.caption, design: .monospaced))
                        } else {
                            Text(entry.requestHeaders[key] ?? "")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Body
            VStack(alignment: .leading, spacing: 4) {
                Text("Body")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                JSONTextView(jsonString: entry.requestBody)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

/// Response tab content
struct ResponseView: View {
    let entry: APILogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let responseBody = entry.responseBody {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    JSONTextView(jsonString: responseBody)
                }
                .padding(.horizontal)
            } else {
                ContentUnavailableView(
                    "No Response",
                    systemImage: "exclamationmark.triangle",
                    description: Text("No response body was received.")
                )
            }
        }
        .padding(.vertical)
    }
}

/// Error tab content
struct ErrorView: View {
    let entry: APILogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = entry.error {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error Message")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(error)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

/// Formatted JSON text view
struct JSONTextView: View {
    let jsonString: String

    private var formattedJSON: String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }

    var body: some View {
        Text(formattedJSON)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

/// Share sheet for exporting debug logs
struct DebugShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    APIDebugLogView()
}
