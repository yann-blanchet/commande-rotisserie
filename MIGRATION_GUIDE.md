# Guide de Migration SQL

## Scripts SQL disponibles

### 1. `supabase-migration-final.sql` ⭐ **RECOMMANDÉ**
**Script consolidé complet** incluant toutes les améliorations :
- ✅ Schéma de base (tables, foreign keys, index)
- ✅ Déplacement `nom`/`description` vers `profiles` (stand_nom, stand_description)
- ✅ Suppression de `next_market_day` de `vendors` (calculé depuis `markets.days`)
- ✅ Contrainte unique `(profile_id, market_id)`
- ✅ Vue `vendor_stands`
- ✅ Migration automatique des données existantes
- ✅ RLS policies

**Utilisez ce script si :**
- Vous voulez tout en un seul script
- Vous partez de zéro ou vous voulez réinitialiser
- Vous voulez la structure finale optimale

### 2. Scripts incrémentaux (pour migrations progressives)

#### `improved-schema.sql`
- Ajoute `stand_nom` et `stand_description` à `profiles`
- Migre les données depuis `vendors`
- Crée la contrainte unique et la vue

#### `remove-next-market-day.sql`
- Supprime `next_market_day` de `vendors`
- Met à jour la vue `vendor_stands`

## Recommandation

### Pour une nouvelle installation
```sql
-- Exécutez simplement :
supabase-migration-final.sql
```

### Pour une base existante
Vous avez deux options :

#### Option A : Script consolidé (recommandé)
```sql
-- Exécutez :
supabase-migration-final.sql
```
Ce script est idempotent (peut être exécuté plusieurs fois sans problème).

#### Option B : Scripts incrémentaux
```sql
-- 1. D'abord :
improved-schema.sql

-- 2. Ensuite :
remove-next-market-day.sql
```

## Structure finale

```
profiles
  ├── id
  ├── email
  ├── role
  ├── stand_nom          ← Nom du stand (partagé)
  └── stand_description  ← Description (partagée)

vendors
  ├── id
  ├── profile_id
  ├── market_id
  ├── location           ← Emplacement dans le marché
  └── is_available

markets
  ├── id
  ├── name
  ├── place
  └── days              ← Jours récurrents (pour calculer le prochain jour)

products
  ├── id
  ├── vendor_id
  ├── nom
  ├── prix
  └── next_market_day   ← Date spécifique par produit (conservé)
```

## Notes importantes

1. **`next_market_day` dans `vendors`** : ❌ Supprimé (calculé depuis `markets.days`)
2. **`next_market_day` dans `products`** : ✅ Conservé (date spécifique par produit)
3. **`nom` et `description` dans `vendors`** : ❌ Supprimés (déplacés vers `profiles`)
4. **Contrainte unique** : Un trader ne peut avoir qu'un seul stand par marché

## Après la migration

Le code a été mis à jour pour :
- ✅ Utiliser `profiles.stand_nom` au lieu de `vendors.nom`
- ✅ Calculer le prochain jour de marché depuis `markets.days`
- ✅ Supprimer la section de saisie manuelle dans `TraderProducts.vue`

## Vérification

Après la migration, vérifiez :
```sql
-- Vérifier la structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'vendors'
ORDER BY ordinal_position;

-- Vérifier la vue
SELECT * FROM vendor_stands LIMIT 5;

-- Vérifier la contrainte unique
SELECT conname, contype 
FROM pg_constraint 
WHERE conrelid = 'vendors'::regclass;
```







