/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The single entry point of the app.
*/

import SwiftUI

@main
struct GuidedCaptureSampleApp: App {
    static let subsystem: String = "com.example.apple-samplecode.guided-capture-sample"

    init() {
        // ─── Metal GPU Validation Override ───────────────────────────────────
        // Bypass Metal Validation to prevent RealityKit's meshShadowCalculateMip from crashing
        // the app during bounding box detection. Since the GCD crash is resolved via Scheme settings,
        // this is now safe to use.
        setenv("MTL_DEBUG_LAYER", "0", 1)
        setenv("MTL_ARGUMENT_VALIDATION", "0", 1)
        setenv("MTL_SHADER_VALIDATION", "0", 1)

        // ─── Crash Recovery ───────────────────────────────────────────────
        // Log whether the previous capture session exited cleanly.
        // capture_in_progress is set true in ObjectCaptureContainer.startSession()
        // capture_completed_cleanly is set true in AppDataModel after capture finishes.
        // If we launch and find in_progress=true + completed=false, the last session crashed.
        let captureInProgress = UserDefaults.standard.bool(forKey: "capture_in_progress")
        let captureCompleted  = UserDefaults.standard.bool(forKey: "capture_completed_cleanly")
        if captureInProgress && !captureCompleted {
            // Previous session crashed mid-capture. Log for diagnostics.
            // The geometry-based startup gate handles the next session correctly
            // regardless — no warmup delay needed.
            print("[AppInit] Previous capture session did NOT complete cleanly. Crash likely.")
        } else {
            print("[AppInit] Previous capture session exited cleanly (or no session was active).")
        }
        // Reset flags for this launch
        UserDefaults.standard.set(false, forKey: "capture_in_progress")
        UserDefaults.standard.set(false, forKey: "capture_completed_cleanly")
    }

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
