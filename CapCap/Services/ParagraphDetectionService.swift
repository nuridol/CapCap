import Foundation
import OSLog

/// Represents the outcome of comparing newly extracted text with the previous text
enum ParagraphDetectionResult {
    /// No significant change detected compared to the last line
    case noChange
    /// The new text is considered a continuation/update of the last line
    case updateLastLine(newText: String)
    /// The new text is considered a new paragraph/line
    case addNewLine(newText: String)
}

/// Service responsible for detecting paragraph changes based on text similarity
class ParagraphDetectionService {

    private let logger = Logger(subsystem: AppConstants.Bundle.currentIdentifier, category: "ParagraphDetectionService")

    /// Determines whether new text is a continuation of the previous text or a new paragraph
    /// - Parameters:
    ///   - previousText: The entire text captured so far
    ///   - newText: The newly extracted text from the latest capture
    /// - Returns: A `ParagraphDetectionResult` indicating how the new text relates to the previous text
    func detectChange(previousText: String, newText: String) -> ParagraphDetectionResult {
        // Handle empty new text
        let trimmedNewText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewText.isEmpty else {
            return .noChange
        }

        // Get the last non-empty line from the previous text
        guard let lastLine = previousText.split(separator: "\n", omittingEmptySubsequences: true).last?.trimmingCharacters(in: .whitespacesAndNewlines),
              !lastLine.isEmpty else {
            // If there's no previous text or the last line was empty, add as new line
            return .addNewLine(newText: trimmedNewText)
        }

        // Exact match check
        if lastLine == trimmedNewText {
            return .noChange
        }

        // Calculate similarity using Levenshtein distance
        let distance = levenshteinDistance(from: lastLine, to: trimmedNewText)
        let maxLength = max(lastLine.count, trimmedNewText.count)
        
        guard maxLength > 0 else {
            return .noChange
        }

        // Calculate difference percentage
        let differencePercentage = Double(distance) / Double(maxLength)

        // Determine result based on similarity threshold (10%)
        if differencePercentage < 0.10 {
            // Small difference: update the last line
            return .updateLastLine(newText: trimmedNewText)
        } else {
            // Significant difference: add as new line
            return .addNewLine(newText: trimmedNewText)
        }
    }

    /// Calculates the Levenshtein distance between two strings
    /// - Parameters:
    ///   - s1: First string to compare
    ///   - s2: Second string to compare
    /// - Returns: The minimum number of single-character edits required to change one string into the other
    private func levenshteinDistance(from s1: String, to s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        var d = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        // Initialize first row and column
        for i in 0...m {
            d[i][0] = i
        }
        for j in 0...n {
            d[0][j] = j
        }

        // Convert strings to arrays for faster character access
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        // Fill the distance matrix
        for j in 1...n {
            for i in 1...m {
                let cost = (s1Array[i - 1] == s2Array[j - 1]) ? 0 : 1
                d[i][j] = min(
                    d[i - 1][j] + 1,      // Deletion
                    d[i][j - 1] + 1,      // Insertion
                    d[i - 1][j - 1] + cost // Substitution
                )
            }
        }

        return d[m][n]
    }
}
