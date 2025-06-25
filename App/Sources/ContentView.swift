import SwiftUI
import Tuist

public struct ContentView: View {
    @State private var responseText = ""
    @State private var requestHistory: [InterceptedRequest] = []
    
    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Tuist SDK Demo")
                    .font(.largeTitle)
                    .padding()
                
                Button("Make Sample Request") {
                    makeRequest()
                }
                .buttonStyle(.borderedProminent)
                
                Button("View Request History") {
                    loadRequestHistory()
                }
                .buttonStyle(.bordered)
                
                if !responseText.isEmpty {
                    ScrollView {
                        Text("Response:")
                            .font(.headline)
                        Text(responseText)
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(maxHeight: 200)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if !requestHistory.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Request History:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List(requestHistory, id: \.id) { request in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(request.method) \(request.url?.host ?? "Unknown")")
                                    .font(.headline)
                                Text("Path: \(request.url?.path ?? "/")")
                                    .font(.caption)
                                HStack {
                                    Text("Status: \(request.response.statusCode ?? 0)")
                                    Spacer()
                                    Text("Duration: \(String(format: "%.2f", request.duration))s")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Spacer()
                
                Text("MCP Server running on port 8080")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Tuist SDK")
            .padding()
        }
    }
    
    private func makeRequest() {
        // Make a sample request that will be intercepted
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let text = String(data: data, encoding: .utf8) {
                    responseText = text
                } else if let error = error {
                    responseText = "Error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    private func loadRequestHistory() {
        // Get the last 10 requests from the SDK
        requestHistory = Tuist.requests.getRecentRequests(count: 10)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}