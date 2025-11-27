# Guide de Configuration

## 1. Configuration Supabase

### Créer les tables

1. Allez dans votre projet Supabase
2. Ouvrez l'éditeur SQL
3. Exécutez le contenu du fichier `supabase-migration.sql`

### Authentification OTP pour les commerçants

Les commerçants utilisent maintenant un système d'authentification par code OTP à 6 chiffres:

1. Le commerçant entre son **email** (qui doit être associé à un stand dans la table `vendors`)
2. Un code OTP à 6 chiffres est généré et stocké dans la table `trader_otps`
3. Le code est valide pendant 10 minutes
4. Le commerçant entre le code pour se connecter

**Important:** Chaque stand doit avoir un email unique dans la table `vendors`. Assurez-vous d'ajouter le champ `email` lors de la création des stands.

**Note:** En développement, le code OTP est affiché directement dans l'interface. En production, vous devriez:
- Envoyer le code par SMS (via un service comme Twilio)
- Ou envoyer le code par email (via Supabase Edge Functions ou un service externe)

Pour implémenter l'envoi par SMS/Email, modifiez la fonction `requestOTP` dans `src/services/otpService.ts`.

## 2. Variables d'environnement

Créez un fichier `.env` à la racine du projet:

```env
VITE_SUPABASE_URL=https://votre-projet.supabase.co
VITE_SUPABASE_ANON_KEY=votre-cle-anonyme
```

Vous trouverez ces valeurs dans:
- Supabase Dashboard > Settings > API

## 3. Installation et lancement

```bash
# Installer les dépendances
npm install

# Lancer en développement
npm run dev

# Build pour production
npm run build
```

## 4. Test de l'application

### Côté client (sans authentification)
1. Accédez à `http://localhost:5173`
2. Vous devriez voir la liste des stands
3. Cliquez sur un stand pour voir les produits
4. Créez une commande (fonctionne même hors ligne)

### Enregistrement d'un commerçant

**Première utilisation :**
1. Cliquez sur "Espace commerçant"
2. Cliquez sur "S'enregistrer" (ou allez sur `/trader/register`)
3. Entrez votre email
4. Cliquez sur "S'enregistrer"
5. Un stand temporaire est créé avec votre email
6. Après la connexion, vous devrez configurer votre stand (nom, description, emplacement)

### Connexion d'un commerçant (avec authentification OTP)
1. Cliquez sur "Espace commerçant"
2. Entrez votre **email** (ex: `stand1@marche.com`)
3. Cliquez sur "Recevoir le code" - un code OTP à 6 chiffres sera généré
4. Entrez le code OTP (affiché à l'écran en développement)
5. **Si c'est votre première connexion** : Vous devrez configurer votre stand (nom, description, emplacement)
6. **Sinon** : Vous verrez la liste des commandes pour votre stand
7. Vous pouvez marquer les commandes comme "retirées"

## 5. Test du mode offline

1. Ouvrez les DevTools (F12)
2. Allez dans Network > Throttling
3. Sélectionnez "Offline"
4. Créez une commande - elle sera sauvegardée localement
5. Remettez la connexion - la commande sera synchronisée automatiquement

## 6. Installation PWA

1. Build l'application: `npm run build`
2. Ouvrez `dist/index.html` dans un navigateur
3. Sur mobile, vous verrez une option "Ajouter à l'écran d'accueil"
4. Sur desktop, l'icône d'installation apparaîtra dans la barre d'adresse

## Notes importantes

- Les commandes créées hors ligne sont automatiquement synchronisées quand la connexion revient
- Les stands et produits sont mis en cache après la première visite
- Les commerçants peuvent gérer leurs commandes même sans connexion
- Assurez-vous que les RLS (Row Level Security) sont correctement configurées dans Supabase

