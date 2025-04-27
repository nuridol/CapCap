import SwiftUI
import AppKit
import OSLog // Import the unified logging system

/// Manages a window that overlays the entire screen for region selection
@MainActor
class RegionSelectorWindowManager: NSObject {
    private let logger = Logger(subsystem: AppConstants.Bundle.currentIdentifier, category: "RegionSelectorWindowManager")
    private var selectorWindow: NSWindow?
    private var onRegionSelected: (CGRect) -> Void
    private var isPresented: Binding<Bool>

    init(onRegionSelected: @escaping (CGRect) -> Void, isPresented: Binding<Bool>) {
        self.onRegionSelected = onRegionSelected
        self.isPresented = isPresented
        super.init()
    }

    func show() {
        logger.debug("Showing full-screen window(s)")

        // Determine the union of all screen frames to cover all monitors
        let allScreensFrame = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
        
        // Adjust the frame to be relative to the main screen's coordinate system origin (bottom-left)
        // This is needed because NSWindow positions are relative to the main screen's bottom-left.
        guard let _ = NSScreen.main else { // Use wildcard '_' as mainScreen is not used
             logger.error("Cannot get main screen for coordinate adjustment.")
             return
        }
        // No adjustment needed if allScreensFrame already uses global coordinates (which it should)
        let windowFrame = allScreensFrame
        logger.debug("Calculated window frame covering all screens: \(String(describing: windowFrame), privacy: .public)")

        // Create the selection view
        let selectorView = RegionSelectorView(
            onRegionSelected: { [weak self] selectedRect in
                self?.logger.debug("Region selected: \(String(describing: selectedRect), privacy: .public)")
                self?.onRegionSelected(selectedRect)
                self?.dismiss()
            },
            isPresented: isPresented
        )
        
        let hostingView = NSHostingView(rootView: selectorView)
        hostingView.frame = windowFrame // Ensure hosting view covers the window frame
        
        // Create a borderless window covering the calculated frame for all screens
        let window = NSWindow(
            contentRect: windowFrame, // Use the combined frame
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating // So it appears above other windows
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovable = false
        window.contentView = hostingView
        window.makeKey() // Make it the key window to receive events
        
        // Save the window reference
        selectorWindow = window
        
        // Show the window
        window.orderFrontRegardless()
        logger.debug("Full-screen window displayed")
    }

    func dismiss() {
        logger.debug("Dismissing window")
        selectorWindow?.orderOut(nil)
        selectorWindow = nil
        isPresented.wrappedValue = false
        logger.debug("Window dismissed")
    }
}
