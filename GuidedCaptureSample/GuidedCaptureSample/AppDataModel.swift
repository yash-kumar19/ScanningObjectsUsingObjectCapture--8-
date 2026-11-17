/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A data model for maintaining the app state, including the underlying object capture state as well as any extra app state
 you maintain in addition, perhaps with invariants between them.
*/

import RealityKit
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem,
                            category: "AppDataModel")

@MainActor
@Observable
class AppDataModel: Identifiable {
    static let instance = AppDataModel()

    /// When we start the capture phase, this will be set to the correct locations in the captureFolderManager.
    var objectCaptureSession: ObjectCaptureSession? {
        willSet {
            detachListeners()
        }
        didSet {
            guard objectCaptureSession != nil else { return }
            attachListeners()
        }
    }

    static let minNumImages = 10

    /// Once we are headed to reconstruction portion, we will hold the session here.
    private(set) var photogrammetrySession: PhotogrammetrySession?

    /// When we start a new capture, the folder will be set here.
    private(set) var captureFolderManager: CaptureFolderManager?

    /// Shows whether the user decided to skip reconstruction.
    private(set) var isSaveDraftEnabled = false

    var messageList = TimedMessageList()

    enum ModelState {
        case notSet
        case ready
        case capturing
        case prepareToReconstruct
        case reconstructing
        case viewing
        case completed
        case restart
        case failed
    }

    var state: ModelState = .notSet {
        didSet {
            logger.debug("didSet AppDataModel.state to \(String(describing: self.state))")
            performStateTransition(from: oldValue, to: state)
        }
    }

    var orbit: Orbit = .orbit1
    var isObjectFlipped: Bool = false

    var hasIndicatedObjectCannotBeFlipped: Bool = false
    var hasIndicatedFlipObjectAnyway: Bool = false
    var isObjectFlippable: Bool {
        // Override the objectNotFlippable feedback if the user has indicated
        // the object cannot be flipped or if they want to flip the object anyway
        guard !hasIndicatedObjectCannotBeFlipped else { return false }
        guard !hasIndicatedFlipObjectAnyway else { return true }
        guard let session = objectCaptureSession else { return true }
        return !session.feedback.contains(.objectNotFlippable)
    }

    enum CaptureMode: Equatable {
        case object
        case area
    }

    var captureMode: CaptureMode = .object

    // When state moves to failed, this is the error causing it.
    private(set) var error: Swift.Error?

    // Use setShowOverlaySheets(to:) to change this so you can maintain ObjectCaptureSession's pause state
    // properly because you don't hide the ObjectCaptureView. If you hide the ObjectCaptureView it pauses automatically.
    private(set) var showOverlaySheets = false

    // Shows whether the tutorial has played once during a session.
    var tutorialPlayedOnce = false

