/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A wrapper for AR QuickLook viewer that lets you view the reconstructed USDZ model file directly.
*/

import QuickLook
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "ModelView")

// Using UIViewControllerRepresentable to wrap QLPreviewController directly
struct ModelView: UIViewControllerRepresentable {
    let modelFile: URL
    let endCaptureCallback: () -> Void

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        // QLPreviewController usually presents modally, but in fullScreenCover we might want to ensure it feels right.
        // The controller itself is a view controller.
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // Force refresh if needed
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let parent: ModelView

        init(parent: ModelView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.modelFile as QLPreviewItem
        }
        
        func previewControllerDidDismiss(_ controller: QLPreviewController) {
             logger.log("Quick Look dismissed by user interaction")
             parent.endCaptureCallback()
        }
        
        // This is not always called if wrapped in SwiftUI sheet/cover, but good to have
        func previewControllerWillDismiss(_ controller: QLPreviewController) {
            logger.log("Exiting ARQL ...")
        }
    }
}
