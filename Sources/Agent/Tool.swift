import Foundation

public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: ToolInputSchema { get }
    
    func execute(input: [String: Any]) async throws -> String
}

public struct ToolInputSchema: Sendable, Codable {
    public let type: String
    public let properties: [String: PropertySchema]
    public let required: [String]
    
    public init(
        type: String = "object",
        properties: [String: PropertySchema],
        required: [String] = []
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

public struct PropertySchema: Sendable, Codable {
    public let type: String
    public let description: String?
    public let enumValues: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }
    
    public init(
        type: String,
        description: String? = nil,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }
}

public struct ToolCall: Sendable, Codable {
    public let id: String
    public let name: String
    private let _input: [String: AnyCodable]
    
    public var input: [String: Any] {
        _input.mapValues { $0.value }
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        input: [String: Any]
    ) {
        self.id = id
        self.name = name
        self._input = input.mapValues { AnyCodable($0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case _input = "input"
    }
}

public struct ToolResult: Sendable {
    public let toolCallId: String
    public let output: String
    public let isError: Bool
    
    public init(
        toolCallId: String,
        output: String,
        isError: Bool = false
    ) {
        self.toolCallId = toolCallId
        self.output = output
        self.isError = isError
    }
}

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}