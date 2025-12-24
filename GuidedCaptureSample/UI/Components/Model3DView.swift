import SwiftUI
import SceneKit
import Combine

struct Model3DView: View {
    var modelName: String = "buger"
    @State private var rotationAngle: Float = 0
    @State private var dragRotationY: Float = 0
    @State private var dragRotationX: Float = 0
    @State private var isDragging = false
    @State private var timer: AnyCancellable?
    
    var body: some View {
        ZStack {
            // SceneKit view
            RotatingSceneView(
                modelName: modelName,
                rotationY: rotationAngle + dragRotationY,
                rotationX: dragRotationX
            )
            .frame(width: 340, height: 300)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            stopRotation()
                        }
                        // Rotate both horizontally (Y-axis) and vertically (X-axis)
                        dragRotationY = Float(value.translation.width) / 100.0
                        dragRotationX = -Float(value.translation.height) / 100.0
                    }
                    .onEnded { _ in
                        isDragging = false
                        
                        // Spring back to auto-rotation AND resume immediately
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            dragRotationY = 0
                            dragRotationX = 0
                        }
                        
                        // Resume auto-rotation IMMEDIATELY (no delay)
                        startRotation()
                    }
            )
            .onAppear {
                startRotation()
            }
            .onDisappear {
                stopRotation()
            }
            
            // AR and Camera buttons
            HStack(spacing: 20) {
                Button(action: {}) {
                    Image(systemName: "arkit")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.fromHex("3B82F6").opacity(0.3))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.fromHex("3B82F6"), lineWidth: 1))
                }
                
                Button(action: {}) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.fromHex("3B82F6").opacity(0.3))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.fromHex("3B82F6"), lineWidth: 1))
                }
            }
            .offset(y: 110)
        }
    }
    
    private func startRotation() {
        timer?.cancel() // Cancel any existing timer
        timer = Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if !isDragging {
                    rotationAngle += 0.02 // Smooth continuous rotation
                    if rotationAngle > Float.pi * 2 {
                        rotationAngle -= Float.pi * 2
                    }
                }
            }
    }
    
    private func stopRotation() {
        timer?.cancel()
        timer = nil
    }
}

struct RotatingSceneView: UIViewRepresentable {
    let modelName: String
    let rotationY: Float
    let rotationX: Float
    
    class Coordinator {
        var modelNode: SCNNode?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = false
        
        let scene = SCNScene()
        scnView.scene = scene
        
        // Load model
        setupModel(in: scene, coordinator: context.coordinator)
        
        // Camera - better positioning for center
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0.2, z: 5) // Slight Y offset for better view
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 900
        scene.rootNode.addChildNode(ambientLight)
        
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 1400
        directionalLight.position = SCNVector3(x: 3, y: 5, z: 3)
        scene.rootNode.addChildNode(directionalLight)
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        // Update rotation - both Y and X axes
        if let modelNode = context.coordinator.modelNode {
            modelNode.eulerAngles.y = rotationY
            modelNode.eulerAngles.x = rotationX
        }
    }
    
    private func setupModel(in scene: SCNScene, coordinator: Coordinator) {
        let containerNode = SCNNode()
        
        if let bundlePath = Bundle.main.path(forResource: modelName, ofType: "usdz"),
           let modelScene = try? SCNScene(url: URL(fileURLWithPath: bundlePath), options: nil) {
            
            // Add all model nodes
            for child in modelScene.rootNode.childNodes {
                containerNode.addChildNode(child)
            }
            
            // BIGGER SIZE - Scale to fit
            let (min, max) = containerNode.boundingBox
            let size = SCNVector3(
                x: max.x - min.x,
                y: max.y - min.y,
                z: max.z - min.z
            )
            
            let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))
            if maxDimension > 0 {
                // Reduced to 3.0 to fit properly without clipping
                let scaleFactor = 3.0 / maxDimension
                containerNode.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
            }
            
            // PERFECTLY CENTER with slight downward shift
            let (minScaled, maxScaled) = containerNode.boundingBox
            let center = SCNVector3(
                x: (minScaled.x + maxScaled.x) / 2,
                y: (minScaled.y + maxScaled.y) / 2,
                z: (minScaled.z + maxScaled.z) / 2
            )
            // Move down by subtracting from Y position
            containerNode.position = SCNVector3(-center.x, -center.y - 0.3, -center.z)
            
            scene.rootNode.addChildNode(containerNode)
            coordinator.modelNode = containerNode
            
            print("✅ Model loaded: size \(maxDimension), scale \(4.0/maxDimension)")
        } else {
            print("❌ Failed to load model: \(modelName)")
        }
    }
}

#Preview {
    Model3DView()
        .background(Color.appBackground)
}
