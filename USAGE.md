# Tuist SDK Usage Guide

Comprehensive usage examples and configuration options for the Tuist development SDK.

## Basic Setup

### Simple Initialization

```swift
import Tuist

@main
struct MyApp: App {
    init() {
        #if DEBUG
        Tuist.initialize()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Custom Configuration

```swift
// Using fluent API
Tuist.initialize(with: .options(
    mcp: .options(port: 8080, maxRequests: 100)
))

// Individual configuration methods
Tuist.initialize(with: .options(
    mcp: .port(9000)
))

Tuist.initialize(with: .options(
    mcp: .maxRequests(200)
))
```

## Command Line Port Configuration

The Tuist SDK supports overriding the MCP server port via command line arguments, making it perfect for development workflows with iOS Simulator and testing.

### Command Line Examples

```bash
# Default port (8080) from configuration
MyApp.app

# Override port to 9001 via command line
MyApp.app --tuist-mcp-port 9001

# Using with iOS Simulator
xcrun simctl launch booted com.company.MyApp --tuist-mcp-port 9001

# Using with Xcode Run
# Add "--tuist-mcp-port 9001" to your scheme's "Arguments Passed On Launch"
```

### Integration Testing

```bash
# Start your app with custom port
xcrun simctl launch booted com.company.MyApp --tuist-mcp-port 8888

# Access request history via MCP endpoint
curl http://localhost:8888/requests

# Or use MCP client tools to connect to localhost:8888
```

### Development Workflow

1. **Configure in Code**: Set a reasonable default port (e.g., 8080)
2. **Override During Testing**: Use `--tuist-mcp-port` to avoid conflicts
3. **Multiple Apps**: Run different apps on different ports simultaneously
4. **CI/CD**: Script port allocation for parallel test runs

### Xcode Scheme Configuration

To set the port permanently in Xcode:

1. Edit your app's scheme
2. Go to "Run" → "Arguments"
3. Add to "Arguments Passed On Launch":
   ```
   --tuist-mcp-port
   9001
   ```
4. The app will always start with port 9001 when run from Xcode

### Port Resolution Priority

1. **Command Line**: `--tuist-mcp-port 9001` (highest priority)
2. **Configuration**: `Tuist.MCPConfiguration.port(8080)` (fallback)

This allows flexible development while maintaining sensible defaults.

## Accessing Request History

### Request History API

```swift
// Get all requests
let allRequests = Tuist.requests.getAllRequests()

// Get recent requests
let recentRequests = Tuist.requests.getRecentRequests(count: 10)

// Filter by URL pattern
let apiRequests = Tuist.requests.getRequests(matching: "api.example.com")

// Filter by HTTP method
let postRequests = Tuist.requests.getRequests(method: "POST")

// Get failed requests
let failedRequests = Tuist.requests.getFailedRequests()

// Get requests within time range
let lastHourRequests = Tuist.requests.getRequests(
    from: Date().addingTimeInterval(-3600)
)
```

### Request Data Structure

Each intercepted request provides:

```swift
struct InterceptedRequest {
    let id: UUID
    let url: URL?
    let method: String
    let headers: [String: String]?
    let body: Data?
    let timestamp: Date
    let duration: TimeInterval
    let response: InterceptedResponse
}

struct InterceptedResponse {
    let statusCode: Int?
    let headers: [String: String]?
    let body: Data?
    let error: String?
}
```

## MCP Client Connection

The Tuist SDK now supports the Model Context Protocol (MCP) with HTTP transport. MCP clients can connect using HTTPClientTransport from the MCP Swift SDK.

### Connecting with MCP Swift SDK

```swift
import ModelContextProtocol

// Create HTTP transport to connect to Tuist MCP server
let transport = HTTPClientTransport(
    endpoint: URL(string: "http://localhost:8080")!,
    streaming: true  // Enable real-time updates via Server-Sent Events
)

// Initialize MCP client
let client = MCPClient()
try await client.connect(transport: transport)

// List available resources
let resources = try await client.listResources()
// Returns: ["tuist://requests"] - intercepted HTTP/HTTPS requests

// Read intercepted requests
let requestsData = try await client.readResource(uri: "tuist://requests")
```

### Direct HTTP API

You can also access the MCP server directly via HTTP:

```bash
# Get intercepted requests
curl http://localhost:8080/requests

# MCP protocol endpoints
curl -X POST http://localhost:8080/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "resources/list",
    "params": {}
  }'
```

### Server Features

- **HTTP Transport**: Full HTTP/1.1 server implementation using Network.framework
- **MCP Protocol**: Supports `resources/list` and `resources/read` methods
- **Request History**: Access intercepted HTTP/HTTPS requests via `tuist://requests` resource
- **JSON-RPC 2.0**: Standard MCP protocol communication
- **Streaming Support**: Compatible with Server-Sent Events for real-time updates

## MCP Server Access

The MCP server runs on the configured port (default: 8080) and provides:

- **Resource**: `tuist://requests` - Returns JSON array of all captured requests

Example MCP client request:
```
GET http://localhost:8080/resources/tuist://requests
```

## Cleanup

Stop the SDK when no longer needed:

```swift
Tuist.stop()
```

## Best Practices

1. Only initialize in DEBUG builds to avoid overhead in production
2. Configure appropriate `maxStoredRequests` based on your app's traffic
3. Clear request history periodically for long-running sessions
4. Use the MCP server for development tools integration

## Example Integration

```swift
import SwiftUI
import Tuist

@main
struct MyApp: App {
    init() {
        #if DEBUG
        Tuist.initialize()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```