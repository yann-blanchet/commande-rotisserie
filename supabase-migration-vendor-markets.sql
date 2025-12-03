-- ============================================
-- MIGRATION : SUPPORT MULTIPLE MARKETS PER STAND
-- ============================================
-- Ce script modifie le schéma pour permettre à un stand
-- d'être associé à plusieurs marchés via une table de liaison
-- ============================================

-- ============================================
-- 1. CRÉER LA TABLE DE LIAISON vendor_markets
-- ============================================

CREATE TABLE IF NOT EXISTS vendor_markets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  market_id UUID NOT NULL REFERENCES markets(id) ON DELETE CASCADE,
  location TEXT, -- Emplacement du stand dans ce marché spécifique (ex: "Allée 6")
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vendor_id, market_id) -- Un stand ne peut être qu'une fois dans le même marché
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_vendor_markets_vendor_id ON vendor_markets(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_markets_market_id ON vendor_markets(market_id);

-- ============================================
-- 2. DÉPLACER stand_nom ET stand_description DE profiles VERS vendors
-- ============================================

-- Ajouter les colonnes à vendors si elles n'existent pas
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'stand_nom'
  ) THEN
    ALTER TABLE vendors ADD COLUMN stand_nom TEXT;
    RAISE NOTICE '✅ Colonne stand_nom ajoutée à vendors';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'stand_description'
  ) THEN
    ALTER TABLE vendors ADD COLUMN stand_description TEXT;
    RAISE NOTICE '✅ Colonne stand_description ajoutée à vendors';
  END IF;
END $$;

-- Migrer les données de profiles vers vendors
DO $$
DECLARE
  vendor_record RECORD;
BEGIN
  -- Pour chaque vendor, copier stand_nom et stand_description depuis profiles
  FOR vendor_record IN 
    SELECT v.id, v.profile_id, p.stand_nom, p.stand_description
    FROM vendors v
    JOIN profiles p ON v.profile_id = p.id
    WHERE (v.stand_nom IS NULL OR v.stand_description IS NULL)
      AND (p.stand_nom IS NOT NULL OR p.stand_description IS NOT NULL)
  LOOP
    UPDATE vendors
    SET 
      stand_nom = COALESCE(vendors.stand_nom, vendor_record.stand_nom),
      stand_description = COALESCE(vendors.stand_description, vendor_record.stand_description)
    WHERE id = vendor_record.id;
  END LOOP;
  
  RAISE NOTICE '✅ Données migrées de profiles vers vendors';
END $$;

-- ============================================
-- 3. MIGRER LES ASSOCIATIONS MARKET VERS vendor_markets
-- ============================================

-- Migrer les vendors existants avec market_id vers vendor_markets
DO $$
DECLARE
  vendor_record RECORD;
BEGIN
  -- Pour chaque vendor qui a un market_id, créer une entrée dans vendor_markets
  FOR vendor_record IN 
    SELECT id, market_id, location
    FROM vendors
    WHERE market_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM vendor_markets vm 
        WHERE vm.vendor_id = vendors.id AND vm.market_id = vendors.market_id
      )
  LOOP
    INSERT INTO vendor_markets (vendor_id, market_id, location)
    VALUES (vendor_record.id, vendor_record.market_id, vendor_record.location)
    ON CONFLICT (vendor_id, market_id) DO NOTHING;
  END LOOP;
  
  RAISE NOTICE '✅ Associations market migrées vers vendor_markets';
END $$;

-- ============================================
-- 4. SUPPRIMER LA VUE vendor_stands (AVANT DE SUPPRIMER LES COLONNES)
-- ============================================

-- Supprimer la vue d'abord car elle dépend des colonnes qu'on va supprimer
DROP VIEW IF EXISTS vendor_stands CASCADE;

-- ============================================
-- 5. SUPPRIMER market_id ET location DE vendors
-- ============================================

-- Supprimer la contrainte unique (profile_id, market_id) car elle n'est plus nécessaire
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'vendors_profile_market_unique'
  ) THEN
    ALTER TABLE vendors DROP CONSTRAINT vendors_profile_market_unique;
    RAISE NOTICE '✅ Contrainte unique (profile_id, market_id) supprimée';
  END IF;
END $$;

