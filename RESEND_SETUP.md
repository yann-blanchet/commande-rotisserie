# Guide de configuration Resend - Étape par étape

## Étape 1 : Créer un compte Resend

1. Allez sur **https://resend.com**
2. Cliquez sur **"Sign Up"** ou **"Get Started"**
3. Créez votre compte (email + mot de passe)
4. Vérifiez votre email

## Étape 2 : Obtenir votre clé API

1. Une fois connecté, allez dans **API Keys** (dans le menu de gauche)
2. Cliquez sur **"Create API Key"**
3. Donnez un nom à votre clé (ex: "Commande Rotisserie")
4. Sélectionnez les permissions : **"Sending access"**
5. Cliquez sur **"Add"**
6. **⚠️ IMPORTANT** : Copiez la clé API immédiatement (elle commence par `re_`). Vous ne pourrez plus la voir après !

Exemple de clé : `re_123456789abcdefghijklmnop`

## Étape 3 : Configurer un domaine (Optionnel pour les tests)

### Pour les tests (domaine Resend)
- Resend fournit un domaine de test : `onboarding@resend.dev`
- Vous pouvez l'utiliser pour tester, mais les emails iront dans les spams

### Pour la production (votre propre domaine)
1. Allez dans **Domains** dans le menu Resend
2. Cliquez sur **"Add Domain"**
3. Entrez votre domaine (ex: `votredomaine.com`)
4. Suivez les instructions pour ajouter les enregistrements DNS
5. Attendez la vérification (peut prendre quelques minutes)

## Étape 4 : Déployer la Edge Function dans Supabase

### Méthode A : Via Supabase Dashboard (Recommandé - Pas besoin de CLI)

1. **Ouvrez votre projet Supabase Dashboard**
   - Allez sur https://supabase.com/dashboard
   - Sélectionnez votre projet

2. **Créez la fonction**
   - Dans le menu de gauche, cliquez sur **"Edge Functions"**
   - Cliquez sur **"Create a new function"**
   - Nommez-la : `send-otp-email`
   - Cliquez sur **"Create function"**

3. **Copiez le code**
   - Ouvrez le fichier `supabase/functions/send-otp-email/index.ts` dans votre éditeur
   - Copiez **tout le contenu** du fichier
   - Collez-le dans l'éditeur de code dans Supabase Dashboard

4. **Modifiez l'adresse d'expéditeur**
   - Dans le code, trouvez la ligne :
     ```typescript
     from: 'Commande Rotisserie <noreply@votredomaine.com>',
     ```
   - Remplacez par :
     - Pour les tests : `'onboarding@resend.dev'`
     - Pour la production : `'noreply@votredomaine.com'` (votre domaine vérifié)

5. **Déployez**
   - Cliquez sur **"Deploy"** en haut à droite
   - Attendez quelques secondes que le déploiement se termine

### Méthode B : Via CLI (si vous avez installé Supabase CLI)

```bash
# Se connecter
supabase login

# Lier le projet
supabase link --project-ref votre-project-ref

# Déployer
supabase functions deploy send-otp-email
```

## Étape 5 : Configurer la variable d'environnement

1. Dans Supabase Dashboard, allez dans **Project Settings** (icône engrenage en bas à gauche)
2. Cliquez sur **"Edge Functions"** dans le menu
3. Dans la section **"Environment Variables"**, cliquez sur **"Add new variable"**
4. Ajoutez :
   - **Name**: `RESEND_API_KEY`
   - **Value**: Votre clé API Resend (celle qui commence par `re_`)
5. Cliquez sur **"Save"**

## Étape 6 : Tester l'envoi d'email

1. Allez sur votre application : `/trader/login`
2. Entrez un email enregistré
3. Cliquez sur **"Recevoir le code"**
4. Vérifiez votre boîte de réception (et les spams si vous utilisez le domaine de test)

## Dépannage

### L'email n'arrive pas

1. **Vérifiez les spams** - Les emails de test peuvent aller dans les spams
2. **Vérifiez la clé API** - Assurez-vous que `RESEND_API_KEY` est bien configurée
3. **Vérifiez les logs** - Dans Supabase Dashboard > Edge Functions > Logs
4. **Vérifiez Resend Dashboard** - Allez dans "Emails" pour voir l'historique

### Erreur "Function not found"

- Vérifiez que la fonction est bien déployée
- Le nom doit être exactement : `send-otp-email`

### Erreur "Unauthorized"

- Vérifiez que votre clé API Resend est correcte
- Vérifiez que la variable d'environnement est bien nommée `RESEND_API_KEY`

## Configuration finale

Une fois que tout fonctionne, modifiez l'adresse d'expéditeur dans la fonction pour utiliser votre propre domaine :

```typescript
from: 'Commande Rotisserie <noreply@votredomaine.com>',
```

Et dans `supabase/functions/send-otp-email/index.ts`, vous pouvez supprimer ou commenter la section de fallback (Option 2) si vous voulez forcer l'utilisation de Resend.









