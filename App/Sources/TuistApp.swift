import SwiftUI
import Tuist

@main
struct TuistApp: App {
    init() {
        // Initialize Tuist SDK
        #if DEBUG
        Tuist.initialize(with: .options(
            mcp: .options(port: 8080, maxRequests: 100)
        ))
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
