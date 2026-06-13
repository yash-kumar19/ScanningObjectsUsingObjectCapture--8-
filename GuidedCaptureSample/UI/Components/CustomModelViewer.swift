import SwiftUI
import RealityKit
import ARKit
import SceneKit
import Combine

// MARK: - Viewer Mode Enum
enum ViewerMode: String, CaseIterable, Identifiable {
    case ar = "AR"
    case object = "Object"
    
    var id: String { self.rawValue }
}

// MARK: - Placement State
enum PlacementState {
    case notPlaced
    case placed
    case loading
}

// MARK: - Main Viewer View
struct CustomModelViewer: View {
    let modelFile: URL
    let onDismiss: () -> Void
    
    @State private var selectedMode: ViewerMode = .ar // Default to AR mode
    @State private var placementState: PlacementState = .notPlaced
    @State private var showCoachingText = false
    @State private var trackingState: ARCamera.TrackingState = .notAvailable
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Content Layer
            Group {
                switch selectedMode {
                case .object:
                    SceneKitViewer(modelFile: modelFile)
                        .transition(.opacity)
                case .ar:
                    ARRealityViewer(
                        modelFile: modelFile,
                        placementState: $placementState,
                        trackingState: $trackingState
                    )
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            
            // 2. UI Overlay Layer
            VStack {
                // Header (Tabs + Close)
                HStack(alignment: .center) {
                    // Close button (Top Left)
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Mode Toggle (Top Center)
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(ViewerMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 160)
                    .background(Material.thinMaterial)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // Share Button (Top Right)
                    Button(action: { shareModel(url: modelFile) }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // AR Guidance Text
                if selectedMode == .ar {
                    VStack(spacing: 8) {
                        if case .limited(_) = trackingState {
                            Text("Move iPhone slowly to map area")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.black.opacity(0.6)))
                        } else if placementState == .notPlaced {
                            Text("Double tap to place object")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color(hex: "2b7fff").opacity(0.9)))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 50)
                    .animation(.spring(), value: placementState)
                    .animation(.default, value: trackingState)
                }
            } // Close VStack
        } // Close ZStack
        .onAppear {
            // Slight delay to allow scene to load before forcing AR if desired,
            // but for now defaulting to Object mode is safer/cleaner.
        }
    } // Close body
    
    // MARK: - Helper Methods
    private func shareModel(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            // Present from the top-most view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true, completion: nil)
        }
    }
}

// MARK: - SceneKit Viewer (Object Mode)
struct SceneKitViewer: UIViewRepresentable {
    let modelFile: URL
    
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        
        // Load Scene
        do {
            let scene = try SCNScene(url: modelFile, options: nil)
            view.scene = scene
            
            // Normalize Model Scale & Position
            let rootNode = scene.rootNode
            
            // Calculate bounding box of the entire scene content
            let (minVec, maxVec) = rootNode.boundingBox
            
            let bound = SCNVector3(
                x: maxVec.x - minVec.x,
                y: maxVec.y - minVec.y,
                z: maxVec.z - minVec.z
            )
            
            // Calculate scale to fit model nicely in view
            let maxDimension = max(bound.x, max(bound.y, bound.z))
            // Scale to 8.0 meters (large enough to fill screen)
            let targetScale = (maxDimension > 0.001) ? (8.0 / Float(maxDimension)) : 1.0
            rootNode.scale = SCNVector3(targetScale, targetScale, targetScale)
            
            // Center the model
            rootNode.pivot = SCNMatrix4MakeTranslation(
                (maxVec.x + minVec.x) / 2,
                (maxVec.y + minVec.y) / 2,
                (maxVec.z + minVec.z) / 2
            )
            
            // Set up camera at close but safe distance
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 60 // Good viewing angle
            cameraNode.camera?.zNear = 0.1 // Near clipping plane
            cameraNode.camera?.zFar = 100 // Far clipping plane
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 1.2) // Close camera for large model
            scene.rootNode.addChildNode(cameraNode)
            view.pointOfView = cameraNode
            
