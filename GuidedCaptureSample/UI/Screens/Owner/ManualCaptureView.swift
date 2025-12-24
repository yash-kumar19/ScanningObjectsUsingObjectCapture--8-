import SwiftUI
import AVFoundation
import Combine

struct ManualCaptureView: View {
    @Binding var isPresented: Bool
    let sessionDir: URL
    var onCaptureFinished: () -> Void
    
    @StateObject private var cameraModel = CameraModel()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera Preview
            CameraPreview(session: cameraModel.session)
                .ignoresSafeArea()
            
            // UI Overlay
            VStack {
                // Top Bar
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("\(cameraModel.photoCount) / 20+")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                    
                    Spacer()
                    
                    // Finish Button (Hidden until min photos taken)
                    if cameraModel.photoCount >= 20 {
                        Button(action: {
                            onCaptureFinished()
                        }) {
                            Text("Finish")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(20)
                        }
                    } else {
                        // Placeholder to balance layout
                        Color.clear.frame(width: 80, height: 40)
                    }
                }
                .padding()
                
                Spacer()
                
                // Instructions
                if cameraModel.photoCount < 20 {
                    Text("Move around the object and take overlapping photos")
                        .font(.callout)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                }
                
                // Shutter Button
                Button(action: {
                    cameraModel.capturePhoto(saveTo: sessionDir)
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .scaleEffect(cameraModel.isCapturing ? 0.9 : 1.0)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            cameraModel.checkPermissions()
        }
    }
}

class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var photoCount = 0
    @Published var isCapturing = false
    @Published var alertError: AlertError?
    
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera_queue")
    private var currentSaveDir: URL?
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupCamera()
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        queue.async {
            self.session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
    
    func capturePhoto(saveTo dir: URL) {
        guard !isCapturing else { return }
        isCapturing = true
        currentSaveDir = dir
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
        
        // Reset button animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isCapturing = false
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let dir = currentSaveDir else { return }
        
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            DispatchQueue.main.async {
                self.photoCount += 1
            }
        } catch {
            print("Error saving photo: \(error)")
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

struct AlertError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
