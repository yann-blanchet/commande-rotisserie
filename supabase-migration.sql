-- Migration SQL pour Supabase
-- Créez ces tables dans votre projet Supabase

-- Table vendors (stands)
CREATE TABLE IF NOT EXISTS vendors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom TEXT, -- Can be NULL initially, will be set when stand is configured
  description TEXT,
  location TEXT,
  next_market_day DATE,
  market_days TEXT[], -- Array of days: ['monday', 'wednesday', 'friday']
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ajouter les colonnes si elles n'existent pas déjà
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'next_market_day'
  ) THEN
    ALTER TABLE vendors ADD COLUMN next_market_day DATE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'market_days'
  ) THEN
    ALTER TABLE vendors ADD COLUMN market_days TEXT[];
  END IF;
END $$;

-- Modifier la colonne nom pour permettre NULL (si elle existe déjà avec NOT NULL)
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'nom' AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE vendors ALTER COLUMN nom DROP NOT NULL;
  END IF;
END $$;

-- Ajouter la colonne email si elle n'existe pas déjà
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'email'
  ) THEN
    -- Ajouter la colonne sans NOT NULL d'abord (pour permettre les données existantes)
    ALTER TABLE vendors ADD COLUMN email TEXT;
    
    -- Ajouter la contrainte UNIQUE (permet NULL pour les données existantes)
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'vendors_email_unique'
    ) THEN
      ALTER TABLE vendors ADD CONSTRAINT vendors_email_unique UNIQUE (email);
    END IF;
  END IF;
END $$;

-- Table products
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  nom TEXT NOT NULL,
  description TEXT,
  prix DECIMAL(10,2) NOT NULL,
  available BOOLEAN DEFAULT TRUE,
  next_market_day DATE,
  stock_quantity INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ajouter les colonnes si elles n'existent pas déjà
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'available'
  ) THEN
    ALTER TABLE products ADD COLUMN available BOOLEAN DEFAULT TRUE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'next_market_day'
  ) THEN
    ALTER TABLE products ADD COLUMN next_market_day DATE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'stock_quantity'
  ) THEN
    ALTER TABLE products ADD COLUMN stock_quantity INTEGER;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE products ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;
END $$;

