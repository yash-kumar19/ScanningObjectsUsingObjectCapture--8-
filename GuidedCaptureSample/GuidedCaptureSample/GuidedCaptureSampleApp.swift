/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The single entry point of the app.
*/

import SwiftUI

@main
struct GuidedCaptureSampleApp: App {
    static let subsystem: String = "com.example.apple-samplecode.guided-capture-sample"

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Handle deep links via DeepLinkHandler
                    // This will route menu links and OAuth callbacks appropriately
                    _ = DeepLinkHandler.shared.handleURL(url)
                }
                .task {
                    AppDataModel.instance.resumePendingUploads()
                }
        }
    }
}
