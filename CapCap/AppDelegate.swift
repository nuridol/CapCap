import SwiftUI
import AppKit
import OSLog

/// Handles application lifecycle events and system-level interactions
class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(subsystem: AppConstants.Bundle.currentIdentifier, category: "AppDelegate")

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        logger.debug("Last window closed, application will terminate.")
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.debug("Application did finish launching.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.debug("Application will terminate.")
    }
}
