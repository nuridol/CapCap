# CapCap

A native macOS app (SwiftUI, VisionKit) to continuously capture text from a user-selected screen region. Select an area, start capture, and get the text.

## Introduction

CapCap solves the problem of extracting text from non-selectable screen areas (images, videos, app interfaces) by continuously monitoring a user-defined region and using macOS's Live Text (VisionKit) to extract text automatically.

![Sample](https://github.com/user-attachments/assets/7a93931c-1325-4399-a426-8f9a27610a56)

## Key Features

*   **Region Selection:** Select any part of the screen using a drag-and-drop overlay.
*   **Continuous Capture:** Automatically captures the selected region at a configurable interval (default: 1s).
*   **Live Text Extraction:** Uses the Vision framework to accurately extract text from captured images.
*   **Paragraph Detection:** Intelligently appends or updates captured text to minimize redundancy.
*   **Controls:** Start/Stop capture, adjust overlay transparency, save captured text to a file, clear text area.

## Tech Stack

*   **Language:** Swift
*   **UI:** SwiftUI
*   **Text Recognition:** VisionKit (`ImageAnalyzer`)
*   **Screen Capture:** Core Graphics (`CGWindowListCreateImage`)
*   **Concurrency:** Swift Concurrency (`async/await`)
*   **Architecture:** MVVM

## System Requirements

*   macOS 13.0 (Ventura) or later (due to VisionKit `ImageAnalyzer` usage)
*   Xcode (for building)

## Build & Run

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd CapCap
    ```
2.  **Grant Screen Recording Permission:** The app needs Screen Recording permission. The first time you run it (or try to capture), it might prompt you or require you to manually enable it in `System Settings > Privacy & Security > Screen Recording`. You might need to restart the app after granting permission.
3.  **Build the project:**
    ```bash
    swift build
    ```
4.  **Run the application:**
    *   Locate the executable in the `.build/debug/` directory (e.g., `.build/debug/CapCap`).
    *   Run it from the terminal: `./.build/debug/CapCap` or double-click it in Finder.

## How to Use

1.  Launch the CapCap application.
2.  Click the "Select Region" button. A full-screen overlay will appear.
3.  Click and drag to define the screen area you want to capture.
4.  Adjust the capture interval (seconds) and overlay transparency (%) using the sliders/steppers if needed.
5.  Click the "Start Capture" button.
6.  Text appearing within the selected region will be automatically extracted and displayed in the text area.
7.  Click "Stop Capture" to pause.
8.  Use "Save" to save the captured text to a file or "Clear" to empty the text area.
