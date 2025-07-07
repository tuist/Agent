import Foundation

@MainActor
public class Agent {
    private let backend: AgentBackend
    private var conversation: Conversation
    private var tools: [Tool]
    private var userInputHandler: ((String) async -> String)?
    
    public init(backend: AgentBackend, systemPrompt: String? = nil, tools: [Tool] = []) {
        self.backend = backend
        self.conversation = Conversation()
        self.tools = tools
        
        if let systemPrompt = systemPrompt {
            let systemMessage = Message(role: .system, content: systemPrompt)
            self.conversation = Conversation(messages: [systemMessage])
        }
    }
    
    public func addTool(_ tool: Tool) {
        tools.append(tool)
    }
    
    public func setUserInputHandler(_ handler: @escaping (String) async -> String) {
        self.userInputHandler = handler
    }
    
    public func sendMessage(_ message: String) async throws -> String {
        let userMessage = Message(role: .user, content: message)
        conversation = Conversation(
            id: conversation.id,
            messages: conversation.messages + [userMessage]
        )
        
        return try await runAgentLoop()
    }
    
    private func runAgentLoop() async throws -> String {
        var finalResponse = ""
        
        while true {
            let response = try await backend.sendMessage(
                conversation.messages.last?.content ?? "",
                conversation: conversation,
                tools: tools
            )
            
            if let content = response.content {
                finalResponse = content
                let assistantMessage = Message(role: .assistant, content: content, toolCalls: response.toolCalls)
                conversation = Conversation(
                    id: conversation.id,
                    messages: conversation.messages + [assistantMessage]
                )
            }
            
            if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                for toolCall in toolCalls {
                    let toolResult = await executeToolCall(toolCall)
                    let toolMessage = Message(
                        role: .tool,
                        content: toolResult.output,
                        toolCallId: toolCall.id
                    )
                    conversation = Conversation(
                        id: conversation.id,
                        messages: conversation.messages + [toolMessage]
                    )
                }
                continue
            }
            
            break
        }
        
        return finalResponse
    }
    
    private func executeToolCall(_ toolCall: ToolCall) async -> ToolResult {
        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            return ToolResult(
                toolCallId: toolCall.id,
                output: "Error: Tool '\(toolCall.name)' not found",
                isError: true
            )
        }
        
        do {
            let output = try await tool.execute(input: toolCall.input)
            return ToolResult(toolCallId: toolCall.id, output: output)
        } catch {
            return ToolResult(
                toolCallId: toolCall.id,
                output: "Error executing tool: \(error.localizedDescription)",
                isError: true
            )
        }
    }
    
    public func streamMessage(_ message: String) -> AsyncThrowingStream<String, Error> {
        let userMessage = Message(role: .user, content: message)
        conversation = Conversation(
            id: conversation.id,
            messages: conversation.messages + [userMessage]
        )
        
        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }
                
                do {
                    try await self.runStreamingAgentLoop { chunk in
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func runStreamingAgentLoop(onContent: @escaping (String) -> Void) async throws {
        var pendingToolCalls: [ToolCall] = []
        var fullResponse = ""
        
        while true {
            for try await chunk in backend.streamMessage(
                conversation.messages.last?.content ?? "",
                conversation: conversation,
                tools: tools
            ) {
                switch chunk {
                case .content(let text):
                    fullResponse += text
                    onContent(text)
                case .toolCall(let toolCall):
                    pendingToolCalls.append(toolCall)
                case .done:
                    break
                }
            }
            
            if !fullResponse.isEmpty || !pendingToolCalls.isEmpty {
                let assistantMessage = Message(
                    role: .assistant,
                    content: fullResponse.isEmpty ? nil : fullResponse,
                    toolCalls: pendingToolCalls.isEmpty ? nil : pendingToolCalls
                )
                await MainActor.run {
                    self.conversation = Conversation(
                        id: self.conversation.id,
                        messages: self.conversation.messages + [assistantMessage]
                    )
                }
            }
            
            if !pendingToolCalls.isEmpty {
                for toolCall in pendingToolCalls {
                    let toolResult = await executeToolCall(toolCall)
                    let toolMessage = Message(
                        role: .tool,
                        content: toolResult.output,
                        toolCallId: toolCall.id
                    )
                    await MainActor.run {
                        self.conversation = Conversation(
                            id: self.conversation.id,
                            messages: self.conversation.messages + [toolMessage]
                        )
                    }
                }
                pendingToolCalls = []
                fullResponse = ""
                continue
            }
            
            break
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
    
    public func askUser(_ prompt: String) async -> String? {
        guard let handler = userInputHandler else { return nil }
        return await handler(prompt)
    }
    
    public var messages: [Message] {
        conversation.messages
    }
    
    public var conversationId: String {
        conversation.id
    }
}

public extension Agent {
    static func withClaude(apiKey: String, model: String = "claude-3-opus-20240229", systemPrompt: String? = nil, tools: [Tool] = []) -> Agent {
        let backend = ClaudeBackend(apiKey: apiKey, model: model)
        return Agent(backend: backend, systemPrompt: systemPrompt, tools: tools)
    }
    
    static func withOpenAI(apiKey: String, model: String = "gpt-4", systemPrompt: String? = nil, tools: [Tool] = []) -> Agent {
        let backend = OpenAIBackend(apiKey: apiKey, model: model)
        return Agent(backend: backend, systemPrompt: systemPrompt, tools: tools)
    }
    
    static func withCustomServer(baseURL: URL, headers: [String: String] = [:], systemPrompt: String? = nil, tools: [Tool] = []) -> Agent {
        let backend = CustomServerBackend(baseURL: baseURL, headers: headers)
        return Agent(backend: backend, systemPrompt: systemPrompt, tools: tools)
    }
}