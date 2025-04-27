import SwiftUI
import Combine // For ObservableObject and Timer
import CoreGraphics // For CGRect
import OSLog // Import the unified logging system

@available(macOS 13.0, *) // Mark ViewModel as available only on macOS 13.0+ due to TextRecognitionService
@MainActor // Ensure UI updates are on the main thread
class AppViewModel: ObservableObject {

    // Define a logger for this ViewModel
    private let logger = Logger(subsystem: AppConstants.Bundle.currentIdentifier, category: "AppViewModel")

    // MARK: - Published Properties (State for the View)

    @Published var captureSettings = CaptureSettings()
    @Published var capturedContent = CapturedContent()
    @Published var isCapturing: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var showRegionSelector: Bool = false // To trigger region selection UI
    // Removed @Published var overlayWindowVisible: Bool - now managed directly through OverlayWindowManager

    // MARK: - Window Managers
    // Use lazy to defer initialization until first use (after self is fully initialized)
    private lazy var overlayWindowManager: OverlayWindowManager = {
        let manager = OverlayWindowManager(viewModel: self)
        logger.debug("OverlayWindowManager lazy initialized")
        return manager
    }()
    
    // Region selector window manager is created on demand and not persisted
    private var regionSelectorWindowManager: RegionSelectorWindowManager?

    // MARK: - Services (Dependencies)

