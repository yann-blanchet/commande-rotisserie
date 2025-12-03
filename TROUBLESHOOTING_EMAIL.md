# Dépannage : Ne pas recevoir l'email OTP

## Vérifications immédiates

### 1. Vérifier le format de l'email

**❌ Incorrect** : `yanblanchet+admin.gmail.com` (manque le @)  
**✅ Correct** : `yanblanchet+admin@gmail.com`

Assurez-vous que l'email contient bien un `@` avant le domaine.

### 2. Le code OTP est affiché dans l'interface

Si l'envoi d'email échoue, le code OTP est **automatiquement affiché** dans l'interface de connexion :

1. Allez sur `/admin/login`
2. Entrez votre email
3. Cliquez sur "Recevoir le code"
4. **Regardez le message affiché** - il devrait contenir le code si l'email n'a pas pu être envoyé

Le message devrait ressembler à :
```
Code OTP: 123456 (valide 10 minutes) - Email non envoyé, vérifiez votre configuration
```

### 3. Récupérer le code depuis la base de données

Si vous ne voyez pas le code dans l'interface, vous pouvez le récupérer directement depuis Supabase :

1. Allez dans **Supabase Dashboard > SQL Editor**
2. Exécutez ce script (remplacez l'email) :

```sql
SELECT 
  email,
  code,
  expires_at,
  used,
  CASE 
    WHEN expires_at < NOW() THEN 'EXPIRÉ'
    WHEN used = true THEN 'UTILISÉ'
    ELSE 'VALIDE'
  END as status
FROM otps
WHERE email = 'yanblanchet+admin@gmail.com' -- VOTRE EMAIL
ORDER BY created_at DESC
LIMIT 1;
```

## Vérifier la configuration de l'envoi d'emails

### 1. Vérifier que l'Edge Function est déployée

1. Allez dans **Supabase Dashboard > Edge Functions**
2. Vérifiez que `send-otp-email` est listée et déployée

Si elle n'est pas déployée, suivez les instructions dans `EMAIL_SETUP.md` ou `DEPLOY_EDGE_FUNCTION.md`.

### 2. Vérifier les variables d'environnement

1. Allez dans **Supabase Dashboard > Project Settings > Edge Functions**
2. Vérifiez que `RESEND_API_KEY` est configurée (si vous utilisez Resend)

### 3. Vérifier les logs de l'Edge Function

1. Allez dans **Supabase Dashboard > Edge Functions > send-otp-email > Logs**
2. Regardez les erreurs récentes

Erreurs communes :
- `RESEND_API_KEY not found` → La clé API n'est pas configurée
- `Invalid API key` → La clé API est incorrecte
- `Domain not verified` → Le domaine d'envoi n'est pas vérifié dans Resend

## Solutions rapides

### Solution 1 : Utiliser le code affiché dans l'UI (temporaire)

1. Demandez un code OTP
2. Le code sera affiché dans l'interface si l'email échoue
3. Utilisez ce code pour vous connecter

### Solution 2 : Configurer Resend (recommandé pour la production)

1. Créez un compte sur https://resend.com
2. Obtenez votre API key
3. Déployez l'Edge Function (voir `EMAIL_SETUP.md`)
4. Ajoutez `RESEND_API_KEY` dans Supabase Dashboard

### Solution 3 : Vérifier le profil dans la base de données

Assurez-vous que votre profil existe avec le bon role :

```sql
SELECT 
  id,
  email,
  role,
  created_at
FROM profiles
WHERE email = 'yanblanchet+admin@gmail.com'; -- VOTRE EMAIL
```

Le role doit être `admin` pour se connecter en tant qu'admin.

## Vérifier que tout fonctionne

### Test complet

1. **Créer le profil** (si pas déjà fait) :
   ```sql
   INSERT INTO profiles (email, role) VALUES 
     ('yanblanchet+admin@gmail.com', 'admin')
   ON CONFLICT (email) DO UPDATE SET role = 'admin';
   ```

2. **Demander un code OTP** :
   - Allez sur `/admin/login`
   - Entrez `yanblanchet+admin@gmail.com`
   - Cliquez sur "Recevoir le code"

3. **Vérifier le code** :
   - Regardez l'interface (le code devrait être affiché)
   - OU exécutez la requête SQL ci-dessus pour récupérer le code

4. **Se connecter** :
   - Entrez le code OTP
   - Vous devriez être redirigé vers `/admin/markets`

## Problèmes courants

### "Email non trouvé"

Le profil n'existe pas ou le role est incorrect. Créez-le :

```sql
INSERT INTO profiles (email, role) VALUES 
  ('yanblanchet+admin@gmail.com', 'admin')
ON CONFLICT (email) DO UPDATE SET role = 'admin';
```

### "Code expiré"

Les codes OTP expirent après 10 minutes. Demandez un nouveau code.

### "Code invalide"

Vérifiez que vous utilisez le bon code (6 chiffres) et qu'il n'a pas été utilisé.

## Mode développement

En mode développement, si l'envoi d'email n'est pas configuré, le code est toujours affiché dans l'interface. C'est normal et permet de tester sans configurer l'email.

Pour la production, configurez Resend ou un autre service d'email.








