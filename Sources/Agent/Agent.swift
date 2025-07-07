import Foundation

@MainActor
public class Agent {
    private let backend: AgentBackend
    private var conversation: Conversation
    
    public init(backend: AgentBackend, systemPrompt: String? = nil) {
        self.backend = backend
        self.conversation = Conversation()
        
        if let systemPrompt = systemPrompt {
            let systemMessage = Message(role: .system, content: systemPrompt)
            self.conversation = Conversation(messages: [systemMessage])
        }
    }
    
    public func sendMessage(_ message: String) async throws -> String {
        let userMessage = Message(role: .user, content: message)
        conversation = Conversation(
            id: conversation.id,
            messages: conversation.messages + [userMessage]
        )
        
        let response = try await backend.sendMessage(message, conversation: conversation)
        
        let assistantMessage = Message(role: .assistant, content: response)
        conversation = Conversation(
            id: conversation.id,
            messages: conversation.messages + [assistantMessage]
        )
        
        return response
    }
    
    public func streamMessage(_ message: String) -> AsyncThrowingStream<String, Error> {
        let userMessage = Message(role: .user, content: message)
        conversation = Conversation(
            id: conversation.id,
            messages: conversation.messages + [userMessage]
        )
        
        var fullResponse = ""
        
        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }
                
                do {
                    for try await chunk in self.backend.streamMessage(message, conversation: self.conversation) {
                        fullResponse += chunk
                        continuation.yield(chunk)
                    }
                    
                    let assistantMessage = Message(role: .assistant, content: fullResponse)
                    await MainActor.run {
                        self.conversation = Conversation(
                            id: self.conversation.id,
                            messages: self.conversation.messages + [assistantMessage]
                        )
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func clearConversation() {
        let systemMessage = conversation.messages.first { $0.role == .system }
        if let systemMessage = systemMessage {
            conversation = Conversation(messages: [systemMessage])
        } else {
            conversation = Conversation()
        }
    }
    
    public var messages: [Message] {
        conversation.messages
    }
    
    public var conversationId: String {
        conversation.id
    }
}

public extension Agent {
    static func withClaude(apiKey: String, model: String = "claude-3-opus-20240229", systemPrompt: String? = nil) -> Agent {
        let backend = ClaudeBackend(apiKey: apiKey, model: model)
        return Agent(backend: backend, systemPrompt: systemPrompt)
    }
    
    static func withOpenAI(apiKey: String, model: String = "gpt-4", systemPrompt: String? = nil) -> Agent {
        let backend = OpenAIBackend(apiKey: apiKey, model: model)
        return Agent(backend: backend, systemPrompt: systemPrompt)
    }
    
    static func withCustomServer(baseURL: URL, headers: [String: String] = [:], systemPrompt: String? = nil) -> Agent {
        let backend = CustomServerBackend(baseURL: baseURL, headers: headers)
        return Agent(backend: backend, systemPrompt: systemPrompt)
    }
}