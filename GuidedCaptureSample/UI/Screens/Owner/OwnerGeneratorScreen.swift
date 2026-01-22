import SwiftUI
import RealityKit

// MARK: - Helper Components

struct GeneratorGlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var isDashed: Bool = false
    var isSelected: Bool = false
    var action: (() -> Void)? = nil
    let content: Content
    
    init(padding: CGFloat = 16, isDashed: Bool = false, isSelected: Bool = false, action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.isDashed = isDashed
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        if let action = action {
            Button(action: action) {
                cardContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            cardContent
        }
    }
    
    var cardContent: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? AnyShapeStyle(Color(hex: "2b7fff").opacity(0.15)) : AnyShapeStyle(Color(hex: "1e293b")),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: "2b7fff").opacity(0.4) :
                            (isDashed ? Color(hex: "2b7fff").opacity(0.3) : Color.white.opacity(0.08)),
                        style: StrokeStyle(lineWidth: isDashed ? 2 : 1, dash: isDashed ? [5, 5] : [])
                    )
            )
            .shadow(color: isSelected ? Color(hex: "2b7fff").opacity(0.2) : Color.clear, radius: 24, x: 0, y: 8)
    }
}

// MARK: - Main Screen

struct OwnerGeneratorScreen: View {
    @Environment(AppDataModel.self) var appModel
    

    @State private var outputFormat = "lszg" // default to glb/usdz area?
    @State private var showCaptureSetup = false
    @State private var isCapturePresented = false
    @State private var showModelPreview = false
    @State private var showAddDish = false
    @State private var capturedModelURL: URL?
    @State private var isRetaking = false // Logic state to track user intent
    

    
    let outputFormats = [
        (value: "glb", label: ".GLB", description: "Universal format"),
        (value: "gltf", label: ".GLTF", description: "Web optimized"),
        (value: "usdz", label: ".USDZ", description: "Apple AR")
    ]
    
