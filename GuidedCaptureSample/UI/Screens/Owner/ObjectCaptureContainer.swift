import SwiftUI
import RealityKit
import AVFoundation
import OSLog

struct ObjectCaptureContainer: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppDataModel.self) var appModel
    
    var onCaptureComplete: (URL) -> Void
    
    @State private var showReconstructionView: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var processedModelURL: URL?
    
    @State private var viewHasValidFrame: Bool = false
    @State private var sessionStartScheduled: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
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
        // ─── Geometry-Based Session Start ─────────────────────────────────────
        // CRITICAL: Do NOT start ObjectCaptureSession until the view has a
        // valid (non-zero) frame. A zero-size frame means the CAMetalLayer drawable
        // backing store has not been allocated yet. Starting a session at this point
        // permanently corrupts the voxel integration compute pipeline.
        //
        // One-shot gate: viewHasValidFrame is set exactly once (the first time the
        // layout size is non-zero). Subsequent geometry changes (rotation, safe-area
        // shifts, etc.) are ignored because !viewHasValidFrame will be false.
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            if newSize.width > 0 && newSize.height > 0 && !viewHasValidFrame {
                Logger.capture.info("[Lifecycle] View layout validated: \(newSize.width)×\(newSize.height). Setting viewHasValidFrame = true.")
                viewHasValidFrame = true
                scheduleSessionStart()
            } else if viewHasValidFrame {
                // Geometry changed after initial layout (e.g. rotation). Startup already
                // completed or was scheduled — do NOT start a second session.
                Logger.capture.info("[Lifecycle] Geometry updated to \(newSize.width)×\(newSize.height) — startup already handled, ignoring.")
            }
        }
        .onAppear {
            // ⚠️ This is a strict fallback path ONLY. It only fires if onGeometryChange
            // has not yet validated the frame (e.g. some older SwiftUI versions or edge
            // cases where geometry change fires after appear). We check BOTH guards:
            //   1. viewHasValidFrame  — layout has a real, non-zero size
            //   2. !sessionStartScheduled — ensures exactly one startup attempt
            //
            // Do NOT remove the viewHasValidFrame check here. Without it, this path
            // would eagerly start the session before layout is committed, which is
            // the exact bug that caused the "0×0 CAMetalLayer" pipeline corruption.
            Task { @MainActor in
                if viewHasValidFrame && !sessionStartScheduled {
                    Logger.capture.info("[Lifecycle] onAppear fallback: view has valid frame and session not yet scheduled. Scheduling now.")
                    scheduleSessionStart()
                } else if !viewHasValidFrame {
                    Logger.capture.info("[Lifecycle] onAppear fired but view frame not yet valid. Waiting for onGeometryChange.")
                } else {
                    Logger.capture.info("[Lifecycle] onAppear fired but session already scheduled. Skipping.")
                }
            }
        }
        .onChange(of: appModel.state) { _, newState in
            print("ObjectCaptureContainer state changed to: \(newState)")
            
            if newState == .failed {
                // Clear crash-in-progress flag on managed failure
                UserDefaults.standard.set(false, forKey: "capture_in_progress")
                showErrorAlert = true
                showReconstructionView = false
            } else if newState == .reconstructing || newState == .viewing {
                // ✅ APPLE-PREFERRED: Don't assume filename, URL will be set via setLocalModelURL()
                showErrorAlert = false
                showReconstructionView = true
            } else if newState == .completed {
                // ✅ Mark clean completion (clears crash detection flag)
                UserDefaults.standard.set(true, forKey: "capture_completed_cleanly")
                UserDefaults.standard.set(false, forKey: "capture_in_progress")
                processedModelURL = appModel.localModelURL
            } else if newState == .restart || newState == .notSet {
                UserDefaults.standard.set(false, forKey: "capture_in_progress")
                dismiss()
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
            "Capture Failed",
            isPresented: $showErrorAlert,
            actions: {
                Button("Cancel", role: .cancel) {
                    appModel.reset()
                    dismiss()
                }
                Button("Retry") {
                    appModel.resetStateAndRestart()
                }
            },
            message: {
                Text(errorDiagnosticText)
            }
        )
    }

    /// Schedules the ObjectCaptureSession start.
    /// ONE-SHOT: Must only be called after the view has a valid (non-zero) frame.
    /// Guarded by both `sessionStartScheduled` and a valid app-model state check.
    private func scheduleSessionStart() {
        guard !sessionStartScheduled else {
            Logger.capture.info("[Lifecycle] scheduleSessionStart() called but already scheduled. Skipping.")
            return
        }
        guard appModel.state == .notSet || appModel.state == .completed else {
            Logger.capture.info("[Lifecycle] scheduleSessionStart() called but appModel.state=\(String(describing: appModel.state)) is not eligible. Skipping.")
            return
        }
        sessionStartScheduled = true
        Logger.capture.info("[Lifecycle] scheduleSessionStart() — one-shot gate acquired. Checking camera permission...")

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            Logger.capture.info("[Permission] Camera permission not determined. Requesting access...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        Logger.capture.info("[Permission] Camera access granted by user. Proceeding to startSession().")
                        self.startSession()
                    } else {
                        Logger.capture.info("[Permission] Camera access denied by user. Dismissing.")
                        self.dismiss()
                    }
                }
            }
        case .authorized:
            Logger.capture.info("[Permission] Camera already authorized. Proceeding to startSession().")
            startSession()
        default:
            Logger.capture.info("[Permission] Camera access restricted or denied (status=\(status.rawValue)). Dismissing.")
            dismiss()
        }
    }

    /// Triggers the appModel state transition that causes `startNewCapture()` to be called.
    /// The actual session.start() call happens INSIDE startNewCapture(), after two
    /// Task.yield() calls guarantee the CapturePrimaryView is committed to the layout.
    /// The yields are a best-effort UI-settle helper — the real gate is the geometry check.
    private func startSession() {
        Logger.capture.info("[Lifecycle] startSession() — setting crash-detection flags and transitioning appModel to .ready.")
        // Set crash-detection flag BEFORE starting capture so that if the process is
        // killed mid-capture, the next cold launch can detect the incomplete session
        // and reset the Metal warmup state.
        UserDefaults.standard.set(true, forKey: "capture_in_progress")
        UserDefaults.standard.set(false, forKey: "capture_completed_cleanly")
        // Triggers startNewCapture() via the state machine in AppDataModel
        appModel.state = .ready
        Logger.capture.info("[Lifecycle] appModel.state set to .ready. startNewCapture() will be invoked by the state machine.")
    }
    
    private var errorDiagnosticText: String {
        let errorText = appModel.error != nil ? "\(appModel.error!.localizedDescription)" : "Unknown error"
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelMirror = Mirror(reflecting: systemInfo.machine)
        let deviceModel = modelMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        let osVersion = UIDevice.current.systemVersion
        
        return """
        \(errorText)
        
        --- Diagnostic Info ---
        Device: \(deviceModel)
        iOS: \(osVersion)
        """
    }
}
