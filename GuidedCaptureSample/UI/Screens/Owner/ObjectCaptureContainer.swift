import SwiftUI
import RealityKit

struct ObjectCaptureContainer: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppDataModel.self) var appModel
    
    var onCaptureComplete: (URL) -> Void
    
    @State private var showReconstructionView: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var processedModelURL: URL?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header with Cancel button
                if !showReconstructionView {
                    HStack {
                        Button(action: {
                            appModel.state = .restart
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }
                    .zIndex(10)
                }
                
                // Main Capture View
                if appModel.state == .capturing {
                    if let session = appModel.objectCaptureSession {
                        CapturePrimaryView(session: session)
                    }
                } else if appModel.state == .reconstructing || appModel.state == .viewing {
                     // Handled by sheet
                     Color.clear
                } else {
                     // Loading/Progress
                     ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
        }
        .onAppear {
            if appModel.state == .notSet || appModel.state == .completed {
                appModel.state = .ready // Triggers startNewCapture
            }
        }
        .onChange(of: appModel.state) { _, newState in
            print("ObjectCaptureContainer state changed to: \(newState)")
            
            if newState == .failed {
                showErrorAlert = true
                showReconstructionView = false
            } else if newState == .reconstructing || newState == .viewing {
                // ✅ APPLE-PREFERRED: Don't assume filename, URL will be set via setLocalModelURL()
                showErrorAlert = false
                showReconstructionView = true
            } else if newState == .completed {
                // ✅ Consume the actual URL captured by the system
                processedModelURL = appModel.localModelURL
            }
        }
        .sheet(isPresented: $showReconstructionView, onDismiss: {
            // When reconstruction view is dismissed, check if we have a valid model URL
            if let url = processedModelURL, FileManager.default.fileExists(atPath: url.path) {
                onCaptureComplete(url)
                dismiss()
            }
        }) {
            if let folderManager = appModel.captureFolderManager {
                // ✅ APPLE-PREFERRED: Use captureSessionID for predictable, unique filename
                let outputFile = folderManager.modelsFolder.appendingPathComponent("\(appModel.captureSessionID.uuidString).usdz")
                
                ReconstructionPrimaryView(outputFile: outputFile, onDismiss: { [self] in
                    self.showReconstructionView = false
                })
                    .interactiveDismissDisabled()
                    .environment(appModel) // Ensure environment is passed
            }
        }
        .alert(
            "Failed: " + (appModel.error != nil ? "\(String(describing: appModel.error!))" : ""),
            isPresented: $showErrorAlert
        ) {
            Button("OK") {
                appModel.state = .restart
            }
        }
    }
}
