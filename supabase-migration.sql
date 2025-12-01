-- ============================================
-- MIGRATION SQL FINALE POUR SUPABASE
-- ============================================
-- Ce script inclut toutes les améliorations :
-- - Schéma de base (tables, foreign keys, index)
-- - Déplacement nom/description vers profiles
-- - Suppression de next_market_day de vendors
-- - Contrainte unique (profile_id, market_id)
-- - Vue vendor_stands
-- ============================================

-- ============================================
-- 1. CRÉER LES TABLES DE BASE
-- ============================================

-- Table markets (marchés)
CREATE TABLE IF NOT EXISTS markets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  place TEXT NOT NULL,
  days TEXT[] NOT NULL, -- Array of days: ['monday', 'wednesday', 'friday']
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table profiles (utilisateurs avec role vendor ou admin)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('vendor', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table vendors (stands) - SANS next_market_day et nom/description (déplacés vers profiles)
CREATE TABLE IF NOT EXISTS vendors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  location TEXT, -- Emplacement du stand dans le marché (ex: "Allée 6")
  market_id UUID REFERENCES markets(id) ON DELETE SET NULL,
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table products
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  nom TEXT NOT NULL,
  description TEXT,
  prix DECIMAL(10,2) NOT NULL,
  available BOOLEAN DEFAULT TRUE,
  next_market_day DATE, -- Date spécifique par produit (différent du jour de marché général)
  stock_quantity INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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

-- Table otps (unifiée pour vendors et admins)
DROP TABLE IF EXISTS trader_otps CASCADE;
DROP TABLE IF EXISTS admin_otps CASCADE;

CREATE TABLE IF NOT EXISTS otps (
  email TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 2. AJOUTER LES COLONNES AMÉLIORÉES
-- ============================================

-- Ajouter stand_nom et stand_description à profiles
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'stand_nom'
  ) THEN
    ALTER TABLE profiles ADD COLUMN stand_nom TEXT;
    RAISE NOTICE '✅ Colonne stand_nom ajoutée à profiles';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'stand_description'
  ) THEN
    ALTER TABLE profiles ADD COLUMN stand_description TEXT;
    RAISE NOTICE '✅ Colonne stand_description ajoutée à profiles';
  END IF;
END $$;

-- Ajouter les colonnes manquantes si elles n'existent pas déjà
DO $$ 
BEGIN
  -- Ajouter profile_id à vendors si nécessaire
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'profile_id'
  ) THEN
    ALTER TABLE vendors ADD COLUMN profile_id UUID;
    ALTER TABLE vendors 
      ADD CONSTRAINT vendors_profile_id_fkey 
      FOREIGN KEY (profile_id) 
      REFERENCES profiles(id) 
      ON DELETE CASCADE;
  END IF;
  
  -- Ajouter market_id à vendors si nécessaire
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'market_id'
  ) THEN
    ALTER TABLE vendors ADD COLUMN market_id UUID;
    ALTER TABLE vendors 
      ADD CONSTRAINT vendors_market_id_fkey 
      FOREIGN KEY (market_id) 
      REFERENCES markets(id) 
      ON DELETE SET NULL;
  END IF;
  
  -- Ajouter is_available à vendors si nécessaire
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'is_available'
  ) THEN
    ALTER TABLE vendors ADD COLUMN is_available BOOLEAN DEFAULT TRUE;
  END IF;
  
  -- Supprimer next_market_day de vendors (redondant, calculé depuis markets.days)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'next_market_day'
  ) THEN
    ALTER TABLE vendors DROP COLUMN next_market_day;
    RAISE NOTICE '✅ Colonne next_market_day supprimée de vendors';
  END IF;
  
  -- Supprimer les vues qui dépendent de nom/description avant de supprimer les colonnes
  DROP VIEW IF EXISTS vendor_stands_with_markets CASCADE;
  DROP VIEW IF EXISTS vendor_stands CASCADE;
  
  -- Supprimer nom et description de vendors (déplacés vers profiles)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'nom'
  ) THEN
    ALTER TABLE vendors DROP COLUMN nom;
    RAISE NOTICE '✅ Colonne nom supprimée de vendors (déplacée vers profiles.stand_nom)';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'description'
  ) THEN
    ALTER TABLE vendors DROP COLUMN description;
    RAISE NOTICE '✅ Colonne description supprimée de vendors (déplacée vers profiles.stand_description)';
  END IF;
  
  -- Ajouter les colonnes à products si nécessaire
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

