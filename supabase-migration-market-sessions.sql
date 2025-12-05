-- ============================================
-- MIGRATION : SESSIONS DE MARCHÉ
-- ============================================
-- Ce script ajoute le support des sessions de marché :
-- 1. Table market_sessions : stocke les sessions de marché avec date et date de fermeture
-- 2. Table market_session_products : associe les produits disponibles à chaque session
-- ============================================

-- ============================================
-- 1. CRÉER LA TABLE market_sessions
-- ============================================

CREATE TABLE IF NOT EXISTS market_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  market_id UUID NOT NULL REFERENCES markets(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  order_closure_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(market_id, date)
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_market_sessions_market_id ON market_sessions(market_id);
CREATE INDEX IF NOT EXISTS idx_market_sessions_date ON market_sessions(date);
CREATE INDEX IF NOT EXISTS idx_market_sessions_active ON market_sessions(is_active) WHERE is_active = TRUE;

-- ============================================
-- 2. CRÉER LA TABLE market_session_products
-- ============================================

CREATE TABLE IF NOT EXISTS market_session_products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  market_session_id UUID NOT NULL REFERENCES market_sessions(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(market_session_id, product_id)
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_market_session_products_session_id ON market_session_products(market_session_id);
CREATE INDEX IF NOT EXISTS idx_market_session_products_product_id ON market_session_products(product_id);

-- ============================================
-- 3. TRIGGER POUR UPDATED_AT
-- ============================================

-- Fonction pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_market_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour market_sessions
DROP TRIGGER IF EXISTS trigger_update_market_sessions_updated_at ON market_sessions;
CREATE TRIGGER trigger_update_market_sessions_updated_at
  BEFORE UPDATE ON market_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_market_sessions_updated_at();

-- ============================================
-- 4. ROW LEVEL SECURITY (RLS)
-- ============================================
-- RLS activé avec policies permissives (sécurité gérée au niveau applicatif via OTP)

-- Activer RLS
ALTER TABLE market_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_session_products ENABLE ROW LEVEL SECURITY;

-- Policies permissives (sécurité gérée par l'application)
CREATE POLICY "Market sessions are viewable by everyone" ON market_sessions
  FOR SELECT USING (true);

CREATE POLICY "Anyone can create market sessions" ON market_sessions
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update market sessions" ON market_sessions
  FOR UPDATE USING (true)
  WITH CHECK (true);

CREATE POLICY "Market session products are viewable by everyone" ON market_session_products
  FOR SELECT USING (true);

CREATE POLICY "Anyone can create market session products" ON market_session_products
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can delete market session products" ON market_session_products
  FOR DELETE USING (true);

-- ============================================
-- 5. VUE POUR FACILITER LES REQUÊTES
-- ============================================

-- Vue pour obtenir les sessions actives avec leurs informations
CREATE OR REPLACE VIEW active_market_sessions AS
SELECT 
  ms.id,
  ms.market_id,
  ms.date,
  ms.order_closure_date,
  ms.is_active,
  ms.created_at,
  ms.updated_at,
  m.name as market_name,
  m.place as market_place,
  m.days as market_days
FROM market_sessions ms
JOIN markets m ON m.id = ms.market_id
WHERE ms.is_active = TRUE
ORDER BY ms.date ASC;

-- Vue pour obtenir les sessions avec leurs produits
CREATE OR REPLACE VIEW market_sessions_with_products AS
SELECT 
  ms.id as session_id,
  ms.market_id,
  ms.date,
  ms.order_closure_date,
  ms.is_active,
  m.name as market_name,
  m.place as market_place,
  json_agg(
    json_build_object(
      'id', p.id,
      'nom', p.nom,
      'description', p.description,
      'prix', p.prix,
      'available', p.available,
      'vendor_id', p.vendor_id
    )
  ) as products
FROM market_sessions ms
JOIN markets m ON m.id = ms.market_id
LEFT JOIN market_session_products msp ON msp.market_session_id = ms.id
LEFT JOIN products p ON p.id = msp.product_id
WHERE ms.is_active = TRUE
GROUP BY ms.id, ms.market_id, ms.date, ms.order_closure_date, ms.is_active, m.name, m.place
ORDER BY ms.date ASC;

-- ============================================
-- 6. COMMENTAIRES
-- ============================================

COMMENT ON TABLE market_sessions IS 'Sessions de marché avec date et date de fermeture des commandes';
COMMENT ON TABLE market_session_products IS 'Association entre les sessions de marché et les produits disponibles';
COMMENT ON COLUMN market_sessions.date IS 'Date de la session de marché';
COMMENT ON COLUMN market_sessions.order_closure_date IS 'Date et heure de fermeture des commandes pour cette session';
COMMENT ON COLUMN market_sessions.is_active IS 'Indique si la session est active (en cours ou à venir)';

-- ============================================
-- 7. MESSAGE DE CONFIRMATION
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration terminée : Tables market_sessions et market_session_products créées';
  RAISE NOTICE '✅ RLS activé avec policies permissives (sécurité gérée au niveau applicatif)';
  RAISE NOTICE '✅ Vues créées : active_market_sessions, market_sessions_with_products';
END $$;

