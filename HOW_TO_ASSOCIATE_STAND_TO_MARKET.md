# Comment associer un stand à un marché

## 📋 Vue d'ensemble

L'admin peut associer des stands aux marchés depuis la page de gestion des marchés.

## 🎯 Étapes pour associer un stand à un marché

### 1. Se connecter en tant qu'admin
- Allez sur `/admin/login`
- Connectez-vous avec votre code OTP

### 2. Accéder à la gestion des marchés
- Allez sur `/admin/markets`
- Vous verrez la liste de tous les marchés

### 3. Gérer les stands d'un marché
- Pour chaque marché, cliquez sur le bouton **"🍗 Gérer les stands"**
- Un modal s'ouvre avec :
  - La liste des stands disponibles
  - Les stands déjà associés à ce marché

### 4. Associer un stand
- Dans le menu déroulant, sélectionnez un stand
- Cliquez sur **"Associer"**
- Le stand est maintenant associé au marché

### 5. Retirer un stand
- Dans la liste des stands associés, cliquez sur **"Retirer"**
- Le stand est retiré du marché (mais n'est pas supprimé)

## 🔍 Informations affichées

### Sur la carte du marché
- **Stands associés** : Liste des stands déjà associés à ce marché
- Si aucun stand n'est associé : "Aucun stand"

### Dans le modal de gestion
- **Stands disponibles** : Tous les stands qui peuvent être associés
- **Stands déjà dans un autre marché** : Indiqués avec "(déjà dans un autre marché)"
- **Stands associés** : Liste des stands actuellement dans ce marché

## ⚠️ Notes importantes

1. **Un stand peut être dans un seul marché à la fois**
   - Si vous associez un stand à un nouveau marché, il sera automatiquement retiré de l'ancien

2. **Les stands sans nom ne sont pas listés**
   - Seuls les stands configurés (avec un nom) apparaissent dans la liste

3. **Un stand peut ne pas avoir de marché**
   - Un stand peut exister sans être associé à un marché
   - Dans ce cas, le vendeur verra "Aucun marché associé" dans le formulaire d'édition

## 🗄️ Structure de la base de données

- **Table `vendors`** : Contient le champ `market_id` qui référence `markets.id`
- **Table `markets`** : Contient les informations du marché (nom, lieu, jours)

## 🔧 Via SQL (pour les admins techniques)

Si vous préférez associer un stand à un marché directement en SQL :

```sql
-- Associer un stand à un marché
UPDATE vendors
SET market_id = 'UUID_DU_MARCHE'
WHERE id = 'UUID_DU_STAND';

-- Retirer un stand d'un marché
UPDATE vendors
SET market_id = NULL
WHERE id = 'UUID_DU_STAND';

-- Voir tous les stands avec leurs marchés
SELECT 
  v.id,
  v.nom,
  m.name as market_name,
  m.place as market_place
FROM vendors v
LEFT JOIN markets m ON v.market_id = m.id
ORDER BY m.name, v.nom;
```

## ✅ Résultat

Une fois un stand associé à un marché :
- Le vendeur verra les informations du marché dans le formulaire d'édition de son stand
- Les utilisateurs verront le lieu du marché sur la page du stand
- La date de livraison sera calculée automatiquement selon les jours du marché








