import Foundation

public struct UserInputTool: Tool {
    public let name = "ask_user"
    public let description = "Ask the user for input or clarification"
    
    public var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "question": PropertySchema(
                    type: "string",
                    description: "The question to ask the user"
                )
            ],
            required: ["question"]
        )
    }
    
    private weak var agent: Agent?
    
    public init(agent: Agent) {
        self.agent = agent
    }
    
    public func execute(input: [String: Any]) async throws -> String {
        guard let question = input["question"] as? String else {
            throw AgentError.invalidResponse
        }
        
        guard let agent = agent else {
            return "Error: Agent reference lost"
        }
        
        if let response = await agent.askUser(question) {
            return "User response: \(response)"
        } else {
            return "No user input handler configured"
        }
    }
}