<template>
  <div class="markets">
    <header class="header">
      <h1>🏪 Gestion des Marchés (Admin)</h1>
      <div class="header-actions">
        <button @click="goToHome" class="btn-secondary">Retour à l'accueil</button>
        <button @click="handleLogout" class="logout-btn">Déconnexion</button>
      </div>
    </header>

    <div class="status-bar">
      <span :class="['status-indicator', isOnline() ? 'online' : 'offline']">
        {{ isOnline() ? '🟢 En ligne' : '🔴 Hors ligne' }}
      </span>
      <button @click="refreshMarkets" class="refresh-btn" :disabled="!isOnline()">
        Actualiser
      </button>
    </div>

    <div class="markets-section">
      <div class="section-header">
        <h2>Marchés disponibles</h2>
        <button @click="showAddMarket = true" class="btn-add">
          + Ajouter un marché
        </button>
      </div>

      <div v-if="loading" class="loading">Chargement des marchés...</div>

      <div v-else-if="markets.length === 0" class="empty-state">
        <p>Aucun marché pour le moment</p>
        <button @click="showAddMarket = true" class="btn-primary">
          Créer votre premier marché
        </button>
      </div>

      <div v-else class="markets-grid">
        <div
          v-for="market in markets"
          :key="market.id"
          class="market-card"
        >
          <div class="market-header">
            <h3>{{ market.data.name }}</h3>
            <div class="market-actions">
              <button @click="editMarket(market)" class="btn-edit">✏️</button>
              <button @click="deleteMarket(market.id)" class="btn-delete">🗑️</button>
            </div>
          </div>
          
          <div class="market-info">
            <div class="market-place">
              <strong>📍 Lieu:</strong> {{ market.data.place }}
            </div>
            <div class="market-days">
              <strong>📅 Jours:</strong>
              <div class="days-list">
                <span
                  v-for="day in market.data.days"
                  :key="day"
                  class="day-badge"
                >
                  {{ formatDay(day) }}
                </span>
              </div>
            </div>
            <div class="market-stands">
              <strong>🍗 Stands associés:</strong>
              <span v-if="getMarketStands(market.id).length === 0" class="no-stands">
                Aucun stand
              </span>
              <div v-else class="stands-list">
                <span
                  v-for="stand in getMarketStands(market.id)"
                  :key="stand.id"
                  class="stand-badge"
                >
                  {{ stand.stand_nom || stand.nom || 'Stand sans nom' }}
                </span>
              </div>
            </div>
          </div>
          <div class="market-card-actions">
            <button @click="manageStands(market)" class="btn-manage-stands">
              🍗 Gérer les stands
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Manage Stands Modal -->
    <div v-if="showManageStands" class="modal-overlay" @click="closeManageStandsModal">
      <div class="modal-content" @click.stop>
        <button class="close-btn" @click="closeManageStandsModal">×</button>
        <h2>🍗 Gérer les stands - {{ selectedMarket?.data.name }}</h2>
        
        <div v-if="loadingStands" class="loading">Chargement des stands...</div>
        
        <div v-else class="stands-management">
          <div class="form-group">
            <label>Associer un stand à ce marché</label>
            <select v-model="selectedVendorId" class="vendor-select" :disabled="savingStand">
              <option value="">-- Sélectionner un stand --</option>
              <option
                v-for="vendor in availableVendors"
                :key="vendor.id"
                :value="vendor.id"
                :disabled="vendor.market_id === selectedMarket?.id"
              >
                {{ vendor.stand_nom || vendor.nom || 'Stand sans nom' }}
                <span v-if="vendor.market_id && vendor.market_id !== selectedMarket?.id">
                  (déjà dans un autre marché)
                </span>
              </option>
            </select>
            <button
              @click="assignStandToMarket"
              class="btn-primary"
              :disabled="!selectedVendorId || savingStand"
            >
              {{ savingStand ? 'Association...' : 'Associer' }}
            </button>
          </div>

          <div class="assigned-stands">
            <h3>Stands associés à ce marché</h3>
            <div v-if="marketStands.length === 0" class="empty-stands">
              <p>Aucun stand associé</p>
            </div>
            <div v-else class="stands-list-modal">
              <div
                v-for="stand in marketStands"
                :key="stand.id"
                class="stand-item"
              >
                <div class="stand-item-info">
                  <strong>{{ stand.stand_nom || stand.nom || 'Stand sans nom' }}</strong>
                  <span v-if="stand.location" class="stand-location">📍 {{ stand.location }}</span>
                </div>
                <button
                  @click="removeStandFromMarket(stand.id)"
                  class="btn-remove-stand"
                  :disabled="savingStand"
                >
                  Retirer
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Add/Edit Market Modal -->
    <div v-if="showAddMarket || editingMarket" class="modal-overlay" @click="closeModal">
      <div class="modal-content" @click.stop>
        <button class="close-btn" @click="closeModal">×</button>
        <h2>{{ editingMarket ? 'Modifier le marché' : 'Nouveau marché' }}</h2>
        
        <form @submit.prevent="saveMarket" class="market-form">
          <div class="form-group">
            <label>Nom du marché *</label>
            <input
              v-model="marketForm.name"
              type="text"
              required
              placeholder="Ex: Marché Central"
              :disabled="saving"
            />
          </div>

          <div class="form-group">
            <label>Lieu *</label>
            <input
              v-model="marketForm.place"
              type="text"
              required
              placeholder="Ex: Place de la République, 75001 Paris"
              :disabled="saving"
            />
          </div>

          <div class="form-group">
            <label>Jours de marché *</label>
            <div class="days-selector">
              <label
                v-for="day in availableDays"
                :key="day.value"
                class="day-checkbox"
              >
                <input
                  type="checkbox"
                  :value="day.value"
                  v-model="marketForm.days"
                  :disabled="saving"
                />
                <span>{{ day.label }}</span>
              </label>
            </div>
            <small class="form-hint">Sélectionnez au moins un jour</small>
          </div>

          <div class="form-actions">
            <button type="button" @click="closeModal" class="btn-secondary" :disabled="saving">
              Annuler
            </button>
            <button type="submit" class="btn-primary" :disabled="saving || marketForm.days.length === 0">
              {{ saving ? 'Enregistrement...' : 'Enregistrer' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import { supabase, isOnline } from '../lib/supabase'
import type { MarketCache } from '../db/database'

const router = useRouter()
const markets = ref<MarketCache[]>([])
const vendors = ref<any[]>([])
const loading = ref(true)
const saving = ref(false)
const showAddMarket = ref(false)
const editingMarket = ref<MarketCache | null>(null)
const showManageStands = ref(false)
const selectedMarket = ref<MarketCache | null>(null)
const selectedVendorId = ref<string>('')
const loadingStands = ref(false)
const savingStand = ref(false)

const availableDays = [
  { value: 'monday', label: 'Lundi' },
  { value: 'tuesday', label: 'Mardi' },
  { value: 'wednesday', label: 'Mercredi' },
  { value: 'thursday', label: 'Jeudi' },
  { value: 'friday', label: 'Vendredi' },
  { value: 'saturday', label: 'Samedi' },
  { value: 'sunday', label: 'Dimanche' }
]

const marketForm = ref({
  name: '',
  place: '',
  days: [] as string[]
})

const loadMarkets = async () => {
  loading.value = true

  // Vérifier la session admin
  const adminSession = localStorage.getItem('admin_session')
  if (!adminSession) {
    router.push('/admin/login')
    return
  }

  try {
    const session = JSON.parse(adminSession)
    if (!session.authenticated) {
      router.push('/admin/login')
      return
    }
  } catch {
    router.push('/admin/login')
    return
  }

  // Sync markets if online
  if (isOnline()) {
    await syncService.syncMarkets()
    await syncService.syncVendors()
  }

  // Load from cache
  const cachedMarkets = await db.markets_cache.toArray()
  markets.value = cachedMarkets.sort((a, b) => 
    (a.data.name || '').localeCompare(b.data.name || '')
  )

  // Load vendors from cache
  const cachedVendors = await db.vendors_cache.toArray()
  vendors.value = cachedVendors.map(v => v.data)

  loading.value = false
}

const refreshMarkets = async () => {
  if (isOnline()) {
    await syncService.syncMarkets()
    await loadMarkets()
  }
}

const editMarket = (market: MarketCache) => {
  editingMarket.value = market
  marketForm.value = {
    name: market.data.name || '',
    place: market.data.place || '',
    days: [...(market.data.days || [])]
  }
  showAddMarket.value = true
}

const closeModal = () => {
  showAddMarket.value = false
  editingMarket.value = null
  marketForm.value = {
    name: '',
    place: '',
    days: []
  }
}

const saveMarket = async () => {
  if (!marketForm.value.name || !marketForm.value.place || marketForm.value.days.length === 0) return

  saving.value = true

  try {
    if (!isOnline()) {
      alert('Vous devez être en ligne pour créer/modifier un marché')
      saving.value = false
      return
    }

    const marketData: any = {
      name: marketForm.value.name.trim(),
      place: marketForm.value.place.trim(),
      days: marketForm.value.days,
      updated_at: new Date().toISOString()
    }

    if (editingMarket.value) {
      // Update existing market
      const { error } = await supabase
        .from('markets')
        .update(marketData)
        .eq('id', editingMarket.value.id)

      if (error) throw error
    } else {
      // Create new market
      const { error } = await supabase
        .from('markets')
        .insert(marketData)

      if (error) throw error
    }

    await syncService.syncMarkets()
    await loadMarkets()
    closeModal()
  } catch (error: any) {
    console.error('Error saving market:', error)
    alert('Erreur lors de l\'enregistrement: ' + (error.message || 'Erreur inconnue'))
  } finally {
    saving.value = false
  }
}

const deleteMarket = async (marketId: string) => {
  if (!confirm('Êtes-vous sûr de vouloir supprimer ce marché ? Les stands associés seront dissociés.')) return

  try {
    if (!isOnline()) {
      alert('Vous devez être en ligne pour supprimer un marché')
      return
    }

    const { error } = await supabase
      .from('markets')
      .delete()
      .eq('id', marketId)

    if (error) throw error

    await db.markets_cache.delete(marketId)
    await syncService.syncMarkets()
    await loadMarkets()
  } catch (error: any) {
    console.error('Error deleting market:', error)
    alert('Erreur lors de la suppression: ' + (error.message || 'Erreur inconnue'))
  }
}

const formatDay = (day: string): string => {
  const dayMap: Record<string, string> = {
    monday: 'Lun',
    tuesday: 'Mar',
    wednesday: 'Mer',
    thursday: 'Jeu',
    friday: 'Ven',
    saturday: 'Sam',
    sunday: 'Dim'
  }
  return dayMap[day] || day
}

const goToHome = () => {
  router.push('/')
}

const handleLogout = () => {
  localStorage.removeItem('admin_session')
  router.push('/')
}

const getMarketStands = (marketId: string) => {
  return vendors.value.filter(v => v.market_id === marketId)
}

const manageStands = async (market: MarketCache) => {
  selectedMarket.value = market
  showManageStands.value = true
  loadingStands.value = true
  selectedVendorId.value = ''

  try {
    if (isOnline()) {
      await syncService.syncVendors()
    }
    
    // Reload vendors from cache
    const cachedVendors = await db.vendors_cache.toArray()
    vendors.value = cachedVendors.map(v => v.data)
  } catch (error) {
    console.error('Error loading vendors:', error)
  } finally {
    loadingStands.value = false
  }
}

const closeManageStandsModal = () => {
  showManageStands.value = false
  selectedMarket.value = null
  selectedVendorId.value = ''
}

const availableVendors = computed(() => {
  return vendors.value.filter(v => {
    const nom = v.stand_nom || v.nom
    return nom && nom !== 'Stand à configurer'
  })
})

const marketStands = computed(() => {
  if (!selectedMarket.value) return []
  return getMarketStands(selectedMarket.value.id)
})

const assignStandToMarket = async () => {
  if (!selectedVendorId.value || !selectedMarket.value || savingStand.value) return

  savingStand.value = true

  try {
    if (!isOnline()) {
      alert('Vous devez être en ligne pour associer un stand à un marché')
      savingStand.value = false
      return
    }

    const { error } = await supabase
      .from('vendors')
      .update({ market_id: selectedMarket.value.id })
      .eq('id', selectedVendorId.value)

    if (error) throw error

    // Refresh vendors cache
    await syncService.syncVendors()
    
    // Reload vendors
    const cachedVendors = await db.vendors_cache.toArray()
    vendors.value = cachedVendors.map(v => v.data)

    selectedVendorId.value = ''
    await loadMarkets()
  } catch (error: any) {
    console.error('Error assigning stand to market:', error)
    alert('Erreur lors de l\'association: ' + (error.message || 'Erreur inconnue'))
  } finally {
    savingStand.value = false
  }
}

const removeStandFromMarket = async (vendorId: string) => {
  if (!confirm('Retirer ce stand de ce marché ?')) return

  savingStand.value = true

  try {
    if (!isOnline()) {
      alert('Vous devez être en ligne pour retirer un stand d\'un marché')
      savingStand.value = false
      return
    }

    const { error } = await supabase
      .from('vendors')
      .update({ market_id: null })
      .eq('id', vendorId)

    if (error) throw error

    // Refresh vendors cache
    await syncService.syncVendors()
    
    // Reload vendors
    const cachedVendors = await db.vendors_cache.toArray()
    vendors.value = cachedVendors.map(v => v.data)

    await loadMarkets()
  } catch (error: any) {
    console.error('Error removing stand from market:', error)
    alert('Erreur lors du retrait: ' + (error.message || 'Erreur inconnue'))
  } finally {
    savingStand.value = false
  }
}

onMounted(() => {
  loadMarkets()
})
</script>

<style scoped>
.markets {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  flex-wrap: wrap;
  gap: 15px;
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
  margin-bottom: 30px;
  padding: 15px;
  background: var(--color-bg-light);
  border-radius: 8px;
}

.status-indicator {
  font-weight: 600;
}

.status-indicator.online {
  color: var(--color-success);
}

.status-indicator.offline {
  color: var(--color-error);
}

.refresh-btn {
  padding: 8px 16px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
}

.refresh-btn:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.refresh-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.markets-section {
  margin-top: 30px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  flex-wrap: wrap;
  gap: 15px;
}

.section-header h2 {
  font-size: 1.8rem;
  margin: 0;
}

.btn-add {
  padding: 12px 24px;
  background: var(--color-success);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  font-weight: 600;
}

.btn-add:hover {
  background: var(--color-success-hover);
}

.loading {
  text-align: center;
  padding: 40px;
  color: var(--color-text-secondary);
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  background: var(--color-bg-white);
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.empty-state p {
  color: var(--color-text-secondary);
  margin-bottom: 20px;
  font-size: 1.1rem;
}

.markets-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
}

.market-card {
  background: var(--color-bg-white);
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border-left: 4px solid var(--color-success);
  transition: transform 0.2s, box-shadow 0.2s;
}

.market-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.market-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 15px;
}

.market-header h3 {
  margin: 0;
  font-size: 1.3rem;
  color: var(--color-text-primary);
  flex: 1;
}

.market-actions {
  display: flex;
  gap: 8px;
}

.btn-edit,
.btn-delete {
  background: none;
  border: none;
  font-size: 1.2rem;
  cursor: pointer;
  padding: 5px;
  border-radius: 4px;
  transition: background 0.2s;
}

.btn-edit:hover {
  background: var(--color-info-medium);
}

.btn-delete:hover {
  background: var(--color-error-light);
}

.market-info {
  margin-bottom: 15px;
}

.market-stands {
  margin-top: 15px;
  padding-top: 15px;
  border-top: 1px solid var(--color-border-light);
}

.market-stands strong {
  display: block;
  margin-bottom: 8px;
  color: var(--color-text-primary);
}

.no-stands {
  color: var(--color-text-tertiary);
  font-style: italic;
  font-size: 0.9rem;
}

.stands-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 8px;
}

