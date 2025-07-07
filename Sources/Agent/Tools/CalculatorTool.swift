import Foundation

public struct CalculatorTool: Tool {
    public let name = "calculator"
    public let description = "Performs basic mathematical calculations"
    
    public var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "expression": PropertySchema(
                    type: "string",
                    description: "Mathematical expression to evaluate (e.g., '2 + 2', '10 * 5')"
                )
            ],
            required: ["expression"]
        )
    }
    
    public init() {}
    
    public func execute(input: [String: Any]) async throws -> String {
        guard let expression = input["expression"] as? String else {
            throw AgentError.invalidResponse
        }
        
        let mathExpression = NSExpression(format: expression)
        guard let result = mathExpression.expressionValue(with: nil, context: nil) else {
            throw AgentError.invalidResponse
        }
        
        return "The result of \(expression) is \(result)"
    }
}