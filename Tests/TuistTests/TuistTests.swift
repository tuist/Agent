import Testing
@testable import Tuist

@Suite("Tuist SDK Tests")
struct TuistTests {
    
    @Test("SDK initialization creates default configuration")
    func testSDKInitialization() {
        // Test that we can create a default configuration
        let config = Tuist.Configuration()
        #expect(config.mcp.port == 8080)
        #expect(config.mcp.maxStoredRequests == 100)
    }
    
    @Test("SDK configuration with custom MCP settings")
    func testCustomMCPConfiguration() {
        let mcpConfig = Tuist.MCPConfiguration.options(port: 9000, maxRequests: 200)
        let config = Tuist.Configuration.options(mcp: mcpConfig)
        
        #expect(config.mcp.port == 9000)
        #expect(config.mcp.maxStoredRequests == 200)
    }
    
    @Test("MCP configuration factory methods")
    func testMCPConfigurationFactoryMethods() {
        // Test port factory method
        let portConfig = Tuist.MCPConfiguration.port(3000)
        #expect(portConfig.port == 3000)
        #expect(portConfig.maxStoredRequests == 100) // default
        
        // Test maxRequests factory method
        let maxRequestsConfig = Tuist.MCPConfiguration.maxRequests(50)
        #expect(maxRequestsConfig.port == 8080) // default
        #expect(maxRequestsConfig.maxStoredRequests == 50)
        
        // Test options factory method
        let optionsConfig = Tuist.MCPConfiguration.options(port: 4000, maxRequests: 300)
        #expect(optionsConfig.port == 4000)
        #expect(optionsConfig.maxStoredRequests == 300)
    }
}