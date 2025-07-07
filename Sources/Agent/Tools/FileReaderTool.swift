import Foundation

public struct FileReaderTool: Tool {
    public let name = "read_file"
    public let description = "Reads the contents of a file from the file system"
    
    public var inputSchema: ToolInputSchema {
        ToolInputSchema(
            properties: [
                "path": PropertySchema(
                    type: "string",
                    description: "The file path to read"
                )
            ],
            required: ["path"]
        )
    }
    
    public init() {}
    
    public func execute(input: [String: Any]) async throws -> String {
        guard let path = input["path"] as? String else {
            throw AgentError.invalidResponse
        }
        
        do {
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            return "File contents:\n\(contents)"
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}