# 3D Restaurant Menu App

A cutting-edge iOS restaurant app that leverages **Object Capture** to create stunning 3D models of dishes, providing customers with an immersive dining preview experience.

## ✨ Features

### For Customers
- 🏠 Browse restaurants with beautiful UI
- 🍽️ View dish menus with live updates
- 📱 Interactive 3D dish previews using AR Quick Look
- 🔍 Search and filter dishes by category
- 👤 User profiles and reservations

### For Restaurant Owners
- 📸 **3D Dish Capture** - Use iPhone's Object Capture to create photorealistic 3D models
- ➕ Add, edit, and manage dishes
- 🎨 Upload dish images and details
- 📊 Owner dashboard
- 🏪 Restaurant onboarding and management

## 🛠️ Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **Object Capture** - Apple's photogrammetry API for 3D scanning
- **AR Quick Look** - Native 3D model preview
- **Supabase** - Backend (Auth, Database, Storage)
- **URLSession** - Network layer

## 📋 Prerequisites

- **Xcode 15+**
- **iOS 17+** target device
- **Device with LiDAR** (iPhone 12 Pro or newer, iPad Pro 2020+) for Object Capture
- **Supabase Account** - [Sign up here](https://supabase.com)

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yash-kumar19/ScanningObjectsUsingObjectCapture--8-.git
cd "ScanningObjectsUsingObjectCapture (8)/GuidedCaptureSample"
```

### 2. Configure Supabase

#### Create Supabase Project
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Create a new project
3. Navigate to **Settings > API**
4. Copy your **Project URL** and **anon/public key**

#### Setup Configuration File
```bash
# Copy the template
cp UI/Components/SupabaseConfig.swift.template UI/Components/SupabaseConfig.swift

# Edit the file and replace placeholders with your actual values
```

**SupabaseConfig.swift:**
```swift
import Foundation

struct SupabaseConfig {
    static let url = "https://YOUR_PROJECT.supabase.co"
    static let anonKey = "your-anon-key-here"
    
    // ... rest of the file
}
```

> ⚠️ **Important:** Never commit `SupabaseConfig.swift` with real credentials to version control!

### 3. Setup Database Schema

Run this SQL in your Supabase SQL Editor:

```sql
-- Create restaurants table
CREATE TABLE restaurants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create dishes table
CREATE TABLE dishes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10,2),
    category TEXT,
    image_url TEXT,
    model_3d_url TEXT,
    is_active BOOLEAN DEFAULT true,
    generation_status TEXT DEFAULT 'idle',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES 
    ('dish-images', 'dish-images', true),
    ('models', 'models', true);

-- Enable Row Level Security
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE dishes ENABLE ROW LEVEL SECURITY;

-- RLS Policies (adjust based on your auth setup)
CREATE POLICY "Public read access" ON dishes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert" ON dishes FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can update" ON dishes FOR UPDATE USING (auth.role() = 'authenticated');
```

### 4. Build & Run

1. Open `GuidedCaptureSample.xcodeproj` in Xcode
2. Select your development team in **Signing & Capabilities**
3. Choose a device with LiDAR scanner
4. **Build and Run** (⌘R)

## 📱 Usage

### Capturing 3D Dish Models

1. **Login as Restaurant Owner** (or create account)
2. Navigate to **Owner Dashboard**
3. Tap **Add Dish** → **Start 3D Capture**
4. Follow the on-screen instructions to scan the dish
5. Wait for processing (creates USDZ model)
6. Fill in dish details (name, price, category)
7. Save - the model automatically uploads to Supabase

### Viewing 3D Models (Customer Side)

1. Browse restaurants
2. Tap on any dish card
3. The 3D model loads inline with Quick Look
4. Pinch, zoom, and rotate to explore

## 🗂️ Project Structure

```
GuidedCaptureSample/
├── GuidedCaptureSample/           # Core Object Capture views
│   ├── AppDataModel.swift         # Capture session management
│   ├── Views/                     # Apple's Object Capture UI
│   └── GuidedCaptureSampleApp.swift
├── UI/
│   ├── Components/                # Reusable components
│   │   ├── SupabaseManager.swift  # Backend API client
│   │   ├── ModelDownloader.swift  # 3D model caching
│   │   ├── DishCard.swift
│   │   └── BottomTabBar.swift
│   ├── Screens/                   # Customer screens
│   │   ├── HomeView.swift
│   │   ├── RestaurantDetailsScreen.swift
│   │   └── SearchScreen.swift
│   └── Screens/Owner/             # Owner screens
│       ├── OwnerDashboardScreen.swift
│       ├── AddEditDishScreen.swift
│       └── OwnerGeneratorScreen.swift
```

## 🎯 Roadmap

- [ ] Shopping cart & checkout
- [ ] Push notifications for order updates
- [ ] Advanced AR features (table placement)
- [ ] Admin analytics dashboard
- [ ] Multi-restaurant support
- [ ] Reviews & ratings

See [task list](/.gemini/antigravity/brain/090af25f-6ff6-40d0-9a1c-b47b2e7490a4/task.md) for detailed roadmap.

## 🔒 Security Notes

- `SupabaseConfig.swift` is gitignored to protect API keys
- Use Row Level Security (RLS) policies in production
- Implement proper authentication before deploying
- Review and restrict storage bucket policies

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is for educational purposes. Based on Apple's Object Capture sample code.

## 🙏 Acknowledgments

- Apple's Object Capture API and sample code
- Supabase for the backend infrastructure
- SwiftUI community

---

**Built with ❤️ using SwiftUI and Object Capture**
