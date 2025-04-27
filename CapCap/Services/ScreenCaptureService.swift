import Foundation
import CoreGraphics
import AppKit
import OSLog

/// Errors that can occur during screen capture operations
enum ScreenCaptureError: Error {
    /// Screen recording permission was denied by the user or system
    case permissionDenied
    /// The specified capture region is invalid (empty, zero-sized, or off-screen)
    case invalidRegion
    /// The screen capture operation failed with an optional underlying error
    case captureFailed(Error?)
}

/// Service responsible for capturing specified regions of the screen
class ScreenCaptureService {

    private let logger = Logger(subsystem: AppConstants.Bundle.currentIdentifier, category: "ScreenCaptureService")

    /// Checks if the application has screen recording permission
    /// - Returns: `true` if the app has permission, `false` otherwise
    func hasScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        } else {
            // On older macOS versions, assume permission is granted
            return true
        }
    }

    /// Requests screen recording permission from the user
    /// - Returns: `true` if permission was granted or already existed, `false` otherwise
    @available(macOS 10.15, *)
    func requestScreenRecordingPermission() -> Bool {
        // Check if we already have permission
        if CGPreflightScreenCaptureAccess() {
            logger.info("Screen capture permission already granted")
            return true
        }

        // Show guidance alert to help the user through the permission process
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "CapCap needs permission to capture screen content. You will see a system dialog asking for \"Screen Recording\" permission.\n\n" +
                                "1. Click \"Open System Settings\"\n" +
                                "2. Enable permission for \"CapCap\"\n" +
                                "3. If CapCap is not in the list, add it manually with the \"+\" button\n" +
                                "4. Restart CapCap after granting permission"
        alert.addButton(withTitle: "Continue")
        alert.runModal()
        
        // Request permission through the system
        let result = CGRequestScreenCaptureAccess()
        logger.info("Screen capture permission request result: \(result)")
        return result
    }

    /// Captures the specified rectangular area of the screen
    /// - Parameter region: The `CGRect` defining the area to capture in screen coordinates
    /// - Returns: A `CGImage` of the captured area
    /// - Throws: `ScreenCaptureError` if the operation fails
    func captureScreenRegion(_ region: CGRect) throws -> CGImage {
        // Verify screen recording permission
        guard hasScreenRecordingPermission() else {
             logger.error("Screen recording permission not granted when capture was attempted")
             throw ScreenCaptureError.permissionDenied
        }

        // Validate region dimensions
        guard !region.isEmpty, region.width > 0, region.height > 0 else {
            throw ScreenCaptureError.invalidRegion
        }

        // Perform capture using CGWindowListCreateImage
        guard let image = CGWindowListCreateImage(region, .optionOnScreenOnly, kCGNullWindowID, .boundsIgnoreFraming) else {
            // Check if the region is outside the bounds of all screens
            let allScreensFrame = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
            // Convert global top-left region to global bottom-left for comparison with allScreensFrame
            let mainScreenHeight = NSScreen.main?.frame.height ?? 0
            let globalBottomLeftRegion = CGRect(x: region.origin.x, y: mainScreenHeight - region.origin.y - region.height, width: region.width, height: region.height)

            if !allScreensFrame.intersects(globalBottomLeftRegion) {
                 logger.error("Capture region \(String(describing: region), privacy: .public) seems to be outside all screen bounds")
                 throw ScreenCaptureError.invalidRegion
            } else {
                 logger.error("CGWindowListCreateImage failed for region \(String(describing: region), privacy: .public)")
                 throw ScreenCaptureError.captureFailed(nil)
            }
        }

        logger.debug("Successfully captured image for region \(String(describing: region), privacy: .public)")
        return image
    }
}
