import SwiftUI

@available(macOS 13.0, *) // Mark View as available only on macOS 13.0+
struct ContentView: View {
    // Access the shared ViewModel from the environment
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack {
            Text("CapCap - Screen Text Capture")
                .font(.title)
                .padding(.bottom)

            // Settings Section
            HStack {
                Text("Interval (s):")
                TextField("Seconds", value: $viewModel.captureSettings.captureInterval, formatter: NumberFormatter.decimalFormatter)
                    .frame(width: 50)
                    .onChange(of: viewModel.captureSettings.captureInterval) { newValue in
                        viewModel.updateCaptureInterval(newValue)
                    }

                Text("Opacity:")
                Slider(value: $viewModel.captureSettings.overlayTransparency, in: 0.0...1.0, step: 0.05) {
                    Text("Overlay Opacity") // Accessibility label
                }
                .onChange(of: viewModel.captureSettings.overlayTransparency) { newValue in
                     viewModel.updateOverlayTransparency(newValue)
                }
                Text("\(Int(viewModel.captureSettings.overlayTransparency * 100))%")
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal)

            Spacer()

            // Text Editor with automatic scrolling
            ScrollViewReader { scrollProxy in
                ScrollView {
                    // Use ZStack to position the TextEditor within the ScrollView
                    ZStack(alignment: .topLeading) {
                        // Text Editor bound to ViewModel
                        TextEditor(text: $viewModel.capturedContent.fullText)
                            .font(.body) // Use body font for editor
                            .id("textEditor") // ID for ScrollViewReader
                            .padding(1) // Small padding inside to avoid clipping
                            // Necessary to make TextEditor work well within ScrollView
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .border(Color.gray)
                .padding()
                // Watch for changes to scroll to bottom when content changes
                .onChange(of: viewModel.capturedContent.fullText) { _ in
                    withAnimation {
                        scrollProxy.scrollTo("textEditor", anchor: .bottom)
                    }
                }
            }

            Spacer()

            // Status Message
            Text(viewModel.statusMessage)
                .font(.footnote)
                .padding(.bottom, 5)

            // Action Buttons
            HStack {
                Button {
                    viewModel.selectArea()
                } label: {
                    Label("Select Area", systemImage: "crop")
                }

                Button {
                    viewModel.startStopCapture()
                } label: {
                    Label(viewModel.isCapturing ? "Stop Capture" : "Start Capture",
                          systemImage: viewModel.isCapturing ? "stop.circle.fill" : "play.circle.fill")
                }
                .tint(viewModel.isCapturing ? .red : .green) // Color hint for state

                Spacer() // Push save/clear to the right

                Button {
                    viewModel.saveText()
                } label: {
                    Label("Save Text", systemImage: "square.and.arrow.down")
                }

                Button {
                    viewModel.clearText()
                } label: {
                    Label("Clear Text", systemImage: "trash")
                }
                .tint(.red)
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400) // Adjusted minimum size
        // Use onChange to monitor showRegionSelector changes
        .onChange(of: viewModel.showRegionSelector) { newValue in
            if newValue {
                // Use the RegionSelectorWindowManager to show in a window
                viewModel.showRegionSelectorWindow()
            }
        }
    }
}

// Helper view for transparent background is no longer needed with this approach
// struct ClearBackgroundView: NSViewRepresentable { ... }

// Helper formatter for the interval TextField
extension NumberFormatter {
    static var decimalFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        formatter.minimum = 0.1 // Enforce minimum interval visually
        return formatter
    }
}


@available(macOS 13.0, *) // Mark Preview as available only on macOS 13.0+
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy ViewModel instance for the preview
        ContentView()
            .environmentObject(AppViewModel())
    }
}
