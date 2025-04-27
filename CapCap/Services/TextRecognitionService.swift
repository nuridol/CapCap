import Foundation
import VisionKit
import Vision
import CoreGraphics
import AppKit
import OSLog

/// Errors that can occur during text recognition operations
enum TextRecognitionError: Error {
    /// The text analysis process failed with an optional underlying error
    case analysisFailed(Error?)
    /// No text was found in the analyzed image
    case noTextFound
}

/// Service responsible for recognizing text from images using VisionKit's ImageAnalyzer (Live Text)
@available(macOS 13.0, *)
@MainActor
class TextRecognitionService {

    private let logger = Logger(subsystem: AppConstants.Bundle.currentIdentifier, category: "TextRecognitionService")
    private let analyzer = ImageAnalyzer()
    private let configuration = ImageAnalyzer.Configuration([.text])

    /// Recognizes text within the provided image using Live Text
    /// - Parameter cgImage: The image containing the text to recognize
    /// - Returns: A string containing the recognized text
    /// - Throws: `TextRecognitionError` if analysis fails or no text is found
    @available(macOS 13.0, *)
    func recognizeText(from cgImage: CGImage) async throws -> String {
        logger.debug("Starting Live Text analysis")

        // Convert CGImage to NSImage for the analyzer
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

        do {
            // Perform the analysis
            let analysis = try await analyzer.analyze(nsImage, orientation: .up, configuration: configuration)
            let transcript = analysis.transcript

            guard !transcript.isEmpty else {
                logger.debug("Live Text analysis found no text")
                throw TextRecognitionError.noTextFound
            }

            // Remove newline characters to prevent issues with paragraph detection
            let cleanedTranscript = transcript.replacingOccurrences(of: "\n", with: " ")

            logger.debug("Live Text analysis successful")
            return cleanedTranscript

        } catch {
            logger.error("Live Text analysis failed: \(String(describing: error), privacy: .public)")
            throw TextRecognitionError.analysisFailed(error)
        }
    }
}
