import Foundation

public protocol AgentBackend: Sendable {
    func sendMessage(_ message: String, conversation: Conversation) async throws -> String
    func streamMessage(_ message: String, conversation: Conversation) -> AsyncThrowingStream<String, Error>
}

public struct Conversation: Sendable {
    public let id: String
    public let messages: [Message]
    
    public init(id: String = UUID().uuidString, messages: [Message] = []) {
        self.id = id
        self.messages = messages
    }
}

public struct Message: Sendable {
    public enum Role: String, Sendable {
        case user
        case assistant
        case system
    }
    
    public let id: String
    public let role: Role
    public let content: String
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        role: Role,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

public enum AgentError: Error, Equatable {
    case invalidResponse
    case networkError(String)
    case authenticationError
    case rateLimitExceeded
    case serverError(String)
    case invalidConfiguration
    
    public static func == (lhs: AgentError, rhs: AgentError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse),
             (.authenticationError, .authenticationError),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.invalidConfiguration, .invalidConfiguration):
            return true
        case (.networkError(let lhsMessage), .networkError(let rhsMessage)),
             (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}