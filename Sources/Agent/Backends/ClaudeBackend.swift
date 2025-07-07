import Foundation

public struct ClaudeBackend: AgentBackend {
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let session: URLSession
    
    public init(
        apiKey: String,
        model: String = "claude-3-opus-20240229",
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.session = session
    }
    
    public func sendMessage(_ message: String, conversation: Conversation, tools: [Tool]) async throws -> BackendResponse {
        let request = try createRequest(messages: conversation.messages, tools: tools)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try parseResponse(data)
        case 401:
            throw AgentError.authenticationError
        case 429:
            throw AgentError.rateLimitExceeded
        case 500...599:
            throw AgentError.serverError("Server error: \(httpResponse.statusCode)")
        default:
            throw AgentError.networkError("Bad server response: \(httpResponse.statusCode)")
        }
    }
    
    public func streamMessage(_ message: String, conversation: Conversation, tools: [Tool]) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try createStreamRequest(messages: conversation.messages, tools: tools)
                    
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: AgentError.invalidResponse)
                        return
                    }
                    
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if let data = jsonString.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(ClaudeStreamEvent.self, from: data) {
                                if let text = chunk.delta?.text {
                                    continuation.yield(.content(text))
                                } else if let toolUse = chunk.content_block {
                                    if toolUse.type == "tool_use" {
                                        let toolCall = ToolCall(
                                            id: toolUse.id ?? UUID().uuidString,
                                            name: toolUse.name ?? "",
                                            input: toolUse.input ?? [:]
                                        )
                                        continuation.yield(.toolCall(toolCall))
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func createRequest(messages: [Message], tools: [Tool] = []) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("/v1/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let claudeMessages = messages.compactMap { message -> ClaudeMessage? in
            if message.role == .tool {
                return ClaudeMessage(
                    role: "user",
                    content: [
                        ClaudeContent(
                            type: "tool_result",
                            tool_use_id: message.toolCallId,
                            content: message.content
                        )
                    ]
                )
            } else if let content = message.content {
                var contents: [ClaudeContent] = [ClaudeContent(type: "text", text: content)]
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        contents.append(ClaudeContent(
                            type: "tool_use",
                            id: toolCall.id,
                            name: toolCall.name,
                            input: toolCall.input
                        ))
                    }
                }
                return ClaudeMessage(role: message.role.rawValue, content: contents)
            }
            return nil
        }
        
        let requestBody = ClaudeRequest(
            model: model,
            messages: claudeMessages,
            max_tokens: 4096,
            tools: tools.map { tool in
                ClaudeTool(
                    name: tool.name,
                    description: tool.description,
                    input_schema: tool.inputSchema
                )
            }
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
    
    private func createStreamRequest(messages: [Message], tools: [Tool] = []) throws -> URLRequest {
        var request = try createRequest(messages: messages, tools: tools)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        if let body = request.httpBody,
           var requestBody = try? JSONDecoder().decode(ClaudeRequest.self, from: body) {
            requestBody.stream = true
            request.httpBody = try JSONEncoder().encode(requestBody)
        }
        
        return request
    }
    
    private func parseResponse(_ data: Data) throws -> BackendResponse {
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        
        var responseText: String?
        var toolCalls: [ToolCall] = []
        
        for content in response.content {
            if content.type == "text" {
                responseText = content.text
            } else if content.type == "tool_use" {
                let toolCall = ToolCall(
                    id: content.id ?? UUID().uuidString,
                    name: content.name ?? "",
                    input: content.input ?? [:]
                )
                toolCalls.append(toolCall)
            }
        }
        
        return BackendResponse(
            content: responseText,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )
    }
}

private struct ClaudeRequest: Codable {
    let model: String
    let messages: [ClaudeMessage]
    let max_tokens: Int
    var stream: Bool = false
    let tools: [ClaudeTool]?
}

private struct ClaudeMessage: Codable {
    let role: String
    let content: [ClaudeContent]
}

private struct ClaudeContent: Codable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: Any]?
    let tool_use_id: String?
    let content: String?
    
    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, tool_use_id, content
    }
    
    init(type: String, text: String? = nil, id: String? = nil, name: String? = nil, input: [String: Any]? = nil, tool_use_id: String? = nil, content: String? = nil) {
        self.type = type
        self.text = text
        self.id = id
        self.name = name
        self.input = input
        self.tool_use_id = tool_use_id
        self.content = content
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        if let input = input {
            try container.encode(input.mapValues { AnyCodable($0) }, forKey: .input)
        }
        try container.encodeIfPresent(tool_use_id, forKey: .tool_use_id)
        try container.encodeIfPresent(content, forKey: .content)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        if let inputDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .input) {
            input = inputDict.mapValues { $0.value }
        } else {
            input = nil
        }
        tool_use_id = try container.decodeIfPresent(String.self, forKey: .tool_use_id)
        content = try container.decodeIfPresent(String.self, forKey: .content)
    }
}

private struct ClaudeTool: Codable {
    let name: String
    let description: String
    let input_schema: ToolInputSchema
}

private struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
}

private struct ClaudeStreamEvent: Decodable {
    let type: String?
    let delta: Delta?
    let content_block: ContentBlock?
    
    struct Delta: Codable {
        let text: String?
    }
    
    struct ContentBlock: Decodable {
        let type: String?
        let id: String?
        let name: String?
        let input: [String: Any]?
        
        enum CodingKeys: String, CodingKey {
            case type, id, name, input
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            if let inputDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .input) {
                input = inputDict.mapValues { $0.value }
            } else {
                input = nil
            }
        }
    }
}