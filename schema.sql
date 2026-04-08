```sql
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table (maps to Supabase auth.users)
CREATE TABLE users (
  id UUID REFERENCES auth.users NOT NULL,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);

-- Enable RLS on users
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- User profiles are public
CREATE POLICY "Allow public read access to user profiles" ON users
  FOR SELECT USING (true);

-- Users can only update their own profile
CREATE POLICY "Allow users to update their own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Ebooks table
CREATE TABLE ebooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  cover_image_url TEXT,
  price DECIMAL(10, 2) NOT NULL,
  file_url TEXT NOT NULL,
  is_published BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on ebooks
ALTER TABLE ebooks ENABLE ROW LEVEL SECURITY;

-- Published ebooks are public
CREATE POLICY "Allow public read access to published ebooks" ON ebooks
  FOR SELECT USING (is_published = true);

-- Authors have full access to their ebooks
CREATE POLICY "Allow full access to own ebooks" ON ebooks
  FOR ALL USING (auth.uid() = user_id);

-- Indexes for ebooks
CREATE INDEX idx_ebooks_user_id ON ebooks(user_id);
CREATE INDEX idx_ebooks_published ON ebooks(is_published) WHERE is_published = true;

-- Purchases table
CREATE TABLE purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ebook_id UUID REFERENCES ebooks(id) NOT NULL,
  buyer_id UUID REFERENCES users(id) NOT NULL,
  amount_paid DECIMAL(10, 2) NOT NULL,
  transaction_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (ebook_id, buyer_id)
);

-- Enable RLS on purchases
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

-- Users can see their own purchases
CREATE POLICY "Allow users to see their own purchases" ON purchases
  FOR SELECT USING (auth.uid() = buyer_id);

-- Authors can see purchases of their ebooks
CREATE POLICY "Allow authors to see purchases of their ebooks" ON purchases
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM ebooks 
    WHERE ebooks.id = purchases.ebook_id 
    AND ebooks.user_id = auth.uid()
  ));

-- Indexes for purchases
CREATE INDEX idx_purchases_buyer_id ON purchases(buyer_id);
CREATE INDEX idx_purchases_ebook_id ON purchases(ebook_id);

-- Reviews table
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ebook_id UUID REFERENCES ebooks(id) NOT NULL,
  user_id UUID REFERENCES users(id) NOT NULL,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (ebook_id, user_id)
);

-- Enable RLS on reviews
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Public can see reviews
CREATE POLICY "Allow public read access to reviews" ON reviews
  FOR SELECT USING (true);

-- Users can only manage their own reviews
CREATE POLICY "Allow users to manage their own reviews" ON reviews
  FOR ALL USING (auth.uid() = user_id);

-- Indexes for reviews
CREATE INDEX idx_reviews_ebook_id ON reviews(ebook_id);
CREATE INDEX idx_reviews_user_id ON reviews(user_id);

-- Seed data (example admin user and sample ebook)
INSERT INTO users (id, username, full_name, avatar_url)
VALUES ('00000000-0000-0000-0000-000000000000', 'admin', 'Admin User', 'https://example.com/avatar.jpg');

INSERT INTO ebooks (id, user_id, title, description, price, file_url, is_published)
VALUES (
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'Getting Started with Writing',
  'A comprehensive guide for new writers',
  9.99,
  'https://example.com/ebooks/getting-started.pdf',
  true
);

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for automatic timestamps
CREATE TRIGGER update_users_timestamp
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_ebooks_timestamp
BEFORE UPDATE ON ebooks
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_reviews_timestamp
BEFORE UPDATE ON reviews
FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```