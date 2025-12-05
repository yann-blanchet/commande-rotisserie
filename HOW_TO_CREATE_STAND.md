# Comment créer un stand

## 📋 Vue d'ensemble

Un stand est créé en deux étapes :
1. **Création du profil trader** (lors de l'enregistrement)
2. **Création du vendor/stand** (par un admin ou par le trader lui-même)

## 🎯 Méthode 1 : Par un administrateur (recommandé)

### Étape 1 : Le trader s'enregistre
1. Le trader va sur `/trader/register`
2. Il entre son email
3. Un profil avec `role: 'vendor'` est créé dans la table `profiles`

### Étape 2 : L'admin crée le stand
1. L'admin se connecte sur `/admin/login`
2. L'admin va sur `/admin/markets`
3. L'admin crée un marché s'il n'existe pas encore
4. L'admin associe le trader au marché :
   - Clique sur "🍗 Gérer les stands" pour un marché
   - Sélectionne le trader dans la liste
   - Clique sur "Associer"

**Note** : Actuellement, l'interface admin ne permet pas de créer un nouveau vendor. Il faut le faire via SQL (voir Méthode 3).

### Étape 3 : Le trader configure son stand
1. Le trader se connecte sur `/trader/login`
2. Il est redirigé vers `/trader/home`
3. S'il a un stand, il peut :
   - Aller sur `/trader/orders?stand=STAND_ID` pour configurer le stand
   - Remplir le formulaire avec :
     - Nom du stand
     - Description
     - Emplacement (ex: "Allée 6")

## 🎯 Méthode 2 : Par le trader lui-même (à implémenter)

Actuellement, un trader ne peut pas créer son propre stand via l'interface. Il faut qu'un admin le crée d'abord.

**Suggestion d'amélioration** : Ajouter un bouton "Créer mon premier stand" sur `/trader/home` qui permet de :
1. Créer un vendor avec le `profile_id` du trader
2. Optionnellement associer à un marché
3. Rediriger vers la configuration du stand

## 🎯 Méthode 3 : Via SQL (pour les admins techniques)

### Créer un stand pour un trader existant

```sql
-- 1. Trouver le profile_id du trader
SELECT id, email, role 
FROM profiles 
WHERE email = 'trader@example.com' AND role = 'vendor';

-- 2. Créer un vendor (stand) pour ce trader
INSERT INTO vendors (profile_id, market_id, location)
VALUES (
  'PROFILE_ID_DU_TRADER',  -- UUID du profil
  'MARKET_ID_OPTIONNEL',   -- UUID du marché (peut être NULL)
  'Allée 6'                -- Emplacement dans le marché
)
RETURNING id;

-- 3. Mettre à jour le profil avec le nom et la description du stand
UPDATE profiles
SET 
  stand_nom = 'Nom du Stand',
  stand_description = 'Description du stand'
WHERE id = 'PROFILE_ID_DU_TRADER';
```

### Créer un stand complet (profil + vendor)

```sql
-- 1. Créer le profil
INSERT INTO profiles (email, role, stand_nom, stand_description)
VALUES (
  'nouveau-trader@example.com',
  'vendor',
  'Nom du Stand',
  'Description du stand'
)
RETURNING id;

-- 2. Créer le vendor (stand)
INSERT INTO vendors (profile_id, market_id, location)
VALUES (
  'ID_DU_PROFIL_CREE',  -- Utiliser l'ID retourné ci-dessus
  'MARKET_ID_OPTIONNEL',
  'Allée 6'
)
RETURNING id;
```

### Créer plusieurs stands pour le même trader (différents marchés)

```sql
-- Un trader peut avoir plusieurs stands dans différents marchés
INSERT INTO vendors (profile_id, market_id, location)
VALUES 
  ('PROFILE_ID', 'MARKET_1_ID', 'Allée 6'),
  ('PROFILE_ID', 'MARKET_2_ID', 'Allée 12'),
  ('PROFILE_ID', 'MARKET_3_ID', 'Allée 3');
```

## 🔍 Vérifier qu'un stand existe

```sql
-- Voir tous les stands d'un trader
SELECT 
  v.id as vendor_id,
  v.location,
  v.market_id,
  p.email,
  p.stand_nom,
  p.stand_description,
  m.name as market_name,
  m.place as market_place
FROM vendors v
JOIN profiles p ON v.profile_id = p.id
LEFT JOIN markets m ON v.market_id = m.id
WHERE p.email = 'trader@example.com';

-- Voir tous les stands sans marché
SELECT 
  v.id,
  p.email,
  p.stand_nom,
  v.location
FROM vendors v
JOIN profiles p ON v.profile_id = p.id
WHERE v.market_id IS NULL;
```

## ⚠️ Notes importantes

1. **Un trader peut avoir plusieurs stands** : Chaque stand est dans un marché différent
2. **Le nom du stand est dans `profiles.stand_nom`** : Tous les stands d'un même trader partagent le même nom (car ils représentent le même commerçant)
3. **L'emplacement est dans `vendors.location`** : Chaque stand a son propre emplacement dans son marché
4. **Un stand peut exister sans marché** : `market_id` peut être `NULL`
5. **Contrainte unique** : Un trader ne peut avoir qu'un seul stand par marché (`UNIQUE (profile_id, market_id)`)

## 🗄️ Structure de la base de données

### Table `profiles`
- `id` : UUID du profil
- `email` : Email du trader
- `role` : 'vendor' ou 'admin'
- `stand_nom` : Nom du stand (partagé par tous les stands du trader)
- `stand_description` : Description du stand

### Table `vendors`
- `id` : UUID du stand
- `profile_id` : Référence vers `profiles.id`
- `market_id` : Référence vers `markets.id` (peut être NULL)
- `location` : Emplacement du stand dans le marché (ex: "Allée 6")
- `is_available` : Si le stand est disponible

### Table `markets`
- `id` : UUID du marché
- `name` : Nom du marché
- `place` : Lieu du marché
- `days` : Jours de marché (array: ['monday', 'wednesday'])

## ✅ Résultat attendu

Une fois le stand créé :
- Le trader peut se connecter et voir son stand sur `/trader/home`
- Le trader peut configurer le nom et la description du stand
- Le trader peut gérer ses produits et commandes
- Les utilisateurs peuvent voir le stand dans la liste des stands
- Les utilisateurs peuvent passer des commandes

## 🔧 Amélioration suggérée

Ajouter une interface pour que le trader puisse créer son premier stand directement depuis `/trader/home` :

1. Détecter si le trader n'a pas de stand
2. Afficher un bouton "Créer mon premier stand"
3. Permettre de sélectionner un marché (ou créer sans marché)
4. Créer automatiquement le vendor avec le `profile_id` du trader
5. Rediriger vers la configuration du stand







