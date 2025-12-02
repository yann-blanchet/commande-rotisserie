<template>
  <div class="trader-home">
    <header class="header">
      <h1>🍗 Mes Stands</h1>
      <div class="header-actions">
        <button @click="handleLogout" class="logout-btn">Déconnexion</button>
      </div>
    </header>

    <div class="status-bar">
      <span :class="['status-indicator', isOnline() ? 'online' : 'offline']">
        {{ isOnline() ? '🟢 En ligne' : '🔴 Hors ligne' }}
      </span>
      <button @click="loadStands" class="refresh-btn" :disabled="!isOnline() || loading">
        Actualiser
      </button>
    </div>

    <div v-if="loading" class="loading">Chargement...</div>

    <div v-else-if="error" class="error-message">
      <p>{{ error }}</p>
      <button @click="loadStands" class="btn-primary">Réessayer</button>
    </div>

    <div v-else-if="stands.length > 0" class="stands-container">
      <!-- Display stand name once if all stands have the same name -->
      <div v-if="stands.length > 0 && stands[0].stand_nom" class="stand-name-header">
        <h2>{{ stands[0].stand_nom }}</h2>
        <p v-if="stands[0].stand_description" class="stand-description">{{ stands[0].stand_description }}</p>
      </div>

      <div class="stands-grid">
        <div
          v-for="stand in stands"
          :key="stand.id"
          class="stand-card"
        >
          <div class="stand-info">
            <!-- Market is the main focus -->
            <div v-if="stand.markets" class="market-info">
              <h3 class="market-name">🏪 {{ stand.markets.name || 'Non associé' }}</h3>
              <span v-if="stand.markets.place" class="market-place">📍 {{ stand.markets.place }}</span>
              <span v-if="getNextMarketDate(stand.markets)" class="next-market-date">
                📅 Prochain marché: {{ getNextMarketDate(stand.markets) }}
              </span>
            </div>
            <div v-else class="market-info no-market">
              <h3>⚠️ Aucun marché associé</h3>
            </div>
            
            <!-- Stand location if different per market -->
            <div v-if="stand.location" class="stand-location">
              <span class="location">📍 Emplacement: {{ stand.location }}</span>
            </div>
          </div>
          <div class="stand-actions">
            <router-link :to="`/trader/orders?stand=${stand.id}`" class="btn-primary">
              Voir les commandes
            </router-link>
            <router-link :to="`/trader/products?stand=${stand.id}`" class="btn-secondary">
              Gérer les produits
            </router-link>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="empty-state">
      <div v-if="!showCreateStand" class="empty-content">
        <h2 style="font-size: 1.8rem; margin-bottom: 15px; color: #333; font-weight: 600;">
          🍗 Vous n'avez pas encore de stand
        </h2>
        <p class="empty-hint">
          Créez votre premier stand pour commencer à vendre.
        </p>
        <button 
          @click="showCreateStand = true" 
          class="btn-primary create-stand-btn" 
          :disabled="!isOnline()">
          🍗 Créer mon premier stand
        </button>
        <p v-if="!isOnline()" class="offline-hint">
          ⚠️ Vous devez être en ligne pour créer un stand.
        </p>
      </div>

      <!-- Create Stand Form -->
      <div v-else class="create-stand-form">
        <h2>🍗 Créer votre stand</h2>
        
        <div v-if="error" class="form-error">
          {{ error }}
        </div>
        
        <form @submit.prevent="createStand">
          <div class="form-group">
            <label>Marché (optionnel)</label>
            <select v-model="newStandForm.market_id" class="form-select" :disabled="creating || loadingMarkets">
              <option value="">Aucun marché (vous pourrez l'ajouter plus tard)</option>
              <option v-for="market in markets" :key="market.id" :value="market.id">
                {{ market.name }} - {{ market.place }}
              </option>
            </select>
            <small class="form-hint">Vous pourrez associer votre stand à un marché plus tard si vous ne le faites pas maintenant.</small>
          </div>

          <div class="form-group">
            <label>Emplacement dans le marché (optionnel)</label>
            <input 
              v-model="newStandForm.location" 
              type="text" 
              placeholder="Ex: Allée 6, Stand 12" 
              :disabled="creating || !newStandForm.market_id"
              class="form-input"
            />
            <small class="form-hint">Indiquez où se trouve votre stand dans le marché.</small>
          </div>

          <div class="form-actions">
            <button type="button" @click="cancelCreateStand" class="btn-secondary" :disabled="creating">
              Annuler
            </button>
            <button type="submit" class="btn-primary" :disabled="creating || loadingMarkets">
              {{ creating ? 'Création...' : 'Créer le stand' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase, isOnline } from '../lib/supabase'
import { syncService } from '../services/syncService'
import { db } from '../db/database'

const router = useRouter()
const stands = ref<any[]>([])
const loading = ref(true)
const error = ref<string | null>(null)
const showCreateStand = ref(false)
const creating = ref(false)
const markets = ref<any[]>([])
const loadingMarkets = ref(false)
const newStandForm = ref({
  market_id: '',
  location: ''
})

const loadStands = async () => {
  loading.value = true

  // Get trader session
  const sessionStr = localStorage.getItem('trader_session')
  if (!sessionStr) {
    router.push('/trader/login')
    return
  }

  try {
    const session = JSON.parse(sessionStr)
    if (!session.authenticated) {
      router.push('/trader/login')
      return
    }

    // Get profile_id from session or from vendor_id
    let profileId: string | null = session.profile_id || null
    console.log('Session:', { profile_id: profileId, vendor_id: session.vendor_id, email: session.email })

    // If profile_id is not in session, get it from the vendor
    if (!profileId && session.vendor_id) {
      if (isOnline()) {
        console.log('Fetching profile_id from vendor_id:', session.vendor_id)
        const { data: vendor, error: vendorError } = await supabase
          .from('vendors')
          .select('profile_id')
          .eq('id', session.vendor_id)
          .maybeSingle()

        if (vendorError) {
          console.error('Error fetching vendor:', vendorError)
        }

        if (vendor && vendor.profile_id) {
          profileId = vendor.profile_id
          console.log('Found profile_id:', profileId)
          // Update session with profile_id
          session.profile_id = profileId
          localStorage.setItem('trader_session', JSON.stringify(session))
        } else {
          console.warn('No profile_id found in vendor record')
        }
      }
    }

    // If still no profile_id, try to get it from email
    if (!profileId && session.email && isOnline()) {
      console.log('Trying to get profile_id from email:', session.email)
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('id')
        .eq('email', session.email.toLowerCase().trim())
        .eq('role', 'vendor')
        .maybeSingle()

      if (profileError) {
        console.error('Error fetching profile:', profileError)
      }

      if (profile && profile.id) {
        profileId = profile.id
        console.log('Found profile_id from email:', profileId)
        // Update session with profile_id
        session.profile_id = profileId
        localStorage.setItem('trader_session', JSON.stringify(session))
      }
    }

    if (!profileId) {
      console.error('No profile_id found after all attempts')
      error.value = 'Impossible de récupérer votre profil. Veuillez vous reconnecter.'
      loading.value = false
      return
    }

    // Load all stands for this profile
    if (isOnline()) {
      console.log('Loading stands for profile_id:', profileId)
      const { data: vendors, error: vendorsError } = await supabase
        .from('vendors')
        .select('*, markets(*), profiles(stand_nom, stand_description)')
        .eq('profile_id', profileId)
        .order('created_at', { ascending: false })
      
      console.log('Vendors query result:', { vendors, vendorsError, vendorsCount: vendors?.length || 0 })

      if (vendorsError) {
        console.error('Error loading stands:', vendorsError)
        error.value = `Erreur lors du chargement des stands: ${vendorsError.message}`
      } else {
        console.log('Loaded stands:', vendors)
        if (vendors && vendors.length > 0) {
          // Map vendors to include stand_nom and stand_description from profiles
          stands.value = vendors.map(v => ({
            ...v,
            stand_nom: v.profiles?.stand_nom || null,
            stand_description: v.profiles?.stand_description || null
          }))
          error.value = null
        } else {
          console.log('No stands found for this profile')
          console.log('Will show create stand form. Loading:', loading.value, 'Error:', error.value, 'Stands length:', stands.value.length)
          stands.value = []
          error.value = null
        }
      }
    } else {
      // Offline: try to load from cache if available
      console.warn('Offline mode: cannot load stands list')
      error.value = 'Mode hors ligne: impossible de charger la liste des stands'
    }
  } catch (err: any) {
    console.error('Error loading stands:', err)
    error.value = err.message || 'Erreur lors du chargement des stands'
  } finally {
    loading.value = false
    console.log('loadStands finished. Loading:', loading.value, 'Error:', error.value, 'Stands:', stands.value.length)
  }
}

// Calculate next market date based on market days
const calculateNextMarketDate = (marketDays: string[]): Date | null => {
  if (!marketDays || marketDays.length === 0) {
    return null
  }

  const dayMap: Record<string, number> = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 0
  }

  const today = new Date()
  const currentDay = today.getDay()
  
  // Get market day numbers (filter out undefined values)
  const marketDayNumbers = marketDays
    .map(day => dayMap[day.toLowerCase()])
    .filter((dayNum): dayNum is number => dayNum !== undefined)
    .sort((a, b) => a - b)

  // Find next market day
  for (const dayNum of marketDayNumbers) {
    if (dayNum > currentDay) {
      // Market day is later this week
      const daysUntil = dayNum - currentDay
      const nextDate = new Date(today)
      nextDate.setDate(today.getDate() + daysUntil)
      return nextDate
    }
  }

  // If no market day found this week, get the first one next week
  if (marketDayNumbers.length > 0) {
    const firstDayNum = marketDayNumbers[0]
    if (firstDayNum !== undefined) {
      const daysUntil = 7 - currentDay + firstDayNum
      const nextDate = new Date(today)
      nextDate.setDate(today.getDate() + daysUntil)
      return nextDate
    }
  }

  return null
}

const formatMarketDate = (date: Date): string => {
  return new Intl.DateTimeFormat('fr-FR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  }).format(date)
}

const getNextMarketDate = (market: any): string | null => {
  if (!market || !market.days || market.days.length === 0) {
    return null
  }

  const nextDate = calculateNextMarketDate(market.days)
  if (nextDate) {
    return formatMarketDate(nextDate)
  }

  return null
}

const handleLogout = () => {
  localStorage.removeItem('trader_session')
  router.push('/trader/login')
}

const loadMarkets = async () => {
  loadingMarkets.value = true
  try {
    if (isOnline()) {
      await syncService.syncMarkets()
    }
    
    // Load from cache
    const cachedMarkets = await db.markets_cache.toArray()
    markets.value = cachedMarkets
      .map(m => m.data)
      .sort((a, b) => (a.name || '').localeCompare(b.name || ''))
  } catch (error) {
    console.error('Error loading markets:', error)
  } finally {
    loadingMarkets.value = false
  }
}

const cancelCreateStand = () => {
  showCreateStand.value = false
  newStandForm.value = {
    market_id: '',
    location: ''
  }
  error.value = null
}

// Watch for showCreateStand to load markets when form is shown
watch(showCreateStand, (newVal) => {
  if (newVal) {
    error.value = null // Reset error when opening form
    loadMarkets()
  }
})

const createStand = async () => {
  if (creating.value || !isOnline()) {
    return
  }

  // Get trader session
  const sessionStr = localStorage.getItem('trader_session')
  if (!sessionStr) {
    router.push('/trader/login')
    return
  }

  try {
    const session = JSON.parse(sessionStr)
    if (!session.authenticated || !session.profile_id) {
      error.value = 'Session invalide. Veuillez vous reconnecter.'
      return
    }

    creating.value = true
    error.value = null

    // Create vendor (stand)
    const vendorData: any = {
      profile_id: session.profile_id
    }

    // Add market_id if selected
    if (newStandForm.value.market_id) {
      vendorData.market_id = newStandForm.value.market_id
    }

    // Add location if provided
    if (newStandForm.value.location && newStandForm.value.location.trim()) {
      vendorData.location = newStandForm.value.location.trim()
    }

    console.log('Creating vendor with data:', vendorData)
    const { data: newVendor, error: vendorError } = await supabase
      .from('vendors')
      .insert(vendorData)
      .select()
      .single()

    if (vendorError) {
      console.error('Error creating vendor:', vendorError)
      throw vendorError
    }

    if (!newVendor) {
      console.error('No vendor returned from insert')
      throw new Error('Erreur lors de la création du stand')
    }

    console.log('Vendor created successfully:', newVendor)

    // Update session with vendor_id if it's the first stand
    if (!session.vendor_id) {
      session.vendor_id = newVendor.id
      localStorage.setItem('trader_session', JSON.stringify(session))
    }

    // Refresh stands list
    await loadStands()

    // Redirect to configure the stand
    router.push(`/trader/orders?stand=${newVendor.id}`)
  } catch (err: any) {
    console.error('Error creating stand:', err)
    error.value = err.message || 'Erreur lors de la création du stand'
    creating.value = false
  }
}

onMounted(() => {
  loadStands()
})
</script>

<style scoped>
.trader-home {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  padding-bottom: 20px;
  border-bottom: 2px solid var(--color-border-light);
}

.header h1 {
  font-size: 2rem;
  margin: 0;
}

.header-actions {
  display: flex;
  gap: 10px;
}

.status-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 10px 15px;
  background: var(--color-bg-gray);
  border-radius: 8px;
}

.status-indicator {
  font-weight: 600;
  font-size: 0.9rem;
}

.status-indicator.online {
  color: var(--color-success);
}

.status-indicator.offline {
  color: var(--color-error-text);
}

.refresh-btn {
  padding: 8px 16px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.9rem;
}

.refresh-btn:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.refresh-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.logout-btn {
  padding: 10px 20px;
  background: var(--color-error-light);
  color: var(--color-error-text);
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.9rem;
}

.logout-btn:hover {
  background: var(--color-error);
  color: white;
}

.loading {
  text-align: center;
  padding: 40px;
  font-size: 1.1rem;
  color: var(--color-text-secondary);
}

.stands-container {
  margin-top: 20px;
}

.stand-name-header {
  text-align: center;
  margin-bottom: 30px;
  padding-bottom: 20px;
  border-bottom: 2px solid var(--color-border-light);
}

.stand-name-header h2 {
  font-size: 2rem;
  margin: 0 0 10px 0;
  color: var(--color-text-primary);
}

.stand-name-header .stand-description {
  color: var(--color-text-secondary);
  font-size: 1.1rem;
  margin: 0;
}

.stands-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 20px;
}