    // Postpone creating ObjectCaptureSession and PhotogrammetrySession until necessary.
    private init() {
        state = .notSet
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAppTermination(notification:)),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        DispatchQueue.main.async {
            self.detachListeners()
        }
    }

    /// Once reconstruction and viewing are complete, this should be called to let the app know it can go back to the new capture
    /// view.  We explicitly DO NOT destroy the model here to avoid transition state errors.  The splash screen will set up the
    /// AppDataModel to a clean slate when it starts.
    /// This can also be called after a cancelled or error reconstruction to go back to the start screen.
    func endCapture() {
        state = .completed
    }

    func removeCaptureFolder() {
        logger.log("Removing the capture folder...")
        guard let url = captureFolderManager?.captureFolder else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // Don't touch the showOverlaySheets directly, call setShowOverlaySheets() instead.
    // Since we use sheets and leave the ObjectCaptureView on screen and blur it underneath,
    // the session doesn't pause. We need to pause/resume the session by hand.
    func setShowOverlaySheets(to shown: Bool) {
        guard shown != showOverlaySheets else { return }
        if shown {
            showOverlaySheets = true
            objectCaptureSession?.pause()
        } else {
            objectCaptureSession?.resume()
            showOverlaySheets = false
        }
    }

    func saveDraft() {
        objectCaptureSession?.finish()
        isSaveDraftEnabled = true
    }

    // - MARK: Private Interface

    private var currentFeedback: Set<Feedback> = []

    private typealias Feedback = ObjectCaptureSession.Feedback
    private typealias Tracking = ObjectCaptureSession.Tracking

    private var tasks: [ Task<Void, Never> ] = []
    
    // MARK: - Upload Management
    
    // Upload state tracking now handled by BackgroundUploader
    private(set) var captureSessionID: UUID = UUID()
    private var modelUploadTask: Task<Void, Never>?
    private(set) var localModelURL: URL?
    
    // startBackgroundUpload removed in favor of BackgroundUploader trigger in UI
    
    /// Invariant:
    /// 1. Cancel uploadTask
    /// 2. Reset uploadState
    /// 3. Invalidate captureSessionID
    /// 4. Leave no background work alive
    func cancelUploadAndRestart() {
        logger.log("Cancelling upload and restarting capture. Explicit user action.")
        
        // 1. Cancel Task
        modelUploadTask?.cancel()
        modelUploadTask = nil
        
        // 2. Reset State
        localModelURL = nil
        
        // 3. Invalidate Session
        captureSessionID = UUID()
        logger.log("New Session ID generated: \(self.captureSessionID)")
        
        // 4. Trigger Restart
        state = .restart
    }
    
    func resumePendingUploads() {
        Task {
            // Read pending uploads
            guard let pendingList = UserDefaults.standard.array(forKey: "pending_dish_uploads") as? [[String: String]],
                  !pendingList.isEmpty else {
                logger.log("No pending uploads to resume.")
                return
            }
            
            logger.log("Found \(pendingList.count) pending uploads. Resuming...")
            
            var updatedList = pendingList
            
            for (index, item) in pendingList.enumerated().reversed() {
                guard let dishId = item["dish_id"],
                      let localPath = item["local_path"] else {
                    continue
                }
                
                let fileURL = URL(fileURLWithPath: localPath)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    logger.warning("Pending upload file missing at \(localPath). Removing from queue.")
                    updatedList.remove(at: index)
                    continue
                }
                
                do {
                    let sessionId = item["session_id"] ?? UUID().uuidString
                    logger.log("Resuming upload for dish \(dishId) via BackgroundUploader...")
                    
                    let token = try await SupabaseManager.shared.getValidAccessTokenOrRefresh()
                    
                    try BackgroundUploader.shared.startUpload(
                        fileURL: fileURL,
                        name: "\(sessionId).usdz",
                        dishId: dishId,
                        intendedStatus: "published",
                        sessionId: sessionId,
                        token: token
                    )
                    
                    logger.log("Dish \(dishId) resumed via background uploader.")
                } catch {
                    logger.error("Failed to enqueue background upload for dish \(dishId): \(error.localizedDescription). Will retry later.")
                }
            }
            
            // Save updated list
            updatedList = updatedList // Avoid mutating iterator source directly if not reversed, but here we used reversed index
            UserDefaults.standard.set(updatedList, forKey: "pending_dish_uploads")
        }
    }

    func setLocalModelURL(_ url: URL) {
        self.localModelURL = url
        logger.debug("Local Model URL set to: \(url.path)")
    }
}

extension AppDataModel {
    private func attachListeners() {
        logger.debug("Attaching listeners...")
        guard let model = objectCaptureSession else {
            fatalError("Logic error")
        }

        // ObjectCaptureSession properties are MainActor-isolated, so we must use
        // a Task bound to the MainActor. Using `@MainActor` guarantees the closure
        // executes correctly on the main thread, satisfying RealityKit and preventing
        // the GCD memory corruption crash that DispatchQueue.main.async caused.
        tasks.append(
            Task { @MainActor [weak self] in
                for await newFeedback in model.feedbackUpdates {
                    self?.updateFeedbackMessages(for: newFeedback)
                }
            })

        tasks.append(
            Task { @MainActor [weak self] in
                for await newState in model.stateUpdates {
                    self?.onStateChanged(newState: newState)
                }
            })
    }

    private func detachListeners() {
        logger.debug("Detaching listeners...")
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }

    @objc
    private func handleAppTermination(notification: Notification) {
        logger.log("Notification for the app termination is received...")
        if state == .ready || state == .capturing {
            removeCaptureFolder()
        }
    }

    // Should be called when a new capture is to be created, before the session will be needed.
    private func startNewCapture() throws {
        Logger.capture.info("startNewCapture() called. Setting up capture folder and instantiating ObjectCaptureSession...")
        
        // 🔥 CRITICAL: Reset upload state for new capture
        // Without this, second capture will be silently skipped if first one completed/failed
        localModelURL = nil
        modelUploadTask?.cancel()
        modelUploadTask = nil
        // DO NOT touch captureSessionID here - it stays frozen for the entire flow
        
        if !ObjectCaptureSession.isSupported {
            throw NSError(
                domain: "GuidedCaptureSample",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey:
                    "ObjectCaptureSession is not supported on this device. " +
                    "LiDAR-equipped iPhone/iPad is required (iPhone 12 Pro or later)."]
            )
        }

        captureFolderManager = try CaptureFolderManager()
        objectCaptureSession = ObjectCaptureSession()

        guard let session = objectCaptureSession else {
            preconditionFailure("startNewCapture() got unexpectedly nil session!")
        }

        guard let captureFolderManager else {
            preconditionFailure("captureFolderManager unexpectedly nil!")
        }