-- ============================================
-- 3. MIGRER LES DONNÉES EXISTANTES
-- ============================================

-- Migrer nom et description depuis vendors vers profiles (si elles existent encore)
DO $$ 
DECLARE
  vendor_rec RECORD;
  profile_nom TEXT;
  profile_desc TEXT;
BEGIN
  -- Vérifier si la colonne nom existe encore dans vendors
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'nom'
  ) THEN
    -- Pour chaque profile_id unique dans vendors
    FOR vendor_rec IN 
      SELECT DISTINCT profile_id 
      FROM vendors 
      WHERE profile_id IS NOT NULL
    LOOP
      -- Récupérer le premier nom non-null pour ce profile
      SELECT nom INTO profile_nom
      FROM vendors
      WHERE profile_id = vendor_rec.profile_id 
        AND nom IS NOT NULL 
        AND nom != ''
      LIMIT 1;

      -- Récupérer la première description non-null pour ce profile
      SELECT description INTO profile_desc
      FROM vendors
      WHERE profile_id = vendor_rec.profile_id 
        AND description IS NOT NULL 
        AND description != ''
      LIMIT 1;

      -- Mettre à jour le profile si des valeurs ont été trouvées
      IF profile_nom IS NOT NULL OR profile_desc IS NOT NULL THEN
        UPDATE profiles
        SET 
          stand_nom = COALESCE(stand_nom, profile_nom),
          stand_description = COALESCE(stand_description, profile_desc)
        WHERE id = vendor_rec.profile_id
          AND (stand_nom IS NULL OR stand_description IS NULL);
      END IF;
    END LOOP;
  END IF;
END $$;

-- Migration des profiles pour vendors existants avec email (si colonne email existe encore)
DO $$ 
DECLARE
  vendor_record RECORD;
  admin_record RECORD;
  new_profile_id UUID;
BEGIN
  -- Vérifier si la colonne email existe encore dans vendors
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'email'
  ) THEN
    -- Migrer vendors avec email vers profiles
    FOR vendor_record IN 
      SELECT DISTINCT email FROM vendors WHERE email IS NOT NULL
    LOOP
      IF NOT EXISTS (SELECT 1 FROM profiles WHERE email = vendor_record.email) THEN
        INSERT INTO profiles (email, role) 
        VALUES (vendor_record.email, 'vendor')
        RETURNING id INTO new_profile_id;
        
        UPDATE vendors 
        SET profile_id = new_profile_id 
        WHERE email = vendor_record.email AND profile_id IS NULL;
      ELSE
        SELECT id INTO new_profile_id FROM profiles WHERE email = vendor_record.email;
        UPDATE vendors 
        SET profile_id = new_profile_id 
        WHERE email = vendor_record.email AND profile_id IS NULL;
      END IF;
    END LOOP;
  END IF;
  
  -- Migrer admin_users vers profiles
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_users') THEN
    FOR admin_record IN 
      SELECT email FROM admin_users
    LOOP
      IF NOT EXISTS (SELECT 1 FROM profiles WHERE email = admin_record.email) THEN
        INSERT INTO profiles (email, role) 
        VALUES (admin_record.email, 'admin');
      END IF;
    END LOOP;
  END IF;
END $$;

-- ============================================
-- 4. CONTRAINTES ET INDEX
-- ============================================

-- Contrainte unique : un trader ne peut avoir qu'un seul stand par marché
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'vendors_profile_market_unique'
  ) THEN
    ALTER TABLE vendors 
      ADD CONSTRAINT vendors_profile_market_unique 
      UNIQUE (profile_id, market_id);
    RAISE NOTICE '✅ Contrainte unique (profile_id, market_id) ajoutée';
  END IF;
