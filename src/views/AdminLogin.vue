<template>
  <div class="admin-login">
    <div class="login-card">
      <h1>🔐 Connexion Admin</h1>
      <p class="subtitle">Connectez-vous avec votre code OTP</p>

      <!-- Step 1: Request OTP -->
      <div v-if="step === 'request'" class="login-form">
        <div class="form-group">
          <label>Email admin</label>
          <input v-model="email" type="email" required placeholder="admin@example.com" :disabled="loading" />
        </div>
        <button @click="requestCode" class="btn-primary" :disabled="loading || !email">
          {{ loading ? 'Envoi...' : 'Recevoir le code' }}
        </button>
      </div>

      <!-- Step 2: Verify OTP -->
      <div v-if="step === 'verify'" class="login-form">
        <div class="otp-info">
          <p>Code envoyé à: <strong>{{ email }}</strong></p>
          <p class="otp-hint">{{ otpMessage }}</p>
          <div v-if="otpMessage.includes('Code OTP:')" class="otp-code-display">
            <div class="dev-warning-header">
              <span>⚠️</span>
              <span>Mode développement</span>
            </div>
            <div class="dev-warning-text">Email non configuré - Code affiché ci-dessous</div>
            <div class="otp-code-value">
              {{ extractOTPCode(otpMessage) }}
            </div>
          </div>
        </div>
        <div class="form-group">
          <label>Code OTP (6 chiffres)</label>
          <input v-model="otpCode" type="text" required maxlength="6" pattern="[0-9]{6}" placeholder="000000"
            class="otp-input" :disabled="loading" @input="formatOTP" @keyup.enter="verifyCode" />
        </div>
        <div class="form-actions">
          <button @click="step = 'request'" class="btn-secondary" :disabled="loading">
            Retour
          </button>
          <button @click="verifyCode" class="btn-primary" :disabled="loading || otpCode.length !== 6">
            {{ loading ? 'Vérification...' : 'Se connecter' }}
          </button>
        </div>
      </div>

      <div v-if="error" class="error-message">
        {{ error }}
      </div>

      <div class="login-footer">
        <p>Pas encore enregistré ?</p>
        <router-link to="/admin/register" class="register-link">S'enregistrer</router-link>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { unifiedOtpService } from '../services/unifiedOtpService'

const router = useRouter()
const step = ref<'request' | 'verify'>('request')
const email = ref('')
const otpCode = ref('')
const otpMessage = ref('')
const loading = ref(false)
const error = ref('')

const formatOTP = () => {
  // Only allow numbers
  otpCode.value = otpCode.value.replace(/\D/g, '').slice(0, 6)
}

const extractOTPCode = (message: string): string => {
  const match = message.match(/Code OTP:\s*(\d{6})/)
  return match ? (match[1] || '') : ''
}

const requestCode = async () => {
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
  otpMessage.value = ''

  const result = await unifiedOtpService.requestOTP(email.value.trim(), 'admin')

  if (result.success) {
    otpMessage.value = result.message
    step.value = 'verify'
    otpCode.value = ''
  } else {
    error.value = result.message
    // Si l'email n'est pas trouvé, suggérer l'enregistrement
    if (result.message.includes('non trouvé') || result.message.includes('autorisé')) {
      error.value = result.message + ' Vous pouvez vous enregistrer ci-dessous.'
    }
  }

  loading.value = false
}

const verifyCode = async () => {
  if (otpCode.value.length !== 6) {
    error.value = 'Le code doit contenir 6 chiffres'
    return
  }

  loading.value = true
  error.value = ''

  const result = await unifiedOtpService.verifyOTP(email.value.trim(), otpCode.value, 'admin')

  if (result.success) {
    // Store admin session
    localStorage.setItem('admin_session', JSON.stringify({
      email: email.value.trim(),
      authenticated: true,
      authenticated_at: new Date().toISOString()
    }))
    router.push('/admin/markets')
  } else {
    error.value = result.message
  }

  loading.value = false
}
</script>

<style scoped>
.admin-login {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--color-secondary) 0%, var(--color-secondary-gradient-end) 100%);
  padding: 20px;
}

.login-card {
  background: var(--color-bg-white);
  border-radius: 12px;
  padding: 40px;
  max-width: 400px;
  width: 100%;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
}

.login-card h1 {
  text-align: center;
  margin-bottom: 10px;
  font-size: 2rem;
}

.subtitle {
  text-align: center;
  color: var(--color-text-secondary);
  margin-bottom: 30px;
}

.login-form {
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

.form-group input {
  padding: 12px;
  border: 1px solid var(--color-border-medium);
  border-radius: 8px;
  font-size: 1rem;
}

.otp-input {
  font-size: 1.5rem;
  text-align: center;
  letter-spacing: 0.5rem;
  font-weight: 600;
}

.otp-info {
  background: var(--color-info-light);
  padding: 15px;
  border-radius: 8px;
  margin-bottom: 20px;
}

.otp-info p {
  margin: 5px 0;
  color: var(--color-text-primary);
}

.otp-hint {
  font-size: 0.9rem;
  color: var(--color-text-secondary);
  font-style: italic;
}

.otp-code-display {
  margin-top: 15px;
  padding: 15px;
  background: var(--color-warning-light);
  border: 1px solid var(--color-warning);
  border-radius: 8px;
}

.dev-warning-header {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: bold;
  color: var(--color-warning-dark);
  margin-bottom: 8px;
  font-size: 0.95rem;
}

.dev-warning-text {
  font-size: 0.85rem;
  color: var(--color-warning-dark);
  margin-bottom: 12px;
}

.otp-code-value {
  font-size: 1.8rem;
  font-weight: bold;
  text-align: center;
  color: var(--color-warning-dark);
  letter-spacing: 8px;
  background: var(--color-bg-white);
  padding: 12px;
  border-radius: 6px;
  border: 2px dashed var(--color-warning);
}

.form-actions {
  display: flex;
  gap: 10px;
  margin-top: 10px;
}

.btn-secondary {
  flex: 1;
  padding: 12px;
  background: var(--color-bg-gray);
  color: var(--color-text-primary);
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  font-weight: 600;
}

.btn-secondary:hover:not(:disabled) {
  background: var(--color-bg-gray-hover);
}

.btn-secondary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
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

.error-message {
  margin-top: 20px;
  padding: 12px;
  background: var(--color-error-light);
  color: var(--color-error-text);
  border-radius: 8px;
  text-align: center;
}

.login-footer {
  margin-top: 30px;
  text-align: center;
  padding-top: 20px;
  border-top: 1px solid var(--color-border-light);
}

.login-footer p {
  color: var(--color-text-secondary);
  margin-bottom: 10px;
}

.register-link {
  color: var(--color-secondary);
  font-weight: 600;
  text-decoration: none;
}

.register-link:hover {
  text-decoration: underline;
}
</style>

