/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A motion coach that monitors device attitude using CoreMotion, triggers supplemental high-density shutter
requests every ~7.5 degrees of rotation, tracks angled top coverage per 45-degree sector with hysteresis,
and provides real-time guidance to ensure optimal 3D capture.
*/

import CoreMotion
import RealityKit
import SwiftUI
import os

private let logger = Logger(subsystem: GuidedCaptureSampleApp.subsystem, category: "MotionCoach")

@MainActor
@Observable
final class MotionCoach {
    struct Tuning {
        /// Angular spacing between capture checkpoints in degrees.
        /// 7.8° yields ~46 candidate checkpoints around a 360° orbit, reliably landing at 35-40 photos.
        var stepDegrees: Double = 7.8

        /// Minimum time between manual shutter requests (~5.5 fps max).
        var minSecondsBetweenRequests: Double = 0.18

        /// Fallback time interval to maintain high photo density even when walking at a slower pace.
        var cadenceInterval: Double = 0.55

        /// Minimum angular movement (degrees) required for cadence fallback to prevent stationary duplicates.
        var minAngleCadence: Double = 2.2

        /// Blur guard: maximum angular velocity magnitude allowed (rad/s ≈ 260°/s).
        var maxRotationRate: Double = 4.5

        /// Hard ceiling on total shots per pass to protect memory and storage.
        var maxShotsPerPass: Int = 100

        /// Pitch angle hysteresis thresholds (degrees downward tilt).
        /// Entering angled mode requires >= 32.0°; exiting back to flat requires < 26.0°.
        var angledEnterThreshold: Double = 32.0
        var angledExitThreshold: Double = 26.0

        /// Minimum number of angled shots required per 45° sector.
        var minAngledShotsPerSector: Int = 1

        /// Guidance message displayed when the current orbit sector lacks angled top shots.
        var topHintText: String = "Raise the phone and aim down at the top"

        /// CoreMotion update interval in seconds (20 Hz).
        var updateInterval: Double = 1.0 / 20.0

        /// Flag controlling CMRotationMatrix interpretation:
        /// - true (default): M transforms device coordinates to reference coordinates (columns represent device axes).
        ///   Rear camera (-Z) = column 3 (-m13, -m23, -m33); phone up (+Y) = column 2 (m12, m22).
        /// - false: M transposed (rows represent device axes).
        var matrixMapsDeviceToReference: Bool = true

        /// Horizontal projection magnitude threshold below which heading smoothly hands off to device +Y axis.
        var downwardFacingThreshold: Double = 0.35
    }

    var tuning = Tuning()

    /// The active guidance hint observed directly by the UI banner (avoids TimedMessageList FIFO starvation).
    var activeCoachHint: String? = nil

    /// Sets the target shot count per 360° orbit (e.g. 35 to 40 shots).
    func setTargetShotsPerOrbit(_ targetShots: Int) {
        guard targetShots > 0 else { return }
        tuning.stepDegrees = 360.0 / Double(targetShots)
        logger.info("MotionCoach: target shots set to \(targetShots) (stepDegrees=\(self.tuning.stepDegrees)°)")
    }

    private let motionManager = CMMotionManager()
    private weak var session: ObjectCaptureSession?
    private var onHint: ((String?) -> Void)?

    // Attitude tracking state
    private var isTrackingActive = false
    private var lastHeading = 0.0
    private var lastShotHeading: Double?
    private var lastKnownShotCount = 0
    private var lastRequestTime = Date.distantPast
    private var signedOrbitRadians = 0.0

    // Tilt angle hysteresis state
    private var isCurrentlyAngled = false

    // Per-sector tracking (8 sectors of 45° across 360°)
    private var totalShotsPerSector = [Int](repeating: 0, count: 8)
    private var angledShotsPerSector = [Int](repeating: 0, count: 8)
    private var supplementalShotsCount = 0

    // Per-scan lifecycle & diagnostics
    private var passStartTime: Date?

    // Debug logging throttle
    private var lastDebugLogTime = Date.distantPast

