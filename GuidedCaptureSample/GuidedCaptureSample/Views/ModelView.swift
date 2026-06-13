/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A wrapper for AR QuickLook viewer that lets you view the reconstructed USDZ model file directly.
*/

import QuickLook
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "ModelView")


// MARK: - Wrapper
struct ModelView: View {
    let modelFile: URL
    let endCaptureCallback: () -> Void
    
    var body: some View {
        CustomModelViewer(modelFile: modelFile, onDismiss: endCaptureCallback)
    }
}

