import SwiftUI
import AppKit
import OSLog // Import the unified logging system

/// A view that overlays the screen to allow the user to select a rectangular region.
struct RegionSelectorView: NSViewRepresentable {
    // Callback to pass the selected rectangle back to the ViewModel
    var onRegionSelected: (CGRect) -> Void
    // Binding to control the presentation of this view
    @Binding var isPresented: Bool

    func makeNSView(context: Context) -> NSView {
        let view = RegionSelectorNSView(frame: .zero) // Use custom NSView subclass
        view.onRegionSelected = self.onRegionSelected
        view.parentBinding = $isPresented // Pass the binding to the NSView
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update the NSView if needed, e.g., based on state changes.
        // For now, we primarily rely on the NSView's internal logic.
    }

    // Custom NSView subclass to handle mouse events for region selection
    class RegionSelectorNSView: NSView {
        private let logger = Logger(subsystem: AppConstants.Bundle.currentIdentifier, category: "RegionSelectorView")
        var onRegionSelected: ((CGRect) -> Void)?
        var parentBinding: Binding<Bool>? // Binding to dismiss the view

        private var startPoint: NSPoint?
        private var currentRect: NSRect?
        private var trackingArea: NSTrackingArea?

        override var acceptsFirstResponder: Bool { true } // Needed to receive key events if desired

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            // Ensure the view covers the entire screen later when presented
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea = trackingArea {
                removeTrackingArea(trackingArea)
            }
            // Track mouse movement within the view's bounds
            trackingArea = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .mouseEnteredAndExited], owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            // Semi-transparent background
            NSColor.black.withAlphaComponent(0.1).setFill()
            dirtyRect.fill()

            // Draw the selection rectangle if it exists
            if let rect = currentRect {
                // Draw fill
                NSColor.white.withAlphaComponent(0.3).setFill() // Slightly less opaque fill
                rect.fill()
                // Draw stroke using NSBezierPath
                let path = NSBezierPath(rect: rect)
                path.lineWidth = 1.0
                NSColor.white.setStroke()
                path.stroke()
            }

            // Optional: Draw crosshairs or instructions
            // let center = NSPoint(x: bounds.midX, y: bounds.midY)
            // Draw crosshairs, text, etc.
        }

        override func mouseDown(with event: NSEvent) {
            // Start selection
            startPoint = convert(event.locationInWindow, from: nil)
            currentRect = nil // Clear previous rect
            needsDisplay = true
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = startPoint else { return }
            let currentPoint = convert(event.locationInWindow, from: nil)

            // Create/update the rectangle based on start and current points
            currentRect = NSRect(x: min(start.x, currentPoint.x),
                                 y: min(start.y, currentPoint.y),
                                 width: abs(start.x - currentPoint.x),
                                 height: abs(start.y - currentPoint.y))
            needsDisplay = true // Redraw to show the rectangle
        }

        override func mouseUp(with event: NSEvent) {
            guard let finalRect = currentRect, finalRect.width > 0, finalRect.height > 0 else {
                // If no valid rect was drawn, dismiss without selecting
                dismiss()
                 return
            }

            // Convert the view's local rect (bottom-left origin) to global screen coordinates.
            // 1. Convert view's local rect to window coordinates.
            let rectInWindow = self.convert(finalRect, to: nil)
            
            // 2. Convert window coordinates to global screen coordinates (bottom-left origin).
            guard let globalBottomLeftRect = self.window?.convertToScreen(rectInWindow) else {
                logger.error("Could not convert rect to global screen coordinates.")
                dismiss()
                return
            }

            // 3. Convert global screen coordinates (bottom-left origin) to global screen coordinates (top-left origin)
            //    as expected by CGWindowListCreateImage. The global origin (0,0) in CoreGraphics is the
            //    top-left corner of the main display. AppKit's global origin is the bottom-left of the main display.
            guard let mainScreen = NSScreen.main else {
                 logger.error("Could not get main screen for coordinate conversion.")
                 dismiss()
                 return
            }
            let mainScreenHeight = mainScreen.frame.height
            let globalTopLeftRect = CGRect(
                x: globalBottomLeftRect.origin.x,
                y: mainScreenHeight - globalBottomLeftRect.origin.y - globalBottomLeftRect.height, // Flip Y based on main screen height
                width: globalBottomLeftRect.width,
                height: globalBottomLeftRect.height
            )

            logger.debug("Selected Global Rect (Top-Left Origin): \(String(describing: globalTopLeftRect), privacy: .public)")
            onRegionSelected?(globalTopLeftRect) // Pass the global top-left rect back
            dismiss()
        }

        override func keyDown(with event: NSEvent) {
            // Allow dismissing with the Escape key
            if event.keyCode == 53 { // 53 is the key code for Escape
                dismiss()
            } else {
                super.keyDown(with: event)
            }
        }

        private func dismiss() {
            // Reset state and dismiss the view via the binding
            startPoint = nil
            currentRect = nil
            needsDisplay = true
            // Use the binding to signal dismissal
            DispatchQueue.main.async { [weak self] in
                 self?.parentBinding?.wrappedValue = false
            }
        }
        
        // Ensure the view is transparent to clicks initially if needed,
        // though for selection, we want it to capture clicks.
        // override func hitTest(_ point: NSPoint) -> NSView? { ... }
    }
}

// Preview Provider (Optional, might be tricky for full screen views)
// struct RegionSelectorView_Previews: PreviewProvider {
//     static var previews: some View {
//         RegionSelectorView(onRegionSelected: { rect in print("Preview selected: \(rect)") }, isPresented: .constant(true))
//     }
// }