            // Add soft ambient light
            let ambientLightNode = SCNNode()
            ambientLightNode.light = SCNLight()
            ambientLightNode.light?.type = .ambient
            ambientLightNode.light?.color = UIColor(white: 0.3, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLightNode)
            
        } catch {
            print("Failed to load SCNScene: \(error)")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// MARK: - RealityKit Viewer (AR Mode)
struct ARRealityViewer: UIViewRepresentable {
    let modelFile: URL
    @Binding var placementState: PlacementState
    @Binding var trackingState: ARCamera.TrackingState
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configuration
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arView.session.run(config)
        
        // Coaching Overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.activatesAutomatically = true
        arView.addSubview(coachingOverlay)
        
        // Double Tap Gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        arView.addGestureRecognizer(doubleTap)
        
        // Scale/Rotate Gestures (only active when placed, logic inside coordinator)
        context.coordinator.arView = arView
        
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // updates if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARRealityViewer
        weak var arView: ARView?
        var modelEntity: ModelEntity?
        var currentAnchor: AnchorEntity?
        
        var loadCancellable: AnyCancellable?
        
        init(parent: ARRealityViewer) {
            self.parent = parent
        }
        
        deinit {
            loadCancellable?.cancel()
        }
        
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            DispatchQueue.main.async {
                self.parent.trackingState = camera.trackingState
            }
        }
        
        @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            // Prevent double taps during async load
            if parent.placementState == .loading { return }
            
            let location = sender.location(in: arView)
            
            // 1. Raycast Strategy
            // Order: Existing Plane (Geometry) -> Infinite Plane -> Fallback
            
            var hitPosition: SIMD3<Float>?
            
            // A. Existing Plane Geometry (Best)
            if let hit = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .any).first {
                hitPosition = hit.worldTransform.positionVector
            }
            // B. Infinite Plane (Forgiving)
            else if let hit = arView.raycast(from: location, allowing: .existingPlaneInfinite, alignment: .any).first {
                hitPosition = hit.worldTransform.positionVector
            }
            // C. Fallback (Camera Forward)
            else if let cameraTransform = arView.session.currentFrame?.camera.transform {
                // Place 0.5m in front of camera
                var translation = matrix_identity_float4x4
                translation.columns.3.z = -0.5
                let transform = matrix_multiply(cameraTransform, translation)
                hitPosition = transform.positionVector
            }
            
            guard let position = hitPosition else { return }
            
            placeModel(at: position, in: arView)
        }
        
        func placeModel(at position: SIMD3<Float>, in arView: ARView) {
            // Haptic Feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Remove old anchor if exists
            if let oldAnchor = currentAnchor {
                arView.scene.removeAnchor(oldAnchor)
            }
            
            // Create new Anchor at hit position
            let anchor = AnchorEntity(world: position)
            arView.scene.addAnchor(anchor)
            currentAnchor = anchor
            
            if let entity = modelEntity {
                // Already loaded, just reparent and animate
                anchor.addChild(entity)
                
                // CRITICAL: Scene modifications must be on Main Thread
                // Generate simplified collisions (recursive: false) for stability
                entity.generateCollisionShapes(recursive: false)
                
                animateEntity(entity)
                
                // Enable gestures (Must be on Main Thread)
                arView.installGestures([.all], for: entity)
                
                updatePlacementState()
            } else {
                // Cancel any existing load
                loadCancellable?.cancel()
                loadCancellable = nil
                
                // Set loading state
                DispatchQueue.main.async {
                    self.parent.placementState = .loading
                }
                
                // Robust Async Load using RealityKit Native Pipeline
                loadCancellable = Entity.loadAsync(contentsOf: parent.modelFile)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            print("Failed to load model async: \(error)")
                            self?.parent.placementState = .notPlaced
                        }
                    }, receiveValue: { [weak self] loadedEntity in
                        guard let self = self else { return }
                        guard let current = self.currentAnchor, current == anchor else { return }
                        guard let arView = self.arView else { return }
                        
                        // Create wrapper entity
                        let entity = ModelEntity()
                        entity.addChild(loadedEntity)
                        self.modelEntity = entity
                        
                        // CRITICAL: Generate collision shapes on Main Thread (safe)
                        // recursive: false prevents watchdog kills on complex meshes
                        // Instead, we use Bounding Box for performance and gesture stability.
                        let bounds = entity.visualBounds(relativeTo: nil)
                        let box = ShapeResource.generateBox(size: bounds.extents)
                        let shape = box.offsetBy(translation: bounds.center)
                        
                        // Set Collision
                        entity.components.set(CollisionComponent(shapes: [shape]))
                        
                        // Set Physics (Kinematic to prevent falling)
                        entity.components.set(PhysicsBodyComponent(
                            massProperties: .default,
                            material: .default,
                            mode: .kinematic
                        ))
                        
                        // Attach and Animate
                        anchor.addChild(entity)
                        self.animateEntity(entity)
                        
                        // Enable gestures
                        arView.installGestures([.all], for: entity)
                        
                        // Disable Coaching
                        if let coaching = arView.subviews.first(where: { $0 is ARCoachingOverlayView }) as? ARCoachingOverlayView {
                            coaching.activatesAutomatically = false
                            coaching.setActive(false, animated: true)
                        }
                        
                        self.updatePlacementState()
                    })
            }
        }
        
        func animateEntity(_ entity: ModelEntity) {
            entity.scale = SIMD3(repeating: 0.01)
            var trans = entity.transform
            trans.scale = SIMD3(repeating: 1.0)
            entity.move(to: trans, relativeTo: entity.parent, duration: 0.5, timingFunction: .easeInOut)
        }
        
        func updatePlacementState() {
            DispatchQueue.main.async {
                withAnimation {
                    self.parent.placementState = .placed
                }
            }
        }
    }
}

// Helper extension for Matrix translation
extension simd_float4x4 {
    var positionVector: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

