<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/icon-dark.svg">
  <img src="docs/icon-light.svg" alt="Agent" width="100" align="right">
</picture>
<h1>Agent</h1>

[![Swift](https://github.com/tuist/agent/actions/workflows/swift.yml/badge.svg)](https://github.com/tuist/agent/actions/workflows/swift.yml)
![Swift Version](https://img.shields.io/badge/swift-6.1-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgray.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Agent is a Swift SDK for Apple applications that enables easy integration with various AI APIs (Claude, ChatGPT, and custom servers) to build agentic features. It provides a unified interface for different AI backends, allowing you to switch between providers or use your own server without changing your application code.

## Features

- 🔌 **Multiple Backend Support**: Claude (Anthropic), OpenAI/ChatGPT, and custom server backends
- 🔄 **Streaming Support**: Real-time streaming responses for better user experience
- 🔒 **Flexible Authentication**: Use API keys directly or proxy through your own server
- 💬 **Conversation Management**: Built-in conversation history and context management
- 🧪 **Fully Tested**: Comprehensive test suite using Swift Testing framework
- 📱 **Multi-Platform**: Works on iOS, macOS, tvOS, and watchOS

## Installation

### Swift Package Manager

Add Agent to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/tuist/agent.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies...
2. Enter: `https://github.com/tuist/agent.git`

## Usage

### Basic Usage with Claude

```swift
import Agent

// Create an agent with Claude backend
let agent = Agent.withClaude(
    apiKey: "your-api-key",
    model: "claude-3-opus-20240229", // optional, defaults to claude-3-opus
    systemPrompt: "You are a helpful assistant" // optional
)

// Send a message
let response = try await agent.sendMessage("Hello, Claude!")
print(response)

// Stream a response
for try await chunk in agent.streamMessage("Tell me a story") {
    print(chunk, terminator: "")
}
```

### Using OpenAI/ChatGPT

```swift
let agent = Agent.withOpenAI(
    apiKey: "your-openai-api-key",
    model: "gpt-4", // optional, defaults to gpt-4
    systemPrompt: "You are a creative writer"
)

let response = try await agent.sendMessage("Write a haiku about Swift")
```

### Using a Custom Server

Perfect for keeping your API keys secure on your server:

```swift
let agent = Agent.withCustomServer(
    baseURL: URL(string: "https://your-server.com/api")!,
    headers: ["Authorization": "Bearer your-auth-token"], // optional
    systemPrompt: "You are a domain expert"
)

let response = try await agent.sendMessage("Analyze this data...")
```

### Advanced Usage

```swift
// Access conversation history
let messages = agent.messages
for message in messages {
    print("\(message.role): \(message.content)")
}

// Clear conversation while keeping system prompt
agent.clearConversation()

// Get conversation ID
let conversationId = agent.conversationId
```

### Custom Backend Implementation

You can create your own backend by conforming to the `AgentBackend` protocol:

```swift
struct MyCustomBackend: AgentBackend {
    func sendMessage(_ message: String, conversation: Conversation) async throws -> String {
        // Your implementation
    }
    
    func streamMessage(_ message: String, conversation: Conversation) -> AsyncThrowingStream<String, Error> {
        // Your streaming implementation
    }
}

let customBackend = MyCustomBackend()
let agent = Agent(backend: customBackend)
```

## Server Implementation Guide

When using the custom server backend, your server should implement the following endpoints:

### POST /chat
- Request body: `{ conversationId: string, messages: [{ role: string, content: string }] }`
- Response: `{ content: string }`

### POST /chat/stream
- Request body: Same as `/chat`
- Response: Server-sent events (SSE) stream
- Event format: `data: { "content": "chunk" }\n\n`
- End stream with: `data: [DONE]\n\n`

## Error Handling

Agent provides specific error types for different scenarios:

```swift
do {
    let response = try await agent.sendMessage("Hello")
} catch AgentError.authenticationError {
    print("Invalid API key")
} catch AgentError.rateLimitExceeded {
    print("Rate limit hit, please wait")
} catch AgentError.networkError(let message) {
    print("Network error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Testing

Run the test suite:

```bash
swift test
```

## Requirements

- Swift 6.1+
- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+

## License

Agent is released under the MIT License. See [LICENSE](LICENSE) for details.

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## Acknowledgments

Built with ❤️ by the [Tuist](https://tuist.io) team.