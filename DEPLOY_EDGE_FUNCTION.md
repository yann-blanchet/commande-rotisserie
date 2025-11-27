# Déployer la Edge Function sans Supabase CLI

Si vous ne pouvez pas installer Supabase CLI, voici des alternatives pour déployer la fonction d'envoi d'email.

## Option 1 : Via Supabase Dashboard (Le plus simple)

### 1. Créer la fonction dans le Dashboard

1. Allez dans votre projet Supabase Dashboard
2. Cliquez sur **Edge Functions** dans le menu de gauche
3. Cliquez sur **Create a new function**
4. Nommez-la `send-otp-email`

### 2. Copier le code

1. Ouvrez le fichier `supabase/functions/send-otp-email/index.ts`
2. Copiez tout le contenu
3. Collez-le dans l'éditeur de la fonction dans le Dashboard
4. Cliquez sur **Deploy**

### 3. Configurer les variables d'environnement

1. Dans **Project Settings > Edge Functions**
2. Ajoutez la variable :
   - **Key**: `RESEND_API_KEY`
   - **Value**: Votre clé API Resend

## Option 2 : Utiliser npx (sans installation)

Vous pouvez utiliser Supabase CLI via npx sans l'installer :

```bash
# Se connecter
npx supabase login

# Lier le projet (vous aurez besoin du project ref)
npx supabase link --project-ref votre-project-ref

# Déployer la fonction
npx supabase functions deploy send-otp-email
```

## Option 3 : Utiliser l'API Supabase directement

Si vous ne pouvez pas utiliser les Edge Functions, vous pouvez modifier le code pour appeler directement l'API Resend depuis le client (moins sécurisé) ou créer un endpoint backend.

### Modification du service OTP

Dans `src/services/otpService.ts`, vous pouvez appeler directement Resend depuis le client si vous utilisez une clé API publique (non recommandé pour la production) :

```typescript
// ⚠️ ATTENTION : Ne faites cela que pour le développement
// En production, utilisez toujours une Edge Function
const resendResponse = await fetch('https://api.resend.com/emails', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${import.meta.env.VITE_RESEND_API_KEY}`,
  },
  body: JSON.stringify({
    from: 'Commande Rotisserie <noreply@votredomaine.com>',
    to: [email],
    subject: 'Votre code OTP',
    html: `...`
  })
})
```

**⚠️ Important** : Exposer votre clé API Resend dans le client n'est pas sécurisé. Utilisez cette méthode uniquement pour le développement.

## Option 4 : Utiliser un service backend externe

Créez un endpoint simple (Node.js, Python, etc.) qui envoie les emails et appelez-le depuis votre application.

## Recommandation

**Utilisez l'Option 1 (Dashboard)** - C'est la plus simple et ne nécessite aucune installation.

