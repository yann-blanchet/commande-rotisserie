# Commande Rotisserie

Application de commande de poulet rôti en marché avec support offline-first et synchronisation avec Supabase.

## Fonctionnalités

- 🍗 Commande de poulet rôti depuis différents stands
- 📱 PWA (Progressive Web App) - Installable sur mobile
- 🔄 Offline-first - Fonctionne sans connexion internet
- 🔐 Authentification des commerçants via Supabase
- 💾 Cache local avec Dexie (IndexedDB)
- 🔄 Synchronisation automatique avec Supabase

## Structure de la base de données

### Tables locales (Dexie/IndexedDB)

- **favorites**: Stands favoris
- **offline_orders**: Commandes créées hors ligne
- **vendors_cache**: Cache des stands
- **products_cache**: Cache des produits
- **orders_cache**: Cache des commandes (pour commerçants)

### Tables Supabase

Vous devez créer les tables suivantes dans Supabase:

```sql
-- Table vendors (stands)
CREATE TABLE vendors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom TEXT NOT NULL,
  description TEXT,
  location TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Table products
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES vendors(id),
  nom TEXT NOT NULL,
  description TEXT,
  prix DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Table orders
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES vendors(id),
  product_id UUID REFERENCES products(id),
  customer_name TEXT NOT NULL,
  pickup_time TIMESTAMP NOT NULL,
  picked_up BOOLEAN DEFAULT FALSE,
  picked_up_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Installation

1. Installer les dépendances:
```bash
npm install
```

2. Configurer les variables d'environnement:
```bash
cp .env.example .env
```

Puis éditez `.env` avec vos credentials Supabase:
- `VITE_SUPABASE_URL`: URL de votre projet Supabase
- `VITE_SUPABASE_ANON_KEY`: Clé anonyme de votre projet Supabase

3. Lancer le serveur de développement:
```bash
npm run dev
```

4. Build pour production:
```bash
npm run build
```

## Architecture Offline-First

1. **Commandes**: Les commandes sont créées localement et synchronisées automatiquement quand la connexion est rétablie
2. **Cache**: Les stands et produits sont mis en cache dès la première visite
3. **Commerçants**: Les commerçants peuvent marquer les commandes comme "retirées" même hors ligne

## Authentification

- **Clients**: Pas d'authentification requise
- **Commerçants**: Authentification via code OTP à 6 chiffres
  - Le commerçant entre son **email** (associé à un stand dans la table `vendors`)
  - Un code OTP est généré et valide pendant 10 minutes
  - Le code est affiché dans l'interface (en développement)
  - En production, le code devrait être envoyé par SMS ou email

Pour créer un compte commerçant, utilisez l'interface Supabase ou créez un utilisateur avec `user_metadata.vendor_id` correspondant à l'ID du stand.