    func start(session: ObjectCaptureSession, onHint: ((String?) -> Void)? = nil) {
        stop()
        guard motionManager.isDeviceMotionAvailable else {
            logger.warning("Device motion is not available on this hardware.")
            return
        }

        self.session = session
        self.onHint = onHint
        resetPass()

        motionManager.deviceMotionUpdateInterval = tuning.updateInterval
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated {
                self?.handle(motion)
            }
        }
        logger.info("MotionCoach started.")
    }

    func stop() {
        logScanSummary()
        motionManager.stopDeviceMotionUpdates()
        setHint(nil)
        session = nil
        onHint = nil
        isTrackingActive = false
        lastShotHeading = nil
        passStartTime = nil
        logger.info("MotionCoach stopped.")
    }

    func resetPass() {
        logScanSummary()
        signedOrbitRadians = 0.0
        isTrackingActive = false
        lastShotHeading = nil
        isCurrentlyAngled = false
        totalShotsPerSector = [Int](repeating: 0, count: 8)
        angledShotsPerSector = [Int](repeating: 0, count: 8)
        supplementalShotsCount = 0
        passStartTime = Date()
        setHint(nil)
        logger.info("MotionCoach pass reset.")
    }

    private func handle(_ motion: CMDeviceMotion) {
        guard let session, session.state == .capturing, !session.isPaused else {
            isTrackingActive = false
            return
        }

        let pose = pose(from: motion.attitude.rotationMatrix)
        let shots = session.numberOfShotsTaken

        // 1. Update tilt state with hysteresis (no flickering between 26° and 32°)
        if pose.tiltDownDegrees >= tuning.angledEnterThreshold {
            isCurrentlyAngled = true
        } else if pose.tiltDownDegrees < tuning.angledExitThreshold {
            isCurrentlyAngled = false
        }

        // 2. Identify current 45° sector index (0..7)
        let normHeading = pose.heading >= 0 ? pose.heading : (pose.heading + 2.0 * .pi)
        let sectorIndex = min(7, max(0, Int(normHeading / (.pi / 4.0))))

        // Periodic debug logging (~1.5 Hz) for live visibility in Xcode LLDB console
        let now = Date()
        if now.timeIntervalSince(lastDebugLogTime) >= 1.5 {
            lastDebugLogTime = now
            print("[MotionCoach Monitor] Heading=\(Int(pose.heading * 180 / .pi))° | Tilt=\(Int(pose.tiltDownDegrees))° | Sector=\(sectorIndex) | TotalShots=\(shots) | CanCapture=\(session.canRequestImageCapture) | Feedback=\(session.feedback)")
        }

        guard isTrackingActive else {
            isTrackingActive = true
            lastHeading = pose.heading
            if lastShotHeading == nil {
                lastShotHeading = pose.heading
            }
            lastKnownShotCount = shots
            if passStartTime == nil {
                passStartTime = now
            }
            print("🚀 [MotionCoach] Tracking activated in .capturing state. Initial shot count: \(shots)")
            return
        }

        // Accumulate orbit angle traversed
        signedOrbitRadians += Self.wrap(pose.heading - lastHeading)
        lastHeading = pose.heading

        // 3. Synchronize tracking when any shot occurs (Apple auto-capture or MotionCoach)
        if shots > lastKnownShotCount {
            let diff = shots - lastKnownShotCount
            totalShotsPerSector[sectorIndex] += diff
            if isCurrentlyAngled {
                angledShotsPerSector[sectorIndex] += diff
            }
            print("📸 [MotionCoach] Shot recorded: \(lastKnownShotCount) -> \(shots) (+\(diff)) | Sector: \(sectorIndex) | Heading: \(Int(pose.heading * 180 / .pi))° | Angled: \(isCurrentlyAngled)")
            lastKnownShotCount = shots
            lastShotHeading = pose.heading
            lastRequestTime = now
        }

        // 4. Update sector-based tilt guidance
        updateTiltGuidance(forSector: sectorIndex)

        // 5. Hard ceiling check: stop extra shots if ceiling reached
        guard shots < tuning.maxShotsPerPass else { return }

        // 6. Thermal state check: pause extra shots on critical; slow down on serious
        let thermalState = ProcessInfo.processInfo.thermalState
        guard thermalState != .critical else { return }

        var effectiveStepDegrees = tuning.stepDegrees
        var effectiveCooldown = tuning.minSecondsBetweenRequests
        if thermalState == .serious {
            // Slow down extra shots when device is under serious thermal stress
            effectiveStepDegrees *= 1.5
            effectiveCooldown *= 2.0
        }

        // 7. Check if user has rotated sufficiently from our last accepted shot heading
        guard let shotHeading = lastShotHeading else {
            lastShotHeading = pose.heading
            lastRequestTime = now
            return
        }

        let moved = abs(Self.wrap(pose.heading - shotHeading))
        let timeSinceLast = now.timeIntervalSince(lastRequestTime)

        // Dual capture trigger:
        // (a) Primary angle step: rotated >= 9.0° (~40 photos per 360° orbit)
        // (b) Cadence fallback: user is moving (>= 3.5°) and >= 0.75s elapsed without a shot
        let isAngleStepReached = moved >= (effectiveStepDegrees * .pi / 180.0) && timeSinceLast >= effectiveCooldown
        let isCadenceFallbackReached = moved >= (tuning.minAngleCadence * .pi / 180.0) && timeSinceLast >= tuning.cadenceInterval

        guard isAngleStepReached || isCadenceFallbackReached else { return }

        // 8. Blur guard: only catch violent whip pans (> 4.5 rad/s ≈ 260°/s)
        let r = motion.rotationRate
        let rotationRateMagnitude = (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot()
        guard rotationRateMagnitude <= tuning.maxRotationRate else {
            return
        }

        // 9. Camera sensor readiness check
        guard session.canRequestImageCapture else {
            return
        }

        // 10. Fire supplemental shot request
        session.requestImageCapture()
        supplementalShotsCount += 1
        lastRequestTime = now
        lastShotHeading = pose.heading
        let reason = isAngleStepReached ? "Angle (\(String(format: "%.1f", moved * 180 / .pi))°)" : "Cadence (\(String(format: "%.1f", timeSinceLast))s)"
        print("🎯 [MotionCoach] Shot #\(shots + 1) [\(reason)] FIRED! Heading=\(Int(pose.heading * 180 / .pi))°, Tilt=\(Int(pose.tiltDownDegrees))°, Sector=\(sectorIndex)")
        logger.log("MotionCoach: supplemental shot #\(self.supplementalShotsCount) requested [\(reason)]")
    }

    private func updateTiltGuidance(forSector sectorIndex: Int) {
        let sectorNeedsAngled = angledShotsPerSector[sectorIndex] < tuning.minAngledShotsPerSector
        if sectorNeedsAngled && !isCurrentlyAngled {
            setHint(tuning.topHintText)
        } else {
            setHint(nil)
        }
    }

    private func setHint(_ text: String?) {
        guard text != activeCoachHint else { return }
        activeCoachHint = text
        onHint?(text)
    }

    private func logScanSummary() {
        guard let startTime = passStartTime, let session else { return }
        let duration = Date().timeIntervalSince(startTime)
        let totalPhotos = session.numberOfShotsTaken
        guard totalPhotos > 0 || supplementalShotsCount > 0 else { return }

        let thermalStr: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalStr = "nominal"
        case .fair: thermalStr = "fair"
        case .serious: thermalStr = "serious"
        case .critical: thermalStr = "critical"
        @unknown default: thermalStr = "unknown"
        }

        logger.info("""
        [MotionCoach Per-Scan Summary]
          Duration: \(String(format: "%.1f", duration))s
          Total Photos: \(totalPhotos) (Supplemental Requested: \(self.supplementalShotsCount))
          Photos Per Sector (45° [0..7]): \(self.totalShotsPerSector)
          Angled Shots Per Sector (45° [0..7]): \(self.angledShotsPerSector)
          Thermal State: \(thermalStr)
        """)
    }

    private func pose(from m: CMRotationMatrix) -> (heading: Double, tiltDownDegrees: Double) {
        let fx: Double
        let fy: Double
        let fz: Double
        let upX: Double
        let upY: Double

        if tuning.matrixMapsDeviceToReference {
            // Column vectors: M * [0, 0, -1]^T and M * [0, 1, 0]^T
            fx = -m.m13
            fy = -m.m23
            fz = -m.m33
            upX = m.m12
            upY = m.m22
        } else {
            // Row vectors: M^T * [0, 0, -1]^T and M^T * [0, 1, 0]^T
            fx = -m.m31
            fy = -m.m32
            fz = -m.m33
            upX = m.m21
            upY = m.m22
        }

        let horizontal = (fx * fx + fy * fy).squareRoot()
        let heading = horizontal > tuning.downwardFacingThreshold ? atan2(fy, fx) : atan2(upY, upX)
        let tiltDown = -asin(max(-1.0, min(1.0, fz))) * 180.0 / .pi
        return (heading, tiltDown)
    }

    private static func wrap(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2.0 * .pi)
        if a > .pi { a -= 2.0 * .pi } else if a < -.pi { a += 2.0 * .pi }
        return a
    }
}
