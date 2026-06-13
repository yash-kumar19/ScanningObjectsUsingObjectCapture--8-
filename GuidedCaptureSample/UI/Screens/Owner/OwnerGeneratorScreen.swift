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

struct StepRow: View {
    let stepNumber: Int
    let title: String
    let description: String
    let iconName: String
    let gradientColors: [Color]
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .shadow(color: gradientColors[0].opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Step \(stepNumber)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(gradientColors[0])
                    .textCase(.uppercase)
                    .tracking(1)
                
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "1e293b").opacity(0.4))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct BestResultItem: View {
    let icon: String
    let label: String
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Main Screen

struct OwnerGeneratorScreen: View {
    @Environment(AppDataModel.self) var appModel
    
    @State private var showCaptureSetup = false
    @State private var isCapturePresented = false
    @State private var showModelPreview = false
    @State private var showAddDish = false
    @State private var capturedModelURL: URL?
    @State private var isRetaking = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create a 3D Dish")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("3D Capture Assistant")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.primaryBlue)
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    
                    // Capture Steps Guidance
                    VStack(spacing: 16) {
                        StepRow(
                            stepNumber: 1,
                            title: "Prepare Your Dish",
                            description: "Choose a fresh, well-presented plate. Arrange the food nicely to look fresh and appetizing.",
                            iconName: "fork.knife",
                            gradientColors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")]
                        )
                        
                        StepRow(
                            stepNumber: 2,
                            title: "Place Your Dish",
                            description: "Set the plate on a clean, stable surface in a bright room with even lighting.",
                            iconName: "square.dashed",
                            gradientColors: [Color(hex: "3b82f6"), Color(hex: "2b7fff")]
                        )
                        
                        StepRow(
                            stepNumber: 3,
                            title: "Capture All Angles",
                            description: "Hold your phone steady and walk slowly 360° around the dish to capture every detail.",
                            iconName: "camera.viewfinder",
                            gradientColors: [Color(hex: "8b5cf6"), Color(hex: "a78bfa")]
                        )
                        
                        StepRow(
                            stepNumber: 4,
                            title: "We'll Create The 3D Model",
                            description: "We process the images to build a realistic 3D model, ready for AR viewing and your digital menu.",
                            iconName: "sparkles",
                            gradientColors: [Color(hex: "f59e0b"), Color(hex: "fbbf24")]
                        )
                    }
                    

                    // Estimated Time Card & Instructions
                    HStack(spacing: 16) {
                        Image(systemName: "hourglass.badge.plus")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.primaryBlue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated Time: 2–3 Minutes")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("You'll walk around the dish while we capture it.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Theme.primaryBlue.opacity(0.08))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.primaryBlue.opacity(0.25), lineWidth: 1)
                    )
                    
                    // Start Button
                    Button(action: { showCaptureSetup = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Start 3D Capture")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Theme.gradientPurple)
                        .cornerRadius(18)
                        .shadow(color: Theme.primaryPurple.opacity(0.35), radius: 20, x: 0, y: 8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.top, 8)
                    
                    Spacer().frame(height: 120)
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
                 isCapturePresented = false
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
            if wasShowing && !isShowing && appModel.state == .completed {
                showModelPreview = true
            }
        }
        .fullScreenCover(isPresented: $showModelPreview) {
            if let url = capturedModelURL {
                 ZStack(alignment: .bottom) {
                     ModelView(modelFile: url, endCaptureCallback: {
                         showModelPreview = false
                     })
                     .ignoresSafeArea()
                     
                     VStack {
                          Spacer()
                          HStack(spacing: 16) {
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
                              
                              Button(action: {
                                  isRetaking = false
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
             if wasShowing && !isShowing {
                  if isRetaking {
                      showCaptureSetup = true 
                  } else {
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
                existingDish: nil,
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
                    let outputFile = folder.modelsFolder.appendingPathComponent("\(appModel.captureSessionID.uuidString).usdz")
                    ReconstructionPrimaryView(outputFile: outputFile, onDismiss: {
                        dismiss()
                    })
                } else {
                     ProgressView("Preparing Reconstruction...")
                        .preferredColorScheme(.dark)
                }
            } else if appModel.state == .failed {
                  Text("Capture Failed: \(appModel.error?.localizedDescription ?? "Unknown error")")
                    .foregroundColor(.red)
            } else {
                  ProgressView()
                    .preferredColorScheme(.dark)
            }
        }
        .colorScheme(.dark)
    }
}