        var configuration = ObjectCaptureSession.Configuration()
        configuration.isOverCaptureEnabled = false
        configuration.checkpointDirectory = captureFolderManager.checkpointFolder
        
        // 🔥 CRITICAL FIX: We must set the state to .capturing BEFORE we call session.start.
        // This allows SwiftUI to mount `CapturePrimaryView` and size its underlying CAMetalLayer
        // to the full screen. If we call session.start() synchronously while the view is
        // still being inserted, the CAMetalLayer is 0x0 and permanently corrupts the
        // voxel integration pipeline.
        Logger.capture.info("Setting state to .capturing to mount CapturePrimaryView...")
        state = .capturing
        
        // ✅ Use Task { @MainActor } instead of DispatchQueue.main.async to stay within the
        // Swift concurrency model. Two `await Task.yield()` calls surrender the main runloop
        // twice — once for SwiftUI to commit the CapturePrimaryView layout (CAMetalLayer sized),
        // and once for the GPU driver to allocate the drawable backing store.
        // This eliminates the SIGABRT / "9000+ ms" hang on first-open.
        Task { @MainActor [weak self] in
            guard let self else { return }
            Logger.capture.info("Yielding main actor control (Yield 1: let SwiftUI commit CapturePrimaryView)...")
            await Task.yield()
            Logger.capture.info("Yielding main actor control (Yield 2: let the GPU driver size the CAMetalLayer)...")
            await Task.yield()
            
            Logger.capture.info("Invoking session.start()...")
            // Starts the initial segment and sets the output locations after view is laid out.
            session.start(imagesDirectory: captureFolderManager.imagesFolder,
                          configuration: configuration)
            
            if case let .failed(error) = session.state {
                Logger.capture.error("session.start() failed: \(String(describing: error))")
                self.switchToErrorState(error: error)
            } else {
                Logger.capture.info("session.start() successfully invoked. Current session state: \(String(describing: session.state))")
            }
        }
    }

    private func switchToErrorState(error inError: Swift.Error) {
        // Set the error first since the transitions will assume it is non-nil!
        error = inError
        state = .failed
    }

    // Moves from prepareToReconstruct to .reconstructing.
    // Should be called from the ReconstructionPrimaryView async task once it is on the screen.
    private func startReconstruction() throws {
        logger.debug("startReconstruction() called.")

        var configuration = PhotogrammetrySession.Configuration()
        if captureMode == .area {
            configuration.isObjectMaskingEnabled = false
        }

        guard let captureFolderManager else {
            preconditionFailure("captureFolderManager unexpectedly nil!")
        }

        configuration.checkpointDirectory = captureFolderManager.checkpointFolder
        photogrammetrySession = try PhotogrammetrySession(
            input: captureFolderManager.imagesFolder,
            configuration: configuration)

        state = .reconstructing
    }

    func reset() {
        logger.info("reset() called...")
        photogrammetrySession = nil
        objectCaptureSession = nil
        captureFolderManager = nil
        showOverlaySheets = false
        orbit = .orbit1
        isObjectFlipped = false
        currentFeedback = []
        messageList.removeAll()
        captureMode = .object
        state = .notSet
        isSaveDraftEnabled = false
        tutorialPlayedOnce = false
        // ❌ REMOVED: captureSessionID = UUID()
        // Session ID is now only regenerated in cancelUploadAndRestart()
        // This preserves session identity across reconstruction + preview + add dish
    }

    private func onStateChanged(newState: ObjectCaptureSession.CaptureState) {
        logger.info("OCViewModel switched to state: \(String(describing: newState))")
        
        switch newState {
        case .capturing:
            Logger.capture.info("Capture session started capturing successfully!")
        case .completed:
            Logger.capture.info("Capture session completed successfully.")
            if isSaveDraftEnabled {
                logger.log("The data is stored. Closing the session...")
                reset()
            } else {
                logger.log("Switch app model to reconstruction...")
                state = .prepareToReconstruct
            }
        case .failed(let error):
            Logger.capture.error("Capture session failed with error: \(error.localizedDescription)")
            if case ObjectCaptureSession.Error.cancelled = error {
                state = .restart
            } else {
                switchToErrorState(error: error)
            }
        default:
            break
        }
    }

    private func updateFeedbackMessages(for feedback: Set<Feedback>) {
        // Log bounding box state changes
        if currentFeedback.contains(.objectNotDetected) && !feedback.contains(.objectNotDetected) {
            Logger.capture.info("Bounding box detected successfully! objectNotDetected feedback cleared.")
        } else if !currentFeedback.contains(.objectNotDetected) && feedback.contains(.objectNotDetected) {
            Logger.capture.info("Bounding box lost or failed. objectNotDetected feedback added.")
        }

        // Compare the incoming feedback with the previous feedback to find the intersection.
        let persistentFeedback = currentFeedback.intersection(feedback)

        // Find the feedbacks that are not active anymore.
        let feedbackToRemove = currentFeedback.subtracting(persistentFeedback)
        for thisFeedback in feedbackToRemove {
            if let feedbackString = FeedbackMessages.getFeedbackString(for: thisFeedback, captureMode: captureMode) {
                messageList.remove(feedbackString)
            }
        }

        // Find the new feedbacks.
        let feebackToAdd = feedback.subtracting(persistentFeedback)
        for thisFeedback in feebackToAdd {
            if let feedbackString = FeedbackMessages.getFeedbackString(for: thisFeedback, captureMode: captureMode) {
                messageList.add(feedbackString)
            }
        }

        currentFeedback = feedback
    }

    private func performStateTransition(from fromState: ModelState, to toState: ModelState) {
        if fromState == toState { return }
        if fromState == .failed { error = nil }

        switch toState {
            case .ready:
                do {
                    try startNewCapture()
                } catch {
                    logger.error("Starting new capture failed: \(error)")
                    switchToErrorState(error: error)
                }
            case .prepareToReconstruct:
                // Clean up the session to free GPU and memory resources.
                objectCaptureSession = nil
                do {
                    try startReconstruction()
                } catch {
                    logger.error("Reconstructing failed!")
                    switchToErrorState(error: error)
                }
            case .restart:
                removeCaptureFolder()
                reset()
            case .completed:
                logger.log("State is completed. Waiting for UI to handle next steps.")
                photogrammetrySession = nil // Release memory immediately
                removeCheckpointFolder()
            case .viewing:
                photogrammetrySession = nil
            case .failed:
                logger.error("App failed state error=\(String(describing: self.error!))")
                photogrammetrySession = nil // Release memory immediately
                removeCaptureFolder()
            default:
                break
        }
    }

    private func removeCheckpointFolder() {
        // Remove checkpoint folder to free up space now that the model is generated.
        if let captureFolderManager {
            DispatchQueue.global(qos: .background).async {
                try? FileManager.default.removeItem(at: captureFolderManager.checkpointFolder)
            }
        }
    }

    func determineCurrentOnboardingState() -> OnboardingState? {
        guard let session = objectCaptureSession else { return nil }

        switch captureMode {
            case .object:
                let orbitCompleted = session.userCompletedScanPass
                var currentState = OnboardingState.tooFewImages
                if session.numberOfShotsTaken >= AppDataModel.minNumImages {
                    switch orbit {
                        case .orbit1:
                            currentState = orbitCompleted ? .firstSegmentComplete : .firstSegmentNeedsWork
                        case .orbit2:
                            currentState = orbitCompleted ? .secondSegmentComplete : .secondSegmentNeedsWork
                        case .orbit3:
                            currentState = orbitCompleted ? .thirdSegmentComplete : .thirdSegmentNeedsWork
                        }
                }
                return currentState
            case .area:
                return .captureInAreaMode
        }
    }
    
    func resetStateAndRestart() {
        logger.info("resetStateAndRestart() called")
        removeCaptureFolder()
        reset()
        state = .ready
    }
}

