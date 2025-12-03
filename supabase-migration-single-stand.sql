-- ============================================
-- MIGRATION : UN SEUL STAND PAR COMMERÇANT
-- ============================================
-- Ce script modifie le schéma pour :
-- 1. S'assurer qu'un commerçant ne peut avoir qu'UN SEUL stand
-- 2. Ajouter market_id aux commandes pour savoir sur quel marché elles ont été passées
-- ============================================

-- ============================================
-- 1. CONTRAINTE UNIQUE : UN SEUL VENDOR PAR PROFILE_ID
-- ============================================

-- Supprimer les vendors en double si nécessaire (garder le plus ancien)
DO $$
DECLARE
  duplicate_record RECORD;
BEGIN
  FOR duplicate_record IN
    SELECT profile_id, COUNT(*) as count
    FROM vendors
    WHERE profile_id IS NOT NULL
    GROUP BY profile_id
    HAVING COUNT(*) > 1
  LOOP
    -- Garder le plus ancien, supprimer les autres
    DELETE FROM vendors
    WHERE profile_id = duplicate_record.profile_id
      AND id NOT IN (
        SELECT id FROM vendors
        WHERE profile_id = duplicate_record.profile_id
        ORDER BY created_at ASC
        LIMIT 1
      );
    
    RAISE NOTICE 'Supprimé % vendor(s) en double pour profile_id: %', 
      duplicate_record.count - 1, duplicate_record.profile_id;
  END LOOP;
END $$;

-- Ajouter la contrainte unique sur profile_id
DO $$
BEGIN
  -- Vérifier si la contrainte existe déjà
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'vendors_profile_id_unique'
  ) THEN
    ALTER TABLE vendors 
    ADD CONSTRAINT vendors_profile_id_unique UNIQUE (profile_id);
    
    RAISE NOTICE '✅ Contrainte unique ajoutée sur vendors.profile_id';
  ELSE
    RAISE NOTICE '⚠️ Contrainte vendors_profile_id_unique existe déjà';
  END IF;
END $$;

-- ============================================
-- 2. AJOUTER market_id AUX COMMANDES
-- ============================================

-- Ajouter la colonne market_id à orders si elle n'existe pas
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'market_id'
  ) THEN
    ALTER TABLE orders ADD COLUMN market_id UUID REFERENCES markets(id) ON DELETE SET NULL;
    
    -- Créer un index pour améliorer les performances
    CREATE INDEX IF NOT EXISTS idx_orders_market_id ON orders(market_id);
    
    -- Migrer les données : récupérer le market_id depuis vendor_markets
    -- Si le vendor a un seul marché associé, on l'utilise
    UPDATE orders o
    SET market_id = (
      SELECT vm.market_id
      FROM vendor_markets vm
      WHERE vm.vendor_id = o.vendor_id
      LIMIT 1
    )
    WHERE market_id IS NULL;
    
    -- Note: Si vendor_markets n'existe pas encore, les orders.market_id resteront NULL
    -- Ils pourront être mis à jour manuellement ou lors de la prochaine création de commande
    
    RAISE NOTICE '✅ Colonne market_id ajoutée à orders et données migrées';
  ELSE
    RAISE NOTICE '⚠️ Colonne market_id existe déjà dans orders';
  END IF;
END $$;

-- ============================================
-- 3. MISE À JOUR DES INDEX
-- ============================================

-- Index composite pour améliorer les requêtes de commandes par vendor et market
CREATE INDEX IF NOT EXISTS idx_orders_vendor_market ON orders(vendor_id, market_id);
CREATE INDEX IF NOT EXISTS idx_orders_market_created ON orders(market_id, created_at DESC);

-- ============================================
-- 4. COMMENTAIRES POUR DOCUMENTATION
-- ============================================

COMMENT ON CONSTRAINT vendors_profile_id_unique ON vendors IS 
  'Un commerçant (profile) ne peut avoir qu''un seul stand (vendor)';

COMMENT ON COLUMN orders.market_id IS 
  'Marché sur lequel la commande a été passée. Permet de filtrer les commandes par marché.';

-- ============================================
-- 5. VÉRIFICATIONS
-- ============================================

-- Vérifier qu'il n'y a pas de vendors en double
DO $$
DECLARE
  duplicate_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO duplicate_count
  FROM (
    SELECT profile_id, COUNT(*) as count
    FROM vendors
    WHERE profile_id IS NOT NULL
    GROUP BY profile_id
    HAVING COUNT(*) > 1
  ) duplicates;
  
  IF duplicate_count > 0 THEN
    RAISE WARNING '⚠️ Il reste % profile_id(s) avec plusieurs vendors', duplicate_count;
  ELSE
    RAISE NOTICE '✅ Aucun vendor en double trouvé';
  END IF;
END $$;

-- Message de confirmation
DO $$
BEGIN
  RAISE NOTICE '✅ Migration terminée : Un seul stand par commerçant et market_id dans les commandes';
END $$;