.stand-card {
  background: var(--color-bg-white);
  border: 1px solid var(--color-border-light);
  border-radius: 12px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 15px;
  transition: transform 0.2s, box-shadow 0.2s;
}

.stand-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.stand-info {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.stand-location {
  margin-top: 8px;
}

.location {
  color: var(--color-text-secondary);
  font-size: 0.9rem;
}

.market-info {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 15px;
  background: var(--color-info-light);
  border-radius: 8px;
  margin-bottom: 10px;
}

.market-info.no-market {
  background: var(--color-warning-light);
  color: var(--color-warning-dark);
}

.market-info h3 {
  margin: 0;
  font-size: 1.3rem;
  font-weight: 700;
  color: var(--color-text-primary);
}

.market-name {
  font-weight: 700;
  font-size: 1.3rem;
  color: var(--color-text-primary);
  margin: 0 0 8px 0;
}

.market-place {
  color: var(--color-text-secondary);
  font-size: 0.85rem;
}

.next-market-date {
  color: var(--color-primary);
  font-weight: 600;
  font-size: 0.9rem;
  margin-top: 6px;
  padding-top: 6px;
  border-top: 1px solid var(--color-border-light);
}

.stand-actions {
  display: flex;
  gap: 10px;
  margin-top: auto;
}

.stand-actions .btn-primary,
.stand-actions .btn-secondary {
  flex: 1;
  padding: 12px;
  text-align: center;
  text-decoration: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.9rem;
  transition: background 0.2s;
}

.stand-actions .btn-primary {
  background: var(--color-primary);
  color: white;
}

.stand-actions .btn-primary:hover {
  background: var(--color-primary-hover);
}

.stand-actions .btn-secondary {
  background: var(--color-bg-gray);
  color: var(--color-text-primary);
}

.stand-actions .btn-secondary:hover {
  background: var(--color-bg-gray-hover);
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: var(--color-text-secondary);
  min-height: 400px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.empty-content {
  max-width: 500px;
  margin: 0 auto;
  padding: 40px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.empty-state p {
  font-size: 1.1rem;
  margin-bottom: 10px;
}

.empty-hint {
  font-size: 1rem;
  color: var(--color-text-secondary);
  margin-bottom: 30px;
  line-height: 1.6;
}

.create-stand-btn {
  margin-top: 10px;
  padding: 15px 30px;
  font-size: 1.1rem;
  min-width: 250px;
  font-weight: 600;
}

.offline-hint {
  margin-top: 15px;
  color: var(--color-warning-dark);
  font-size: 0.9rem;
}

.create-stand-form {
  max-width: 500px;
  margin: 0 auto;
  padding: 30px;
  background: var(--color-bg-white);
  border: 1px solid var(--color-border-light);
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.create-stand-form h2 {
  margin: 0 0 25px 0;
  font-size: 1.8rem;
  text-align: center;
  color: var(--color-text-primary);
}

.form-error {
  padding: 12px;
  margin-bottom: 20px;
  background: var(--color-error-light);
  color: var(--color-error-text);
  border: 1px solid var(--color-error);
  border-radius: 8px;
  font-size: 0.9rem;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.form-select,
.form-input {
  width: 100%;
  padding: 12px;
  border: 1px solid var(--color-border-medium);
  border-radius: 8px;
  font-size: 1rem;
  background: white;
}

.form-select:disabled,
.form-input:disabled {
  background: var(--color-bg-gray);
  cursor: not-allowed;
  opacity: 0.6;
}

.form-hint {
  display: block;
  margin-top: 6px;
  font-size: 0.85rem;
  color: var(--color-text-secondary);
}

.form-actions {
  display: flex;
  gap: 10px;
  margin-top: 25px;
}

.form-actions .btn-primary,
.form-actions .btn-secondary {
  flex: 1;
  padding: 12px;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 1rem;
  cursor: pointer;
  transition: background 0.2s;
}

.form-actions .btn-primary {
  background: var(--color-primary);
  color: white;
}

.form-actions .btn-primary:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.form-actions .btn-secondary {
  background: var(--color-bg-gray);
  color: var(--color-text-primary);
}

.form-actions .btn-secondary:hover:not(:disabled) {
  background: var(--color-bg-gray-hover);
}

.form-actions .btn-primary:disabled,
.form-actions .btn-secondary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error-message {
  text-align: center;
  padding: 40px 20px;
  background: var(--color-error-light);
  border: 1px solid var(--color-error);
  border-radius: 8px;
  margin: 20px 0;
}

.error-message p {
  color: var(--color-error-text);
  margin-bottom: 20px;
  font-size: 1.1rem;
}
</style>

