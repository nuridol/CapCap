// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CapCap",
    platforms: [
        .macOS(.v12) // Specify macOS 12.0 or later (adjust if needed based on API usage)
    ],
    products: [
        .executable(name: "CapCap", targets: ["CapCap"])
    ],
    dependencies: [
        // No external dependencies for now
    ],
    targets: [
        // The main application target
        .executableTarget(
            name: "CapCap",
            dependencies: [],
            path: "CapCap", // Specify that source files are inside the "CapCap" directory
            resources: [.process("Resources")] // Include the Resources directory
        )
        // If you had tests, define a test target:
        // .testTarget(
        //     name: "CapCapTests",
        //     dependencies: ["CapCap"]),
    ]
)
