import Foundation

/// Manages the history of intercepted requests
public final class RequestHistory: @unchecked Sendable {
    private var requests: [InterceptedRequest] = []
    private let maxRequests: Int
    private let queue = DispatchQueue(label: "com.tuist.request-history", attributes: .concurrent)
    
    init(maxRequests: Int = 100) {
        self.maxRequests = maxRequests
    }
    
    /// Add a new request to the history
    func addRequest(_ request: InterceptedRequest) {
        queue.async(flags: .barrier) {
            self.requests.append(request)
            
            // Remove oldest requests if we exceed the limit
            if self.requests.count > self.maxRequests {
                self.requests.removeFirst(self.requests.count - self.maxRequests)
            }
        }
    }
    
    /// Get all stored requests
    public func getAllRequests() -> [InterceptedRequest] {
        queue.sync {
            requests
        }
    }
    
    /// Get requests filtered by URL pattern
    public func getRequests(matching pattern: String) -> [InterceptedRequest] {
        queue.sync {
            requests.filter { request in
                request.url?.absoluteString.contains(pattern) ?? false
            }
        }
    }
    
    /// Get requests within a time range
    public func getRequests(from startDate: Date, to endDate: Date = Date()) -> [InterceptedRequest] {
        queue.sync {
            requests.filter { request in
                request.timestamp >= startDate && request.timestamp <= endDate
            }
        }
    }
    
    /// Get the most recent N requests
    public func getRecentRequests(count: Int) -> [InterceptedRequest] {
        queue.sync {
            Array(requests.suffix(count))
        }
    }
    
    /// Clear all stored requests
    public func clear() {
        queue.async(flags: .barrier) {
            self.requests.removeAll()
        }
    }
    
    /// Get requests by HTTP method
    public func getRequests(method: String) -> [InterceptedRequest] {
        queue.sync {
            requests.filter { $0.method.uppercased() == method.uppercased() }
        }
    }
    
    /// Get failed requests (with errors or non-2xx status codes)
    public func getFailedRequests() -> [InterceptedRequest] {
        queue.sync {
            requests.filter { request in
                if request.response.error != nil {
                    return true
                }
                if let statusCode = request.response.statusCode {
                    return statusCode < 200 || statusCode >= 300
                }
                return false
            }
        }
    }
}

/// Represents an intercepted network request and its response
public struct InterceptedRequest: Codable, Sendable {
    public let id: UUID
    public let url: URL?
    public let method: String
    public let headers: [String: String]?
    public let body: Data?
    public let timestamp: Date
    public let duration: TimeInterval
    public let response: InterceptedResponse
    
    /// Get the request body as a string (if possible)
    public var bodyString: String? {
        guard let body = body else { return nil }
        return String(data: body, encoding: .utf8)
    }
    
    /// Get the request body as JSON (if possible)
    public var bodyJSON: Any? {
        guard let body = body else { return nil }
        return try? JSONSerialization.jsonObject(with: body)
    }
}

/// Represents the response of an intercepted request
public struct InterceptedResponse: Codable, Sendable {
    public let statusCode: Int?
    public let headers: [String: String]?
    public let body: Data?
    public let error: String?
    
    /// Get the response body as a string (if possible)
    public var bodyString: String? {
        guard let body = body else { return nil }
        return String(data: body, encoding: .utf8)
    }
    
    /// Get the response body as JSON (if possible)
    public var bodyJSON: Any? {
        guard let body = body else { return nil }
        return try? JSONSerialization.jsonObject(with: body)
    }
    
    /// Check if the response indicates success
    public var isSuccess: Bool {
        guard let statusCode = statusCode else { return false }
        return statusCode >= 200 && statusCode < 300
    }
}