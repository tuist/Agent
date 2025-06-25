import Testing
import Foundation
@testable import Tuist

@Suite("Request History Tests")
struct RequestHistoryTests {
    
    @Test("Request history initialization")
    func testRequestHistoryInitialization() {
        let history = RequestHistory(maxRequests: 50)
        #expect(history.getAllRequests().isEmpty)
    }
    
    @Test("Adding requests to history")
    func testAddingRequests() async {
        let history = RequestHistory(maxRequests: 10)
        
        let request = createMockRequest(method: "GET", url: "https://api.example.com/users")
        history.addRequest(request)
        
        // Wait a bit for async operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let allRequests = history.getAllRequests()
        #expect(allRequests.count == 1)
        #expect(allRequests.first?.method == "GET")
        #expect(allRequests.first?.url?.absoluteString == "https://api.example.com/users")
    }
    
    @Test("Request history respects max limit")
    func testMaxRequestsLimit() async {
        let maxRequests = 3
        let history = RequestHistory(maxRequests: maxRequests)
        
        // Add more requests than the limit
        for i in 1...5 {
            let request = createMockRequest(method: "GET", url: "https://api.example.com/user/\(i)")
            history.addRequest(request)
        }
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let allRequests = history.getAllRequests()
        #expect(allRequests.count == maxRequests)
        
        // Should keep the most recent requests
        #expect(allRequests.last?.url?.absoluteString == "https://api.example.com/user/5")
    }
    
    @Test("Filtering requests by URL pattern")
    func testFilteringByURLPattern() async {
        let history = RequestHistory()
        
        let request1 = createMockRequest(method: "GET", url: "https://api.example.com/users")
        let request2 = createMockRequest(method: "POST", url: "https://api.different.com/posts")
        let request3 = createMockRequest(method: "GET", url: "https://api.example.com/posts")
        
        history.addRequest(request1)
        history.addRequest(request2)
        history.addRequest(request3)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let exampleRequests = history.getRequests(matching: "api.example.com")
        #expect(exampleRequests.count == 2)
        
        let differentRequests = history.getRequests(matching: "api.different.com")
        #expect(differentRequests.count == 1)
    }
    
    @Test("Filtering requests by HTTP method")
    func testFilteringByMethod() async {
        let history = RequestHistory()
        
        let getRequest = createMockRequest(method: "GET", url: "https://api.example.com/users")
        let postRequest = createMockRequest(method: "POST", url: "https://api.example.com/users")
        let putRequest = createMockRequest(method: "PUT", url: "https://api.example.com/users/1")
        
        history.addRequest(getRequest)
        history.addRequest(postRequest)
        history.addRequest(putRequest)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let getRequests = history.getRequests(method: "GET")
        #expect(getRequests.count == 1)
        #expect(getRequests.first?.method == "GET")
        
        let postRequests = history.getRequests(method: "POST")
        #expect(postRequests.count == 1)
        #expect(postRequests.first?.method == "POST")
    }
    
    @Test("Getting recent requests")
    func testGetRecentRequests() async {
        let history = RequestHistory()
        
        // Add 5 requests
        for i in 1...5 {
            let request = createMockRequest(method: "GET", url: "https://api.example.com/user/\(i)")
            history.addRequest(request)
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let recentRequests = history.getRecentRequests(count: 3)
        #expect(recentRequests.count == 3)
        
        // Should get the most recent ones
        #expect(recentRequests.last?.url?.absoluteString == "https://api.example.com/user/5")
    }
    
    @Test("Getting failed requests")
    func testGetFailedRequests() async {
        let history = RequestHistory()
        
        let successRequest = createMockRequest(method: "GET", url: "https://api.example.com/users", statusCode: 200)
        let failedRequest = createMockRequest(method: "GET", url: "https://api.example.com/error", statusCode: 500)
        let errorRequest = createMockRequest(method: "GET", url: "https://api.example.com/timeout", error: "Timeout")
        
        history.addRequest(successRequest)
        history.addRequest(failedRequest)
        history.addRequest(errorRequest)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let failedRequests = history.getFailedRequests()
        #expect(failedRequests.count == 2)
    }
    
    @Test("Clearing request history")
    func testClearingHistory() async {
        let history = RequestHistory()
        
        let request = createMockRequest(method: "GET", url: "https://api.example.com/users")
        history.addRequest(request)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(history.getAllRequests().count == 1)
        
        history.clear()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(history.getAllRequests().isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func createMockRequest(
        method: String,
        url: String,
        statusCode: Int? = 200,
        error: String? = nil
    ) -> InterceptedRequest {
        return InterceptedRequest(
            id: UUID(),
            url: URL(string: url),
            method: method,
            headers: ["Content-Type": "application/json"],
            body: nil,
            timestamp: Date(),
            duration: 0.5,
            response: InterceptedResponse(
                statusCode: statusCode,
                headers: ["Content-Type": "application/json"],
                body: nil,
                error: error
            )
        )
    }
}