END $$;

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_markets_name ON markets(name);
CREATE INDEX IF NOT EXISTS idx_vendors_market_id ON vendors(market_id);
CREATE INDEX IF NOT EXISTS idx_vendors_profile_id ON vendors(profile_id);
CREATE INDEX IF NOT EXISTS idx_vendors_profile_market ON vendors(profile_id, market_id);
CREATE INDEX IF NOT EXISTS idx_products_vendor_id ON products(vendor_id);
CREATE INDEX IF NOT EXISTS idx_orders_vendor_id ON orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_orders_product_id ON orders(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_otps_code ON otps(code);
CREATE INDEX IF NOT EXISTS idx_otps_expires ON otps(expires_at);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_stand_nom ON profiles(stand_nom) WHERE stand_nom IS NOT NULL;

-- ============================================
-- 5. VUE UTILE
-- ============================================

-- Supprimer les anciennes vues qui pourraient dépendre de nom/description
DROP VIEW IF EXISTS vendor_stands_with_markets CASCADE;
DROP VIEW IF EXISTS vendor_stands CASCADE;

-- Créer la nouvelle vue avec la structure améliorée
CREATE OR REPLACE VIEW vendor_stands AS
SELECT 
  v.id,
  v.profile_id,
  p.stand_nom,
  p.stand_description,
  p.email,
  v.market_id,
  m.name as market_name,
  m.place as market_place,
  m.days as market_days,
  v.location,
  v.is_available,
  v.created_at
FROM vendors v
LEFT JOIN profiles p ON v.profile_id = p.id
LEFT JOIN markets m ON v.market_id = m.id;

-- ============================================
-- 6. RLS (Row Level Security)
-- ============================================

ALTER TABLE markets ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE otps ENABLE ROW LEVEL SECURITY;

-- Supprimer les politiques existantes
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Anyone can create profiles" ON profiles;
DROP POLICY IF EXISTS "Vendors are viewable by everyone" ON vendors;
DROP POLICY IF EXISTS "Vendors can update their email" ON vendors;
DROP POLICY IF EXISTS "Anyone can create vendors" ON vendors;
DROP POLICY IF EXISTS "Products are viewable by everyone" ON products;
DROP POLICY IF EXISTS "Anyone can create orders" ON orders;
DROP POLICY IF EXISTS "Anyone can view orders" ON orders;
DROP POLICY IF EXISTS "Anyone can update orders" ON orders;
DROP POLICY IF EXISTS "Anyone can manage OTPs" ON otps;
DROP POLICY IF EXISTS "Traders can view their orders" ON orders;
DROP POLICY IF EXISTS "Traders can update their orders" ON orders;
DROP POLICY IF EXISTS "Markets are viewable by everyone" ON markets;
DROP POLICY IF EXISTS "Admins can manage markets" ON markets;
DROP POLICY IF EXISTS "Traders can manage their products" ON products;

-- RLS Policies
CREATE POLICY "Profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Anyone can create profiles" ON profiles
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Vendors are viewable by everyone" ON vendors
  FOR SELECT USING (true);

CREATE POLICY "Anyone can create vendors" ON vendors
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Vendors can update their email" ON vendors
  FOR UPDATE USING (true)
  WITH CHECK (true);

CREATE POLICY "Traders can manage their products" ON products
  FOR ALL USING (true)
  WITH CHECK (true);

CREATE POLICY "Markets are viewable by everyone" ON markets
  FOR SELECT USING (true);

CREATE POLICY "Admins can manage markets" ON markets
  FOR ALL USING (true)
  WITH CHECK (true);

CREATE POLICY "Products are viewable by everyone" ON products
  FOR SELECT USING (true);

CREATE POLICY "Anyone can create orders" ON orders
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can view orders" ON orders
  FOR SELECT USING (true);

CREATE POLICY "Anyone can update orders" ON orders
  FOR UPDATE USING (true)
  WITH CHECK (true);

CREATE POLICY "Anyone can manage OTPs" ON otps
  FOR ALL USING (true);

-- ============================================
-- FIN DE LA MIGRATION
-- ============================================
-- Structure finale:
-- - profiles: email, role, stand_nom, stand_description
-- - vendors: profile_id, market_id, location, is_available
-- - markets: name, place, days (pour calculer le prochain jour)
-- - products: vendor_id, nom, prix, next_market_day (spécifique au produit)
-- ============================================