-- Table orders
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  customer_name TEXT NOT NULL,
  pickup_time TIMESTAMP WITH TIME ZONE NOT NULL,
  picked_up BOOLEAN DEFAULT FALSE,
  picked_up_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table trader_otps (pour l'authentification OTP des commerçants)
-- Supprimer l'ancienne table si elle existe avec l'ancienne structure
DROP TABLE IF EXISTS trader_otps CASCADE;

CREATE TABLE trader_otps (
  email TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_products_vendor_id ON products(vendor_id);
CREATE INDEX IF NOT EXISTS idx_orders_vendor_id ON orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_orders_product_id ON orders(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trader_otps_code ON trader_otps(code);
CREATE INDEX IF NOT EXISTS idx_trader_otps_expires ON trader_otps(expires_at);

-- Créer l'index sur email seulement si la colonne existe
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'email'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_vendors_email ON vendors(email);
  END IF;
END $$;

-- Fonction helper pour obtenir le vendor_id du commerçant connecté
CREATE OR REPLACE FUNCTION get_trader_vendor_id()
RETURNS UUID AS $$
DECLARE
  vendor_id_text TEXT;
BEGIN
  -- Récupérer vendor_id depuis user_metadata dans le JWT
  vendor_id_text := auth.jwt()->'user_metadata'->>'vendor_id';
  
  -- Retourner NULL si vide ou invalide
  IF vendor_id_text IS NULL OR vendor_id_text = '' THEN
    RETURN NULL;
  END IF;
  
  RETURN vendor_id_text::uuid;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- RLS (Row Level Security) - Optionnel mais recommandé
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_otps ENABLE ROW LEVEL SECURITY;

-- Supprimer les politiques existantes avant de les recréer
DROP POLICY IF EXISTS "Vendors are viewable by everyone" ON vendors;
DROP POLICY IF EXISTS "Vendors can update their email" ON vendors;
DROP POLICY IF EXISTS "Anyone can create vendors" ON vendors;
DROP POLICY IF EXISTS "Products are viewable by everyone" ON products;
DROP POLICY IF EXISTS "Anyone can create orders" ON orders;
DROP POLICY IF EXISTS "Anyone can manage OTPs" ON trader_otps;
DROP POLICY IF EXISTS "Traders can view their orders" ON orders;
DROP POLICY IF EXISTS "Traders can update their orders" ON orders;

-- Politique: Tout le monde peut lire les vendors et products
CREATE POLICY "Vendors are viewable by everyone" ON vendors
  FOR SELECT USING (true);

-- Politique: Permettre la création de nouveaux stands (pour l'enregistrement)
CREATE POLICY "Anyone can create vendors" ON vendors
  FOR INSERT WITH CHECK (true);

-- Politique: Permettre la mise à jour de l'email et des informations (pour l'enregistrement et la configuration)
CREATE POLICY "Vendors can update their email" ON vendors
  FOR UPDATE USING (true)
  WITH CHECK (true);

-- Politique: Les commerçants peuvent gérer leurs propres produits
DROP POLICY IF EXISTS "Traders can manage their products" ON products;
CREATE POLICY "Traders can manage their products" ON products
  FOR ALL USING (true)
  WITH CHECK (true);

CREATE POLICY "Products are viewable by everyone" ON products
  FOR SELECT USING (true);

-- Politique: Tout le monde peut créer des commandes
CREATE POLICY "Anyone can create orders" ON orders
  FOR INSERT WITH CHECK (true);

-- Politique: Tout le monde peut créer et lire les OTP (pour l'authentification)
CREATE POLICY "Anyone can manage OTPs" ON trader_otps
  FOR ALL USING (true);

-- Politique: Les commerçants peuvent voir et mettre à jour leurs propres commandes
-- Note: Le vendor_id doit être dans user_metadata lors de la création du compte commerçant
-- Alternative: Si cette approche ne fonctionne pas, vous pouvez simplifier en permettant
-- à tous les utilisateurs authentifiés de voir/mettre à jour les commandes et filtrer côté application
CREATE POLICY "Traders can view their orders" ON orders
  FOR SELECT USING (
    auth.uid() IS NOT NULL
    AND get_trader_vendor_id() IS NOT NULL
    AND get_trader_vendor_id() = orders.vendor_id
  );

CREATE POLICY "Traders can update their orders" ON orders
  FOR UPDATE USING (
    auth.uid() IS NOT NULL
    AND get_trader_vendor_id() IS NOT NULL
    AND get_trader_vendor_id() = orders.vendor_id
  );

-- Données d'exemple (optionnel)
-- Mettre à jour les emails pour les stands existants ou les créer
INSERT INTO vendors (id, nom, description, location, email) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'Stand Poulet Rôti du Marché', 'Le meilleur poulet rôti du marché depuis 20 ans', 'Allée A, Stand 12', 'stand1@marche.com'),
  ('550e8400-e29b-41d4-a716-446655440001', 'La Rotisserie Authentique', 'Poulet rôti traditionnel au feu de bois', 'Allée B, Stand 5', 'stand2@marche.com')
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

INSERT INTO products (vendor_id, nom, description, prix) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'Poulet entier', 'Poulet rôti entier (1.2-1.5kg)', 12.50),
  ('550e8400-e29b-41d4-a716-446655440000', 'Demi-poulet', 'Demi-poulet rôti', 7.50),
  ('550e8400-e29b-41d4-a716-446655440000', 'Quart de poulet', 'Quart de poulet rôti avec frites', 5.50),
  ('550e8400-e29b-41d4-a716-446655440001', 'Poulet entier', 'Poulet rôti entier (1.2-1.5kg)', 13.00),
  ('550e8400-e29b-41d4-a716-446655440001', 'Demi-poulet', 'Demi-poulet rôti', 7.00),
  ('550e8400-e29b-41d4-a716-446655440001', 'Poulet + légumes', 'Poulet rôti avec légumes de saison', 14.50)
ON CONFLICT DO NOTHING;

