import Foundation

/// Intercepts network requests using URLProtocol
final class RequestInterceptor: @unchecked Sendable {
    static let shared = RequestInterceptor()
    
    private(set) var history: RequestHistory
    private var isIntercepting = false
    
    private init() {
        self.history = RequestHistory()
    }
    
    func configure(maxStoredRequests: Int) {
        history = RequestHistory(maxRequests: maxStoredRequests)
    }
    
    func startIntercepting() {
        guard !isIntercepting else { return }
        
        // Register our custom URLProtocol
        URLProtocol.registerClass(InterceptingURLProtocol.self)
        
        // For URLSession configurations that are already created, we need to swizzle
        swizzleURLSessionConfiguration()
        
        isIntercepting = true
        print("✅ Request interception started")
    }
    
    func stopIntercepting() {
        guard isIntercepting else { return }
        
        URLProtocol.unregisterClass(InterceptingURLProtocol.self)
        isIntercepting = false
        print("🛑 Request interception stopped")
    }
    
    private func swizzleURLSessionConfiguration() {
        // Swizzle default configuration
        swizzleConfiguration(URLSessionConfiguration.default)
        
        // Swizzle ephemeral configuration
        swizzleConfiguration(URLSessionConfiguration.ephemeral)
    }
    
    private func swizzleConfiguration(_ configuration: URLSessionConfiguration) {
        var protocolClasses = configuration.protocolClasses ?? []
        protocolClasses.insert(InterceptingURLProtocol.self, at: 0)
        configuration.protocolClasses = protocolClasses
    }
}

/// Custom URLProtocol to intercept requests
private final class InterceptingURLProtocol: URLProtocol, @unchecked Sendable {
    private var dataTask: URLSessionDataTask?
    private var receivedData = Data()
    private var response: URLResponse?
    private var startTime: Date?
    
    override class func canInit(with request: URLRequest) -> Bool {
        // Check if we've already handled this request to avoid infinite loop
        if URLProtocol.property(forKey: "TuistIntercepted", in: request) != nil {
            return false
        }
        
        // We can handle all HTTP/HTTPS requests
        guard let scheme = request.url?.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        startTime = Date()
        
        // Mark this request as intercepted to avoid infinite loop
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: "TuistIntercepted", in: mutableRequest)
        
        // Create a new request
        let newRequest = mutableRequest as URLRequest
        
        // Create the data task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        dataTask = session.dataTask(with: newRequest)
        dataTask?.resume()
    }
    
    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }
}

// MARK: - URLSessionDataDelegate
extension InterceptingURLProtocol: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        client?.urlProtocol(self, didLoad: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
        
        // Record the intercepted request
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        let interceptedRequest = InterceptedRequest(
            id: UUID(),
            url: request.url,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields,
            body: request.httpBody,
            timestamp: startTime ?? Date(),
            duration: duration,
            response: InterceptedResponse(
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                headers: (response as? HTTPURLResponse)?.allHeaderFields as? [String: String],
                body: receivedData.isEmpty ? nil : receivedData,
                error: error?.localizedDescription
            )
        )
        
        RequestInterceptor.shared.history.addRequest(interceptedRequest)
    }
}