-- Supprimer les colonnes market_id et location de vendors
-- (on garde location dans vendor_markets car chaque marché peut avoir une location différente)
DO $$ 
BEGIN
  -- Supprimer la foreign key d'abord
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'vendors' 
      AND constraint_name LIKE '%market_id%'
  ) THEN
    ALTER TABLE vendors DROP CONSTRAINT IF EXISTS vendors_market_id_fkey;
    RAISE NOTICE '✅ Foreign key market_id supprimée';
  END IF;
  
  -- Supprimer la colonne market_id
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'market_id'
  ) THEN
    ALTER TABLE vendors DROP COLUMN market_id CASCADE;
    RAISE NOTICE '✅ Colonne market_id supprimée de vendors';
  END IF;
  
  -- Supprimer la colonne location (elle est maintenant dans vendor_markets)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vendors' AND column_name = 'location'
  ) THEN
    ALTER TABLE vendors DROP COLUMN location CASCADE;
    RAISE NOTICE '✅ Colonne location supprimée de vendors';
  END IF;
END $$;

-- ============================================
-- 6. RECRÉER LA VUE vendor_stands AVEC LE NOUVEAU SCHÉMA
-- ============================================

CREATE OR REPLACE VIEW vendor_stands AS
SELECT 
  v.id,
  v.profile_id,
  v.stand_nom,
  v.stand_description,
  p.email,
  v.is_available,
  v.created_at,
  -- Agrégation des marchés associés
  COALESCE(
    json_agg(
      json_build_object(
        'market_id', m.id,
        'market_name', m.name,
        'market_place', m.place,
        'market_days', m.days,
        'location', vm.location
      )
    ) FILTER (WHERE m.id IS NOT NULL),
    '[]'::json
  ) as markets
FROM vendors v
LEFT JOIN profiles p ON v.profile_id = p.id
LEFT JOIN vendor_markets vm ON v.id = vm.vendor_id
LEFT JOIN markets m ON vm.market_id = m.id
GROUP BY v.id, v.profile_id, v.stand_nom, v.stand_description, p.email, v.is_available, v.created_at;

-- ============================================
-- 7. RLS (Row Level Security) POUR vendor_markets
-- ============================================

ALTER TABLE vendor_markets ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre la lecture à tous les utilisateurs authentifiés
CREATE POLICY "vendor_markets_select" ON vendor_markets
  FOR SELECT
  USING (true);

-- Politique pour permettre l'insertion aux vendors (via leur profile_id)
CREATE POLICY "vendor_markets_insert" ON vendor_markets
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM vendors v
      JOIN profiles p ON v.profile_id = p.id
      WHERE v.id = vendor_markets.vendor_id
        AND p.role = 'vendor'
    )
  );

-- Politique pour permettre la mise à jour aux vendors
CREATE POLICY "vendor_markets_update" ON vendor_markets
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM vendors v
      JOIN profiles p ON v.profile_id = p.id
      WHERE v.id = vendor_markets.vendor_id
        AND p.role = 'vendor'
    )
  );

-- Politique pour permettre la suppression aux vendors
CREATE POLICY "vendor_markets_delete" ON vendor_markets
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM vendors v
      JOIN profiles p ON v.profile_id = p.id
      WHERE v.id = vendor_markets.vendor_id
        AND p.role = 'vendor'
    )
  );

-- ============================================
-- 8. SUPPRIMER stand_nom ET stand_description DE profiles (optionnel)
-- ============================================
-- Note: On peut garder ces colonnes pour compatibilité, ou les supprimer
-- Si vous voulez les supprimer, décommentez les lignes suivantes :

-- DO $$ 
-- BEGIN
--   IF EXISTS (
--     SELECT 1 FROM information_schema.columns 
--     WHERE table_name = 'profiles' AND column_name = 'stand_nom'
--   ) THEN
--     ALTER TABLE profiles DROP COLUMN stand_nom;
--     RAISE NOTICE '✅ Colonne stand_nom supprimée de profiles';
--   END IF;
-- 
--   IF EXISTS (
--     SELECT 1 FROM information_schema.columns 
--     WHERE table_name = 'profiles' AND column_name = 'stand_description'
--   ) THEN
--     ALTER TABLE profiles DROP COLUMN stand_description;
--     RAISE NOTICE '✅ Colonne stand_description supprimée de profiles';
--   END IF;
-- END $$;

-- ============================================
-- FIN DE LA MIGRATION
-- ============================================

