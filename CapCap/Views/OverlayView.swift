import SwiftUI

/// A simple view representing the content of the overlay window.
/// It draws a border and has a semi-transparent background.
struct OverlayView: View {
    // The opacity is controlled by the window itself, but we might pass it
    // if we need different opacity for the border vs background fill.
    // For now, the window's alphaValue controls overall transparency.
    // var opacity: Double

    var body: some View {
        Rectangle()
            // The background fill color and opacity.
            // The window's alphaValue will further affect this.
            // We might set a very low alpha here and rely mostly on the window's alpha.
            .fill(Color.blue.opacity(0.1)) // Low opacity fill for visual feedback
            .border(Color.blue, width: 2) // Clearly visible border
            // We don't set a frame here; the window controller will size it.
    }
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayView()
            .frame(width: 200, height: 100)
    }
}
