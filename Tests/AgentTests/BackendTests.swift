import Testing
@testable import Agent
import Foundation

@Suite("Backend Protocol Tests")
struct BackendTests {
    
    @Test("Message structure")
    func testMessageStructure() async throws {
        let message = Message(role: .user, content: "Hello")
        #expect(message.role == .user)
        #expect(message.content == "Hello")
        #expect(message.id.isEmpty == false)
        #expect(message.timestamp <= Date())
        
        // Test tool message
        let toolMessage = Message(role: .tool, content: "Tool result", toolCallId: "123")
        #expect(toolMessage.role == .tool)
        #expect(toolMessage.content == "Tool result")
        #expect(toolMessage.toolCallId == "123")
    }
    
    @Test("Conversation structure")
    func testConversationStructure() async throws {
        let messages = [
            Message(role: .system, content: "You are a helpful assistant"),
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "Hi there!")
        ]
        
        let conversation = Conversation(messages: messages)
        #expect(conversation.messages.count == 3)
        #expect(conversation.id.isEmpty == false)
    }
    
    @Test("Agent error cases")
    func testAgentErrors() async throws {
        let error1 = AgentError.invalidResponse
        let error2 = AgentError.authenticationError
        
        #expect(error1 == .invalidResponse)
        #expect(error2 != .invalidResponse)
        #expect(error1 != error2)
        
        let networkError1 = AgentError.networkError("Error 1")
        let networkError2 = AgentError.networkError("Error 1")
        let networkError3 = AgentError.networkError("Error 2")
        
        #expect(networkError1 == networkError2)
        #expect(networkError1 != networkError3)
    }
}

actor MockBackend: AgentBackend {
    private var shouldThrowError = false
    private var responseToReturn = BackendResponse(content: "Mock response")
    private var streamChunks: [StreamChunk] = [.content("Hello"), .content(" "), .content("World"), .content("!")]
    private var callCount = 0
    
    func setShouldThrowError(_ value: Bool) {
        shouldThrowError = value
    }
    
    func setResponse(_ response: String) {
        responseToReturn = BackendResponse(content: response)
    }
    
    func setResponseWithTools(_ response: BackendResponse) {
        responseToReturn = response
    }
    
    func setStreamChunks(_ chunks: [String]) {
        streamChunks = chunks.map { .content($0) }
    }
    
    func sendMessage(_ message: String, conversation: Conversation, tools: [Tool]) async throws -> BackendResponse {
        if shouldThrowError {
            throw AgentError.invalidResponse
        }
        
        // For the tool test, return tool call on first call, then final response
        callCount += 1
        if callCount == 1 && responseToReturn.toolCalls != nil {
            return responseToReturn
        } else if callCount > 1 && responseToReturn.toolCalls != nil {
            // After tool execution, return a final response
            return BackendResponse(content: "Tool executed successfully")
        }
        
        return responseToReturn
    }
    
    nonisolated func streamMessage(_ message: String, conversation: Conversation, tools: [Tool]) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                let shouldThrow = await self.shouldThrowError
                let chunks = await self.streamChunks
                
                if shouldThrow {
                    continuation.finish(throwing: AgentError.invalidResponse)
                    return
                }
                
                for chunk in chunks {
                    continuation.yield(chunk)
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                continuation.finish()
            }
        }
    }
}