    private let screenCaptureService: ScreenCaptureService
    // Make textRecognitionService lazy to handle @MainActor isolation
    private lazy var textRecognitionService: TextRecognitionService = {
        // Ensure this runs on macOS 13+ where TextRecognitionService is available
        if #available(macOS 13.0, *) {
            return TextRecognitionService()
        } else {
            // Handle older macOS versions - perhaps fatalError or return a dummy service
            // For now, let's cause a fatal error as the app requires macOS 13+ for Live Text
            fatalError("TextRecognitionService requires macOS 13.0 or later.")
            // Alternatively, return a dummy/legacy service if you added one:
            // return TextRecognitionService_Legacy()
        }
    }()
    private let paragraphDetectionService: ParagraphDetectionService

    // MARK: - Private State

    private var captureTimer: Timer?
    private var lastDetectedText: String = "" // Keep track of the last text successfully processed to avoid redundant processing

    // MARK: - Initialization

    init(
        // Default screenCaptureService instance
        screenCaptureService: ScreenCaptureService = ScreenCaptureService(),
        // Default paragraphDetectionService instance
        paragraphDetectionService: ParagraphDetectionService = ParagraphDetectionService()
        // Removed textRecognitionService from init parameters as it's now lazy
    ) {
        self.screenCaptureService = screenCaptureService
        self.paragraphDetectionService = paragraphDetectionService

        // textRecognitionService and overlayWindowManager are lazy initialized
        logger.debug("AppViewModel initialized")

        // Perform macOS version check early if critical features depend on it
        if #unavailable(macOS 13.0) {
             logger.error("This application requires macOS 13.0 or later for full functionality (Live Text).")
             // Optionally, disable features or show an alert
             statusMessage = "Warning: Live Text requires macOS 13.0+"
        }
    }

    // MARK: - User Actions

    func selectArea() {
        // Trigger the presentation of the RegionSelectorView
        logger.debug("Initiating area selection...")
        statusMessage = "Select capture area by dragging..."
        showRegionSelector = true // This will trigger showRegionSelectorWindow via ContentView onChange
    }
    
    /// Shows the region selector window manager
    func showRegionSelectorWindow() {
        // Create a new region selector window manager
        // Create a binding for showRegionSelector
        let binding = Binding<Bool>(
            get: { self.showRegionSelector },
            set: { self.showRegionSelector = $0 }
        )
        
        regionSelectorWindowManager = RegionSelectorWindowManager(
            onRegionSelected: didSelectArea, 
            isPresented: binding
        )
        
        // Show the window
        regionSelectorWindowManager?.show()
    }

    func startStopCapture() {
        if isCapturing {
            stopCapture()
        } else {
            // Ensure an area is selected before starting
            guard captureSettings.selectedRegion != nil else {
                statusMessage = "Error: Please select an area first."
                return
            }
            Task {
                await startCapture()
            }
        }
    }

    func saveText() {
        logger.debug("Save Text action triggered.")
        saveTextToFile()
    }

    func clearText() {
        logger.debug("Clear Text action triggered.")
        capturedContent.fullText = ""
        lastDetectedText = "" // Reset last detected text as well
        statusMessage = "Text cleared."
    }

    // MARK: - Capture Cycle Logic

    private func startCapture() { // Removed async
        // Check permission synchronously before starting
        guard checkAndRequestPermissions() else { // Removed await
            // statusMessage is already set by checkAndRequestPermissions if denied
            return
        }

        logger.debug("Starting capture...")
        isCapturing = true
        statusMessage = "Capturing..."
        // Invalidate existing timer just in case
        captureTimer?.invalidate()
        // Create and schedule the timer
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureSettings.captureInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in // performCaptureCycle is async, so needs Task
                await self?.performCaptureCycle()
            }
        }
        // Perform an initial capture immediately in a background Task
        Task {
            await performCaptureCycle()
        }
    }

    private func stopCapture() {
        logger.debug("Stopping capture...")
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false
        statusMessage = "Capture stopped."
        
        // Keep overlay visible when capture stops (removed hideOverlay call)
        // overlayWindowManager.hideOverlay() 
    }

    private func performCaptureCycle() async {
        guard let region = captureSettings.selectedRegion, isCapturing else {
            // Stop if no region is selected or if capturing is turned off
            if isCapturing { // Only stop if it was supposed to be running
                 stopCapture()
                 statusMessage = "Error: Capture region lost. Stopping."
            }
            return
        }

        logger.debug("Performing capture cycle for region: \(String(describing: region), privacy: .public)") // Log region publicly if needed for debugging
        statusMessage = "Capturing..." // Update status

        do {
            // 1. Capture Image
            // Note: captureScreenRegion is now synchronous (throws)
            let image = try screenCaptureService.captureScreenRegion(region) // Removed await
            statusMessage = "Recognizing text..."

            // 2. Recognize Text (Availability check removed as the whole class is macOS 13+)
            let recognizedText = try await textRecognitionService.recognizeText(from: image)
            let trimmedRecognizedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Avoid processing if the text hasn't changed since the last successful detection
            guard trimmedRecognizedText != lastDetectedText else {
                logger.debug("No text change detected.")
                statusMessage = "Capturing (No Change)" // Indicate monitoring but no update
                return
            }
             statusMessage = "Processing text..."

            // 3. Detect Paragraph Change
            let changeResult = paragraphDetectionService.detectChange(
                previousText: capturedContent.fullText,
                newText: trimmedRecognizedText
            )

            // 4. Update Content based on detection result
            updateCapturedContent(with: changeResult)
            lastDetectedText = trimmedRecognizedText // Update last detected text only on successful processing

            statusMessage = "Capture successful." // Update status on success

        } catch let error as ScreenCaptureError {
            handleCaptureError(error)
        } catch let error as TextRecognitionError {
            handleRecognitionError(error)
        } catch {
            logger.error("An unexpected error occurred during capture cycle: \(String(describing: error), privacy: .public)")
            statusMessage = "Error: \(error.localizedDescription)"
            // Consider stopping capture on unexpected errors
            // stopCapture()
        }
    }

    // MARK: - Content Update Logic

    private func updateCapturedContent(with result: ParagraphDetectionResult) {
        switch result {
        case .noChange:
            logger.debug("Paragraph Detection: No change.")
            // Do nothing with the text content
            break
        case .updateLastLine(let newText):
            logger.debug("Paragraph Detection: Updating last line.")
            var lines = capturedContent.fullText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) // Keep empty lines
            if !lines.isEmpty {
                lines[lines.count - 1] = newText // Replace the last element
                capturedContent.fullText = lines.joined(separator: "\n")
            } else {
                // If lines was empty, treat as adding a new line
                capturedContent.fullText = newText
            }
        case .addNewLine(let newText):
            logger.debug("Paragraph Detection: Adding new line.")
            if capturedContent.fullText.isEmpty {
                capturedContent.fullText = newText
            } else {
                capturedContent.fullText += "\n" + newText
            }
        }
    }

    // MARK: - Permissions

    private func checkAndRequestPermissions() -> Bool { // Removed async
        // Check current permission status
        if screenCaptureService.hasScreenRecordingPermission() {
            logger.info("Screen recording permission is granted.")
            return true
        } else {
            logger.warning("Screen recording permission is NOT granted.")
            statusMessage = "Screen Recording permission required."

            // Attempt to request permission (shows system prompt or guides user via alert in ScreenCaptureService)
            // The return value of requestScreenRecordingPermission itself isn't the final grant status.
            _ = screenCaptureService.requestScreenRecordingPermission()

            // Inform the user what to do next.
            // Crucially, tell them they might need to restart the app.
            // Consider showing a more prominent alert in the future if this message isn't sufficient.
            statusMessage = "Please grant Screen Recording in System Settings. You may need to restart CapCap."
            logger.info("Instructed user to grant permission in System Settings and restart if needed.")

            return false // Indicate that permission is currently denied. Capture should not proceed yet.
        }
    } // End checkAndRequestPermissions function


    // MARK: - Error Handling

    private func handleCaptureError(_ error: ScreenCaptureError) {
        switch error {
        case .permissionDenied:
            statusMessage = "Error: Screen Recording permission denied."
            isCapturing = false // Stop capture if permission fails
            captureTimer?.invalidate()
        case .invalidRegion:
            statusMessage = "Error: Invalid capture region."
            isCapturing = false
            captureTimer?.invalidate()
        case .captureFailed(let underlyingError):
            statusMessage = "Error: Screen capture failed."
            logger.error("Capture failed: \(String(describing: underlyingError?.localizedDescription ?? "Unknown reason"), privacy: .public)")
            // Decide whether to stop capture or retry
        }
    }

    private func handleRecognitionError(_ error: TextRecognitionError) {
        switch error {
        case .noTextFound:
            statusMessage = "No text found in the region."
            // This is not necessarily an error stopping the capture, just an update.
            logger.debug("HandleRecognitionError: No text found.")
            // Optionally clear last detected text or handle based on desired behavior
            // lastDetectedText = ""
        case .analysisFailed(let underlyingError): // Updated case name
            statusMessage = "Error: Text analysis failed."
            logger.error("HandleRecognitionError: Analysis failed: \(String(describing: underlyingError?.localizedDescription ?? "Unknown reason"), privacy: .public)")
            // Decide whether to stop capture or retry. Consider stopping if it persists.
            // stopCapture()
        }
    }

    // MARK: - Callback from Selection UI

    func didSelectArea(_ rect: CGRect) {
        logger.debug("didSelectArea: Called with global rect (Top-Left) \(String(describing: rect), privacy: .public)")

        // No correction needed here, RegionSelectorView now provides global top-left coordinates
        captureSettings.selectedRegion = rect
        statusMessage = "Area selected. Ready to capture."
        
        // No need to set showRegionSelector = false, the RegionSelectorWindowManager handles this
        // and will update the binding when the window is dismissed

        // Show the overlay window after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.logger.debug("didSelectArea: Now showing overlay window")
            if let region = self.captureSettings.selectedRegion {
                self.overlayWindowManager.showOrUpdateOverlay(
                    region: region,
                    alpha: CGFloat(self.captureSettings.overlayTransparency)
                )
            }
        }

        logger.debug("didSelectArea: Finished setting up delayed overlay display")
    }
    
    // Removed applyDisplayScaleFactor function as it's no longer needed.
    // ViewModel now consistently uses global top-left coordinates.

    // MARK: - Overlay Window Management (Interface for Delegate Callbacks)

    // These methods now receive global top-left coordinates from OverlayWindowManager
    func updateOverlayPosition(_ newGlobalTopLeftOrigin: CGPoint) {
        logger.debug("updateOverlayPosition: Called with global top-left origin \(String(describing: newGlobalTopLeftOrigin), privacy: .public)")
        guard var region = captureSettings.selectedRegion else {
            logger.debug("updateOverlayPosition: Guard failed (no region)")
            return
        }
        region.origin = newGlobalTopLeftOrigin
        captureSettings.selectedRegion = region
        logger.debug("updateOverlayPosition: Updated captureSettings.selectedRegion.origin (global top-left)")
    }

    func updateOverlaySize(_ newGlobalSize: CGSize) {
        logger.debug("updateOverlaySize: Called with global size \(String(describing: newGlobalSize), privacy: .public)")
        guard var region = captureSettings.selectedRegion else {
            logger.debug("updateOverlaySize: Guard failed (no region)")
            return
        }
        // Size is generally independent of coordinate system origin
        region.size = newGlobalSize
        captureSettings.selectedRegion = region
        logger.debug("updateOverlaySize: Updated captureSettings.selectedRegion.size (global)")
    }

    // MARK: - Settings Update

    func updateCaptureInterval(_ newInterval: TimeInterval) {
        let clampedInterval = max(0.1, newInterval) // Ensure minimum interval
        captureSettings.captureInterval = clampedInterval
        // If capturing, restart timer with new interval
        if isCapturing {
            Task {
                 stopCapture() // Stop existing timer
                 await startCapture() // Start with new interval
            }
        }
        logger.debug("Capture interval updated to: \(String(describing: clampedInterval), privacy: .public)")
    }

    func updateOverlayTransparency(_ newTransparency: Double) {
        let clampedTransparency = min(max(0.0, newTransparency), 1.0) // Clamp between 0 and 1
        captureSettings.overlayTransparency = clampedTransparency
        
        // Directly tell the manager to update the alpha
        overlayWindowManager.updateOverlayAlpha(alpha: CGFloat(clampedTransparency))

        logger.debug("Overlay transparency updated to: \(String(describing: clampedTransparency), privacy: .public)")
    }

    // MARK: - File Saving

    private func saveTextToFile() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "captured_text.txt" // Default filename
        savePanel.level = .modalPanel // Keep it above the main window
        savePanel.begin { [weak self] (result) in
            guard let self = self, result == .OK, let url = savePanel.url else {
                self?.statusMessage = "Save cancelled."
                return
            }

            do {
                self.statusMessage = "Saving to \(url.lastPathComponent)..."
                try self.capturedContent.fullText.write(to: url, atomically: true, encoding: .utf8)
                self.statusMessage = "Text saved successfully."
                self.logger.info("Text saved to: \(String(describing: url.path), privacy: .public)")
            } catch {
                self.statusMessage = "Error: Failed to save text."
                self.logger.error("Error saving text: \(String(describing: error.localizedDescription), privacy: .public)")
                // Optionally show an alert to the user
            }
        }
    }

    // MARK: - Cleanup
    deinit {
        captureTimer?.invalidate()
        // Note: We intentionally do not call overlayWindowManager.hideOverlay() here
        // because deinit is a synchronous context and hideOverlay() is @MainActor isolated.
        // The overlay window will be properly released when the OverlayWindowManager is deallocated.
        logger.debug("AppViewModel deinitialized.")
    }
}