.stand-badge {
  padding: 4px 12px;
  background: var(--color-primary-light);
  color: var(--color-primary);
  border-radius: 12px;
  font-size: 0.85rem;
  font-weight: 600;
}

.market-card-actions {
  margin-top: 15px;
  padding-top: 15px;
  border-top: 1px solid var(--color-border-light);
}

.btn-manage-stands {
  width: 100%;
  padding: 10px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.95rem;
}

.btn-manage-stands:hover {
  background: var(--color-primary-hover);
}

.stands-management {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.vendor-select {
  padding: 12px;
  border: 1px solid var(--color-border-medium);
  border-radius: 8px;
  font-size: 1rem;
  font-family: inherit;
  margin-top: 8px;
  margin-bottom: 10px;
}

.vendor-select:disabled {
  background: var(--color-bg-gray);
  cursor: not-allowed;
}

.assigned-stands {
  margin-top: 20px;
  padding-top: 20px;
  border-top: 2px solid var(--color-border-medium);
}

.assigned-stands h3 {
  margin: 0 0 15px 0;
  font-size: 1.2rem;
  color: var(--color-text-primary);
}

.empty-stands {
  padding: 20px;
  text-align: center;
  color: var(--color-text-secondary);
  font-style: italic;
}

.stands-list-modal {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.stand-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  background: var(--color-bg-light);
  border-radius: 8px;
}

.stand-item-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex: 1;
}

