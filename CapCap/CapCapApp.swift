import SwiftUI

import SwiftUI

@available(macOS 13.0, *) // Mark App as available only on macOS 13.0+
@main
struct CapCapApp: App {
    // Use NSApplicationDelegateAdaptor to connect AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create the ViewModel as a StateObject to keep it alive
    @StateObject private var viewModel = AppViewModel()
    // Removed State variable for overlayManager - it's now handled lazily in ViewModel

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the shared ViewModel into the environment
                .environmentObject(viewModel)
                // Removed onAppear block - OverlayWindowManager is initialized lazily in ViewModel
        }
        // Optional: Settings scene, menu bar commands etc. can be added here
    }
}
