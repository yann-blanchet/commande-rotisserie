<template>
  <div class="trader-home">
    <TraderHeader title="🍗 Mes Stands" />

    <div v-if="loading" class="loading">Chargement...</div>

    <div v-else-if="error" class="error-message">
      <p>{{ error }}</p>
      <button @click="loadStands" class="btn-primary">Réessayer</button>
    </div>

    <div v-else-if="stand" class="stand-container">
      <!-- Display stand name and description -->
      <div class="stand-header">
        <div class="stand-header-content">
          <div class="stand-title-section">
            <h2 class="stand-title">{{ stand.stand_nom || 'Mon Stand' }}</h2>
            <p v-if="stand.stand_description" class="stand-description">{{ stand.stand_description }}</p>
          </div>
        </div>
      </div>

      <!-- Markets associated with this stand -->
      <div class="markets-section">
        <div class="section-header">
          <h3 class="section-title">
            <span class="section-icon">🏪</span>
            Marchés associés
          </h3>
          <button @click="openAddMarketModal(stand)" class="btn-add-market" :disabled="!isOnline()">
            <span class="add-icon">+</span>
            Ajouter un marché
          </button>
        </div>

        <div v-if="stand.markets && stand.markets.length > 0" class="markets-grid">
          <div v-for="(market, index) in stand.markets" :key="market.id || index" class="market-card">
            <div class="market-card-header">
              <div class="market-icon">🏪</div>
              <div class="market-header-content">
                <h4 class="market-name">{{ market.name }}</h4>
                <p v-if="market.place" class="market-place">
                  <span class="place-icon">📍</span>
                  <span class="place-text">{{ market.place }}</span>
                </p>
              </div>
              <div v-if="getStandLocationInMarket(stand, market.id)" class="market-location-inline">
                <span class="location-separator">•</span>
                <span class="location-text">{{ getStandLocationInMarket(stand, market.id) }}</span>
                <button @click="editMarketLocation(stand, market)" class="btn-edit-location-inline"
                  :disabled="!isOnline()" title="Modifier l'emplacement">
                  <span class="edit-icon-small">✏️</span>
                </button>
              </div>
            </div>

            <div class="market-details">

              <div class="market-detail-item next-market" v-if="getNextMarketDate(market)">
                <span class="detail-icon">📅</span>
                <span class="detail-label">Prochain marché:</span>
                <span class="detail-text date-text">{{ getNextMarketDate(market) }}</span>
              </div>
            </div>

            <div class="market-actions">
              <button v-if="!hasActiveSessionForMarket(market.id)" @click="startMarketSession(market)"
                class="btn-start-commands" :disabled="!isOnline()">
                🚀 Commencer les commandes
              </button>
              <router-link :to="`/trader/orders?stand=${stand.id}&market=${market.id}`" class="btn-orders">
                <span>Voir les commandes</span>
                <span class="arrow">→</span>
              </router-link>
            </div>
          </div>
        </div>

        <div v-else class="no-markets">
          <div class="no-markets-icon">🏪</div>
          <p class="no-markets-title">Aucun marché associé</p>
          <p class="no-markets-hint">Associez votre stand à un marché pour commencer à recevoir des commandes</p>
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
        <button @click="showCreateStand = true" class="btn-primary create-stand-btn" :disabled="!isOnline()">
          🍗 Créer mon premier stand
        </button>
        <p v-if="!isOnline()" class="offline-hint">
          ⚠️ Vous devez être en ligne pour créer un stand.
        </p>
      </div>

      <!-- Create Stand Form - 2 Step Onboarding -->
      <div v-else class="create-stand-form">
        <div class="setup-card">
          <!-- Step 1: Nom + Description -->
          <div v-if="onboardingStep === 1">
            <div class="onboarding-header">
              <div class="step-indicator">
                <span class="step-number active">1</span>
                <span class="step-line"></span>
                <span class="step-number" :class="{ active: onboardingStep > 1 }">2</span>
              </div>
              <h2>🍗 Étape 1 : Configurez votre stand</h2>
              <p class="setup-subtitle">Donnez un nom et une description à votre stand</p>
            </div>

            <div v-if="error" class="form-error">
              {{ error }}
            </div>

            <form @submit.prevent="saveStandInfo" class="stand-form">
              <div class="form-group">
                <label>Nom du stand *</label>
                <input v-model="newStandForm.nom" type="text" required placeholder="Ex: Stand Poulet Rôti du Marché"
                  :disabled="creating" />
              </div>

              <div class="form-group">
                <label>Description</label>
                <textarea v-model="newStandForm.description" placeholder="Décrivez votre stand..." rows="3"
                  :disabled="creating"></textarea>
              </div>

              <div class="form-actions">
                <button type="button" @click="cancelCreateStand" class="btn-secondary" :disabled="creating">
                  Annuler
                </button>
                <button type="submit" class="btn-primary" :disabled="creating || !newStandForm.nom.trim()">
                  {{ creating ? 'Enregistrement...' : 'Continuer' }}
                </button>
              </div>
            </form>
          </div>

          <!-- Step 2: Associer un ou plusieurs marchés -->
          <div v-else-if="onboardingStep === 2">
            <div class="onboarding-header">
              <div class="step-indicator">
                <span class="step-number active">1</span>
                <span class="step-line active"></span>
                <span class="step-number active">2</span>
              </div>
              <h2>🏪 Étape 2 : Associez votre stand à un ou plusieurs marchés</h2>
              <p class="setup-subtitle">Sélectionnez les marchés où vous vendez</p>
            </div>

            <div v-if="error" class="form-error">
              {{ error }}
            </div>

            <form @submit.prevent="associateMarkets" class="stand-form">
              <div class="form-group">
                <label>Marchés *</label>
                <div class="markets-selection">
                  <div v-for="market in markets" :key="market.id" class="market-checkbox-item">
                    <label class="checkbox-label">
                      <input type="checkbox" :value="market.id" v-model="selectedMarkets"
                        :disabled="creating || loadingMarkets" />
                      <span class="checkbox-text">
                        <strong>{{ market.name }}</strong> - {{ market.place }}
                      </span>
                    </label>
                    <input v-if="selectedMarkets.includes(market.id)" v-model="marketLocations[market.id]" type="text"
                      placeholder="Emplacement (ex: Allée 6)" class="location-input" :disabled="creating" />
                  </div>
                </div>
                <small class="form-hint">Vous pouvez sélectionner plusieurs marchés. Vous pourrez en ajouter d'autres
                  plus tard.</small>
              </div>

              <div class="form-actions">
                <button type="button" @click="onboardingStep = 1" class="btn-secondary" :disabled="creating">
                  Retour
                </button>
                <button type="submit" class="btn-primary"
                  :disabled="creating || selectedMarkets.length === 0 || loadingMarkets">
                  {{ creating ? 'Association...' : 'Terminer' }}
                </button>
                <button type="button" @click="skipMarketAssociation" class="btn-link" :disabled="creating">
                  Passer cette étape
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal pour ajouter un marché à un stand existant -->
    <div v-if="showAddMarketModal" class="modal-overlay" @click="closeAddMarketModal">
      <div class="modal-content" @click.stop>
        <button class="close-btn" @click="closeAddMarketModal">×</button>
        <h2>Ajouter un marché à "{{ selectedStandForMarket?.stand_nom || 'ce stand' }}"</h2>

        <form @submit.prevent="addMarketToStand" class="stand-form">
          <div class="form-group">
            <label>Marché *</label>
            <select v-model="newMarketForm.market_id" class="form-select" required
              :disabled="creating || loadingMarkets">
              <option value="">Sélectionnez un marché</option>
              <option v-for="market in availableMarketsForStand" :key="market.id" :value="market.id">
                {{ market.name }} - {{ market.place }}
              </option>
            </select>
          </div>

          <div class="form-group">
            <label>Emplacement dans le marché</label>
            <input v-model="newMarketForm.location" type="text" placeholder="Ex: Allée A, Stand 12"
              :disabled="creating || !newMarketForm.market_id" />
            <small class="form-hint">Indiquez où se trouve votre stand dans ce marché</small>
          </div>

          <div v-if="addMarketError" class="error-message">
            {{ addMarketError }}
          </div>

          <div class="form-actions">
            <button type="button" @click="closeAddMarketModal" class="btn-secondary" :disabled="creating">
              Annuler
            </button>
            <button type="submit" class="btn-primary" :disabled="creating || !newMarketForm.market_id">
              {{ creating ? 'Ajout...' : 'Ajouter le marché' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <BottomMenuBar />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase, isOnline } from '../lib/supabase'
import { syncService } from '../services/syncService'
import { db } from '../db/database'
import BottomMenuBar from '../components/BottomMenuBar.vue'
import TraderHeader from '../components/TraderHeader.vue'

const router = useRouter()
const stand = ref<any>(null) // Un seul stand par trader
const loading = ref(true)
const error = ref<string | null>(null)
const showCreateStand = ref(false)
const creating = ref(false)
const markets = ref<any[]>([])
const loadingMarkets = ref(false)
const onboardingStep = ref(1)
const selectedMarkets = ref<string[]>([])
const marketLocations = ref<Record<string, string>>({})
const marketsWithActiveSessions = ref<string[]>([]) // IDs des marchés avec sessions actives
const newStandForm = ref({
  nom: '',
  description: ''
})
const showAddMarketModal = ref(false)
const selectedStandForMarket = ref<any>(null)
const newMarketForm = ref({
  market_id: '',
  location: ''
})
const addMarketError = ref<string | null>(null)

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
        .select('*, vendor_markets(market_id, location, markets(*)), profiles(stand_nom, stand_description)')
        .eq('profile_id', profileId)
        .order('created_at', { ascending: false })

      console.log('Vendors query result:', { vendors, vendorsError, vendorsCount: vendors?.length || 0 })

      if (vendorsError) {
        console.error('Error loading stand:', vendorsError)
        error.value = `Erreur lors du chargement du stand: ${vendorsError.message}`
      } else {
        console.log('Loaded vendors:', vendors)
        if (vendors && vendors.length > 0) {
          // Un seul stand par trader - prendre le premier (ou le seul)
          const v = vendors[0]
          const vendorMarkets = Array.isArray(v.vendor_markets) ? v.vendor_markets : []
          const markets = vendorMarkets.map((vm: any) => vm.markets).filter((m: any) => m) // Flatten markets array

          console.log('Stand loaded:', {
            vendorId: v.id,
            vendorMarkets,
            markets,
            marketsLength: markets.length
          })

          stand.value = {
            ...v,
            stand_nom: v.stand_nom || v.profiles?.stand_nom || null,
            stand_description: v.stand_description || v.profiles?.stand_description || null,
            vendor_markets: vendorMarkets,
            markets: markets
          }

          // Load active sessions for markets
          const marketIds = markets.map((m: any) => m.id)
          if (marketIds.length > 0) {
            const { data: activeSessions } = await supabase
              .from('market_sessions')
              .select('market_id')
              .eq('is_active', true)
              .in('market_id', marketIds)

            marketsWithActiveSessions.value = activeSessions?.map((s: any) => s.market_id) || []
          }

          error.value = null
        } else {
          console.log('No stand found for this profile - will show create stand form')
          stand.value = null
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
    console.log('loadStands finished. Loading:', loading.value, 'Error:', error.value, 'Stand:', stand.value ? 'loaded' : 'none')
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


// Vérifier si un marché a une session active
const hasActiveSessionForMarket = (marketId: string): boolean => {
  return marketsWithActiveSessions.value.includes(marketId)
}

// Fonction pour créer automatiquement une session et rediriger
const startMarketSession = async (market: any) => {
  if (!isOnline()) {
    alert('Vous devez être en ligne pour créer une session')
    return
  }

  try {
    const sessionStr = localStorage.getItem('trader_session')
    if (!sessionStr) {
      router.push('/trader/login')
      return
    }

    const session = JSON.parse(sessionStr)
    if (!session.authenticated || !session.profile_id) {
      alert('Session invalide')
      return
    }

    // Calculer la prochaine date de marché
    const nextDate = calculateNextMarketDate(market.days || [])
    if (!nextDate) {
      alert('Impossible de calculer la date du marché')
      return
    }

    const marketDate = nextDate.toISOString().split('T')[0]

    // Synchroniser les sessions avant de vérifier
    if (session.vendor_id) {
      await syncService.syncMarketSessions(session.vendor_id)
    }

    // Vérifier d'abord dans le cache local
    const cachedSessions = await db.market_sessions_cache
      .where('market_id')
      .equals(market.id)
      .toArray()

    const matchingSession = cachedSessions.find(
      (s: any) => s.data.date === marketDate && s.data.is_active === true
    )

    if (matchingSession) {
      router.push(`/trader/current-market?session=${matchingSession.id}`)
      return
    }

    // Vérifier aussi en ligne si disponible
    if (isOnline()) {
      const { data: existingSession, error: checkError } = await supabase
        .from('market_sessions')
        .select('id')
        .eq('market_id', market.id)
        .eq('date', marketDate)
        .eq('is_active', true)
        .maybeSingle()

      if (checkError) throw checkError

      // Si une session existe déjà, rediriger vers elle
      if (existingSession) {
        router.push(`/trader/current-market?session=${existingSession.id}`)
        return
      }
    }

    // Date de fermeture : veille à 20h
    const closureDate = new Date(nextDate)
    closureDate.setDate(closureDate.getDate() - 1)
    closureDate.setHours(20, 0, 0, 0)
    const closureDateTime = closureDate.toISOString()

    // Créer la session
    const { data: newSession, error: createError } = await supabase
      .from('market_sessions')
      .insert({
        market_id: market.id,
        date: marketDate,
        order_closure_date: closureDateTime,
        is_active: true
      })
      .select('id')
      .single()

    if (createError) {
      // Si l'erreur est due à une contrainte unique, vérifier à nouveau et rediriger
      if (createError.code === '23505' || createError.message?.includes('duplicate key')) {
        // Synchroniser les sessions pour mettre à jour le cache
        if (session.vendor_id) {
          await syncService.syncMarketSessions(session.vendor_id)
        }

        // Chercher dans le cache
        const cachedSessionsAfterError = await db.market_sessions_cache
          .where('market_id')
          .equals(market.id)
          .toArray()

        const matchingSessionAfterError = cachedSessionsAfterError.find(
          (s: any) => s.data.date === marketDate && s.data.is_active === true
        )

        if (matchingSessionAfterError) {
          router.push(`/trader/current-market?session=${matchingSessionAfterError.id}`)
          return
        }

        // Si pas dans le cache, chercher en ligne
        if (isOnline()) {
          const { data: existingSession2 } = await supabase
            .from('market_sessions')
            .select('id')
            .eq('market_id', market.id)
            .eq('date', marketDate)
            .eq('is_active', true)
            .maybeSingle()

          if (existingSession2) {
            router.push(`/trader/current-market?session=${existingSession2.id}`)
            return
          }
        }
      }
      throw createError
    }

    // Mettre à jour le cache avec la nouvelle session
    if (newSession && newSession.id && marketDate && closureDateTime) {
      const sessionId = String(newSession.id)
      await db.market_sessions_cache.put({
        id: sessionId,
        market_id: market.id,
        data: {
          id: sessionId,
          market_id: market.id,
          date: marketDate,
          order_closure_date: closureDateTime,
          is_active: true
        },
        updated_at: new Date().toISOString()
      })
    }

    // Rafraîchir les sessions actives
    await loadStands()

    // Rediriger vers TraderCurrentMarket avec la nouvelle session
    if (newSession) {
      router.push(`/trader/current-market?session=${newSession.id}`)
    } else {
      router.push('/trader/current-market')
    }
  } catch (err: any) {
    console.error('Error starting market session:', err)
    alert('Erreur lors de la création de la session: ' + (err.message || 'Erreur inconnue'))
  }
}

// Get stand location for a specific market
const getStandLocationInMarket = (stand: any, marketId: string | undefined): string | null => {
  if (!marketId || !stand) return null
  const vendorMarkets = Array.isArray(stand.vendor_markets) ? stand.vendor_markets : []
  const marketAssociation = vendorMarkets.find((vm: any) => vm.market_id === marketId)
  return marketAssociation?.location || null
}


// Éditer l'emplacement d'un marché
const editMarketLocation = (stand: any, market: any) => {
  // Pour l'instant, on redirige vers la page d'édition
  // TODO: Créer un modal dédié pour éditer l'emplacement
  const location = getStandLocationInMarket(stand, market.id) || ''
  const newLocation = prompt(`Emplacement dans ${market.name}:`, location)
  if (newLocation !== null && isOnline()) {
    updateMarketLocation(stand.id, market.id, newLocation)
  }
}

// Mettre à jour l'emplacement d'un marché
const updateMarketLocation = async (vendorId: string, marketId: string, location: string) => {
  try {
    // Trouver l'association existante
    const { data: vendorMarket } = await supabase
      .from('vendor_markets')
      .select('id')
      .eq('vendor_id', vendorId)
      .eq('market_id', marketId)
      .maybeSingle()

    if (vendorMarket) {
      // Mettre à jour
      const { error } = await supabase
        .from('vendor_markets')
        .update({ location: location.trim() || null })
        .eq('id', vendorMarket.id)

      if (error) throw error

      // Rafraîchir
      await syncService.syncVendors()
      await loadStands()
    }
  } catch (err: any) {
    console.error('Error updating market location:', err)
    alert('Erreur lors de la mise à jour: ' + (err.message || 'Erreur inconnue'))
  }
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

// Computed pour obtenir les marchés disponibles pour un stand (excluant ceux déjà associés)
const availableMarketsForStand = computed(() => {
  if (!selectedStandForMarket.value) return markets.value

  const associatedMarketIds = new Set(
    (selectedStandForMarket.value.vendor_markets || [])
      .map((vm: any) => vm.market_id)
      .filter((id: any) => id)
  )

  return markets.value.filter(m => !associatedMarketIds.has(m.id))
})

const cancelCreateStand = () => {
  showCreateStand.value = false
  onboardingStep.value = 1
  newStandForm.value = {
    nom: '',
    description: ''
  }
  selectedMarkets.value = []
  marketLocations.value = {}
  error.value = null
}

// Watch for showCreateStand to load markets when form is shown
watch(showCreateStand, (newVal) => {
  if (newVal) {
    error.value = null // Reset error when opening form
    onboardingStep.value = 1
    loadMarkets()
  }
})

// Step 1: Save stand name and description (create vendor without markets)
const saveStandInfo = async () => {
  if (creating.value || !isOnline()) {
    return
  }

  if (!newStandForm.value.nom.trim()) {
    error.value = 'Le nom du stand est requis'
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

    // Vérifier qu'il n'y a pas déjà un stand pour ce profile
    const { data: existingVendor } = await supabase
      .from('vendors')
      .select('id')
      .eq('profile_id', session.profile_id)
      .maybeSingle()

    if (existingVendor) {
      error.value = 'Vous avez déjà un stand. Vous ne pouvez en créer qu\'un seul.'
      creating.value = false
      return
    }

    // Create vendor (stand) with name and description
    const vendorData: any = {
      profile_id: session.profile_id,
      stand_nom: newStandForm.value.nom.trim(),
      stand_description: newStandForm.value.description.trim() || null
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

    // Store vendor_id for step 2
    if (!session.vendor_id) {
      session.vendor_id = newVendor.id
      localStorage.setItem('trader_session', JSON.stringify(session))
    }

    // Store vendor_id in a ref for step 2
    const createdVendorId = newVendor.id
    localStorage.setItem('creating_vendor_id', createdVendorId)

    // Move to step 2
    onboardingStep.value = 2
    creating.value = false
  } catch (err: any) {
    console.error('Error creating stand:', err)
    error.value = err.message || 'Erreur lors de la création du stand'
    creating.value = false
  }
}

// Step 2: Associate markets to the stand
const associateMarkets = async () => {
  if (creating.value || !isOnline()) {
    return
  }

  if (selectedMarkets.value.length === 0) {
    error.value = 'Veuillez sélectionner au moins un marché'
    return
  }

  // Get trader session and vendor_id
  const sessionStr = localStorage.getItem('trader_session')
  const vendorId = localStorage.getItem('creating_vendor_id')

  if (!sessionStr || !vendorId) {
    error.value = 'Session invalide. Veuillez recommencer.'
    router.push('/trader/home')
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

    // Create vendor_markets entries for each selected market
    const vendorMarketsData = selectedMarkets.value.map(marketId => ({
      vendor_id: vendorId,
      market_id: marketId,
      location: marketLocations.value[marketId]?.trim() || null
    }))

    console.log('Creating vendor_markets with data:', vendorMarketsData)
    const { error: vendorMarketsError } = await supabase
      .from('vendor_markets')
      .insert(vendorMarketsData)

    if (vendorMarketsError) {
      console.error('Error creating vendor_markets:', vendorMarketsError)
      throw vendorMarketsError
    }

    console.log('Vendor markets associated successfully')

    // Update session with vendor_id if it's the first stand
    if (!session.vendor_id) {
      session.vendor_id = vendorId
      localStorage.setItem('trader_session', JSON.stringify(session))
    }

    // Clean up
    localStorage.removeItem('creating_vendor_id')

    // Refresh stands list
    await loadStands()

    // Redirect to orders page
    router.push(`/trader/orders?stand=${vendorId}`)
  } catch (err: any) {
    console.error('Error associating markets:', err)
    error.value = err.message || 'Erreur lors de l\'association des marchés'
    creating.value = false
  }
}

// Ouvrir le modal pour ajouter un marché à un stand existant
const openAddMarketModal = async (stand: any) => {
  if (!isOnline()) {
    alert('Vous devez être en ligne pour ajouter un marché')
    return
  }

  selectedStandForMarket.value = stand
  newMarketForm.value = {
    market_id: '',
    location: ''
  }
  addMarketError.value = null
  showAddMarketModal.value = true

  // Charger les marchés si pas encore chargés
  if (markets.value.length === 0) {
    await loadMarkets()
  }
}

// Fermer le modal d'ajout de marché
const closeAddMarketModal = () => {
  showAddMarketModal.value = false
  selectedStandForMarket.value = null
  newMarketForm.value = {
    market_id: '',
    location: ''
  }
  addMarketError.value = null
}

// Ajouter un marché à un stand existant
const addMarketToStand = async () => {
  if (!selectedStandForMarket.value || !newMarketForm.value.market_id || creating.value) {
    return
  }

  if (!isOnline()) {
    addMarketError.value = 'Vous devez être en ligne pour ajouter un marché'
    return
  }

  creating.value = true
  addMarketError.value = null

  try {
    // Vérifier si le stand est déjà associé à ce marché
    const { data: existing } = await supabase
      .from('vendor_markets')
      .select('id')
      .eq('vendor_id', selectedStandForMarket.value.id)
      .eq('market_id', newMarketForm.value.market_id)
      .maybeSingle()

    if (existing) {
      addMarketError.value = 'Ce stand est déjà associé à ce marché'
      creating.value = false
      return
    }

    // Créer l'association
    const { error: insertError } = await supabase
      .from('vendor_markets')
      .insert({
        vendor_id: selectedStandForMarket.value.id,
        market_id: newMarketForm.value.market_id,
        location: newMarketForm.value.location?.trim() || null
      })

    if (insertError) {
      throw insertError
    }

    // Rafraîchir les stands
    await syncService.syncVendors()
    await loadStands()

    // Fermer le modal
    closeAddMarketModal()
  } catch (err: any) {
    console.error('Error adding market to stand:', err)
    addMarketError.value = err.message || 'Erreur lors de l\'ajout du marché'
  } finally {
    creating.value = false
  }
}

// Skip market association (create stand without markets)
const skipMarketAssociation = async () => {
  const vendorId = localStorage.getItem('creating_vendor_id')

  if (!vendorId) {
    error.value = 'Session invalide. Veuillez recommencer.'
    router.push('/trader/home')
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

    // Update session with vendor_id if it's the first stand
    if (!session.vendor_id) {
      session.vendor_id = vendorId
      localStorage.setItem('trader_session', JSON.stringify(session))
    }

    // Clean up
    localStorage.removeItem('creating_vendor_id')

    // Refresh stands list
    await loadStands()

    // Redirect to orders page
    router.push(`/trader/orders?stand=${vendorId}`)
  } catch (err: any) {
    console.error('Error skipping market association:', err)
    error.value = err.message || 'Erreur lors de la finalisation'
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
  padding: 16px;
  padding-bottom: 80px;
  /* Space for bottom menu */
}

.loading {
  text-align: center;
  padding: 40px;
  font-size: 1.1rem;
  color: var(--color-text-secondary);
}

.stand-container {
  margin-top: 20px;
}

.stand-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 20px;
  box-shadow: 0 4px 16px rgba(102, 126, 234, 0.25);
  color: white;
}

.stand-header-content {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}

.stand-title-section {
  flex: 1;
}

.stand-title {
  font-size: 1.8rem;
  font-weight: 700;
  margin: 0 0 8px 0;
  color: white;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.stand-description {
  font-size: 0.95rem;
  color: rgba(255, 255, 255, 0.9);
  margin: 0;
  line-height: 1.5;
}

.markets-section {
  margin-top: 20px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  flex-wrap: wrap;
  gap: 12px;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 1.4rem;
  font-weight: 700;
  color: #2d3748;
  margin: 0;
}

.section-icon {
  font-size: 1.5rem;
}

.btn-add-market {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.85rem;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.btn-add-market:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.btn-add-market:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.add-icon {
  font-size: 1.2rem;
  font-weight: 700;
}

.markets-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 16px;
  margin-bottom: 16px;
}

.market-card {
  background: white;
  border: 2px solid #e2e8f0;
  border-radius: 12px;
  padding: 16px;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  position: relative;
  overflow: hidden;
}

.market-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
  transform: scaleX(0);
  transition: transform 0.3s ease;
}

.market-card:hover {
  transform: translateY(-6px);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.12);
  border-color: #667eea;
}

.market-card:hover::before {
  transform: scaleX(1);
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

.market-card-header {
  display: flex;
  align-items: center;
  gap: 10px;
  /*  margin-bottom: 12px;*/
  /*  padding-bottom: 12px;*/
  /*  border-bottom: 2px solid #f1f5f9;*/
}

.market-icon {
  font-size: 1.5rem;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 10px;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.25);
}

.market-header-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.market-name {
  font-weight: 700;
  font-size: 1.3rem;
  color: #1a202c;
  margin: 0;
}

.market-place {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  color: #64748b;
  font-size: 0.9rem;
}

.place-icon {
  font-size: 1rem;
  flex-shrink: 0;
}

.place-text {
  color: #64748b;
}

.market-location-inline {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-left: auto;
  padding-left: 12px;
  align-self: flex-start;
}

.location-separator {
  color: #cbd5e1;
  font-size: 1.2rem;
  font-weight: 300;
}

.location-text {
  color: #667eea;
  font-weight: 600;
  font-size: 0.95rem;
}

.market-details {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 12px;
}

.market-detail-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  font-size: 0.9rem;
  line-height: 1.4;
}

.market-detail-item.location-item {
  align-items: center;
}

.market-detail-item.next-market {
  padding-top: 8px;
  margin-top: 6px;
  border-top: 1px solid #e2e8f0;
}

.detail-icon {
  font-size: 1.1rem;
  flex-shrink: 0;
  margin-top: 2px;
}

.detail-label {
  color: #64748b;
  font-weight: 500;
}

.detail-text {
  color: #334155;
  flex: 1;
}

.detail-text.highlight {
  color: #667eea;
  font-weight: 600;
}

.detail-text.date-text {
  color: #f59e0b;
  font-weight: 600;
}

.market-actions {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: auto;
  padding-top: 12px;
  border-top: 1px solid #f1f5f9;
}

.btn-orders {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  text-decoration: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.85rem;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.btn-orders:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.btn-orders .arrow {
  font-size: 1.1rem;
  transition: transform 0.3s ease;
}

.btn-orders:hover .arrow {
  transform: translateX(4px);
}

.btn-start-commands {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 16px;
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  color: white;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
  width: 100%;
}

.btn-start-commands:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
}

.btn-start-commands:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-edit-location {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 8px 16px;
  background: #f8fafc;
  color: #475569;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.85rem;
  transition: all 0.3s ease;
}

.btn-edit-location:hover:not(:disabled) {
  background: #f1f5f9;
  border-color: #cbd5e1;
  color: #334155;
}

.btn-edit-location:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-edit-location-inline {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 3px 6px;
  background: transparent;
  color: #667eea;
  border: 1px solid #cbd5e1;
  border-radius: 5px;
  cursor: pointer;
  transition: all 0.2s ease;
  flex-shrink: 0;
  margin-left: 4px;
}

.btn-edit-location-inline:hover:not(:disabled) {
  background: #f1f5f9;
  border-color: #667eea;
  color: #764ba2;
}

.btn-edit-location-inline:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.edit-icon-small {
  font-size: 0.9rem;
}

.no-markets {
  text-align: center;
  padding: 40px 24px;
  background: #f8fafc;
  border: 2px dashed #cbd5e1;
  border-radius: 12px;
  margin-bottom: 16px;
}

.no-markets-icon {
  font-size: 3rem;
  margin-bottom: 12px;
  opacity: 0.5;
}

.no-markets-title {
  font-size: 1.1rem;
  font-weight: 700;
  color: #475569;
  margin: 0 0 6px 0;
}

.no-markets-hint {
  font-size: 0.9rem;
  color: #64748b;
  margin: 0;
  line-height: 1.5;
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
  max-width: 600px;
  margin: 40px auto;
}

.setup-card {
  background: white;
  border-radius: 12px;
  padding: 30px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.onboarding-header {
  text-align: center;
  margin-bottom: 30px;
}

.onboarding-header h2 {
  margin: 0 0 10px 0;
  font-size: 1.8rem;
  color: #333;
}

.setup-subtitle {
  color: #666;
  font-size: 1rem;
  margin: 0;
}

.step-indicator {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  margin-bottom: 20px;
}

.step-number {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: #e0e0e0;
  color: #999;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 1.1rem;
  transition: all 0.3s;
}

.step-number.active {
  background: var(--color-primary);
  color: white;
}

.step-line {
  width: 80px;
  height: 3px;
  background: #e0e0e0;
  transition: all 0.3s;
}

.step-line.active {
  background: var(--color-primary);
}

.stand-form {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.stand-form textarea {
  resize: vertical;
  min-height: 80px;
}

.markets-selection {
  display: flex;
  flex-direction: column;
  gap: 15px;
  max-height: 400px;
  overflow-y: auto;
  padding: 10px;
  border: 1px solid var(--color-border-medium);
  border-radius: 8px;
  background: #f9f9f9;
}

.market-checkbox-item {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
  background: white;
  border-radius: 6px;
  border: 1px solid var(--color-border-light);
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
}

.checkbox-label input[type="checkbox"] {
  width: 20px;
  height: 20px;
  cursor: pointer;
}

.checkbox-text {
  flex: 1;
  font-size: 1rem;
}

.location-input {
  margin-left: 30px;
  padding: 8px 12px;
  border: 1px solid var(--color-border-medium);
  border-radius: 6px;
  font-size: 0.9rem;
}

.btn-link {
  background: none;
  border: none;
  color: var(--color-primary);
  cursor: pointer;
  font-size: 0.9rem;
  text-decoration: underline;
  padding: 8px;
}

.btn-link:hover:not(:disabled) {
  color: var(--color-primary-hover);
}

.btn-link:disabled {
  opacity: 0.6;
  cursor: not-allowed;
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
