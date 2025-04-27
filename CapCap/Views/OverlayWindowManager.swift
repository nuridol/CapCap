import SwiftUI
import AppKit
import OSLog // Import the unified logging system

/// Manages the lifecycle and properties of the floating overlay window using NSWindowDelegate.
/// Uses direct method calls instead of Combine for more deterministic behavior.
@available(macOS 13.0, *) // Mark class as available only on macOS 13.0+
@MainActor
class OverlayWindowManager: NSObject, NSWindowDelegate {
    private let logger = Logger(subsystem: AppConstants.Bundle.currentIdentifier, category: "OverlayWindowManager")
    private var overlayWindow: NSWindow?
    private var viewModel: AppViewModel

    // Track whether the overlay is currently showing
    private var isOverlayVisible: Bool = false

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        super.init()
        logger.debug("OverlayWindowManager initialized")
    }

    private func createOverlayWindow(region: CGRect, alpha: CGFloat) -> NSWindow {
        logger.debug("createOverlayWindow: Starting with region \(String(describing: region), privacy: .public), alpha \(String(describing: alpha), privacy: .public)")
        let overlayContentView = OverlayView()
        let hostingView = NSHostingView(rootView: overlayContentView)

        let window = NSWindow(
            contentRect: region,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = true // Ensure window is released from memory when closed
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.alphaValue = alpha
        window.ignoresMouseEvents = false
        window.contentView = hostingView
        window.isMovableByWindowBackground = true

        window.delegate = self
        logger.debug("createOverlayWindow: Delegate set, returning window")
        return window
    }

    /// Converts a Global Top-Left CGRect (used by ViewModel & Capture API) to a Local Bottom-Left NSRect
    /// suitable for positioning an NSWindow on a specific screen.
    private func convertGlobalTopLeftToLocalBottomLeft(globalRect: CGRect) -> (NSRect, NSScreen)? {
        // Find the screen that contains the majority of the rectangle
        guard let targetScreen = NSScreen.screens.first(where: { $0.frame.intersects(globalRect) }) else {
            logger.warning("Could not find screen for globalRect \(String(describing: globalRect), privacy: .public). Falling back to main screen.")
            // Fallback to main screen if no intersecting screen found (e.g., rect is off-screen)
            guard let mainScreen = NSScreen.main else {
                logger.error("Cannot find main screen.")
                return nil
            }
            // Attempt conversion relative to main screen's coordinate system
            let mainScreenGlobalFrame = mainScreen.frame // Global coordinates (bottom-left origin)
            let localX = globalRect.origin.x - mainScreenGlobalFrame.origin.x
            // Convert global top-left Y to global bottom-left Y relative to main screen
            let globalBottomLeftY = (NSScreen.main?.frame.height ?? 0) - globalRect.origin.y - globalRect.height
            let localY = globalBottomLeftY - mainScreenGlobalFrame.origin.y

            let localRect = NSRect(x: localX, y: localY, width: globalRect.width, height: globalRect.height)
            logger.warning("Converted using main screen fallback: \(String(describing: localRect), privacy: .public)")
            return (localRect, mainScreen)
        }

        // targetScreen.frame is in Global coordinates, origin at bottom-left of the main screen.
        let screenGlobalFrame = targetScreen.frame
        
        // Convert the global top-left Y coordinate to a global bottom-left Y coordinate
        // using the main screen's height as the reference for the global coordinate system.
        let mainScreenHeight = NSScreen.main?.frame.height ?? screenGlobalFrame.height // Use main screen height if available
        let globalBottomLeftY = mainScreenHeight - globalRect.origin.y - globalRect.height
        
        // Calculate the local coordinates relative to the target screen's bottom-left origin
        let localX = globalRect.origin.x - screenGlobalFrame.origin.x
        let localY = globalBottomLeftY - screenGlobalFrame.origin.y

        let localRect = NSRect(x: localX, y: localY, width: globalRect.width, height: globalRect.height)
        logger.debug("Converted global \(String(describing: globalRect), privacy: .public) on screen \(String(describing: targetScreen.localizedName), privacy: .public) to local \(String(describing: localRect), privacy: .public)")
        return (localRect, targetScreen)
    }
    
    /// Converts a Local Bottom-Left NSRect (from NSWindow on a specific screen) to a Global Top-Left CGRect.
    private func convertLocalBottomLeftToGlobalTopLeft(localRect: NSRect, on screen: NSScreen) -> CGRect {
        let screenGlobalFrame = screen.frame // Global coordinates (bottom-left origin)
        
        // Convert local bottom-left coordinates to global bottom-left coordinates
        let globalBottomLeftX = localRect.origin.x + screenGlobalFrame.origin.x
        let globalBottomLeftY = localRect.origin.y + screenGlobalFrame.origin.y
        
        // Convert global bottom-left Y to global top-left Y using main screen height
        let mainScreenHeight = NSScreen.main?.frame.height ?? screenGlobalFrame.height // Use main screen height if available
        let globalTopLeftY = mainScreenHeight - globalBottomLeftY - localRect.height

        let globalRect = CGRect(x: globalBottomLeftX, y: globalTopLeftY, width: localRect.width, height: localRect.height)
        logger.debug("Converted local \(String(describing: localRect), privacy: .public) on screen \(String(describing: screen.localizedName), privacy: .public) to global \(String(describing: globalRect), privacy: .public)")
        return globalRect
    }


    /// Public method to show or update the overlay window
    func showOrUpdateOverlay(region globalTopLeftRegion: CGRect, alpha: CGFloat) {
        logger.debug("showOrUpdateOverlay: Called with global region (Top-Left) \(String(describing: globalTopLeftRegion), privacy: .public), alpha \(String(describing: alpha), privacy: .public)")

        // Ensure we're on the main thread
        assert(Thread.isMainThread, "showOrUpdateOverlay must be called on the main thread")
        
        // Convert the Global Top-Left CGRect to Local Bottom-Left NSRect for the target screen
        guard let (localRect, targetScreen) = convertGlobalTopLeftToLocalBottomLeft(globalRect: globalTopLeftRegion) else {
            logger.error("showOrUpdateOverlay: Failed to convert coordinates.")
            return
        }

        if let window = overlayWindow {
            logger.debug("showOrUpdateOverlay: Window exists, updating frame/alpha")
            // Check if the window needs to move screens
            if window.screen != targetScreen {
                logger.debug("showOrUpdateOverlay: Moving window to screen \(String(describing: targetScreen.localizedName), privacy: .public)")
                // Move window to the target screen first, then set frame
                window.setFrameOrigin(targetScreen.frame.origin) // Move origin to target screen
            }
            // Set frame using local coordinates for the target screen
            window.setFrame(localRect, display: true, animate: false)
            window.alphaValue = alpha
            if !window.isVisible {
                 window.makeKeyAndOrderFront(nil)
            }
        } else {
            logger.debug("showOrUpdateOverlay: Creating new window on screen \(String(describing: targetScreen.localizedName), privacy: .public)")
            // Pass the Local Rect for initial window creation on the target screen
            overlayWindow = createOverlayWindow(region: localRect, alpha: alpha)
            // Ensure the window is created on the correct screen before setting the frame
            overlayWindow?.setFrameOrigin(targetScreen.frame.origin) // Position relative to target screen
            logger.debug("showOrUpdateOverlay: Setting frame before showing (using Local Rect \(String(describing: localRect), privacy: .public))")
            overlayWindow?.setFrame(localRect, display: false)

            // Add a small delay before showing the window to allow any pending operations to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                guard let self = self else { return }
                self.logger.debug("showOrUpdateOverlay: Calling makeKeyAndOrderFront")
                self.overlayWindow?.makeKeyAndOrderFront(nil)
                self.logger.debug("showOrUpdateOverlay: makeKeyAndOrderFront finished")
                self.isOverlayVisible = true
            }
        }
        logger.debug("showOrUpdateOverlay: Finished setup")
    }

    /// Helper to update existing window properties
    func updateOverlayAlpha(alpha: CGFloat) {
        guard let window = overlayWindow, window.isVisible else { return }
        window.alphaValue = alpha
    }

    /// Public method to hide the overlay window
    func hideOverlay() {
        logger.debug("hideOverlay: Called")

        // Ensure we're on the main thread
        assert(Thread.isMainThread, "hideOverlay must be called on the main thread")

        if let window = overlayWindow {
             logger.debug("hideOverlay: Clearing delegate")
             window.delegate = nil // Prevent delegate methods from being called during/after close
             logger.debug("hideOverlay: Calling close()")
             window.close() // Close the window properly, releasing resources
             logger.debug("hideOverlay: close() finished")
        }

        // Window reference is released automatically because isReleasedWhenClosed = true
        overlayWindow = nil // Ensure our reference is nil too
        isOverlayVisible = false
        logger.debug("hideOverlay: Finished. Overlay window closed and released.")
    }

    // MARK: - NSWindowDelegate Methods

    func windowDidMove(_ notification: Notification) {
        logger.trace("windowDidMove: Delegate method called") // Use trace for frequent events
        guard let window = notification.object as? NSWindow,
              window === overlayWindow,
              let currentScreen = window.screen else { // Get the screen the window is currently on
            logger.trace("windowDidMove: Guard failed (window mismatch or no screen)")
            return
        }

        // window.frame is in screen coordinates (bottom-left origin) relative to the window's current screen
        let newLocalRect = window.frame
        
        // Convert the new local rect to global top-left coordinates
        let newGlobalTopLeftRect = convertLocalBottomLeftToGlobalTopLeft(localRect: newLocalRect, on: currentScreen)

        // Check if the global origin actually changed before updating the ViewModel
        if viewModel.captureSettings.selectedRegion?.origin != newGlobalTopLeftRect.origin {
             logger.trace("windowDidMove: Global origin changed to \(String(describing: newGlobalTopLeftRect.origin), privacy: .public). Dispatching update.")
             // Use asyncAfter with a small delay to avoid potential issues
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                 self?.logger.trace("windowDidMove: Async block executing")
                 self?.viewModel.updateOverlayPosition(newGlobalTopLeftRect.origin)
                 self?.logger.trace("windowDidMove: Async block finished")
             }
         } else {
             logger.trace("windowDidMove: Global origin did not change.")
         }
         logger.trace("windowDidMove: Delegate method finished")
    }

    func windowDidResize(_ notification: Notification) {
        logger.trace("windowDidResize: Delegate method called") // Use trace for frequent events
        guard let window = notification.object as? NSWindow,
              window === overlayWindow,
              let currentScreen = window.screen else { // Get the screen the window is currently on
            logger.trace("windowDidResize: Guard failed (window mismatch or no screen)")
            return
        }

        // window.frame is in screen coordinates (bottom-left origin) relative to the window's current screen
        let newLocalRect = window.frame
        
        // Convert the new local rect to global top-left coordinates
        let newGlobalTopLeftRect = convertLocalBottomLeftToGlobalTopLeft(localRect: newLocalRect, on: currentScreen)

        logger.trace("windowDidResize: Resized to global size \(String(describing: newGlobalTopLeftRect.size), privacy: .public), global origin \(String(describing: newGlobalTopLeftRect.origin), privacy: .public).")
        // Use asyncAfter with a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
             self?.logger.trace("windowDidResize: Async block executing")
             guard let self = self else {
                 self?.logger.trace("windowDidResize: Async block - self is nil")
                 return
             }
             // Update both size and position using global coordinates
             self.viewModel.updateOverlaySize(newGlobalTopLeftRect.size)
             if self.viewModel.captureSettings.selectedRegion?.origin != newGlobalTopLeftRect.origin {
                  self.viewModel.updateOverlayPosition(newGlobalTopLeftRect.origin)
             }
             self.logger.trace("windowDidResize: Async block finished")
        }
        logger.trace("windowDidResize: Delegate method finished")
    }
}
