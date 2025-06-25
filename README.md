# Tuist SDK

A development SDK designed to enhance the developer experience for iOS and macOS applications by providing runtime intelligence and debugging tools.

## Features

- **Runtime Intelligence MCP Server**: Exposes application data through the Model Context Protocol for AI-powered development tools
- **Automatic Request Interception**: Captures all URLSession network requests for debugging and analysis
- **Zero Configuration**: Works with any URLSession-based networking out of the box
- **Development Workflow Integration**: Command-line port configuration for flexible testing environments

## Installation

Add the Tuist SDK to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tuist/sdk", from: "1.0.0")
]
```

## Quick Start

Initialize the SDK in your app's entry point (DEBUG builds only):

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

The MCP server will start on port 8080 by default, exposing intercepted network requests to development tools.

## Documentation

- **[USAGE.md](USAGE.md)**: Detailed configuration options, API reference, and integration examples
- **[MCP Client Connection Guide](USAGE.md#mcp-client-connection)**: How to connect development tools using the Model Context Protocol

## Development Use Only

This SDK is designed exclusively for development and debugging. Always wrap initialization in `#if DEBUG` to prevent inclusion in production builds.