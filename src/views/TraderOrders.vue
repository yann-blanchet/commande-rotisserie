<template>
  <div class="trader-orders">
    <header class="header">
      <h1>🍗 Mes Commandes</h1>
      <div class="header-actions">
        <router-link to="/trader/home" class="btn-home">🏠 Mes Stands</router-link>
        <button @click="handleLogout" class="logout-btn">Déconnexion</button>
      </div>
    </header>

    <div class="status-bar">
      <span :class="['status-indicator', isOnline() ? 'online' : 'offline']">
        {{ isOnline() ? '🟢 En ligne' : '🔴 Hors ligne' }}
      </span>
      <button @click="refreshOrders" class="refresh-btn" :disabled="!isOnline()">
        Actualiser
      </button>
    </div>

    <div v-if="loading" class="loading">Chargement...</div>

    <!-- Onboarding Process -->
    <div v-else-if="needsSetup || needsMarketAssociation" class="setup-form">
      <!-- Debug info (temporary) -->
      <div style="padding: 10px; background: #f0f0f0; margin: 10px; border-radius: 4px; font-size: 0.85rem;">
        Debug: needsSetup={{ needsSetup }}, needsMarketAssociation={{ needsMarketAssociation }}, onboardingStep={{
          onboardingStep }}
      </div>
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

          <form @submit.prevent="saveStandInfo" class="stand-form">
            <div class="form-group">
              <label>Nom du stand *</label>
              <input v-model="standForm.nom" type="text" required placeholder="Ex: Stand Poulet Rôti du Marché"
                :disabled="saving" />
            </div>

            <div class="form-group">
              <label>Description</label>
              <textarea v-model="standForm.description" placeholder="Décrivez votre stand..." rows="3"
                :disabled="saving"></textarea>
            </div>

            <div class="form-actions">
              <button type="submit" class="btn-primary" :disabled="saving || !standForm.nom.trim()">
                {{ saving ? 'Enregistrement...' : 'Continuer' }}
              </button>
            </div>
          </form>
        </div>

        <!-- Step 2: Associer un marché -->
        <div v-else-if="onboardingStep === 2">
          <div class="onboarding-header">
            <div class="step-indicator">
              <span class="step-number active">1</span>
              <span class="step-line active"></span>
              <span class="step-number active">2</span>
            </div>
            <h2>🏪 Étape 2 : Associez votre stand à un marché</h2>
            <p class="setup-subtitle">Sélectionnez le marché où vous vendez</p>
          </div>

          <form @submit.prevent="associateMarket" class="stand-form">
            <div class="form-group">
              <label>Marché *</label>
              <select v-model="standForm.market_id" class="form-select" required :disabled="saving || loadingMarkets">
                <option value="">Sélectionnez un marché</option>
                <option v-for="market in availableMarkets" :key="market.id" :value="market.id">
                  {{ market.name }} - {{ market.place }}
                </option>
              </select>
              <small class="form-hint">Vous pourrez modifier cette association plus tard</small>
            </div>

            <div class="form-group">
              <label>Emplacement dans le marché</label>
              <input v-model="standForm.location" type="text" placeholder="Ex: Allée A, Stand 12"
                :disabled="saving || !standForm.market_id" class="form-input" />
              <small class="form-hint">Indiquez où se trouve votre stand dans le marché</small>
            </div>

            <div class="form-actions">
              <button type="button" @click="onboardingStep = 1" class="btn-secondary" :disabled="saving">
                Retour
              </button>
              <button type="submit" class="btn-primary" :disabled="saving || !standForm.market_id || loadingMarkets">
                {{ saving ? 'Association...' : 'Terminer' }}
              </button>
              <button type="button" @click="skipMarketAssociation" class="btn-link" :disabled="saving">
                Passer cette étape
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <div v-else class="orders-list">
      <!-- Market selector -->
      <div v-if="standMarkets && standMarkets.length > 0" class="market-selector-section">
        <label class="selector-label">Sélectionner un marché:</label>
        <select v-model="selectedMarketId" @change="onMarketChange" class="market-selector">
          <option value="">Tous les marchés</option>
          <option v-for="market in standMarkets" :key="market.id" :value="market.id">
            {{ market.name }} - {{ market.place }}
          </option>
        </select>
      </div>

      <!-- Market info and next market day -->
      <div v-if="selectedMarket && selectedMarket.markets" class="market-info-section">
        <div class="market-header-card">
          <div class="market-header-content">
            <div class="market-title-section">
              <h3 class="market-title">
                <span class="market-icon">🏪</span>
                {{ selectedMarket.markets.name }}
              </h3>
              <p v-if="selectedMarket.markets.place" class="market-place">
                <span class="place-icon">📍</span>
                {{ selectedMarket.markets.place }}
              </p>
            </div>
            <div v-if="nextMarketDateDisplay" class="next-market-day">
              <span class="date-icon">📅</span>
              <div class="date-info">
                <span class="date-label">Prochain marché:</span>
                <span class="date-value">{{ nextMarketDateDisplay }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="orders-grid">
        <div v-for="order in orders" :key="order.id" class="order-card" :class="{ 'picked-up': order.data.picked_up }">
          <div class="order-card-header">
            <div class="customer-info">
              <h3 class="customer-name">{{ order.data.customer_name }}</h3>
              <div class="order-meta">
                <div class="meta-item">
                  <span class="meta-icon">📅</span>
                  <span class="meta-label">Retrait:</span>
                  <span class="meta-value">{{ formatDateTime(order.data.pickup_time) }}</span>
                </div>
                <div class="meta-item">
                  <span class="meta-icon">🕐</span>
                  <span class="meta-label">Commandé:</span>
                  <span class="meta-value">{{ formatDateTime(order.data.created_at) }}</span>
                </div>
              </div>
            </div>
            <div class="order-status">
              <span v-if="order.data.picked_up" class="status-badge picked">
                <span class="badge-icon">✓</span>
                <span>Retiré</span>
              </span>
              <span v-else class="status-badge pending">
                <span class="badge-icon">⏳</span>
                <span>En attente</span>
              </span>
            </div>
          </div>

          <div class="order-product-section">
            <span class="product-icon">📦</span>
            <div class="product-info">
              <span class="product-label">Produit:</span>
              <span class="product-name">{{ getProductName(order.data.product_id) }}</span>
            </div>
          </div>

          <div class="order-actions" v-if="!order.data.picked_up">
            <button @click="markAsPickedUp(order)" class="btn-mark-picked">
              <span class="btn-icon">✓</span>
              <span>Marquer comme retiré</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="orders.length === 0 && !loading" class="empty-state">
      <p>Aucune commande pour le moment</p>
    </div>

    <!-- Edit Stand Modal -->
    <div v-if="showEditStand" class="modal-overlay" @click="closeEditModal">
      <div class="modal-content" @click.stop>
        <button class="close-btn" @click="closeEditModal">×</button>
        <h2>✏️ Éditer le stand</h2>

        <!-- Market Info Display -->
        <div v-if="marketInfo && (marketInfo.name || marketInfo.place)" class="market-info-display">
          <h3>🏪 Informations du marché</h3>
          <div class="market-details">
            <p v-if="marketInfo.name"><strong>Nom du marché :</strong> {{ marketInfo.name }}</p>
            <p v-if="marketInfo.place"><strong>📍 Lieu :</strong> {{ marketInfo.place }}</p>
          </div>
        </div>

        <div v-else-if="vendorInfo && !vendorInfo.market_id" class="market-info-display no-market">
          <p>ℹ️ Aucun marché associé à ce stand</p>
        </div>

        <form @submit.prevent="updateStand" class="stand-form">
          <div class="form-group">
            <label>Nom du stand *</label>
            <input v-model="standForm.nom" type="text" required placeholder="Ex: Stand Poulet Rôti du Marché"
              :disabled="saving" />
          </div>

          <div class="form-group">
            <label>Description</label>
            <textarea v-model="standForm.description" placeholder="Décrivez votre stand..." rows="3"
              :disabled="saving"></textarea>
          </div>

          <div class="form-hint">
            <small>💡 Pour modifier l'emplacement dans un marché, utilisez le bouton "Ajouter un marché" depuis la page
              Mes Stands</small>
          </div>

          <div class="form-actions">
            <button type="button" @click="closeEditModal" class="btn-secondary" :disabled="saving">
              Annuler
            </button>
            <button type="submit" class="btn-primary" :disabled="saving || !standForm.nom">
              {{ saving ? 'Enregistrement...' : 'Enregistrer' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <BottomMenuBar />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import { supabase, isOnline } from '../lib/supabase'
import type { OrderCache, ProductCache } from '../db/database'
import BottomMenuBar from '../components/BottomMenuBar.vue'

const router = useRouter()
const route = useRoute()
const orders = ref<OrderCache[]>([])
const products = ref<Map<string, ProductCache>>(new Map())
const loading = ref(true)
const traderVendorId = ref<string | null>(null)
const needsSetup = ref(false)
const needsMarketAssociation = ref(false)
const onboardingStep = ref(1)
const saving = ref(false)
const showEditStand = ref(false)
const vendorInfo = ref<any>(null)
const marketInfo = ref<{ name: string; place: string } | null>(null)
const availableMarkets = ref<any[]>([])
const loadingMarkets = ref(false)
const error = ref<string | null>(null)
const standMarkets = ref<any[]>([]) // Marchés associés au stand
const selectedMarket = ref<any>(null) // Marché sélectionné depuis l'URL
const selectedMarketId = ref<string>('') // ID du marché sélectionné dans le sélecteur
const nextMarketDateDisplay = ref<string | null>(null) // Prochain jour de marché formaté
const standForm = ref({
  nom: '',
  description: '',
  location: '',
  market_id: ''
})

const loadOrders = async () => {
  loading.value = true

  // Get trader's vendor ID from session
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

    // Check if a specific stand is requested via query parameter
    const standId = route.query.stand as string | undefined
    const marketId = route.query.market as string | undefined // Nouveau : filtrer par marché
    let vendorId: string | null = null

    if (standId) {
      // Verify that the stand belongs to the trader's profile
      const profileId = session.profile_id
      if (profileId && isOnline()) {
        const { data: vendor, error: vendorError } = await supabase
          .from('vendors')
          .select('id, profile_id')
          .eq('id', standId)
          .eq('profile_id', profileId)
          .maybeSingle()

        if (vendor && !vendorError) {
          vendorId = vendor.id
        } else {
          console.error('Stand not found or does not belong to trader')
          // Fall back to session vendor_id
          vendorId = session.vendor_id || null
        }
      } else {
        // Offline or no profile_id: use standId directly (trust the client)
        vendorId = standId
      }
    } else {
      // Use vendor_id from session
      vendorId = session.vendor_id || null
    }

    if (!vendorId) {
      router.push('/trader/login')
      return
    }

    traderVendorId.value = vendorId

    // Sync vendors first to ensure cache is up to date
    if (isOnline()) {
      await syncService.syncVendors()
    }

    // Get vendor info to check if setup is needed
    if (isOnline()) {
      const { data: vendor, error: vendorError } = await supabase
        .from('vendors')
        .select('*, vendor_markets(market_id, location, markets(*)), profiles(stand_nom, stand_description)')
        .eq('id', vendorId)
        .single()

      if (vendorError) {
        console.error('Error loading vendor:', vendorError)
        // If error is not critical (e.g., just missing profile relation), continue
        if (vendorError.code !== 'PGRST116' && vendorError.code !== '42P01') {
          error.value = `Erreur lors du chargement du stand: ${vendorError.message}`
          loading.value = false
          return
        }
      }

      if (vendor) {
        vendorInfo.value = vendor
        console.log('Vendor loaded:', vendor)

        // Handle vendor_markets (array of market associations)
        const vendorMarkets = Array.isArray(vendor.vendor_markets) ? vendor.vendor_markets : []
        const firstMarket = vendorMarkets.length > 0 ? vendorMarkets[0].markets : null

        // Charger les marchés associés au stand
        standMarkets.value = vendorMarkets
          .map((vm: any) => vm.markets)
          .filter((m: any) => m)

        // Trouver le marché sélectionné depuis l'URL
        const marketIdFromUrl = route.query.market as string | undefined
        if (marketIdFromUrl) {
          const foundMarket = vendorMarkets.find((vm: any) => vm.market_id === marketIdFromUrl)
          if (foundMarket) {
            selectedMarket.value = foundMarket
            // Calculer le prochain jour de marché
            if (foundMarket.markets && foundMarket.markets.days) {
              const nextDate = calculateNextMarketDate(foundMarket.markets.days)
              if (nextDate) {
                nextMarketDateDisplay.value = formatMarketDate(nextDate)
              }
            } else {
              // Si les données du marché ne sont pas complètes, charger depuis le cache
              const cachedMarket = await db.markets_cache.get(marketIdFromUrl)
              if (cachedMarket && cachedMarket.data.days) {
                const nextDate = calculateNextMarketDate(cachedMarket.data.days)
                if (nextDate) {
                  nextMarketDateDisplay.value = formatMarketDate(nextDate)
                }
              }
            }
          }
        } else if (vendorMarkets.length > 0) {
          // Si pas de marché dans l'URL, utiliser le premier
          selectedMarket.value = vendorMarkets[0]
          if (vendorMarkets[0].markets && vendorMarkets[0].markets.days) {
            const nextDate = calculateNextMarketDate(vendorMarkets[0].markets.days)
            if (nextDate) {
              nextMarketDateDisplay.value = formatMarketDate(nextDate)
            }
          } else {
            // Si les données du marché ne sont pas complètes, charger depuis le cache
            const cachedMarket = await db.markets_cache.get(vendorMarkets[0].market_id)
            if (cachedMarket && cachedMarket.data.days) {
              const nextDate = calculateNextMarketDate(cachedMarket.data.days)
              if (nextDate) {
                nextMarketDateDisplay.value = formatMarketDate(nextDate)
              }
            }
          }
        }

        console.log('Vendor markets:', vendorMarkets)
        console.log('First market:', firstMarket)
        console.log('Stand markets for filter:', standMarkets.value)
        console.log('Profile data:', vendor.profiles)

        // Store market info (use first market for backward compatibility)
        if (firstMarket && (firstMarket.name || firstMarket.place)) {
          marketInfo.value = {
            name: firstMarket.name || '',
            place: firstMarket.place || ''
          }
          console.log('Market info set:', marketInfo.value)
        } else {
          marketInfo.value = null
          console.log('No market info available')
        }

        // Get stand name/description from vendor (now stored in vendors table)
        // Fallback to profiles for backward compatibility
        const standNom = vendor.stand_nom ?? vendor.profiles?.stand_nom ?? null
        const standDescription = vendor.stand_description ?? vendor.profiles?.stand_description ?? null

        console.log('Onboarding check:', {
          standNom,
          standNomType: typeof standNom,
          standNomValue: standNom === null ? 'null' : standNom === undefined ? 'undefined' : `"${standNom}"`,
          standNomLength: standNom?.length || 0,
          hasStandName: standNom !== null && standNom !== undefined && typeof standNom === 'string' && standNom.trim() !== '',
          vendorMarketsCount: vendorMarkets.length,
          hasMarket: vendorMarkets.length > 0
        })

        // Initialize stand form with current values
        standForm.value = {
          nom: standNom || '',
          description: standDescription || '',
          location: vendorMarkets.length > 0 ? vendorMarkets[0].location || '' : '',
          market_id: vendorMarkets.length > 0 ? vendorMarkets[0].market_id || '' : ''
        }

        // Check onboarding status
        // A stand name is considered empty if it's null, undefined, or an empty string (after trim)
        const hasStandName = standNom !== null && standNom !== undefined && typeof standNom === 'string' && standNom.trim() !== ''
        const hasMarket = vendorMarkets.length > 0

        console.log('Final onboarding decision:', {
          hasStandName,
          hasMarket,
          needsSetup: !hasStandName,
          needsMarketAssociation: hasStandName && !hasMarket
        })

        if (!hasStandName) {
          // Step 1: Need to set name and description
          console.log('✅ Showing onboarding step 1 - No stand name')
          needsSetup.value = true
          needsMarketAssociation.value = false
          onboardingStep.value = 1
          loading.value = false
          return
        } else if (!hasMarket) {
          // Step 2: Need to associate market
          console.log('✅ Showing onboarding step 2 - No market')
          needsSetup.value = false
          needsMarketAssociation.value = true
          onboardingStep.value = 2
          // Load markets for selection
          await loadMarkets()
          loading.value = false
          return
        } else {
          // Stand is fully configured
          console.log('✅ Stand is fully configured, no onboarding needed')
          needsSetup.value = false
          needsMarketAssociation.value = false
        }
      } else {
        // No vendor found - this shouldn't happen but handle it
        console.error('No vendor found for id:', vendorId)
        error.value = 'Stand introuvable. Veuillez réessayer.'
        loading.value = false
        return
      }
    } else {
      // Offline: check cache
      const cachedVendor = await db.vendors_cache.get(vendorId)
      if (cachedVendor) {
        vendorInfo.value = cachedVendor.data
        console.log('Cached vendor loaded:', cachedVendor.data)
        console.log('Cached market data:', cachedVendor.data.markets)
        console.log('Cached profile data:', cachedVendor.data.profiles)

        // Store market info from cache
        if (cachedVendor.data.markets && (cachedVendor.data.markets.name || cachedVendor.data.markets.place)) {
          marketInfo.value = {
            name: cachedVendor.data.markets.name || '',
            place: cachedVendor.data.markets.place || ''
          }
          console.log('Market info from cache set:', marketInfo.value)
        } else {
          marketInfo.value = null
          console.log('No market info in cache')
        }

        // Get stand name/description from profile (not vendor)
        // Note: profiles might be an array or an object depending on cache structure
        const profile = Array.isArray(cachedVendor.data.profiles)
          ? cachedVendor.data.profiles[0]
          : cachedVendor.data.profiles
        const standNom = profile?.stand_nom || cachedVendor.data.stand_nom || ''
        const standDescription = profile?.stand_description || cachedVendor.data.stand_description || ''

        console.log('Onboarding check (offline):', {
          standNom,
          hasStandName: standNom && standNom.trim() !== '',
          market_id: cachedVendor.data.market_id,
          hasMarket: cachedVendor.data.market_id !== null && cachedVendor.data.market_id !== undefined
        })

        // Initialize stand form with current values
        // Get location from vendor_markets (or fallback to cached location for backward compatibility)
        const cachedVendorMarkets = Array.isArray(cachedVendor.data.vendor_markets) ? cachedVendor.data.vendor_markets : []
        const cachedLocation = cachedVendorMarkets.length > 0 ? cachedVendorMarkets[0].location : (cachedVendor.data.location || '')
        const cachedMarketId = cachedVendorMarkets.length > 0 ? cachedVendorMarkets[0].market_id : (cachedVendor.data.market_id || '')

        // Initialiser le sélecteur de marché depuis l'URL (offline)
        const marketIdFromUrl = route.query.market as string | undefined
        if (marketIdFromUrl && cachedVendorMarkets.length > 0) {
          selectedMarketId.value = marketIdFromUrl
          const foundMarket = cachedVendorMarkets.find((vm: any) => vm.market_id === marketIdFromUrl)
          if (foundMarket) {
            // Charger les données complètes du marché depuis le cache si nécessaire
            let marketData = foundMarket.markets
            if (!marketData || !marketData.days) {
              const cachedMarket = await db.markets_cache.get(marketIdFromUrl)
              if (cachedMarket) {
                marketData = cachedMarket.data
              }
            }
            selectedMarket.value = {
              ...foundMarket,
              markets: marketData || foundMarket.markets
            }
            // Calculer le prochain jour de marché si disponible
            if (marketData && marketData.days) {
              const nextDate = calculateNextMarketDate(marketData.days)
              if (nextDate) {
                nextMarketDateDisplay.value = formatMarketDate(nextDate)
              }
            }
          }
        } else if (cachedVendorMarkets.length > 0) {
          // Si pas de marché dans l'URL, utiliser le premier
          selectedMarketId.value = cachedVendorMarkets[0].market_id
          const firstMarket = cachedVendorMarkets[0]
          let marketData = firstMarket.markets
          if (!marketData || !marketData.days) {
            const cachedMarket = await db.markets_cache.get(firstMarket.market_id)
            if (cachedMarket) {
              marketData = cachedMarket.data
            }
          }
          selectedMarket.value = {
            ...firstMarket,
            markets: marketData || firstMarket.markets
          }
          if (marketData && marketData.days) {
            const nextDate = calculateNextMarketDate(marketData.days)
            if (nextDate) {
              nextMarketDateDisplay.value = formatMarketDate(nextDate)
            }
          }
        }

        standForm.value = {
          nom: standNom,
          description: standDescription,
          location: cachedLocation,
          market_id: cachedMarketId
        }
        // Check onboarding status (offline mode)
        const hasStandName = standNom && standNom.trim() !== ''
        const hasMarket = cachedVendorMarkets.length > 0 || (cachedVendor.data.market_id !== null && cachedVendor.data.market_id !== undefined)

        if (!hasStandName) {
          console.log('Showing onboarding step 1 (offline)')
          needsSetup.value = true
          needsMarketAssociation.value = false
          onboardingStep.value = 1
          loading.value = false
          return
        } else if (!hasMarket) {
          console.log('Showing onboarding step 2 (offline)')
          needsSetup.value = false
          needsMarketAssociation.value = true
          onboardingStep.value = 2
          loading.value = false
          return
        } else {
          console.log('Stand is fully configured (offline), no onboarding needed')
          needsSetup.value = false
          needsMarketAssociation.value = false
        }
      }
    }

    // Sync orders if online
    if (isOnline()) {
      await syncService.syncOrdersForVendor(vendorId)
    }

    // Load from cache
    let cachedOrders = await db.orders_cache
      .where('vendor_id')
      .equals(vendorId)
      .toArray()

    // Filtrer par marché si un marché est sélectionné
    if (selectedMarketId.value) {
      cachedOrders = cachedOrders.filter(order =>
        order.data.market_id === selectedMarketId.value
      )
    }

    orders.value = cachedOrders.sort((a, b) =>
      new Date(b.data.created_at).getTime() - new Date(a.data.created_at).getTime()
    )

    // Load products for display
    const allProducts = await db.products_cache.toArray()
    products.value = new Map(allProducts.map(p => [p.id, p]))
  } catch (error) {
    console.error('Error loading orders:', error)
  } finally {
    loading.value = false
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
    availableMarkets.value = cachedMarkets
      .map(m => m.data)
      .sort((a, b) => (a.name || '').localeCompare(b.name || ''))
  } catch (error) {
    console.error('Error loading markets:', error)
  } finally {
    loadingMarkets.value = false
  }
}

const saveStandInfo = async () => {
  if (!standForm.value.nom.trim() || !traderVendorId.value) {
    return
  }

  saving.value = true

  try {
    if (!isOnline()) {
      alert('Vous devez être en ligne pour enregistrer les informations du stand')
      saving.value = false
      return
    }

    // Update vendor with stand_nom and stand_description (now in vendors table)
    const { error: vendorUpdateError } = await supabase
      .from('vendors')
      .update({
        stand_nom: standForm.value.nom.trim(),
        stand_description: standForm.value.description.trim() || null
      })
      .eq('id', traderVendorId.value)

    if (vendorUpdateError) {
      throw vendorUpdateError
    }

    // Refresh vendor cache
    await syncService.syncVendors()

    // Move to step 2
    onboardingStep.value = 2
    needsSetup.value = false
    needsMarketAssociation.value = true
    await loadMarkets()
  } catch (error: any) {
    console.error('Error saving stand info:', error)
    alert('Erreur lors de l\'enregistrement: ' + (error.message || 'Erreur inconnue'))
  } finally {
    saving.value = false
  }
}

const associateMarket = async () => {
  if (!standForm.value.market_id || !traderVendorId.value) {
    return
  }

  saving.value = true

  try {
    if (!isOnline()) {
      alert('Vous devez être en ligne pour associer un marché')
      saving.value = false
      return
    }

    // Check if vendor is already associated with this market
    const { data: existing } = await supabase
      .from('vendor_markets')
      .select('id')
      .eq('vendor_id', traderVendorId.value)
      .eq('market_id', standForm.value.market_id)
      .maybeSingle()

    if (existing) {
      // Update existing association with location if provided
      if (standForm.value.location && standForm.value.location.trim()) {
        const { error: updateError } = await supabase
          .from('vendor_markets')
          .update({ location: standForm.value.location.trim() })
          .eq('id', existing.id)

        if (updateError) {
          throw updateError
        }
      }
    } else {
      // Create new association in vendor_markets
      const { error: insertError } = await supabase
        .from('vendor_markets')
        .insert({
          vendor_id: traderVendorId.value,
          market_id: standForm.value.market_id,
          location: standForm.value.location?.trim() || null
        })

      if (insertError) {
        throw insertError
      }
    }

    // Refresh vendor cache
    await syncService.syncVendors()

    // Onboarding complete
    needsMarketAssociation.value = false
    onboardingStep.value = 1
    await loadOrders()
  } catch (error: any) {
    console.error('Error associating market:', error)
    alert('Erreur lors de l\'association du marché: ' + (error.message || 'Erreur inconnue'))
  } finally {
    saving.value = false
  }
}

const skipMarketAssociation = async () => {
  if (!confirm('Êtes-vous sûr de vouloir passer cette étape ? Vous pourrez associer un marché plus tard.')) {
    return
  }

  // Just reload orders, stand is configured (without market)
  needsMarketAssociation.value = false
  onboardingStep.value = 1
  await loadOrders()
}


const updateStand = async () => {
  if (!standForm.value.nom.trim() || !traderVendorId.value) {
    return
  }

  saving.value = true

  try {
    if (!isOnline()) {
      alert('Vous devez être en ligne pour modifier votre stand')
      saving.value = false
      return
    }

    // Update vendor with stand_nom and stand_description (now in vendors table)
    // Note: location is managed per market via vendor_markets, not here
    const { error: vendorUpdateError } = await supabase
      .from('vendors')
      .update({
        stand_nom: standForm.value.nom.trim(),
        stand_description: standForm.value.description.trim() || null
      })
      .eq('id', traderVendorId.value)

    if (vendorUpdateError) {
      throw vendorUpdateError
    }

    // Refresh vendor cache
    await syncService.syncVendors()

    // Reload page data
    needsSetup.value = false
    showEditStand.value = false
    await loadOrders()
  } catch (error: any) {
    console.error('Error updating stand:', error)
    alert('Erreur lors de la mise à jour du stand: ' + (error.message || 'Erreur inconnue'))
  } finally {
    saving.value = false
  }
}

const openEditModal = async () => {
  showEditStand.value = true
  // Reload vendor info to ensure market data is fresh
  if (traderVendorId.value) {
    if (isOnline()) {
      const { data: vendor, error } = await supabase
        .from('vendors')
        .select('*, vendor_markets(market_id, location, markets(*)), profiles(stand_nom, stand_description)')
        .eq('id', traderVendorId.value)
        .single()

      if (!error && vendor) {
        vendorInfo.value = vendor
        // Handle vendor_markets (array of market associations)
        const vendorMarkets = Array.isArray(vendor.vendor_markets) ? vendor.vendor_markets : []
        const firstMarket = vendorMarkets.length > 0 ? vendorMarkets[0].markets : null

        if (firstMarket && (firstMarket.name || firstMarket.place)) {
          marketInfo.value = {
            name: firstMarket.name || '',
            place: firstMarket.place || ''
          }
        } else {
          marketInfo.value = null
        }
        // Update form with current values from vendor (stand_nom/stand_description now in vendors table)
        // Note: location and market_id are not edited here, they're managed per market
        standForm.value = {
          nom: vendor.stand_nom || vendor.profiles?.stand_nom || '',
          description: vendor.stand_description || vendor.profiles?.stand_description || '',
          location: '', // Not used in edit form
          market_id: '' // Not used in edit form
        }
      }
    } else {
      // Offline: use cache
      const cachedVendor = await db.vendors_cache.get(traderVendorId.value)
      if (cachedVendor) {
        vendorInfo.value = cachedVendor.data
        if (cachedVendor.data.markets && (cachedVendor.data.markets.name || cachedVendor.data.markets.place)) {
          marketInfo.value = {
            name: cachedVendor.data.markets.name || '',
            place: cachedVendor.data.markets.place || ''
          }
        } else {
          marketInfo.value = null
        }
        // Get stand name/description from vendor (stand_nom/stand_description now in vendors table)
        const standNom = cachedVendor.data.profiles?.stand_nom || cachedVendor.data.stand_nom || ''
        const standDescription = cachedVendor.data.profiles?.stand_description || cachedVendor.data.stand_description || ''

        standForm.value = {
          nom: standNom,
          description: standDescription,
          location: '', // Not used in edit form
          market_id: '' // Not used in edit form
        }
      }
    }
  }
}

const closeEditModal = () => {
  showEditStand.value = false
  // Reset form to current vendor values
  if (vendorInfo.value) {
    const standNom = vendorInfo.value.profiles?.stand_nom || vendorInfo.value.stand_nom || ''
    const standDescription = vendorInfo.value.profiles?.stand_description || vendorInfo.value.stand_description || ''

    standForm.value = {
      nom: standNom,
      description: standDescription,
      location: '', // Not used in edit form
      market_id: '' // Not used in edit form
    }
  }
}

const refreshOrders = async () => {
  if (isOnline() && traderVendorId.value) {
    await syncService.syncOrdersForVendor(traderVendorId.value)
    await loadOrders()
  }
}

const markAsPickedUp = async (order: OrderCache) => {
  try {
    const updatedOrder = {
      ...order.data,
      picked_up: true,
      picked_up_at: new Date().toISOString()
    }

    // Update in cache immediately (offline-first)
    await db.orders_cache.update(order.id, {
      data: updatedOrder,
      updated_at: new Date().toISOString()
    })

    // Try to sync to Supabase if online
    if (isOnline()) {
      const { error } = await supabase
        .from('orders')
        .update({ picked_up: true, picked_up_at: updatedOrder.picked_up_at })
        .eq('id', order.id)

      if (error) throw error
    }

    // Reload orders
    await loadOrders()
  } catch (error) {
    console.error('Error marking order as picked up:', error)
    alert('Erreur lors de la mise à jour')
  }
}

const getProductName = (productId: string): string => {
  const product = products.value.get(productId)
  return product?.data.nom || product?.data.name || 'Produit inconnu'
}

const formatDateTime = (dateString: string): string => {
  const date = new Date(dateString)
  return new Intl.DateTimeFormat('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  }).format(date)
}

const handleLogout = async () => {
  localStorage.removeItem('trader_session')
  router.push('/trader/login')
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

const onMarketChange = () => {
  if (selectedMarketId.value) {
    const foundMarket = standMarkets.value.find((m: any) => m.id === selectedMarketId.value)
    if (foundMarket) {
      // Find the vendor_market association
      const vendorMarkets = Array.isArray(vendorInfo.value?.vendor_markets) ? vendorInfo.value.vendor_markets : []
      const marketAssociation = vendorMarkets.find((vm: any) => vm.market_id === selectedMarketId.value)
      if (marketAssociation) {
        selectedMarket.value = marketAssociation
        // Calculate next market date
        if (marketAssociation.markets && marketAssociation.markets.days) {
          const nextDate = calculateNextMarketDate(marketAssociation.markets.days)
          if (nextDate) {
            nextMarketDateDisplay.value = formatMarketDate(nextDate)
          }
        }
      }
    }
    // Reload orders with filter
    loadOrders()
  } else {
    selectedMarket.value = null
    nextMarketDateDisplay.value = null
    loadOrders()
  }
}

// Auto-refresh when coming online
let onlineHandler: () => void
onMounted(() => {
  loadOrders()
  onlineHandler = () => {
    if (traderVendorId.value) {
      refreshOrders()
    }
  }
  window.addEventListener('online', onlineHandler)
})

onUnmounted(() => {
  if (onlineHandler) {
    window.removeEventListener('online', onlineHandler)
  }
})
</script>

<style scoped>
.trader-orders {
  max-width: 1200px;
  margin: 0 auto;
  padding: 16px;
  padding-bottom: 80px;
  /* Space for bottom menu */
}

.market-selector-section {
  background: white;
  border: 2px solid #e2e8f0;
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.selector-label {
  display: block;
  font-weight: 600;
  color: #334155;
  font-size: 0.95rem;
  margin-bottom: 8px;
}

.market-selector {
  width: 100%;
  padding: 10px 14px;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.95rem;
  background: white;
  cursor: pointer;
  transition: all 0.2s ease;
}

.market-selector:hover {
  border-color: #cbd5e1;
}

.market-selector:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 16px 0;
  border-bottom: 2px solid #e2e8f0;
}

.header h1 {
  font-size: 1.8rem;
  font-weight: 800;
  margin: 0;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.btn-home {
  padding: 10px 18px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  text-decoration: none;
  display: inline-block;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.btn-home:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.logout-btn {
  padding: 10px 20px;
  background: #fee2e2;
  color: #dc2626;
  border: 2px solid #fecaca;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.9rem;
  transition: all 0.3s ease;
}

.logout-btn:hover {
  background: #dc2626;
  color: white;
  border-color: #dc2626;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
}

.status-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 10px 16px;
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.status-indicator {
  font-weight: 600;
}

.status-indicator.online {
  color: #4caf50;
}

.status-indicator.offline {
  color: #f44336;
}

.refresh-btn {
  padding: 8px 16px;
  background: #ff6b35;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
}

.refresh-btn:hover:not(:disabled) {
  background: #e55a2b;
}

.refresh-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.loading {
  text-align: center;
  padding: 40px;
  color: #666;
}

.orders-list {
  margin-top: 20px;
}

.market-info-section {
  margin-bottom: 20px;
}

.market-header-card {
  background: white;
  border: 2px solid #e2e8f0;
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.market-header-content {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 20px;
  flex-wrap: wrap;
}

.market-title-section {
  flex: 1;
  min-width: 200px;
}

.market-title {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 0 8px 0;
  font-size: 1.5rem;
  font-weight: 700;
  color: #1a202c;
}

.market-icon {
  font-size: 1.8rem;
}

.market-place {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  color: #64748b;
  font-size: 0.95rem;
}

.place-icon {
  font-size: 1.1rem;
}

.next-market-day {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
  border: 2px solid #93c5fd;
  border-radius: 10px;
  min-width: 250px;
}

.date-icon {
  font-size: 1.5rem;
  flex-shrink: 0;
}

.date-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.date-label {
  font-size: 0.85rem;
  color: #1e40af;
  font-weight: 600;
}

.date-value {
  font-size: 1rem;
  color: #1e3a8a;
  font-weight: 700;
}

.orders-grid {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.order-card {
  background: white;
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  border: 2px solid #e2e8f0;
  border-left: 4px solid #667eea;
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}

.order-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 4px;
  height: 100%;
  background: linear-gradient(180deg, #667eea 0%, #764ba2 100%);
  transition: width 0.3s ease;
}

.order-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  border-color: #cbd5e1;
}

.order-card.picked-up {
  opacity: 0.75;
  border-left-color: #10b981;
}

.order-card.picked-up::before {
  background: linear-gradient(180deg, #10b981 0%, #059669 100%);
}

.order-card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 2px solid #f1f5f9;
}

.customer-info {
  flex: 1;
}

.customer-name {
  margin: 0 0 12px 0;
  font-size: 1.4rem;
  font-weight: 700;
  color: #1a202c;
}

.order-meta {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.9rem;
}

.meta-icon {
  font-size: 1rem;
  flex-shrink: 0;
}

.meta-label {
  color: #64748b;
  font-weight: 500;
}

.meta-value {
  color: #334155;
  font-weight: 600;
}

.order-status {
  flex-shrink: 0;
}

.status-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border-radius: 20px;
  font-size: 0.85rem;
  font-weight: 600;
  white-space: nowrap;
}

.status-badge .badge-icon {
  font-size: 1rem;
}

.status-badge.pending {
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
  color: #92400e;
  border: 1px solid #fcd34d;
}

.status-badge.picked {
  background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
  color: #065f46;
  border: 1px solid #6ee7b7;
}

.order-product-section {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
  border-radius: 10px;
  margin-bottom: 16px;
  border: 1px solid #e2e8f0;
}

.product-icon {
  font-size: 1.5rem;
  flex-shrink: 0;
}

.product-info {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
}

.product-label {
  color: #64748b;
  font-weight: 600;
  font-size: 0.9rem;
}

.product-name {
  color: #1a202c;
  font-weight: 600;
  font-size: 1rem;
}

.order-actions {
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid #f1f5f9;
}

.btn-mark-picked {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  padding: 12px 20px;
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  color: white;
  border: none;
  border-radius: 10px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.95rem;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
}

.btn-mark-picked:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
}

.btn-icon {
  font-size: 1.1rem;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #64748b;
  background: #f8fafc;
  border-radius: 12px;
  border: 2px dashed #cbd5e1;
  margin-top: 20px;
}

.empty-state p {
  font-size: 1.1rem;
  margin: 0;
}

.header-actions {
  display: flex;
  gap: 10px;
  align-items: center;
}

.btn-secondary {
  padding: 10px 20px;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  text-decoration: none;
  display: inline-block;
}

.btn-secondary:hover {
  background: #5568d3;
}

.setup-form {
  max-width: 600px;
  margin: 40px auto;
}

.setup-card {
  background: white;
  border-radius: 12px;
  padding: 30px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.setup-card h2 {
  margin: 0 0 10px 0;
  font-size: 1.8rem;
  color: #333;
}

.setup-subtitle {
  color: #666;
  margin-bottom: 30px;
  text-align: center;
  font-size: 1rem;
}

.onboarding-header {
  margin-bottom: 30px;
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

.stand-form .form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.stand-form label {
  font-weight: 600;
  color: #333;
}

.stand-form input,
.stand-form textarea {
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 1rem;
  font-family: inherit;
}

.stand-form textarea {
  resize: vertical;
}

.stand-form input:disabled,
.stand-form textarea:disabled {
  background: #f5f5f5;
  cursor: not-allowed;
}

.form-actions {
  display: flex;
  gap: 10px;
  margin-top: 25px;
  flex-wrap: wrap;
}

.form-actions .btn-primary,
.form-actions .btn-secondary {
  flex: 1;
  min-width: 120px;
}

.form-actions .btn-link {
  width: 100%;
  padding: 10px;
  background: transparent;
  color: #666;
  border: none;
  cursor: pointer;
  text-decoration: underline;
  font-size: 0.9rem;
}

.form-actions .btn-link:hover:not(:disabled) {
  color: var(--color-primary);
}

.form-actions .btn-link:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.form-select,
.form-input {
  width: 100%;
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 1rem;
  background: white;
  font-family: inherit;
}

.form-select:disabled,
.form-input:disabled {
  background: #f5f5f5;
  cursor: not-allowed;
  opacity: 0.6;
}

.form-hint {
  display: block;
  margin-top: 6px;
  font-size: 0.85rem;
  color: #666;
  font-style: italic;
}


.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: var(--color-overlay);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: var(--color-bg-white);
  border-radius: 12px;
  padding: 30px;
  max-width: 600px;
  width: 90%;
  max-height: 90vh;
  overflow-y: auto;
  position: relative;
}

.modal-content .close-btn {
  position: absolute;
  top: 15px;
  right: 15px;
  background: none;
  border: none;
  font-size: 2rem;
  cursor: pointer;
  color: var(--color-text-secondary);
  line-height: 1;
}

.modal-content .close-btn:hover {
  color: var(--color-text-primary);
}

.modal-content h2 {
  margin: 0 0 25px 0;
  font-size: 1.8rem;
}

.modal-content .form-actions {
  display: flex;
  gap: 10px;
  margin-top: 20px;
}

.modal-content .btn-primary {
  flex: 1;
  padding: 12px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  font-weight: 600;
}

.modal-content .btn-primary:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.modal-content .btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.market-info-display {
  margin-bottom: 25px;
  padding: 15px;
  background: var(--color-info-light);
  border-radius: 8px;
  border-left: 4px solid var(--color-primary);
}

.market-info-display h3 {
  margin: 0 0 10px 0;
  font-size: 1.1rem;
  color: var(--color-text-primary);
}

.market-details {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.market-details p {
  margin: 0;
  color: var(--color-text-secondary);
  font-size: 0.95rem;
}

.market-details strong {
  color: var(--color-text-primary);
  font-weight: 600;
}

.market-info-display.no-market {
  background: var(--color-warning-light);
  border-left-color: var(--color-warning);
}

.market-info-display.no-market p {
  margin: 0;
  color: var(--color-warning-dark);
  font-style: italic;
}
</style>
