# Architecture d'authentification recommandée

## Solution recommandée : Système hybride OTP + Supabase Auth

### Pourquoi cette approche ?

**Avantages :**
1. ✅ **Authentification simple** - Les commerçants utilisent OTP (pas de mot de passe)
2. ✅ **Sécurité** - Sessions gérées par Supabase Auth
3. ✅ **RLS efficace** - Les politiques Row Level Security peuvent filtrer par utilisateur
4. ✅ **Traçabilité** - Audit trail dans Supabase Auth
5. ✅ **Évolutif** - Facile d'ajouter des fonctionnalités Auth plus tard

**Inconvénients :**
- Légèrement plus complexe que OTP seul
- Nécessite de gérer deux systèmes (mais ils se complètent)

## Comment ça fonctionne

### 1. Enregistrement
- Crée un **vendor** dans la table `vendors`
- Crée un **utilisateur Auth** avec un mot de passe aléatoire (jamais utilisé)
- Stocke `vendor_id` dans `user_metadata`

### 2. Connexion
- L'utilisateur entre son email
- Reçoit un code OTP (6 chiffres)
- Le code est vérifié
- Une session est créée avec le `vendor_id`

### 3. Utilisation
- La session contient le `vendor_id`
- Les RLS policies peuvent filtrer par `auth.uid()`
- L'utilisateur peut gérer ses commandes

## Alternative : OTP seul (actuel)

**Avantages :**
- ✅ Plus simple
- ✅ Pas de dépendance à Supabase Auth
- ✅ Plus rapide à implémenter

**Inconvénients :**
- ❌ Pas de sessions sécurisées
- ❌ RLS moins efficace
- ❌ Pas de traçabilité centralisée
- ❌ Difficile d'ajouter des fonctionnalités Auth plus tard

## Recommandation finale

**Pour votre projet (Commande Rotisserie) :**

Je recommande le **système hybride** car :
- Vous avez déjà Supabase (pas de coût supplémentaire)
- Les RLS policies sont importantes pour la sécurité
- Vous pourriez vouloir ajouter des fonctionnalités plus tard (reset password, etc.)
- La complexité ajoutée est minime

**Si vous voulez rester simple :**
- Le système OTP seul fonctionne très bien
- Parfait pour un MVP
- Vous pouvez toujours migrer vers le système hybride plus tard

## Migration

Si vous choisissez le système hybride, le code a été mis à jour pour :
- Créer des utilisateurs Auth lors de l'enregistrement
- Garder l'OTP comme méthode d'authentification principale
- Utiliser les sessions Supabase pour la sécurité

Les utilisateurs existants continueront de fonctionner, et les nouveaux utilisateurs auront un compte Auth créé automatiquement.

