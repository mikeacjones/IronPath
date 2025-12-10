import Foundation

// MARK: - Agent Communication Models

/// Represents a tool call from the LLM
struct ToolCall: Identifiable {
    let id: String
    let name: String
    let input: [String: Any]

    init(id: String, name: String, input: [String: Any]) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// Represents the result of executing a tool
struct ToolResult {
    let toolCallId: String
    let content: [String: Any]
    let isError: Bool

    init(toolCallId: String, content: [String: Any], isError: Bool = false) {
        self.toolCallId = toolCallId
        self.content = content
        self.isError = isError
    }

    /// Create a success result
    static func success(toolCallId: String, content: [String: Any]) -> ToolResult {
        ToolResult(toolCallId: toolCallId, content: content, isError: false)
    }

    /// Create an error result
    static func error(toolCallId: String, message: String, suggestion: String? = nil) -> ToolResult {
        var content: [String: Any] = ["error": message]
        if let suggestion = suggestion {
            content["suggestion"] = suggestion
        }
        return ToolResult(toolCallId: toolCallId, content: content, isError: true)
    }

    /// Convert content to JSON string for API response
    func contentAsJSON() -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: content),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

// MARK: - Agent Errors

/// Errors that can occur during agentic workout generation
enum AgentError: LocalizedError {
    case maxIterationsExceeded(Int)
    case unknownTool(String)
    case invalidToolInput(tool: String, reason: String)
    case workoutNotFinalized
    case noExercisesAdded
    case exerciseNotFound(String)
    case invalidExerciseIndex(Int)
    case networkError(Error)
    case parseError(String)
    case unexpectedResponse(String)
    case totalTimeoutExceeded

    var errorDescription: String? {
        switch self {
        case .maxIterationsExceeded(let count):
            return "Workout generation exceeded maximum iterations (\(count))"
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .invalidToolInput(let tool, let reason):
            return "Invalid input for \(tool): \(reason)"
        case .workoutNotFinalized:
            return "Workout was not finalized properly"
        case .noExercisesAdded:
            return "No exercises were added to the workout"
        case .exerciseNotFound(let name):
            return "Exercise not found: \(name)"
        case .invalidExerciseIndex(let index):
            return "Invalid exercise index: \(index)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError(let detail):
            return "Failed to parse response: \(detail)"
        case .unexpectedResponse(let detail):
            return "Unexpected response from LLM: \(detail)"
        case .totalTimeoutExceeded:
            return "Workout generation timed out"
        }
    }
}

// MARK: - Agent State

/// Tracks the state of an agentic conversation
enum AgentState {
    case idle
    case gathering          // Fetching user/gym data
    case planning           // Determining exercises
    case building           // Adding exercises and sets
    case finalizing         // Completing the workout
    case completed
    case failed(Error)

    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .gathering: return "Gathering information..."
        case .planning: return "Planning workout..."
        case .building: return "Building exercises..."
        case .finalizing: return "Finalizing..."
        case .completed: return "Complete"
        case .failed: return "Failed"
        }
    }
}

// MARK: - Agent Progress

/// Progress information for UI updates during generation
struct AgentProgress {
    let state: AgentState
    let iteration: Int
    let maxIterations: Int
    let exerciseCount: Int
    let lastToolCall: String?
    let message: String?

    var progressFraction: Double {
        guard maxIterations > 0 else { return 0 }
        return Double(iteration) / Double(maxIterations)
    }
}

// MARK: - Conversation Message Types

/// Types of messages in the agent conversation
enum AgentMessageRole: String {
    case system
    case user
    case assistant
    case toolResult = "tool_result"
}

/// A message in the agent conversation
struct AgentMessage {
    let role: AgentMessageRole
    let content: Any  // String or array of tool results
    let toolCalls: [ToolCall]?

    /// Create a system message
    static func system(_ content: String) -> AgentMessage {
        AgentMessage(role: .system, content: content, toolCalls: nil)
    }

    /// Create a user message
    static func user(_ content: String) -> AgentMessage {
        AgentMessage(role: .user, content: content, toolCalls: nil)
    }

    /// Create an assistant message with optional tool calls
    static func assistant(_ content: String, toolCalls: [ToolCall]? = nil) -> AgentMessage {
        AgentMessage(role: .assistant, content: content, toolCalls: toolCalls)
    }
}