import os
extension Logger {
    struct CaptureLogger {
        let systemLogger = Logger(subsystem: "com.example.apple-samplecode.guided-capture-sample", category: "Capture")
        
        func info(_ message: String) {
            systemLogger.info("\(message)")
            writeLogToFile(level: "INFO", message: message)
        }
        
        func error(_ message: String) {
            systemLogger.error("\(message)")
            writeLogToFile(level: "ERROR", message: message)
        }
        
        private func writeLogToFile(level: String, message: String) {
            // ⚠️ CRITICAL FIX: DateFormatter is NOT thread-safe. Dispatch file I/O to a
            // dedicated background queue so this is safe to call from any thread.
            // Using a serial queue ensures log entries are written in order.
            Self.logQueue.async {
                let fileManager = FileManager.default
                guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: Date())
                let logFileName = "capture_logs_\(dateString).txt"
                
                let logFileURL = documentsURL.appendingPathComponent(logFileName)
                
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                let logLine = "[\(timestamp)] [\(level)] \(message)\n"
                
                if let data = logLine.data(using: .utf8) {
                    if fileManager.fileExists(atPath: logFileURL.path) {
                        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(data)
                            fileHandle.closeFile()
                        }
                    } else {
                        try? data.write(to: logFileURL, options: .atomic)
                    }
                }
            }
        }
        
        // Serial queue for thread-safe, ordered log file writes
        private static let logQueue = DispatchQueue(label: "com.guidedcapture.logger", qos: .utility)
    }
    
    static let capture = CaptureLogger()
}
