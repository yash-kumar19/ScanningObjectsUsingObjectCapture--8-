import SwiftUI
import AVFoundation

/// QR Code Scanner View for scanning restaurant menu QR codes
struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var scannerDelegate = QRScannerDelegate()
    
    var onScanSuccess: (String) -> Void
    var onDismiss: () -> Void
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Camera preview
            QRCodeScannerRepresentable(delegate: scannerDelegate)
                .ignoresSafeArea()
            
            // Overlay with scanning frame
            VStack {
                // Header
                HStack {
                    Button(action: {
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Scanning frame
                VStack(spacing: 24) {
                    ZStack {
                        // Frame corners
                        // RoundedRectangle(cornerRadius: 20)
                        //    .stroke(Color.white, lineWidth: 3)
                        //    .frame(width: 280, height: 280)
                        
                        // Corner accents
                        VStack {
                            HStack {
                                ScannerCorner()
                                Spacer()
                                ScannerCorner()
                                    .rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1))
                            }
                            Spacer()
                            HStack {
                                ScannerCorner()
                                    .rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1))
                                Spacer()
                                ScannerCorner()
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1))
                            }
                        }
                        .frame(width: 280, height: 280)
                    }
                    
                    // Instruction text
                    VStack(spacing: 8) {
                        Text("Scan Restaurant QR Code")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Position the QR code within the frame")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.8))
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Torch toggle
                Button(action: toggleTorch) {
                    Image(systemName: scannerDelegate.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            scannerDelegate.onScanSuccess = { url in
                onScanSuccess(url)
            }
            scannerDelegate.onError = { error in
                errorMessage = error
                showError = true
            }
        }
        .alert("Scanner Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleTorch() {
        scannerDelegate.toggleTorch()
    }
}

// MARK: - Scanner Corner View

struct ScannerCorner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color(hex: "2b7fff"))
                .frame(width: 40, height: 4)
            Rectangle()
                .fill(Color(hex: "2b7fff"))
                .frame(width: 4, height: 40)
        }
    }
}

// MARK: - QR Code Scanner Representable

struct QRCodeScannerRepresentable: UIViewRepresentable {
    let delegate: QRScannerDelegate
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // Setup capture session
        DispatchQueue.main.async {
            delegate.setupCaptureSession(in: view)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        DispatchQueue.main.async {
            delegate.updatePreviewLayerFrame(to: uiView.bounds)
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Cleanup is handled in delegate
    }
}

// MARK: - QR Scanner Delegate

class QRScannerDelegate: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false
    
    @Published var isTorchOn = false
    
    var onScanSuccess: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    func setupCaptureSession(in view: UIView) {
        print("📷 [QRScanner] Setting up capture session...")
        print("📷 [QRScanner] View bounds: \(view.bounds)")
        
        // Check camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 [QRScanner] Camera permission status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("📷 [QRScanner] Camera authorized, starting session...")
            startSession(in: view)
        case .notDetermined:
            print("📷 [QRScanner] Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("📷 [QRScanner] Permission granted: \(granted)")
                if granted {
                    DispatchQueue.main.async {
                        self?.startSession(in: view)
                    }
                } else {
                    self?.onError?("Camera access denied")
                }
            }
        default:
            print("📷 [QRScanner] Camera access previously denied")
            onError?("Camera access denied. Please enable camera access in Settings.")
        }
    }
    
    private func startSession(in view: UIView) {
        print("📷 [QRScanner] Starting camera session...")
        print("📷 [QRScanner] View bounds at start: \(view.bounds)")
        
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("❌ [QRScanner] Camera device not available")
            onError?("Camera not available")
            return
        }
        
        print("📷 [QRScanner] Camera device obtained: \(device.localizedName)")
        
        if session.canAddInput(input) {
            session.addInput(input)
            print("📷 [QRScanner] Camera input added")
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
                print("📷 [QRScanner] Metadata output added")
            } else {
                print("❌ [QRScanner] QR scanning not supported on this device")
                onError?("QR scanning is not supported on this device.")
                return
            }
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        print("📷 [QRScanner] Preview layer added with frame: \(previewLayer.frame)")
        
        self.captureSession = session
        self.previewLayer = previewLayer
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            print("📷 [QRScanner] Session started running")
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        hasScanned = true
        
        // Haptic feedback
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // Stop session on a background thread to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
        
        // Notify success
        onScanSuccess?(stringValue)
    }
    
    func updatePreviewLayerFrame(to bounds: CGRect) {
        guard let previewLayer = previewLayer else { return }
        
        // Update frame on main thread
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
        }
    }
    
    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            if isTorchOn {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
            }
            device.unlockForConfiguration()
        } catch {
            print("❌ Failed to toggle torch: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    QRScannerView(
        onScanSuccess: { url in
            print("Scanned: \(url)")
        },
        onDismiss: {}
    )
}
