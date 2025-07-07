import Foundation
import Agent

@main
struct ToolExample {
    static func main() async throws {
        // Create an agent with Claude backend
        let agent = Agent.withClaude(
            apiKey: ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? "",
            systemPrompt: "You are a helpful assistant with access to various tools."
        )
        
        // Add some tools
        agent.addTool(CalculatorTool())
        agent.addTool(FileReaderTool())
        agent.addTool(WebSearchTool())
        
        // Set up user input handler for interactive questions
        agent.setUserInputHandler { question in
            print("\n🤖 Assistant asks: \(question)")
            print("👤 Your response: ", terminator: "")
            return readLine() ?? ""
        }
        
        // Example 1: Simple calculation
        print("Example 1: Calculator Tool")
        let response1 = try await agent.sendMessage("What is 42 * 73?")
        print("Response: \(response1)\n")
        
        // Example 2: File reading
        print("Example 2: File Reader Tool")
        let response2 = try await agent.sendMessage("Can you read the contents of /etc/hosts file?")
        print("Response: \(response2)\n")
        
        // Example 3: Web search (mock)
        print("Example 3: Web Search Tool")
        let response3 = try await agent.sendMessage("Search the web for information about Swift concurrency")
        print("Response: \(response3)\n")
        
        // Example 4: User interaction tool
        let userTool = UserInputTool(agent: agent)
        agent.addTool(userTool)
        
        print("Example 4: User Interaction")
        let response4 = try await agent.sendMessage("I need to know the user's favorite programming language")
        print("Response: \(response4)\n")
        
        // Example 5: Streaming with tools
        print("Example 5: Streaming Response with Tools")
        print("Streaming: ", terminator: "")
        for try await chunk in agent.streamMessage("Calculate 123 + 456 and then search for Swift tutorials") {
            print(chunk, terminator: "")
            fflush(stdout)
        }
        print("\n")
    }
}