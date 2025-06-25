import Foundation
import MCP

/// MCP server that provides endpoints for request history using the MCP Swift SDK
final class MCPServer: @unchecked Sendable {
    static let shared = MCPServer()
    
    private var server: Server?
    private var transport: HTTPServerTransport?
    private let serverQueue = DispatchQueue(label: "com.tuist.mcp-server")
    
    private init() {}
    
    func start(port: Int) {
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            
            Task {
                do {
                    let actualPort = self.resolvePort(configuredPort: port)
                    await self.startServer(port: actualPort)
                } catch {
                    print("❌ Failed to start MCP server: \(error)")
                }
            }
        }
    }
    
    private func startServer(port: Int) async {
        do {
            // Create HTTP server transport
            transport = HTTPServerTransport(port: port)
            
            // Create MCP server with resources capability
            let configuration = Server.Configuration.default
            
            server = Server(
                name: "Tuist",
                version: "1.0.0",
                configuration: configuration
            )
            
            // Register resources/list handler
            server = server?.withMethodHandler(ListResources.self) { [weak self] _ in
                return [
                    Resource(
                        name: "Intercepted Requests",
                        uri: "tuist://requests",
                        description: "HTTP/HTTPS requests intercepted by Tuist SDK",
                        mimeType: "application/json"
                    )
                ]
            }
            
            // Register resources/read handler
            server = server?.withMethodHandler(ReadResource.self) { [weak self] parameters in
                if parameters.uri == "tuist://requests" {
                    let requests = RequestInterceptor.shared.history.getAllRequests()
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    
                    do {
                        let jsonData = try encoder.encode(requests)
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                        
                        return [
                            Resource.Content(
                                uri: parameters.uri,
                                mimeType: "application/json",
                                text: jsonString
                            )
                        ]
                    } catch {
                        throw MCPError.internalError("Failed to encode requests: \(error.localizedDescription)")
                    }
                } else {
                    throw MCPError.invalidRequest("Unknown resource URI: \(parameters.uri)")
                }
            }
            
            // Start the server
            guard let transport = transport, let server = server else {
                throw MCPError.internalError("Failed to initialize server components")
            }
            
            try await transport.connect()
            try await server.start(transport: transport)
            print("🚀 Tuist MCP Server started on port \(port)")
            print("📡 MCP clients can connect using HTTPClientTransport to http://localhost:\(port)")
            
        } catch {
            print("❌ Failed to start MCP server: \(error)")
        }
    }
    
    /// Resolves the actual port to use, prioritizing command line arguments over configuration
    private func resolvePort(configuredPort: Int) -> Int {
        // Check for command line argument first
        let arguments = ProcessInfo.processInfo.arguments
        
        if let portIndex = arguments.firstIndex(of: "--tuist-mcp-port"),
           portIndex + 1 < arguments.count,
           let argPort = Int(arguments[portIndex + 1]) {
            print("📍 Using MCP port from command line argument: \(argPort)")
            return argPort
        }
        
        // Fall back to configured port
        return configuredPort
    }
    
    func stop() {
        serverQueue.async { [weak self] in
            Task {
                await self?.server?.stop()
                await self?.transport?.disconnect()
                self?.server = nil
                self?.transport = nil
                print("🛑 Tuist MCP Server stopped")
            }
        }
    }
}

/// MCP-compatible resource endpoints (kept for backward compatibility)
enum MCPEndpoints {
    static func getRequestHistory() -> Data {
        let requests = RequestInterceptor.shared.history.getAllRequests()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            return try encoder.encode(MCPResourceResponse(requests: requests))
        } catch {
            let errorResponse = MCPErrorResponse(error: error.localizedDescription)
            return (try? encoder.encode(errorResponse)) ?? Data()
        }
    }
}

/// MCP response structures (kept for backward compatibility)
struct MCPResourceResponse: Codable {
    let requests: [InterceptedRequest]
    let timestamp: Date
    let count: Int
    
    init(requests: [InterceptedRequest]) {
        self.requests = requests
        self.timestamp = Date()
        self.count = requests.count
    }
}

struct MCPErrorResponse: Codable {
    let error: String
    let timestamp: Date
    
    init(error: String) {
        self.error = error
        self.timestamp = Date()
    }
}