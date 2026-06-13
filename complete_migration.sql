-- ============================================================================
-- COMPLETE MIGRATION SCRIPT FOR 3DMenu APP
-- Run this entire script in Supabase SQL Editor on your NEW project
-- ============================================================================

-- ============================================================================
-- 1. PROFILES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  role TEXT DEFAULT 'customer' CHECK (role IN ('customer', 'owner')),
  restaurant_name TEXT,
  logo_url TEXT,
  cuisine TEXT,
  address TEXT,
  phone TEXT,
  city TEXT,
  pincode TEXT,
  fssai_number TEXT,
  opening_hours TEXT,
  bio TEXT
);

-- RLS for profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can read own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ✅ PUBLIC: Anyone can read owner profiles (needed for restaurant discovery)
CREATE POLICY "Public can read owner profiles" ON profiles
  FOR SELECT
  TO anon, authenticated
  USING (role = 'owner');

-- Auto-create profile on signup trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 2. DISHES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS dishes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  restaurant_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  category TEXT NOT NULL,
  image_url TEXT,
  model_3d_url TEXT,
  is_active BOOLEAN DEFAULT true,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  generation_status TEXT DEFAULT 'pending_upload'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dishes_restaurant_id ON dishes(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_dishes_category ON dishes(category);
CREATE INDEX IF NOT EXISTS idx_dishes_active ON dishes(is_active);

-- RLS for dishes
ALTER TABLE dishes ENABLE ROW LEVEL SECURITY;

-- Owners can manage their own dishes
CREATE POLICY "Owners can manage own dishes" ON dishes
  FOR ALL USING (auth.uid() = restaurant_id);

-- Public can read published active dishes
CREATE POLICY "Public can read published dishes" ON dishes
  FOR SELECT
  TO anon, authenticated
  USING (is_active = true AND status = 'published');

-- ============================================================================
-- 3. ORDERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  customer_id UUID NOT NULL REFERENCES auth.users(id),
  restaurant_id UUID NOT NULL REFERENCES auth.users(id),
  restaurant_name TEXT,
  status TEXT NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'preparing', 'ready', 'completed', 'cancelled')),
  payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash')),
  subtotal DECIMAL(10,2) NOT NULL,
  tax DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  special_notes TEXT,
  customer_name TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_id ON orders(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_updated_at ON orders(updated_at);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS for orders
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Customers can view and create their own orders
CREATE POLICY "Customers can view own orders" ON orders
  FOR SELECT USING (auth.uid() = customer_id);

CREATE POLICY "Customers can create orders" ON orders
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Owners can view and update orders for their restaurant
CREATE POLICY "Owners can view restaurant orders" ON orders
  FOR SELECT USING (auth.uid() = restaurant_id);

CREATE POLICY "Owners can update restaurant orders" ON orders
  FOR UPDATE USING (auth.uid() = restaurant_id);

-- ============================================================================
-- 4. ORDER ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  dish_id UUID NOT NULL,
  name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- RLS for order_items
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Users can view items from their orders
CREATE POLICY "Users can view order items" ON order_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND (orders.customer_id = auth.uid() OR orders.restaurant_id = auth.uid())
    )
  );

-- Customers can create order items
CREATE POLICY "Customers can create order items" ON order_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND orders.customer_id = auth.uid()
    )
  );

-- ============================================================================
-- 5. STORAGE BUCKETS
-- Run these separately if the above SQL doesn't create them:
-- Go to Storage → New Bucket → name: "models", public: true
-- Go to Storage → New Bucket → name: "logos", public: true
-- ============================================================================

-- Done! ✅
