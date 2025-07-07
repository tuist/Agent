import Testing
@testable import Agent
import Foundation

@Suite("Agent Tests")
struct AgentTests {
    
    @Test("Initialize agent with system prompt")
    @MainActor
    func testInitializeWithSystemPrompt() async throws {
        let backend = MockBackend()
        let agent = Agent(backend: backend, systemPrompt: "You are a helpful assistant")
        
        #expect(agent.messages.count == 1)
        #expect(agent.messages.first?.role == .system)
        #expect(agent.messages.first?.content == "You are a helpful assistant")
    }
    
    @Test("Initialize agent without system prompt")
    @MainActor
    func testInitializeWithoutSystemPrompt() async throws {
        let backend = MockBackend()
        let agent = Agent(backend: backend)
        
        #expect(agent.messages.isEmpty)
    }
    
    @Test("Send message")
    @MainActor
    func testSendMessage() async throws {
        let backend = MockBackend()
        await backend.setResponse("Hello from AI!")
        let agent = Agent(backend: backend)
        
        let response = try await agent.sendMessage("Hello")
        
        #expect(response == "Hello from AI!")
        #expect(agent.messages.count == 2)
        #expect(agent.messages[0].role == .user)
        #expect(agent.messages[0].content == "Hello")
        #expect(agent.messages[1].role == .assistant)
        #expect(agent.messages[1].content == "Hello from AI!")
    }
    
    @Test("Stream message")
    @MainActor
    func testStreamMessage() async throws {
        let backend = MockBackend()
        await backend.setStreamChunks(["Hello", " ", "streaming", "!"])
        let agent = Agent(backend: backend)
        
        var collectedChunks: [String] = []
        
        for try await chunk in agent.streamMessage("Test") {
            collectedChunks.append(chunk)
        }
        
        #expect(collectedChunks == ["Hello", " ", "streaming", "!"])
        #expect(agent.messages.count == 2)
        #expect(agent.messages[1].content == "Hello streaming!")
    }
    
    @Test("Clear conversation")
    @MainActor
    func testClearConversation() async throws {
        let backend = MockBackend()
        let agent = Agent(backend: backend, systemPrompt: "System prompt")
        
        _ = try await agent.sendMessage("Hello")
        _ = try await agent.sendMessage("How are you?")
        
        #expect(agent.messages.count == 5) // system + 2 user + 2 assistant
        
        agent.clearConversation()
        
        #expect(agent.messages.count == 1)
        #expect(agent.messages.first?.role == .system)
    }
    
    @Test("Error handling")
    @MainActor
    func testErrorHandling() async throws {
        let backend = MockBackend()
        await backend.setShouldThrowError(true)
        let agent = Agent(backend: backend)
        
        await #expect(throws: AgentError.invalidResponse) {
            _ = try await agent.sendMessage("Hello")
        }
    }
    
    @Test("Convenience initializers")
    @MainActor
    func testConvenienceInitializers() async throws {
        let claudeAgent = Agent.withClaude(apiKey: "test-key")
        #expect(claudeAgent.messages.isEmpty)
        
        let openAIAgent = Agent.withOpenAI(apiKey: "test-key", systemPrompt: "Be helpful")
        #expect(openAIAgent.messages.count == 1)
        
        let customAgent = Agent.withCustomServer(baseURL: URL(string: "https://example.com")!)
        #expect(customAgent.messages.isEmpty)
    }
}
