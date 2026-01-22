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
    
    public enum ModelUploadState: Equatable, Sendable {
        case idle
        case uploading(progress: Double)
        case completed(url: URL)
        case failed(error: String)
        
        var completedURL: URL? {
            if case .completed(let url) = self { return url }
            return nil
        }
    }
    
    var uploadState: ModelUploadState = .idle
    private(set) var captureSessionID: UUID = UUID()
    private var modelUploadTask: Task<Void, Never>?
    private(set) var localModelURL: URL?
    
    /// Starts background upload strictly if constraints are met.
    /// Triggered by data events (file generation), NOT UI state.
    func startBackgroundUpload(modelURL: URL, sessionID: UUID) {
        print("🔍 [UPLOAD CHECK] startBackgroundUpload called")
        print("🔍 [UPLOAD CHECK] - Requested session: \(sessionID)")
        print("🔍 [UPLOAD CHECK] - Current session: \(self.captureSessionID)")
        print("🔍 [UPLOAD CHECK] - Requested URL: \(modelURL.path)")
        print("🔍 [UPLOAD CHECK] - Current localModelURL: \(self.localModelURL?.path ?? "nil")")
        print("🔍 [UPLOAD CHECK] - Current uploadState: \(self.uploadState)")
        
        // 1. Session Identity Check
        guard sessionID == self.captureSessionID else {
            logger.warning("Upload rejected: Session ID mismatch. Current: \(self.captureSessionID), Request: \(sessionID)")
            print("❌ [UPLOAD REJECTED] Session ID mismatch")
            return
        }
        
        // 2. File Identity Check (Path-based, not instance-based)
        let requestedPath = modelURL.standardizedFileURL.path
        let currentPath = self.localModelURL?.standardizedFileURL.path
        guard requestedPath == currentPath else {
            logger.warning("Upload rejected: URL path mismatch. Current: \(currentPath ?? "nil"), Request: \(requestedPath)")
            print("❌ [UPLOAD REJECTED] URL path mismatch")
            print("   Current: \(currentPath ?? "nil")")
            print("   Request: \(requestedPath)")
            return
        }
        
        // 3. File Existence Check
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            logger.error("Upload rejected: File does not exist at path: \(modelURL.path)")
            print("❌ [UPLOAD REJECTED] File does not exist")
            return
        }
        
        // 4. Idempotency Check
        if case .uploading = uploadState {
            logger.warning("Upload already in progress for session \(sessionID). Ignoring.")
            return
        }
        if case .completed = uploadState {
            logger.warning("Upload already completed for session \(sessionID). Ignoring.")
            return
        }
        
        logger.log("Starting background upload for session: \(sessionID)")
        print("🚀 [UPLOAD STARTED] All checks passed, starting upload...")
        uploadState = .uploading(progress: 0.0)
        
        // 5. Background Task Wrapper
        let taskID = UIApplication.shared.beginBackgroundTask {
            // End handler (if time runs out)
            logger.error("Background time expired for upload task.")
        }
        
        modelUploadTask = Task {
            defer {
                UIApplication.shared.endBackgroundTask(taskID)
            }
            
            var attempts = 0
            let maxRetries = 3
            
            while attempts < maxRetries {
                do {
                    if Task.isCancelled { return }
                    
                    let filename = "\(sessionID.uuidString).usdz" // Use session ID for filename to match session
                    // Using SupabaseManager.shared directly
                    let resultURL = try await SupabaseManager.shared.uploadModel(fileURL: modelURL, name: filename)
                    
                    if !Task.isCancelled {
                       await MainActor.run {
                           // Re-verify session ID before committing state
                           guard self.captureSessionID == sessionID else {
                               logger.warning("Upload finished but session ID changed. Discarding result.")
                               return
                           }
                           self.uploadState = .completed(url: URL(string: resultURL)!)
                           logger.log("Background upload successfully completed for session \(sessionID): \(resultURL)")
                       }
                    }
                    return // Success
                } catch {
                    attempts += 1
                    logger.warning("Upload attempt \(attempts) failed for session \(sessionID): \(error.localizedDescription)")
                    
                    if attempts >= maxRetries {
                        if !Task.isCancelled {
                            await MainActor.run {
                                guard self.captureSessionID == sessionID else { return }
                                self.uploadState = .failed(error: error.localizedDescription)
                                logger.error("Background upload failed after \(maxRetries) attempts for session \(sessionID).")
                            }
                        }
                        return // Failure
                    }
                    
                    // Simple backoff: 2s, 4s
                    if !Task.isCancelled {
                         try? await Task.sleep(nanoseconds: UInt64(attempts) * 2 * 1_000_000_000)
                    }
                }
            }
        }
    }
    
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
        uploadState = .idle
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
                    logger.log("Resuming upload for dish \(dishId)...")
                    let filename = "\(UUID().uuidString).usdz"
                    let uploadedURL = try await SupabaseManager.shared.uploadModel(fileURL: fileURL, name: filename)
                    
                    logger.log("Upload success. Updating dish \(dishId)...")
                    try await SupabaseManager.shared.updateDish(id: dishId, modelURL: uploadedURL, generationStatus: "completed")
                    
                    logger.log("Dish \(dishId) updated successfully via resume logic.")
                    updatedList.remove(at: index) // Success, remove from queue
                } catch {
                    logger.error("Failed to resume upload for dish \(dishId): \(error.localizedDescription). Will retry later.")
                    // Leave in queue for next retry
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
        
        // 🔥 DATA-DRIVEN UPLOAD: Start upload immediately when model URL is set
        print("🔥 [DATA-DRIVEN] Model URL set, triggering upload...")
        startBackgroundUpload(modelURL: url, sessionID: captureSessionID)
    }
}

