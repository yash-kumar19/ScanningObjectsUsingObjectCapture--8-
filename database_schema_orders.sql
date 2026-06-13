-- Ordering System Database Schema
-- Run these SQL commands in your Supabase SQL Editor

-- ============================================================================
-- RESTAURANTS TABLE (Required for RLS)
-- ============================================================================

CREATE TABLE restaurants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  owner_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  is_active BOOLEAN DEFAULT true
);

-- Index for owner lookups
CREATE INDEX idx_restaurants_owner_id ON restaurants(owner_id);

-- RLS Policies for restaurants
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;

-- Owners can view their own restaurants
CREATE POLICY "Owners can view own restaurants" ON restaurants
FOR SELECT USING (auth.uid() = owner_id);

-- Owners can create restaurants
CREATE POLICY "Owners can create restaurants" ON restaurants
FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- Owners can update their own restaurants
CREATE POLICY "Owners can update own restaurants" ON restaurants
FOR UPDATE USING (auth.uid() = owner_id);

-- ============================================================================
-- ORDERS TABLE
-- ============================================================================

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  customer_id UUID NOT NULL REFERENCES auth.users(id),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  status TEXT NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'preparing', 'ready', 'completed', 'cancelled')),
  payment_method TEXT NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash')),
  subtotal DECIMAL(10,2) NOT NULL,
  tax DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  special_notes TEXT,
  customer_name TEXT
);

-- Indexes
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_restaurant_id ON orders(restaurant_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_updated_at ON orders(updated_at);  -- For polling efficiency
CREATE INDEX idx_orders_created ON orders(created_at DESC);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

-- RLS Policies for orders
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Customers can view their own orders
CREATE POLICY "Customers can view own orders" ON orders
FOR SELECT USING (auth.uid() = customer_id);

-- Customers can create orders
CREATE POLICY "Customers can create orders" ON orders
FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- ✅ FIXED: Owners can view orders for their restaurants
CREATE POLICY "Owners can view restaurant orders" ON orders
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM restaurants
    WHERE restaurants.id = orders.restaurant_id
    AND restaurants.owner_id = auth.uid()
  )
);

-- ✅ FIXED: Owners can update orders for their restaurants
CREATE POLICY "Owners can update restaurant orders" ON orders
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM restaurants
    WHERE restaurants.id = orders.restaurant_id
    AND restaurants.owner_id = auth.uid()
  )
);

-- ============================================================================
-- ORDER_ITEMS TABLE
-- ============================================================================

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  dish_id UUID NOT NULL,
  name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,  -- Locked price at time of order
  quantity INT NOT NULL CHECK (quantity > 0)
);

-- Index
CREATE INDEX idx_order_items_order ON order_items(order_id);

-- RLS Policies for order_items
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Users can view items from their orders
CREATE POLICY "Users can view order items" ON order_items
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM orders
    WHERE orders.id = order_items.order_id
    AND (orders.customer_id = auth.uid() OR orders.restaurant_id IN (
      SELECT id FROM restaurants WHERE owner_id = auth.uid()
    ))
  )
);

-- Users can create order items for their orders
CREATE POLICY "Users can create order items" ON order_items
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM orders
    WHERE orders.id = order_items.order_id
    AND orders.customer_id = auth.uid()
  )
);
