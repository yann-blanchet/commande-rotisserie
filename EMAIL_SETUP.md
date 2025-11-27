# Configuration de l'envoi d'emails OTP

## Pourquoi utiliser Resend ?

Resend est recommandé pour plusieurs raisons :

### ✅ Avantages de Resend
- **Gratuit** : 100 emails/jour gratuitement (suffisant pour démarrer)
- **Simple** : API moderne et intuitive, documentation claire
- **Rapide** : Envoi d'emails en quelques millisecondes
- **Fiable** : Infrastructure robuste, taux de délivrabilité élevé
- **Moderne** : Conçu pour les développeurs, support React Email
- **Pas de carte bancaire** : Pour le plan gratuit

### Alternatives disponibles

Vous pouvez aussi utiliser :
- **Supabase Auth Email** : Intégré, mais nécessite configuration de templates
- **SendGrid** : Plus d'options, mais plus complexe
- **Mailgun** : Bon pour les volumes importants
- **AWS SES** : Économique à grande échelle, mais configuration plus complexe
- **Postmark** : Excellent pour les emails transactionnels

## Option 1: Utiliser Resend (Recommandé)

### 1. Créer un compte Resend
1. Allez sur https://resend.com
2. Créez un compte gratuit (100 emails/jour gratuits)
3. Obtenez votre API key dans **API Keys**

### 2. Installer Supabase CLI (si pas déjà installé)

**Option A : Via Homebrew (Recommandé sur macOS)**
```bash
brew install supabase/tap/supabase
```

**Option B : Via npx (sans installation globale)**
```bash
# Pas besoin d'installer, utilisez directement :
npx supabase --version
```

**Option C : Via npm (si vous avez configuré npm pour les packages globaux)**
```bash
# Si vous avez des problèmes de permissions, configurez d'abord :
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH=~/.npm-global/bin:$PATH

# Puis installez :
npm install -g supabase
```

**Option D : Via npm avec sudo (non recommandé)**
```bash
sudo npm install -g supabase
```

### 3. Déployer la Edge Function

1. Connectez-vous à Supabase :
   ```bash
   supabase login
   ```

2. Liez votre projet :
   ```bash
   supabase link --project-ref votre-project-ref
   ```

3. Déployez la fonction :
   ```bash
   supabase functions deploy send-otp-email
   ```

### 4. Ajouter la clé API Resend

1. Dans Supabase Dashboard, allez dans **Project Settings > Edge Functions**
2. Ajoutez la variable d'environnement :
   - Key: `RESEND_API_KEY`
   - Value: Votre clé API Resend (commence par `re_`)

### 5. Configurer le domaine d'envoi

Dans Resend Dashboard :
- Allez dans **Domains**
- Ajoutez et vérifiez votre domaine
- Ou utilisez le domaine de test `onboarding@resend.dev` pour les tests

### 6. Modifier l'adresse d'expéditeur

Dans `supabase/functions/send-otp-email/index.ts`, modifiez :
```typescript
from: 'Commande Rotisserie <noreply@votredomaine.com>',
```
Remplacez par votre domaine vérifié dans Resend.

## Option 2: Utiliser Supabase Auth Email (Gratuit, intégré)

Supabase inclut un service d'email gratuit, mais il est limité et nécessite plus de configuration.

### Avantages
- ✅ Gratuit et intégré à Supabase
- ✅ Pas besoin de service externe
- ✅ Fonctionne directement

### Inconvénients
- ❌ Limité à 3 emails/jour en gratuit
- ❌ Configuration des templates plus complexe
- ❌ Moins de contrôle sur le design

### Configuration

1. Dans Supabase Dashboard, allez dans **Authentication > Email Templates**
2. Créez un template personnalisé pour l'OTP
3. Modifiez la Edge Function pour utiliser `supabase.auth.admin.generateLink()` ou créez un trigger database

### Modifier la Edge Function

Remplacez la section Resend dans `supabase/functions/send-otp-email/index.ts` par :

```typescript
// Utiliser Supabase Auth pour envoyer l'email
const { data, error } = await supabase.auth.admin.inviteUserByEmail(email, {
  data: { otp_code: code }
})
```

**Note** : Cette méthode nécessite une configuration supplémentaire et est moins flexible que Resend.

## Option 3: Utiliser un autre service (SendGrid, Mailgun, etc.)

### SendGrid
- **Gratuit** : 100 emails/jour
- **Avantages** : Très populaire, beaucoup de documentation
- **Inconvénients** : Interface plus complexe, nécessite vérification de domaine

### Mailgun
- **Gratuit** : 100 emails/jour (premiers 3 mois), puis payant
- **Avantages** : Excellent pour les volumes importants
- **Inconvénients** : Plus cher après la période gratuite

### AWS SES
- **Gratuit** : 62 000 emails/mois (si hébergé sur AWS)
- **Avantages** : Très économique à grande échelle
- **Inconvénients** : Configuration complexe, nécessite compte AWS

### Comment changer

Modifiez la section Resend dans `supabase/functions/send-otp-email/index.ts` pour utiliser l'API de votre service préféré. La structure reste similaire : un appel HTTP POST avec votre clé API.

## Test

Une fois configuré, testez l'envoi d'email :
1. Allez sur `/trader/login`
2. Entrez un email enregistré
3. Cliquez sur "Recevoir le code"
4. Vérifiez votre boîte de réception

## Mode développement

Si l'envoi d'email échoue, le code OTP sera affiché dans l'interface pour faciliter le développement.

