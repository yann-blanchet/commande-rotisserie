# Comment supprimer un utilisateur Auth dans Supabase

## Méthode 1 : Via Supabase Dashboard (Le plus simple)

1. Allez dans votre projet Supabase Dashboard
2. Dans le menu de gauche, cliquez sur **"Authentication"**
3. Cliquez sur **"Users"**
4. Trouvez l'utilisateur avec l'email que vous voulez supprimer
5. Cliquez sur les **3 points** (menu) à droite de l'utilisateur
6. Cliquez sur **"Delete user"**
7. Confirmez la suppression

## Méthode 2 : Via SQL Editor

1. Allez dans **SQL Editor** dans Supabase Dashboard
2. Exécutez cette requête (remplacez l'email) :

```sql
-- Supprimer un utilisateur Auth par email
DELETE FROM auth.users 
WHERE email = 'votre-email@example.com';
```

⚠️ **Attention** : Cette méthode supprime directement depuis la base de données. Utilisez avec précaution.

## Méthode 3 : Via l'API Supabase (Programmatique)

Si vous voulez créer un script pour supprimer des utilisateurs :

```typescript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'VOTRE_SUPABASE_URL'
const supabaseServiceKey = 'VOTRE_SERVICE_ROLE_KEY' // ⚠️ Ne jamais exposer côté client

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

// Supprimer un utilisateur par email
async function deleteUserByEmail(email: string) {
  // 1. Trouver l'utilisateur
  const { data: { users }, error: listError } = await supabaseAdmin.auth.admin.listUsers()
  
  if (listError) {
    console.error('Error listing users:', listError)
    return
  }
  
  const user = users.find(u => u.email === email)
  
  if (!user) {
    console.log('User not found')
    return
  }
  
  // 2. Supprimer l'utilisateur
  const { data, error } = await supabaseAdmin.auth.admin.deleteUser(user.id)
  
  if (error) {
    console.error('Error deleting user:', error)
  } else {
    console.log('User deleted successfully')
  }
}

// Utilisation
deleteUserByEmail('votre-email@example.com')
```

## Méthode 4 : Supprimer aussi le vendor associé

Si vous voulez supprimer complètement un commerçant (vendor + user) :

```sql
-- Trouver le vendor_id associé à l'email
SELECT id FROM vendors WHERE email = 'votre-email@example.com';

-- Supprimer le vendor (cela supprimera aussi les commandes associées si CASCADE est configuré)
DELETE FROM vendors WHERE email = 'votre-email@example.com';

-- Supprimer l'utilisateur Auth
DELETE FROM auth.users WHERE email = 'votre-email@example.com';
```

## Après suppression

Une fois l'utilisateur supprimé :
1. Vous pouvez réutiliser le même email pour vous enregistrer
2. Un nouveau vendor sera créé
3. Un nouvel utilisateur Auth sera créé

## Note importante

- La suppression d'un utilisateur Auth ne supprime **pas** automatiquement le vendor dans la table `vendors`
- Si vous voulez tout supprimer, supprimez d'abord le vendor, puis l'utilisateur Auth
- Les commandes associées au vendor seront supprimées si vous avez configuré `ON DELETE CASCADE`

