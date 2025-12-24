import SwiftUI

// MARK: - Data Models
struct MenuDish: Identifiable {
    let id: String
    let name: String
    let description: String
    let price: String
    let category: String
    let status: String // "published", "draft", "processing"
    let imageURL: String
}

// MARK: - Helper Components
struct MenuDishCard: View {
    let dish: MenuDish
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                // Main Content
                HStack(alignment: .top, spacing: 16) {
                    // Image
                    AsyncImage(url: URL(string: dish.imageURL)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.3)))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                    .clipped()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dish.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.trailing, 60) // Increased space for delete button
                        
                        Text(dish.description)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 10) {
                            Text(dish.category)
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            
                            Text(dish.price)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "2b7fff"))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "f87171")) // red-400
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "ef4444").opacity(0.1)) // red-500/10
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "ef4444").opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.top, 6) // Moved up more
                .padding(.trailing, 16)
            }
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: { /* Preview 3D */ }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 14))
                        Text("Preview 3D")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                
                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil") // Edit2 -> pencil
                            .font(.system(size: 14))
                        Text("Edit")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "2b7fff"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color(hex: "2b7fff").opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "2b7fff").opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(16)
            .padding(.top, -4) // Adjust spacing to match React's pt-3 (12px) vs VStack spacing
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color(hex: "2b7fff").opacity(0.15), radius: 32, x: 0, y: 8)
    }
}

// MARK: - Screen
struct OwnerMenuScreen: View {
    @State private var searchQuery = ""
    
    // Mock Data
    let dishes: [MenuDish] = [
        MenuDish(
            id: "1",
            name: "Classic Burger",
            description: "Juicy beef patty with fresh vegetables",
            price: "$12.99",
            category: "Main Course",
            status: "published",
            imageURL: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxidXJnZXJ8ZW58MXx8fHwxNzYzNzE3MDYwfDA&ixlib=rb-4.1.0&q=80&w=1080"
        ),
        MenuDish(
            id: "2",
            name: "Margherita Pizza",
            description: "Fresh mozzarella, tomatoes, and basil",
            price: "$14.99",
            category: "Main Course",
            status: "published",
            imageURL: "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxwaXp6YXxlbnwxfHx8fDE3NjM3MTcwNjB8MA&ixlib=rb-4.1.0&q=80&w=1080"
        ),
        MenuDish(
            id: "3",
            name: "Caesar Salad",
            description: "Crisp romaine, parmesan, and croutons",
            price: "$8.99",
            category: "Appetizer",
            status: "draft",
            imageURL: "https://images.unsplash.com/photo-1546793665-c74683f339c1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjYWVzYXIlMjBzYWxhZHxlbnwxfHx8fDE3NjM3MTcwNjB8MA&ixlib=rb-4.1.0&q=80&w=1080"
        ),
        MenuDish(
            id: "4",
            name: "Chocolate Cake",
            description: "Rich chocolate with ganache frosting",
            price: "$6.99",
            category: "Dessert",
            status: "processing",
            imageURL: "https://images.unsplash.com/photo-1578985545062-69928b1d9587?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjaG9jb2xhdGUlMjBjYWtlfGVufDF8fHx8MTc2MzcxNzA2MHww&ixlib=rb-4.1.0&q=80&w=1080"
        )
    ]
    
    var body: some View {
        ZStack {
            // 1. Background Gradient
            LinearGradient(
                colors: [
                    Color(hex: "050505"),
                    Color(hex: "0B0F1A"),
                    Color(hex: "111827")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 2. Background Glow Blob
            VStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "2b7fff").opacity(0.4), Color(hex: "2b7fff").opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 100)
                    .offset(y: -250)
                Spacer()
            }
            .ignoresSafeArea()
            
            // 3. Content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3D Menu")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("Manage your dishes and 3D models")
                            .font(.body)
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    
                    // Search and Filter
                    HStack(spacing: 12) {
                        // Search Bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(Color.white.opacity(0.4))
                            
                            TextField("", text: $searchQuery)
                                .placeholder(when: searchQuery.isEmpty) {
                                    Text("Search dishes...").foregroundColor(Color.white.opacity(0.4))
                                }
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                        
                        // Filter Button
                        Button(action: { /* Filter */ }) {
                            Image(systemName: "line.3.horizontal.decrease.circle") // Filter icon
                                .font(.system(size: 20))
                                .foregroundColor(Color.white.opacity(0.6))
                                .frame(width: 56, height: 56) // Match search bar height roughly
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Dishes List
                    VStack(spacing: 16) {
                        ForEach(dishes) { dish in
                            MenuDishCard(
                                dish: dish,
                                onEdit: { /* Edit dish */ },
                                onDelete: { /* Delete dish */ }
                            )
                        }
                    }
                    .padding(.bottom, 120) // Space for FAB and Tab Bar
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 500)
            }
            
            // 4. Floating Action Button (FAB)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { /* Add Dish */ }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "2b7fff").opacity(0.5), radius: 32, x: 0, y: 8)
                    }
                    .padding(.trailing, 24) // Increased padding to avoid cutoff
                    .padding(.bottom, 120) // Adjust based on tab bar height
                }
            }
        }
    }
}