    var body: some View {
        ZStack {
            // 1. Unified Liquid Glass Background
            Theme.background.ignoresSafeArea()
            
            // 3. Content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3D Generator")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("Create 3D models from photos or videos")
                            .font(.body)
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    
                    // Upload Photos Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upload Photos")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        GeneratorGlassCard(padding: 32, isDashed: true) {
                            VStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 64, height: 64)
                                        .shadow(color: Color(hex: "2b7fff").opacity(0.3), radius: 24, x: 0, y: 8)
                                    
                                    Image(systemName: "arrow.up.doc.fill") // Upload icon
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("Upload multiple photos")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Take 20-40 photos around the dish for best results")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                }
                                
                                Button(action: { showCaptureSetup = true }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                        Text("Capture with Guided Mode")
                                    }
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color(hex: "2b7fff").opacity(0.4), radius: 24, x: 0, y: 8)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    
                    // OR Divider
                    HStack(spacing: 16) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                        Text("OR")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.4))
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                    }
                    
                    // Upload Video Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upload Video")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        GeneratorGlassCard(padding: 32, isDashed: true) {
                            VStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "8b5cf6"), Color(hex: "a78bfa")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 64, height: 64)
                                        .shadow(color: Color(hex: "8b5cf6").opacity(0.3), radius: 24, x: 0, y: 8)
                                    
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("Upload a 360° video")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Record a smooth 360° rotation (15-30 seconds)")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    

                    
                    // Output Format
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Output Format")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(outputFormats, id: \.value) { format in
                                GeneratorGlassCard(
                                    padding: 16,
                                    isSelected: outputFormat == format.value,
                                    action: { outputFormat = format.value }
                                ) {
                                    VStack(spacing: 4) {
                                        Text(format.label)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                        Text(format.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.6))
                                            .fixedSize(horizontal: false, vertical: true)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    
                    // Generate Button
                    Button(action: { /* Generate */ }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                            Text("Generate 3D Model")
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "8b5cf6"), Color(hex: "a78bfa")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color(hex: "8b5cf6").opacity(0.4), radius: 32, x: 0, y: 8)
                    }
                    
                    // Pro Tips
                    GeneratorGlassCard(padding: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("💡")
                            .font(.system(size: 20))
                            Text("Pro Tips: Use good lighting, rotate smoothly, and keep the dish centered for best results. Processing typically takes 5-10 minutes.")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer().frame(height: 120) // Bottom padding
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 500)
            }
        }
        .sheet(isPresented: $showCaptureSetup, onDismiss: {
            guard let url = capturedModelURL,
                  FileManager.default.fileExists(atPath: url.path)
            else {
                return
            }
            showModelPreview = true
        }) {
            CaptureSetupScreen(modelURL: $capturedModelURL)
                .environment(appModel)
        }
        .onChange(of: appModel.state) { _, newState in
             if newState == .completed {
                 // Close capture flow when pipeline is complete
                 isCapturePresented = false
                 // ✅ APPLE-PREFERRED: Consume the URL already set by ReconstructionPrimaryView
                 // No need to reconstruct paths - localModelURL was set via setLocalModelURL()
                 if let url = appModel.localModelURL {
                      self.capturedModelURL = url
                      print("✅ Captured model URL from AppDataModel: \(url.path)")
                 }
             }
        }
        .fullScreenCover(isPresented: $isCapturePresented) {
            CaptureFlowContainer()
        }
        .onChange(of: isCapturePresented) { wasShowing, isShowing in
            // When capture flow dismisses, if completed, show Preview
            if wasShowing && !isShowing && appModel.state == .completed {
                showModelPreview = true
            }
        }
        .fullScreenCover(isPresented: $showModelPreview) {
            if let url = capturedModelURL {
                 ZStack(alignment: .bottom) {
                     ModelView(modelFile: url, endCaptureCallback: {
                         // Callback if user swipes down or closes via built-in controls (if any)
                         // Default to "Add" path if they just close it? Or just dismiss?
                         showModelPreview = false
                     })
                     .ignoresSafeArea()
                     
                     // Overlay Controls
                     VStack {
                         Spacer()
                         HStack(spacing: 16) {
                             // Retake Button
                             Button(action: {
                                 isRetaking = true
                                 showModelPreview = false
                             }) {
                                 HStack {
                                     Image(systemName: "arrow.counterclockwise")
                                     Text("Retake")
                                 }
                                 .font(.system(size: 16, weight: .semibold))
                                 .foregroundColor(.white)
                                 .frame(maxWidth: .infinity)
                                 .padding(.vertical, 16)
                                 .background(Color(hex: "1E293B"))
                                 .cornerRadius(12)
                             }
                             
                             // Add to Menu Button
                             Button(action: {
                                 isRetaking = false // Proceed
                                 showModelPreview = false
                             }) {
                                 HStack {
                                     Image(systemName: "plus.circle.fill")
                                     Text("Add to Menu")
                                 }
                                 .font(.system(size: 16, weight: .semibold))
                                 .foregroundColor(.white)
                                 .frame(maxWidth: .infinity)
                                 .padding(.vertical, 16)
                                 .background(Color(hex: "3B82F6"))
                                 .cornerRadius(12)
                             }
                         }
                         .padding(20)
                         .background(
                             LinearGradient(colors: [Color.black.opacity(0.8), Color.clear], startPoint: .bottom, endPoint: .top)
                         )
                     }
                     .zIndex(100)
                 }
            }
        }
        .onChange(of: showModelPreview) { wasShowing, isShowing in
             // When preview dismisses, handle navigation based on intent
             if wasShowing && !isShowing {
                 if isRetaking {
                     // Go back to capture
                     // appModel.state is likely .completed. 
                     // Setting showCaptureSetup = true might not be enough if state is stuck.
                     // But CaptureSetupScreen handles state init.
                     showCaptureSetup = true 
                 } else {
                     // Proceed to Add Dish
                     showAddDish = true
                 }
             }
        }
        .fullScreenCover(isPresented: $showAddDish) {
            AddEditDishScreen(
                onBack: { 
                    showAddDish = false 
                },
                onSave: {
                    showAddDish = false
                },
                dishId: nil,
                prefilledModelURL: capturedModelURL
            )
        }
    }
}

// Wrapper to switch between Capture and Reconstruction views based on AppModel state
struct CaptureFlowContainer: View {
    @Environment(AppDataModel.self) var appModel
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Group {
            if appModel.state == .capturing || appModel.state == .ready {
                if let session = appModel.objectCaptureSession {
                    CapturePrimaryView(session: session)
                } else {
                    ProgressView("Initializing Capture Session...")
                        .preferredColorScheme(.dark)
                }
            } else if appModel.state == .reconstructing || appModel.state == .prepareToReconstruct || appModel.state == .viewing {
                if let folder = appModel.captureFolderManager {
                    // ✅ APPLE-PREFERRED: Use captureSessionID for predictable, unique filename
                    let outputFile = folder.modelsFolder.appendingPathComponent("\(appModel.captureSessionID.uuidString).usdz")
                    ReconstructionPrimaryView(outputFile: outputFile, onDismiss: {
                        dismiss()
                    })
                } else {
                     ProgressView("Preparing Reconstruction...")
                        .preferredColorScheme(.dark)
                }
            } else if appModel.state == .failed {
                 // Error state handling
                 Text("Capture Failed: \(appModel.error?.localizedDescription ?? "Unknown error")")
                    .foregroundColor(.red)
            } else {
                 // Fallback
                 ProgressView()
                    .preferredColorScheme(.dark)
            }
        }
        .colorScheme(.dark) // Ensure dark mode for sticky capture UI
    }
}
