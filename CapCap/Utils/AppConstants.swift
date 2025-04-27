import Foundation

/// Defines constants used throughout the application
struct AppConstants {
    /// Bundle-related constants
    struct Bundle {
        /// Application bundle identifier (fallback value if not available at runtime)
        static let identifier = "net.nuridol.mac.CapCap"
        
        /// Returns the actual bundle identifier or fallback value
        static var currentIdentifier: String {
            return Foundation.Bundle.main.bundleIdentifier ?? identifier
        }
    }
    
    /// Version-related constants
    struct Version {
        /// Application version (corresponds to both CFBundleShortVersionString and CFBundleVersion)
        static let current = "1.0.0"
    }
    
    /// Copyright information
    struct Copyright {
        /// Copyright text with automatically updated year
        static let text = "Copyright © \(Calendar.current.component(.year, from: Date())) nuridol.net. All rights reserved."
    }
}
