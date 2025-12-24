import SwiftUI
import SceneKit
import Combine

struct Preview3DView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    
    @State private var rotationAngle: Float = 0
    @State private var dragRotationY: Float = 0
    @State private var dragRotationX: Float = 0
    @State private var isDragging = false
    @State private var timer: AnyCancellable?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // SceneKit view
            URLRotatingSceneView(
                url: url,
                rotationY: rotationAngle + dragRotationY,
                rotationX: dragRotationX
            )
            .ignoresSafeArea()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            stopRotation()
                        }
                        dragRotationY = Float(value.translation.width) / 100.0
                        dragRotationX = -Float(value.translation.height) / 100.0
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            dragRotationY = 0
                            dragRotationX = 0
                        }
                        startRotation()
                    }
            )
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
            
            // Controls Overlay
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    Label("Drag to rotate", systemImage: "hand.draw.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startRotation()
        }
        .onDisappear {
            stopRotation()
        }
    }
    
    private func startRotation() {
        timer?.cancel()
        timer = Timer.publish(every: 0.016, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if !isDragging {
                    rotationAngle += 0.01 // Slow auto rotation
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

struct URLRotatingSceneView: UIViewRepresentable {
    let url: URL
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
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0.2, z: 2)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 800
        scene.rootNode.addChildNode(ambientLight)
        
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 1200
        directionalLight.position = SCNVector3(x: 3, y: 5, z: 3)
        scene.rootNode.addChildNode(directionalLight)
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        if let modelNode = context.coordinator.modelNode {
            modelNode.eulerAngles.y = rotationY
            modelNode.eulerAngles.x = rotationX
        }
    }
    
    private func setupModel(in scene: SCNScene, coordinator: Coordinator) {
        let containerNode = SCNNode()
        
        // Try to load from URL
        do {
            let modelScene = try SCNScene(url: url, options: nil)
            
            for child in modelScene.rootNode.childNodes {
                containerNode.addChildNode(child)
            }
            
            // Auto-scale and center
            let (min, max) = containerNode.boundingBox
            let size = SCNVector3(
                x: max.x - min.x,
                y: max.y - min.y,
                z: max.z - min.z
            )
            
            let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))
            if maxDimension > 0 {
                let scaleFactor = 1.5 / maxDimension
                containerNode.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
            }
            
            let (minScaled, maxScaled) = containerNode.boundingBox
            let center = SCNVector3(
                x: (minScaled.x + maxScaled.x) / 2,
                y: (minScaled.y + maxScaled.y) / 2,
                z: (minScaled.z + maxScaled.z) / 2
            )
            containerNode.position = SCNVector3(-center.x, -center.y, -center.z)
            
            scene.rootNode.addChildNode(containerNode)
            coordinator.modelNode = containerNode
            
        } catch {
            print("Failed to load model from URL: \(error)")
        }
    }
}
