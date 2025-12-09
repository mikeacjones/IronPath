import Foundation
import Combine

/// Represents a single API request/response log entry
struct APILogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let endpoint: String
    let method: String
    let requestHeaders: [String: String]
    let requestBody: String
    let responseStatusCode: Int?
    let responseHeaders: [String: String]?
    let responseBody: String?
    let error: String?
    let duration: TimeInterval

    init(
        endpoint: String,
        method: String,
        requestHeaders: [String: String],
        requestBody: String,
        responseStatusCode: Int? = nil,
        responseHeaders: [String: String]? = nil,
        responseBody: String? = nil,
        error: String? = nil,
        duration: TimeInterval = 0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.endpoint = endpoint
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseStatusCode = responseStatusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.error = error
        self.duration = duration
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var isSuccess: Bool {
        guard let code = responseStatusCode else { return false }
        return code >= 200 && code < 300
    }
}

/// Manages debug mode state and API log collection
class APIDebugManager: ObservableObject {
    static let shared = APIDebugManager()

    private let debugModeKey = "api_debug_mode_enabled"

    @Published var isDebugEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDebugEnabled, forKey: debugModeKey)
            if !isDebugEnabled {
                clearLogs()
            }
        }
    }

    @Published private(set) var logs: [APILogEntry] = []

    private init() {
        self.isDebugEnabled = UserDefaults.standard.bool(forKey: debugModeKey)
    }

    /// Add a log entry (only if debug mode is enabled)
    func log(_ entry: APILogEntry) {
        guard isDebugEnabled else { return }
        DispatchQueue.main.async {
            self.logs.insert(entry, at: 0) // Most recent first
            // Keep only last 100 entries to prevent memory issues
            if self.logs.count > 100 {
                self.logs = Array(self.logs.prefix(100))
            }
        }
    }

    /// Clear all logs
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }

    /// Export logs as formatted text
    func exportLogs() -> String {
        var output = "IronPath API Debug Log\n"
        output += "Exported: \(Date().formatted())\n"
        output += "Total Entries: \(logs.count)\n"
        output += String(repeating: "=", count: 60) + "\n\n"

        for entry in logs {
            output += "[\(entry.formattedTimestamp)] \(entry.method) \(entry.endpoint)\n"
            output += "Duration: \(String(format: "%.2f", entry.duration))s\n"

            if let code = entry.responseStatusCode {
                output += "Status: \(code) \(entry.isSuccess ? "OK" : "ERROR")\n"
            }

            output += "\n--- REQUEST HEADERS ---\n"
            for (key, value) in entry.requestHeaders {
                // Mask API key in export
                if key.lowercased() == "x-api-key" {
                    output += "\(key): ****\(value.suffix(4))\n"
                } else {
                    output += "\(key): \(value)\n"
                }
            }

            output += "\n--- REQUEST BODY ---\n"
            output += formatJSON(entry.requestBody) + "\n"

            if let responseBody = entry.responseBody {
                output += "\n--- RESPONSE BODY ---\n"
                output += formatJSON(responseBody) + "\n"
            }

            if let error = entry.error {
                output += "\n--- ERROR ---\n"
                output += error + "\n"
            }

            output += "\n" + String(repeating: "-", count: 60) + "\n\n"
        }

        return output
    }

    /// Export logs as JSON
    func exportLogsAsJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(logs)
    }

    /// Format JSON string for readability
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
