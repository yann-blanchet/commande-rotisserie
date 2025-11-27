<template>
    <div class="trader-register">
        <div class="register-card">
            <h1>🍗 Enregistrement Commerçant</h1>
            <p class="subtitle">Créez votre compte commerçant</p>

            <form @submit.prevent="handleRegister" class="register-form">
                <div class="form-group">
                    <label>Email</label>
                    <input v-model="email" type="email" required placeholder="votre@email.com" :disabled="loading" />
                    <small class="form-hint">Cet email sera utilisé pour recevoir les codes OTP. Vous créerez votre
                        stand après la connexion.</small>
                </div>

                <button type="submit" class="btn-primary" :disabled="loading || !email">
                    {{ loading ? 'Enregistrement...' : 'S\'enregistrer' }}
                </button>
            </form>

            <div v-if="success" class="success-message">
                ✅ Email enregistré avec succès ! Vous pouvez maintenant vous connecter.
                <router-link to="/trader/login" class="login-link">Se connecter</router-link>
            </div>

            <div v-if="error" class="error-message">
                {{ error }}
            </div>

            <div class="register-footer">
                <p>Déjà enregistré ?</p>
                <router-link to="/trader/login" class="login-link">Se connecter</router-link>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { supabase, isOnline } from '../lib/supabase'

const email = ref('')
const loading = ref(false)
const error = ref('')
const success = ref(false)

const handleRegister = async () => {
    if (!email.value.trim()) {
        error.value = 'Veuillez entrer votre email'
        return
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(email.value.trim())) {
        error.value = 'Veuillez entrer un email valide'
        return
    }

    loading.value = true
    error.value = ''
    success.value = false

    try {
        if (!isOnline()) {
            error.value = 'Vous devez être en ligne pour vous enregistrer'
            loading.value = false
            return
        }

        // Check if email is already registered
        const { data: existingVendor, error: checkError } = await supabase
            .from('vendors')
            .select('id, email')
            .eq('email', email.value.toLowerCase().trim())
            .single()

        if (checkError && checkError.code !== 'PGRST116') { // PGRST116 = no rows returned
            throw checkError
        }

        if (existingVendor) {
            error.value = 'Cet email est déjà enregistré. Vous pouvez vous connecter directement. Si vous voulez réinitialiser, supprimez d\'abord l\'utilisateur dans Supabase Dashboard > Authentication > Users.'
            loading.value = false
            return
        }

        // Create a temporary vendor entry with just the email
        // The vendor will complete their profile after login
        const { data: newVendor, error: createError } = await supabase
            .from('vendors')
            .insert({
                email: email.value.toLowerCase().trim(),
                nom: 'Stand à configurer',
                description: 'Stand en attente de configuration'
            })
            .select()
            .single()

        if (createError) {
            console.error('Create vendor error:', createError)
            throw createError
        }

        if (!newVendor) {
            error.value = 'Erreur lors de la création du compte'
            loading.value = false
            return
        }

        // Create user in Supabase Auth (with random password - they'll use OTP)
        // This allows us to use RLS policies and have proper user management
        const randomPassword = Math.random().toString(36).slice(-16) + Math.random().toString(36).slice(-16) + 'A1!'
        const { error: authError } = await supabase.auth.signUp({
            email: email.value.toLowerCase().trim(),
            password: randomPassword, // User won't use this - they use OTP
            options: {
                data: {
                    vendor_id: newVendor.id,
                    role: 'trader',
                    email_verified: false // Will be verified via OTP
                },
                emailRedirectTo: undefined // No email confirmation needed
            }
        })

        // Handle auth creation errors
        if (authError) {
            if (authError.message.includes('already registered') || authError.message.includes('User already registered')) {
                // User already exists in Auth - that's okay, vendor is created
                console.log('User already exists in Auth (non-blocking)')
            } else {
                // Other error - log but continue (vendor is created, OTP will work)
                console.warn('Auth user creation warning (non-blocking):', authError.message)
            }
        }

        success.value = true
        // Reset form after 2 seconds and redirect
        setTimeout(() => {
            email.value = ''
            // Redirect to login
            window.location.href = '/trader/login'
        }, 2000)
    } catch (err: any) {
        console.error('Error registering:', err)
        error.value = err.message || 'Erreur lors de l\'enregistrement'
    } finally {
        loading.value = false
    }
}
</script>

<style scoped>
.trader-register {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    padding: 20px;
}

.register-card {
    background: white;
    border-radius: 12px;
    padding: 40px;
    max-width: 500px;
    width: 100%;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
}

.register-card h1 {
    text-align: center;
    margin-bottom: 10px;
    font-size: 2rem;
}

.subtitle {
    text-align: center;
    color: #666;
    margin-bottom: 30px;
}

.register-form {
    display: flex;
    flex-direction: column;
    gap: 20px;
}

.form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.form-group label {
    font-weight: 600;
    color: #333;
}

.form-group input,
.vendor-select {
    padding: 12px;
    border: 1px solid #ddd;
    border-radius: 8px;
    font-size: 1rem;
}


.form-hint {
    color: #666;
    font-size: 0.85rem;
    margin-top: -5px;
}

.btn-primary {
    padding: 12px;
    background: #ff6b35;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    cursor: pointer;
    font-weight: 600;
    margin-top: 10px;
}

.btn-primary:hover:not(:disabled) {
    background: #e55a2b;
}

.btn-primary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.success-message {
    margin-top: 20px;
    padding: 15px;
    background: #d4edda;
    color: #155724;
    border-radius: 8px;
    text-align: center;
}

.success-message .login-link {
    display: block;
    margin-top: 10px;
    color: #155724;
    font-weight: 600;
    text-decoration: underline;
}

.error-message {
    margin-top: 20px;
    padding: 12px;
    background: #fee;
    color: #c33;
    border-radius: 8px;
    text-align: center;
}

.register-footer {
    margin-top: 30px;
    text-align: center;
    padding-top: 20px;
    border-top: 1px solid #eee;
}

.register-footer p {
    color: #666;
    margin-bottom: 10px;
}

.login-link {
    color: #667eea;
    font-weight: 600;
    text-decoration: none;
}

.login-link:hover {
    text-decoration: underline;
}
</style>
