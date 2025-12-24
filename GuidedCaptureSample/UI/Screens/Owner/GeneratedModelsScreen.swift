import SwiftUI

struct GeneratedModel: Identifiable {
    let id: String
    let name: String
    let status: ModelStatus
    let timeAgo: String
    let image: String
    let progress: Double?
    let error: String?
}

enum ModelStatus: String {
    case ready
    case processing
    case error
}

struct GeneratedModelsScreen: View {
    // Callbacks
    var onPreview: (String) -> Void
    var onAddToMenu: (String) -> Void
    
    // Data
    let models: [GeneratedModel] = [
        GeneratedModel(
            id: "1",
            name: "Classic Burger",
            status: .ready,
            timeAgo: "2 hours ago",
            image: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd",
            progress: nil,
            error: nil
        ),
        GeneratedModel(
            id: "2",
            name: "Caesar Salad",
            status: .processing,
            timeAgo: "15 minutes ago",
            image: "https://images.unsplash.com/photo-1546793665-c74683f339c1",
            progress: 65,
            error: nil
        ),
        GeneratedModel(
            id: "3",
            name: "Chocolate Cake",
            status: .error,
            timeAgo: "1 day ago",
            image: "https://images.unsplash.com/photo-1578985545062-69928b1d9587",
            progress: nil,
            error: "Insufficient image quality"
        ),
        GeneratedModel(
            id: "4",
            name: "Margherita Pizza",
            status: .ready,
            timeAgo: "1 day ago",
            image: "https://images.unsplash.com/photo-1574071318508-1cdbab80d002",
            progress: nil,
            error: nil
        )
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GlowBackground()
            
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generated Models")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Your AI-generated 3D food models")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Models List
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(models) { model in
                            ModelCard(model: model, onPreview: onPreview, onAddToMenu: onAddToMenu)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
                }
            }
        }
    }
}

struct ModelCard: View {
    let model: GeneratedModel
    var onPreview: (String) -> Void
    var onAddToMenu: (String) -> Void
    
    var body: some View {
        GlassCard(padding: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Model Preview
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: model.image)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .cornerRadius(16)
                    .clipped()
                    
                    Text("3D")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .padding(8)
                }
                
                // Model Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(model.timeAgo)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary.opacity(0.7))
                        }
                        Spacer()
                    }
                    
                    // Status Badge
                    StatusBadge(status: model.status)
                    
                    // Processing Progress
                    if model.status == .processing, let progress = model.progress {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Processing...")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(Int(progress))%")
                                    .font(.caption2)
                                    .foregroundColor(Theme.primaryBlue)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(Theme.gradientBlue)
                                        .frame(width: geometry.size.width * CGFloat(progress) / 100.0, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                    
                    // Error Message
                    if model.status == .error, let error = model.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.destructive)
                    }
                    
                    // Action Buttons
                    if model.status == .ready {
                        HStack(spacing: 8) {
                            Button(action: { onPreview(model.id) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye")
                                    Text("Preview 3D")
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            
                            Button(action: { onAddToMenu(model.id) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Add to Menu")
                                }
                                .font(.caption)
                                .foregroundColor(Theme.primaryBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Theme.primaryBlue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.primaryBlue.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    } else if model.status == .error {
                        Button(action: { /* Retry logic */ }) {
                            Text("Try Again")
                                .font(.caption)
                                .foregroundColor(Theme.primaryBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Theme.primaryBlue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.primaryBlue.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.trailing, 16)
            }
        }
    }
}

struct StatusBadge: View {
    let status: ModelStatus
    
    var config: (icon: String, label: String, color: Color, bg: Color) {
        switch status {
        case .ready:
            return ("checkmark.circle", "Ready", Color.green, Color.green.opacity(0.1))
        case .processing:
            return ("clock", "Processing", Theme.primaryBlue, Theme.primaryBlue.opacity(0.1))
        case .error:
            return ("xmark.circle", "Error", Theme.destructive, Theme.destructive.opacity(0.1))
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: config.icon)
            Text(config.label)
        }
        .font(.caption)
        .foregroundColor(config.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(config.bg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(config.color.opacity(0.3), lineWidth: 1)
        )
    }
}
