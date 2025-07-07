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
    
    public func sendMessage(_ message: String, conversation: Conversation) async throws -> String {
        let messages = conversation.messages + [Message(role: .user, content: message)]
        let request = try createRequest(messages: messages)
        
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
    
    public func streamMessage(_ message: String, conversation: Conversation) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let messages = conversation.messages + [Message(role: .user, content: message)]
                    let request = try createStreamRequest(messages: messages)
                    
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
                               let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                               let text = chunk.delta?.text {
                                continuation.yield(text)
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
    
    private func createRequest(messages: [Message]) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("/v1/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody = ClaudeRequest(
            model: model,
            messages: messages.map { ClaudeMessage(role: $0.role.rawValue, content: $0.content) },
            max_tokens: 4096
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
    
    private func createStreamRequest(messages: [Message]) throws -> URLRequest {
        var request = try createRequest(messages: messages)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let requestBody = ClaudeRequest(
            model: model,
            messages: messages.map { ClaudeMessage(role: $0.role.rawValue, content: $0.content) },
            max_tokens: 4096,
            stream: true
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
    
    private func parseResponse(_ data: Data) throws -> String {
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return response.content.first?.text ?? ""
    }
}

private struct ClaudeRequest: Codable {
    let model: String
    let messages: [ClaudeMessage]
    let max_tokens: Int
    var stream: Bool = false
}

private struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

private struct ClaudeResponse: Codable {
    let content: [Content]
    
    struct Content: Codable {
        let text: String
    }
}

private struct StreamChunk: Codable {
    let delta: Delta?
    
    struct Delta: Codable {
        let text: String?
    }
}