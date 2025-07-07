import Foundation

public struct CustomServerBackend: AgentBackend {
    private let baseURL: URL
    private let headers: [String: String]
    private let session: URLSession
    
    public init(
        baseURL: URL,
        headers: [String: String] = [:],
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.headers = headers
        self.session = session
    }
    
    public func sendMessage(_ message: String, conversation: Conversation, tools: [Tool]) async throws -> BackendResponse {
        let request = try createRequest(message: message, conversation: conversation)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let content = try parseResponse(data)
            return BackendResponse(content: content)
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
                    let request = try createStreamRequest(message: message, conversation: conversation)
                    
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
                               let chunk = try? JSONDecoder().decode(CustomStreamChunk.self, from: data) {
                                continuation.yield(.content(chunk.content))
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
    
    private func createRequest(message: String, conversation: Conversation) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let requestBody = CustomServerRequest(
            conversationId: conversation.id,
            messages: conversation.messages.compactMap { message -> CustomMessage? in
                guard let content = message.content else { return nil }
                return CustomMessage(role: message.role.rawValue, content: content)
            }
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
    
    private func createStreamRequest(message: String, conversation: Conversation) throws -> URLRequest {
        var request = try createRequest(message: message, conversation: conversation)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let url = baseURL.appendingPathComponent("/chat/stream")
        request.url = url
        
        return request
    }
    
    private func parseResponse(_ data: Data) throws -> String {
        let response = try JSONDecoder().decode(CustomServerResponse.self, from: data)
        return response.content
    }
}

private struct CustomServerRequest: Codable {
    let conversationId: String
    let messages: [CustomMessage]
}

private struct CustomMessage: Codable {
    let role: String
    let content: String
}

private struct CustomServerResponse: Codable {
    let content: String
}

private struct CustomStreamChunk: Codable {
    let content: String
}