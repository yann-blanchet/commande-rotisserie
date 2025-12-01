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

            <div v-if="success && !error" class="success-message">
                ✅ Email enregistré avec succès ! Vous pouvez maintenant vous connecter.
                <router-link to="/trader/login" class="login-link">Se connecter</router-link>
            </div>

            <div v-if="error" class="error-message">
                <strong>❌ Erreur :</strong><br>
                {{ error }}
                <br><br>
                <small>Veuillez vérifier vos informations et réessayer. Si le problème persiste, contactez le support.</small>
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

        // Check if email is already registered in profiles
        const { data: existingProfile, error: checkError } = await supabase
            .from('profiles')
            .select('id, email, role')
            .eq('email', email.value.toLowerCase().trim())
            .single()

        if (checkError && checkError.code !== 'PGRST116') { // PGRST116 = no rows returned
            throw checkError
        }

        if (existingProfile) {
            error.value = 'Cet email est déjà enregistré. Vous pouvez vous connecter directement.'
            loading.value = false
            return
        }

        // Create profile with role 'vendor'
        // Note: stand_nom and stand_description will be set later when the trader configures their stand
        const { data: newProfile, error: profileError } = await supabase
            .from('profiles')
            .insert({
                email: email.value.toLowerCase().trim(),
                role: 'vendor',
                stand_nom: null, // Will be set when trader configures their stand
                stand_description: null // Will be set when trader configures their stand
            })
            .select()
            .single()

        if (profileError) {
            console.error('Create profile error:', profileError)
            throw profileError
        }

        if (!newProfile) {
            error.value = 'Erreur lors de la création du compte'
            loading.value = false
            return
        }

        // Note: No vendor is created at registration time
        // The vendor/stand will be created later when:
        // 1. An admin associates the trader's profile to a market
        // 2. Or the trader logs in and sets up their stand

        success.value = true
        // Reset form after 3 seconds and redirect (give time to see success message)
        setTimeout(() => {
            // Only redirect if still successful (no error occurred)
            if (success.value && !error.value) {
                email.value = ''
                // Redirect to login
                window.location.href = '/trader/login'
            }
        }, 3000)
    } catch (err: any) {
        console.error('Error registering:', err)
        // Ensure success is false if there's an error
        success.value = false
        
        // Provide more detailed error messages
        let errorMessage = 'Erreur lors de l\'enregistrement'
        if (err.message) {
            errorMessage = err.message
        } else if (err.code) {
            errorMessage = `Erreur ${err.code}: ${err.message || 'Erreur inconnue'}`
        }
        
        // Add more context for common errors
        if (err.code === '23505') { // Unique constraint violation
            errorMessage = 'Cet email est déjà enregistré. Vous pouvez vous connecter directement.'
        } else if (err.code === '23503') { // Foreign key violation
            errorMessage = 'Erreur de référence dans la base de données. Veuillez contacter le support.'
        } else if (err.code === '42501') { // Insufficient privilege
            errorMessage = 'Erreur de permissions. Veuillez contacter le support.'
        }
        
        error.value = errorMessage
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
    background: linear-gradient(135deg, var(--color-secondary) 0%, var(--color-secondary-gradient-end) 100%);
    padding: 20px;
}

.register-card {
    background: var(--color-bg-white);
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
    color: var(--color-text-secondary);
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
    color: var(--color-text-primary);
}

.form-group input,
.vendor-select {
    padding: 12px;
    border: 1px solid var(--color-border-medium);
    border-radius: 8px;
    font-size: 1rem;
}


.form-hint {
    color: var(--color-text-secondary);
    font-size: 0.85rem;
    margin-top: -5px;
}

.btn-primary {
    padding: 12px;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    cursor: pointer;
    font-weight: 600;
    margin-top: 10px;
}

.btn-primary:hover:not(:disabled) {
    background: var(--color-primary-hover);
}

.btn-primary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.success-message {
    margin-top: 20px;
    padding: 15px;
    background: var(--color-success-light);
    color: var(--color-success-dark);
    border-radius: 8px;
    text-align: center;
}

.success-message .login-link {
    display: block;
    margin-top: 10px;
    color: var(--color-success-dark);
    font-weight: 600;
    text-decoration: underline;
}

.error-message {
    margin-top: 20px;
    padding: 15px;
    background: var(--color-error-light);
    color: var(--color-error-text);
    border-radius: 8px;
    text-align: center;
    border: 2px solid var(--color-error);
    font-size: 0.95rem;
    line-height: 1.5;
}

.error-message strong {
    display: block;
    margin-bottom: 8px;
    font-size: 1.1rem;
}

.error-message small {
    display: block;
    margin-top: 10px;
    opacity: 0.8;
    font-size: 0.85rem;
}

.register-footer {
    margin-top: 30px;
    text-align: center;
    padding-top: 20px;
    border-top: 1px solid var(--color-border-light);
}

.register-footer p {
    color: var(--color-text-secondary);
    margin-bottom: 10px;
}

.login-link {
    color: var(--color-secondary);
    font-weight: 600;
    text-decoration: none;
}

.login-link:hover {
    text-decoration: underline;
}
</style>