.stand-item-info strong {
  color: var(--color-text-primary);
}

.stand-location {
  font-size: 0.85rem;
  color: var(--color-text-secondary);
}

.btn-remove-stand {
  padding: 8px 16px;
  background: var(--color-error);
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.9rem;
}

.btn-remove-stand:hover:not(:disabled) {
  background: var(--color-error-light);
  color: var(--color-error-text);
}

.btn-remove-stand:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.market-place {
  margin: 10px 0;
  color: var(--color-text-secondary);
}

.market-days {
  margin: 15px 0;
}

.days-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 8px;
}

.day-badge {
  padding: 4px 12px;
  background: var(--color-info-light);
  color: var(--color-info-dark);
  border-radius: 12px;
  font-size: 0.85rem;
  font-weight: 600;
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

.close-btn {
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

.close-btn:hover {
  color: var(--color-text-primary);
}

.modal-content h2 {
  margin: 0 0 25px 0;
  font-size: 1.8rem;
}

.market-form {
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
  font-family: inherit;
}

.days-selector {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
  margin-top: 8px;
}

.day-checkbox {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 8px;
  border-radius: 6px;
  transition: background 0.2s;
}

.day-checkbox:hover {
  background: var(--color-bg-gray);
}

.day-checkbox input[type="checkbox"] {
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.form-hint {
  color: var(--color-text-secondary);
  font-size: 0.85rem;
  margin-top: -5px;
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

.btn-primary:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.logout-btn {
  padding: 10px 20px;
  background: var(--color-bg-gray);
  color: var(--color-text-primary);
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
}

.logout-btn:hover {
  background: var(--color-bg-gray-hover);
}

@media (max-width: 768px) {
  .days-selector {
    grid-template-columns: 1fr;
  }
  
  .header {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .section-header {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>

