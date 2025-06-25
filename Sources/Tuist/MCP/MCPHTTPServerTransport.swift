import Foundation
import Network
import MCP
import OSLog

/// HTTP server transport implementation for MCP Swift SDK
actor HTTPServerTransport: Transport {
    let logger = Logger(subsystem: "com.tuist.mcp", category: "HTTPServerTransport")
    
    private let port: Int
    private var listener: NWListener?
    private var connections: Set<NWConnection> = []
    private let queue = DispatchQueue(label: "com.tuist.mcp.http-server-transport")
    
    private var receiveStream: AsyncThrowingStream<Data, Swift.Error>?
    private var receiveStreamContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation?
    
    init(port: Int) {
        self.port = port
    }
    
    func connect() async throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        listener = try NWListener(using: parameters, on: nwPort)
        
        listener?.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleNewConnection(connection)
            }
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleListenerState(state)
            }
        }
        
        // Create the receive stream
        let (stream, continuation) = AsyncThrowingStream<Data, Swift.Error>.makeStream()
        receiveStream = stream
        receiveStreamContinuation = continuation
        
        listener?.start(queue: queue)
        logger.info("HTTP Server connecting on port \(self.port)")
    }
    
    func send(_ data: Data) async throws {
        // For HTTP, we send responses back to specific connections
        // This is handled in the request processing
        logger.debug("Sending data: \(data.count) bytes")
    }
    
    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        return receiveStream ?? AsyncThrowingStream { _ in }
    }
    
    func disconnect() async {
        listener?.cancel()
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        receiveStreamContinuation?.finish()
        logger.info("HTTP Server disconnected")
    }
    
    // MARK: - Private methods
    
    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("🚀 MCP HTTP Server listening on port \(self.port)")
        case .failed(let error):
            logger.error("❌ Server failed with error: \(error)")
            receiveStreamContinuation?.finish(throwing: error)
        case .cancelled:
            logger.info("🛑 Server cancelled")
        default:
            break
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connections.insert(connection)
        
        connection.stateUpdateHandler = { [weak self] state in
            Task {
                switch state {
                case .ready:
                    await self?.receiveData(from: connection)
                case .failed(let error):
                    self?.logger.error("Connection failed: \(error)")
                    await self?.removeConnection(connection)
                case .cancelled:
                    await self?.removeConnection(connection)
                default:
                    break
                }
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func removeConnection(_ connection: NWConnection) {
        connections.remove(connection)
    }
    
    private func receiveData(from connection: NWConnection) async {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task {
                if let data = data, !data.isEmpty {
                    await self?.handleHTTPRequest(data, connection: connection)
                }
                
                if isComplete {
                    connection.cancel()
                    await self?.removeConnection(connection)
                } else if error == nil {
                    await self?.receiveData(from: connection)
                }
            }
        }
    }
    
    private func handleHTTPRequest(_ data: Data, connection: NWConnection) async {
        guard let request = String(data: data, encoding: .utf8) else { return }
        
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        
        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2 else { return }
        
        let method = components[0]
        let path = components[1]
        
        if method == "POST" && path == "/" {
            // Extract JSON-RPC body from HTTP request
            let parts = request.components(separatedBy: "\r\n\r\n")
            if parts.count >= 2, let bodyData = parts[1].data(using: .utf8) {
                // Forward to MCP server via the receive stream
                receiveStreamContinuation?.yield(bodyData)
                
                // Send a basic HTTP response
                let response = createHTTPResponse(statusCode: 200, body: "OK")
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        } else if method == "GET" && path == "/requests" {
            // Legacy endpoint for direct access
            let requestsData = MCPEndpoints.getRequestHistory()
            let response = createHTTPResponse(data: requestsData, contentType: "application/json")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        } else {
            let response = createHTTPResponse(statusCode: 404, body: "Not Found")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
    
    private func createHTTPResponse(statusCode: Int = 200, body: String? = nil, data: Data? = nil, contentType: String = "text/plain") -> Data {
        let statusText = statusCode == 200 ? "OK" : statusCode == 404 ? "Not Found" : "Bad Request"
        
        var headers = [
            "HTTP/1.1 \(statusCode) \(statusText)",
            "Content-Type: \(contentType)",
            "Connection: close"
        ]
        
        var responseData: Data?
        if let data = data {
            responseData = data
            headers.append("Content-Length: \(data.count)")
        } else if let body = body {
            responseData = body.data(using: .utf8)
            headers.append("Content-Length: \(body.count)")
        } else {
            headers.append("Content-Length: 0")
        }
        
        var fullResponse = headers.joined(separator: "\r\n") + "\r\n\r\n"
        
        var finalData = fullResponse.data(using: .utf8) ?? Data()
        if let responseData = responseData {
            finalData.append(responseData)
        }
        
        return finalData
    }
}

extension NWConnection: @retroactive @unchecked Sendable, @retroactive Hashable {
    public static func == (lhs: NWConnection, rhs: NWConnection) -> Bool {
        return lhs === rhs
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}