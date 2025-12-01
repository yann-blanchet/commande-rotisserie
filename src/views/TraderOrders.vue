<template>
  <div class="trader-orders">
    <header class="header">
      <h1>🍗 Mes Commandes</h1>
      <div class="header-actions">
        <router-link to="/trader/home" class="btn-home">🏠 Mes Stands</router-link>
        <button @click="openEditModal" class="btn-edit-stand">✏️ Éditer le stand</button>
        <button @click="goToProducts" class="btn-secondary">Gérer les produits</button>
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

    <!-- Debug info (temporary) -->
    <div v-if="!loading" style="padding: 10px; background: #f0f0f0; margin: 10px; border-radius: 4px; font-size: 0.85rem;">
      Debug: needsSetup={{ needsSetup }}, needsMarketAssociation={{ needsMarketAssociation }}, onboardingStep={{ onboardingStep }}
    </div>

    <!-- Onboarding Process -->
    <div v-else-if="needsSetup || needsMarketAssociation" class="setup-form">
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
              <input 
                v-model="standForm.location" 
                type="text" 
                placeholder="Ex: Allée A, Stand 12" 
                :disabled="saving || !standForm.market_id"
                class="form-input"
              />
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
      <div v-for="order in orders" :key="order.id" class="order-card" :class="{ 'picked-up': order.data.picked_up }">
        <div class="order-header">
          <div>
            <h3>{{ order.data.customer_name }}</h3>
            <p class="order-time">
              Retrait: {{ formatDateTime(order.data.pickup_time) }}
            </p>
            <p class="order-created">
              Commandé: {{ formatDateTime(order.data.created_at) }}
            </p>
          </div>
          <div class="order-status">
            <span v-if="order.data.picked_up" class="status-badge picked">Retiré</span>
            <span v-else class="status-badge pending">En attente</span>
          </div>
        </div>
        <div class="order-product">
          <strong>Produit:</strong> {{ getProductName(order.data.product_id) }}
        </div>
        <div class="order-actions">
          <button v-if="!order.data.picked_up" @click="markAsPickedUp(order)" class="btn-mark-picked">
            Marquer comme retiré
          </button>
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

          <div class="form-group">
            <label>Emplacement</label>
            <input v-model="standForm.location" type="text" placeholder="Ex: Allée A, Stand 12" :disabled="saving" />
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
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import { supabase, isOnline } from '../lib/supabase'
import type { OrderCache, ProductCache } from '../db/database'

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
        .select('*, markets(*), profiles(stand_nom, stand_description)')
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
        console.log('Market data:', vendor.markets)
        console.log('Profile data:', vendor.profiles)
        console.log('Profile data type:', typeof vendor.profiles, Array.isArray(vendor.profiles))
        
        // Store market info
        if (vendor.markets && (vendor.markets.name || vendor.markets.place)) {
          marketInfo.value = {
            name: vendor.markets.name || '',
            place: vendor.markets.place || ''
          }
          console.log('Market info set:', marketInfo.value)
        } else {
          marketInfo.value = null
          console.log('No market info available')
        }
        
        // Get stand name/description from profile (not vendor)
        // Note: profiles might be an array or an object depending on Supabase version
        const profile = Array.isArray(vendor.profiles) ? vendor.profiles[0] : vendor.profiles
        console.log('Extracted profile:', profile)
        
        const standNom = profile?.stand_nom || null || ''
        const standDescription = profile?.stand_description || null || ''
        
        console.log('Onboarding check:', {
          profile,
          standNom,
          standNomType: typeof standNom,
          standNomValue: `"${standNom}"`,
          standNomLength: standNom?.length || 0,
          hasStandName: standNom && standNom.trim() !== '',
          market_id: vendor.market_id,
          hasMarket: vendor.market_id !== null && vendor.market_id !== undefined
        })
        
        // Initialize stand form with current values
        standForm.value = {
          nom: standNom || '',
          description: standDescription || '',
          location: vendor.location || '',
          market_id: vendor.market_id || ''
        }
        
        // Check onboarding status
        // A stand name is considered empty if it's null, undefined, or an empty string (after trim)
        const hasStandName = standNom !== null && standNom !== undefined && standNom.trim() !== ''
        const hasMarket = vendor.market_id !== null && vendor.market_id !== undefined
        
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
        standForm.value = {
          nom: standNom,
          description: standDescription,
          location: cachedVendor.data.location || '',
          market_id: cachedVendor.data.market_id || ''
        }
        // Check onboarding status (offline mode)
        const hasStandName = standNom && standNom.trim() !== ''
        const hasMarket = cachedVendor.data.market_id !== null && cachedVendor.data.market_id !== undefined
        
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
    const cachedOrders = await db.orders_cache
      .where('vendor_id')
      .equals(vendorId)
      .toArray()

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

    // Get vendor to find profile_id
    const { data: vendor, error: vendorError } = await supabase
      .from('vendors')
      .select('profile_id')
      .eq('id', traderVendorId.value)
      .single()

    if (vendorError || !vendor || !vendor.profile_id) {
      throw new Error('Impossible de trouver le profil associé')
    }

    // Update profile with stand_nom and stand_description
    const { error: profileError } = await supabase
      .from('profiles')
      .update({
        stand_nom: standForm.value.nom.trim(),
        stand_description: standForm.value.description.trim() || null
      })
      .eq('id', vendor.profile_id)

    if (profileError) {
      throw profileError
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

    // Update vendor with market_id and location
    const updateData: any = {
      market_id: standForm.value.market_id
    }

    if (standForm.value.location && standForm.value.location.trim()) {
      updateData.location = standForm.value.location.trim()
    }

    const { error: vendorUpdateError } = await supabase
      .from('vendors')
      .update(updateData)
      .eq('id', traderVendorId.value)

    if (vendorUpdateError) {
      throw vendorUpdateError
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

const createStand = async () => {
  await updateStand()
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

    // Get vendor to find profile_id
    const { data: vendor, error: vendorError } = await supabase
      .from('vendors')
      .select('profile_id')
      .eq('id', traderVendorId.value)
      .single()

    if (vendorError || !vendor || !vendor.profile_id) {
      throw new Error('Impossible de trouver le profil associé')
    }

    // Update profile with stand_nom and stand_description
    const { error: profileError } = await supabase
      .from('profiles')
      .update({
        stand_nom: standForm.value.nom.trim(),
        stand_description: standForm.value.description.trim() || null
      })
      .eq('id', vendor.profile_id)

    if (profileError) {
      throw profileError
    }

    // Update vendor with location only
    const { error: vendorUpdateError } = await supabase
      .from('vendors')
      .update({
        location: standForm.value.location.trim() || null
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
        .select('*, markets(*), profiles(stand_nom, stand_description)')
        .eq('id', traderVendorId.value)
        .single()
      
      if (!error && vendor) {
        vendorInfo.value = vendor
        if (vendor.markets && (vendor.markets.name || vendor.markets.place)) {
          marketInfo.value = {
            name: vendor.markets.name || '',
            place: vendor.markets.place || ''
          }
        } else {
          marketInfo.value = null
        }
        // Update form with current values from profile
        standForm.value = {
          nom: vendor.profiles?.stand_nom || '',
          description: vendor.profiles?.stand_description || '',
          location: vendor.location || '',
          market_id: vendor.market_id || ''
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
        // Get stand name/description from profile (not vendor)
        const standNom = cachedVendor.data.profiles?.stand_nom || cachedVendor.data.stand_nom || ''
        const standDescription = cachedVendor.data.profiles?.stand_description || cachedVendor.data.stand_description || ''
        standForm.value = {
          nom: standNom,
          description: standDescription,
          location: cachedVendor.data.location || '',
          market_id: cachedVendor.data.market_id || ''
        }
      }
    }
  }
}

const closeEditModal = () => {
  showEditStand.value = false
  // Reset form to current vendor values from profile
  if (vendorInfo.value) {
    const standNom = vendorInfo.value.profiles?.stand_nom || vendorInfo.value.stand_nom || ''
    const standDescription = vendorInfo.value.profiles?.stand_description || vendorInfo.value.stand_description || ''
    standForm.value = {
      nom: standNom,
      description: standDescription,
      location: vendorInfo.value.location || '',
      market_id: vendorInfo.value.market_id || ''
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

const goToProducts = () => {
  router.push('/trader/products')
}

const handleLogout = async () => {
  localStorage.removeItem('trader_session')
  router.push('/trader/login')
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
  padding: 20px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
}

.header h1 {
  font-size: 2rem;
  margin: 0;
}

.btn-home {
  padding: 10px 20px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  text-decoration: none;
  display: inline-block;
}

.btn-home:hover {
  background: var(--color-primary-hover);
}

.logout-btn {
  padding: 10px 20px;
  background: #f0f0f0;
  color: #333;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
}

.logout-btn:hover {
  background: #e0e0e0;
}

.status-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 15px;
  background: #f9f9f9;
  border-radius: 8px;
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
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.order-card {
  background: white;
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border-left: 4px solid #ff6b35;
}

.order-card.picked-up {
  opacity: 0.7;
  border-left-color: #4caf50;
}

.order-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 15px;
}

.order-header h3 {
  margin: 0 0 5px 0;
  font-size: 1.3rem;
  color: #333;
}

.order-time {
  margin: 5px 0;
  color: #666;
  font-size: 0.95rem;
}

.order-created {
  margin: 5px 0;
  color: #999;
  font-size: 0.85rem;
}

.status-badge {
  padding: 6px 12px;
  border-radius: 20px;
  font-size: 0.85rem;
  font-weight: 600;
}

.status-badge.pending {
  background: #fff3cd;
  color: #856404;
}

.status-badge.picked {
  background: #d4edda;
  color: #155724;
}

.order-product {
  margin: 15px 0;
  padding: 10px;
  background: #f9f9f9;
  border-radius: 8px;
}

.order-actions {
  margin-top: 15px;
}

.btn-mark-picked {
  padding: 10px 20px;
  background: #4caf50;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
}

.btn-mark-picked:hover {
  background: #45a049;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #666;
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

.btn-edit-stand {
  padding: 10px 20px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
}

.btn-edit-stand:hover {
  background: var(--color-primary-hover);
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
