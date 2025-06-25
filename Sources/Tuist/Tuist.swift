import Foundation

/// The main entry point for the Tuist SDK
public enum Tuist {
    /// MCP Server configuration
    public struct MCPConfiguration {
        /// Port for the MCP server (default: 8080)
        public let port: Int
        
        /// Maximum number of requests to store in memory
        public let maxStoredRequests: Int
        
        public init(
            port: Int = 8080,
            maxStoredRequests: Int = 100
        ) {
            self.port = port
            self.maxStoredRequests = maxStoredRequests
        }
        
        /// Create MCP configuration with custom port
        public static func port(_ port: Int) -> MCPConfiguration {
            MCPConfiguration(port: port)
        }
        
        /// Create MCP configuration with custom request limit
        public static func maxRequests(_ maxRequests: Int) -> MCPConfiguration {
            MCPConfiguration(maxStoredRequests: maxRequests)
        }
        
        /// Create MCP configuration with custom port and request limit
        public static func options(port: Int = 8080, maxRequests: Int = 100) -> MCPConfiguration {
            MCPConfiguration(port: port, maxStoredRequests: maxRequests)
        }
    }
    
    /// Configuration for the Tuist SDK
    public struct Configuration {
        /// MCP server configuration
        public let mcp: MCPConfiguration
        
        public init(mcp: MCPConfiguration = MCPConfiguration()) {
            self.mcp = mcp
        }
        
        /// Create configuration with MCP options
        public static func options(mcp: MCPConfiguration = MCPConfiguration()) -> Configuration {
            Configuration(mcp: mcp)
        }
    }
    
    /// Initialize the Tuist SDK
    /// - Parameter configuration: SDK configuration
    public static func initialize(with configuration: Configuration = Configuration()) {
        // Start MCP server
        MCPServer.shared.start(port: configuration.mcp.port)
        
        // Configure request interception
        RequestInterceptor.shared.configure(maxStoredRequests: configuration.mcp.maxStoredRequests)
        RequestInterceptor.shared.startIntercepting()
    }
    
    /// Stop the SDK (useful for cleanup in development)
    public static func stop() {
        MCPServer.shared.stop()
        RequestInterceptor.shared.stopIntercepting()
    }
    
    /// Access to the request history
    public static var requests: RequestHistory {
        RequestInterceptor.shared.history
    }
}