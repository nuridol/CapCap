import Foundation
import CoreGraphics // Required for CGRect

/// Stores the settings related to the screen capture process.
struct CaptureSettings {
    /// The interval between captures in seconds.
    var captureInterval: TimeInterval = 1.0

    /// The opacity level of the overlay window (0.0 = fully transparent, 1.0 = fully opaque).
    var overlayTransparency: Double = 0.7

    /// The area of the screen selected for capture. Nil if no area is selected.
    var selectedRegion: CGRect? = nil
}
