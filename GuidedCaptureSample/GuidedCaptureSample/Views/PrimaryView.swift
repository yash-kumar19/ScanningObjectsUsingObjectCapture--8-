/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main view that includes both the image capture and reconstruction.
*/

import SwiftUI

import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "PrimaryView")

struct PrimaryView: View {
    @Environment(AppDataModel.self) var appModel

    @State private var showReconstructionView: Bool = false
    @State private var showErrorAlert: Bool = false
    private var showProgressView: Bool {
        appModel.state == .completed || appModel.state == .restart || appModel.state == .ready || appModel.state == .notSet
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if appModel.state == .capturing {
                if let session = appModel.objectCaptureSession {
                    CapturePrimaryView(session: session)
                }
            } else if appModel.state == .failed {
                ErrorDisplayView(error: appModel.error) {
                    logger.log("Retry tapped in ErrorDisplayView...")
                    appModel.state = .restart
                }
            } else if showProgressView {
                LoadingDisplayView()
            }
        }
        .task {
            appModel.startNewCaptureIfNeeded()
        }
        .onChange(of: appModel.state) { _, newState in
            if newState == .failed {
                showErrorAlert = true
                showReconstructionView = false
            } else {
                showErrorAlert = false
                showReconstructionView = newState == .reconstructing || newState == .viewing
            }
        }
        .sheet(isPresented: $showReconstructionView) {
            if let folderManager = appModel.captureFolderManager {
                // ✅ APPLE-PREFERRED: Use captureSessionID for predictable, unique filename
                let outputFile = folderManager.modelsFolder.appendingPathComponent("\(appModel.captureSessionID.uuidString).usdz")
                ReconstructionPrimaryView(outputFile: outputFile, onDismiss: {
                    showReconstructionView = false
                })
                    .interactiveDismissDisabled()
            }
        }
        .alert(
            "Notice",
            isPresented: $showErrorAlert,
            actions: {
                Button("OK") {
                    logger.log("Calling restart...")
                    appModel.state = .restart
                }
            },
            message: {
                if let error = appModel.error {
                    Text(error.localizedDescription)
                }
            }
        )
    }
}

private struct LoadingDisplayView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)

            Text("Preparing 3D camera...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

private struct ErrorDisplayView: View {
    var error: Swift.Error?
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            Text("Cannot Start 3D Scan")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            Text(error?.localizedDescription ?? "An unexpected error occurred while starting the camera session.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.white, in: Capsule())
            }
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