extension AppDataModel {
    private func attachListeners() {
        logger.debug("Attaching listeners...")
        guard let model = objectCaptureSession else {
            fatalError("Logic error")
        }

        tasks.append(
            Task<Void, Never> { [weak self] in
                for await newFeedback in model.feedbackUpdates {
                    logger.debug("Task got async feedback change to: \(String(describing: newFeedback))")
                    self?.updateFeedbackMessages(for: newFeedback)
                }
                logger.log("^^^ Got nil from stateUpdates iterator!  Ending observation task...")
            })

        tasks.append(Task<Void, Never> { [weak self] in
            for await newState in model.stateUpdates {
                logger.debug("Task got async state change to: \(String(describing: newState))")
                self?.onStateChanged(newState: newState)
            }
            logger.log("^^^ Got nil from stateUpdates iterator!  Ending observation task...")
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
        logger.log("startNewCapture() called...")
        
        // 🔥 CRITICAL: Reset upload state for new capture
        // Without this, second capture will be silently skipped if first one completed/failed
        uploadState = .idle
        localModelURL = nil
        modelUploadTask?.cancel()
        modelUploadTask = nil
        // DO NOT touch captureSessionID here - it stays frozen for the entire flow
        
        if !ObjectCaptureSession.isSupported {
            preconditionFailure("ObjectCaptureSession is not supported on this device!")
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
        configuration.isOverCaptureEnabled = true
        configuration.checkpointDirectory = captureFolderManager.checkpointFolder
        // Starts the initial segment and sets the output locations.
        session.start(imagesDirectory: captureFolderManager.imagesFolder,
                      configuration: configuration)

        if case let .failed(error) = session.state {
            logger.error("Got error starting session! \(String(describing: error))")
            switchToErrorState(error: error)
        } else {
            state = .capturing
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
        if case .completed = newState {
            logger.log("ObjectCaptureSession moved in .completed state.")
            if isSaveDraftEnabled {
                logger.log("The data is stored. Closing the session...")
                reset()
            } else {
                logger.log("Switch app model to reconstruction...")
                state = .prepareToReconstruct
            }
        } else if case let .failed(error) = newState {
            logger.error("OCS moved to error state \(String(describing: error))...")
            if case ObjectCaptureSession.Error.cancelled = error {
                state = .restart
            } else {
                switchToErrorState(error: error)
            }
        }
    }

    private func updateFeedbackMessages(for feedback: Set<Feedback>) {
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
                    logger.error("Starting new capture failed!")
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
                reset()
            case .completed:
                // Do not auto-reset here. Wait for UI to consume the result.
                logger.log("State is completed. Waiting for UI to handle next steps.")
                break
            case .viewing:
                photogrammetrySession = nil

                removeCheckpointFolder()
            case .failed:
                logger.error("App failed state error=\(String(describing: self.error!))")
                // We will show error screen here
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
}
