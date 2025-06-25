# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Swift Package Manager
```bash
# Build the package
swift build

# Run tests 
swift test

# Build and run a specific test
swift test --filter TuistTests

# Run tests for a specific target
swift test --filter RequestHistoryTests
```

### Tuist Project Management
This project uses Tuist for Xcode project generation:

```bash
# Generate Xcode project (requires Tuist CLI)
tuist generate

# Clean generated files
tuist clean

# Install dependencies
tuist install
```

### MCP Server Port Override
The MCP server port can be overridden via command line:
```bash
# Override MCP port to 9001 when testing
--tuist-mcp-port 9001

# For iOS Simulator testing
xcrun simctl launch booted io.tuist.TuistApp --tuist-mcp-port 9001
```

## Architecture Overview

### Core Components

**Main SDK Entry Point (`Sources/Tuist/Tuist.swift`)**
- Public API with fluent configuration
- Coordinates MCP server and request interceptor initialization
- Provides access to captured request history via `Tuist.requests`

**Request Interception System**
- `RequestInterceptor`: Uses URLProtocol swizzling to capture all URLSession traffic
- `RequestHistory`: Thread-safe storage with configurable limits and filtering capabilities
- Automatically captures request/response data, timing, and errors

**MCP Server Implementation**
- `MCPServer`: Orchestrates the MCP server lifecycle using MCP Swift SDK
- `MCPHTTPServerTransport`: Custom HTTP transport implementing the MCP SDK's Transport protocol
- Exposes intercepted requests via `tuist://requests` resource for MCP clients
- Supports both MCP protocol (JSON-RPC 2.0) and legacy HTTP GET endpoints

### Key Design Patterns

**Configuration Architecture**: Fluent API design allows chaining:
```swift
Tuist.initialize(with: .options(mcp: .options(port: 8080, maxRequests: 100)))
```

**Dual Transport Support**: 
- Native MCP protocol for MCP clients using HTTPClientTransport
- Legacy HTTP endpoints for direct browser/curl access
- Both share the same underlying request history data

**URLProtocol Integration**: The interceptor hooks into the iOS/macOS networking stack at the URLProtocol level, capturing requests from any URLSession-based networking (URLSession, Alamofire, etc.)

### Directory Structure

```
Sources/Tuist/
├── Tuist.swift                    # Main SDK entry point
├── MCP/
│   ├── MCPServer.swift           # MCP server orchestration
│   └── MCPHTTPServerTransport.swift # Custom HTTP transport for MCP SDK
└── RequestInterceptor/
    ├── RequestInterceptor.swift  # URLProtocol-based interception
    └── RequestHistory.swift      # Thread-safe request storage
```

### Dependencies

- **MCP Swift SDK**: Used for proper MCP protocol implementation
- **Network.framework**: Powers the HTTP server transport
- **Foundation URLProtocol**: Core mechanism for request interception

### Testing Framework

Uses Swift Testing framework (not XCTest). Test files use `@Test` annotations and `#expect` assertions.

### Port Resolution Priority

1. `--tuist-mcp-port` command line argument (highest)
2. `MCPConfiguration.port` in code (fallback)

This design enables flexible development workflows where the same app binary can run on different ports for parallel testing.

## Documentation Updates

When making changes to the SDK's public API, configuration options, or usage patterns, ensure that both documentation files are updated:

- **README.md**: Update for API changes, new features, configuration options, or usage examples
- **USAGE.md**: Update for detailed usage examples, MCP client connection instructions, or command-line options

Both files should remain in sync to provide consistent documentation for users.