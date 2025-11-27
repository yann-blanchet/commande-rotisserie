<template>
  <div class="trader-orders">
    <header class="header">
      <h1>🍗 Mes Commandes</h1>
      <div class="header-actions">
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

    <!-- Create/Configure Stand Form -->
    <div v-else-if="needsSetup" class="setup-form">
      <div class="setup-card">
        <h2>🍗 Configurez votre stand</h2>
        <p class="setup-subtitle">Complétez les informations de votre stand pour commencer</p>

        <form @submit.prevent="createStand" class="stand-form">
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

          <button type="submit" class="btn-primary" :disabled="saving || !standForm.nom">
            {{ saving ? 'Enregistrement...' : 'Créer mon stand' }}
          </button>
        </form>
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
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import { supabase, isOnline } from '../lib/supabase'
import type { OrderCache, ProductCache } from '../db/database'

const router = useRouter()
const orders = ref<OrderCache[]>([])
const products = ref<Map<string, ProductCache>>(new Map())
const loading = ref(true)
const traderVendorId = ref<string | null>(null)
const needsSetup = ref(false)
const saving = ref(false)
const vendorInfo = ref<any>(null)
const standForm = ref({
  nom: '',
  description: '',
  location: ''
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
    if (!session.authenticated || !session.vendor_id) {
      router.push('/trader/login')
      return
    }

    const vendorId = session.vendor_id
    traderVendorId.value = vendorId

    // Get vendor info to check if setup is needed
    if (isOnline()) {
      const { data: vendor, error: vendorError } = await supabase
        .from('vendors')
        .select('*')
        .eq('id', vendorId)
        .single()

      if (vendorError) {
        console.error('Error loading vendor:', vendorError)
      } else if (vendor) {
        vendorInfo.value = vendor
        // Check if stand needs setup (has default name)
        if (vendor.nom === 'Stand à configurer' || !vendor.nom || vendor.nom.trim() === '') {
          needsSetup.value = true
          standForm.value = {
            nom: vendor.nom === 'Stand à configurer' ? '' : vendor.nom || '',
            description: vendor.description || '',
            location: vendor.location || ''
          }
          loading.value = false
          return
        }
      }
    } else {
      // Offline: check cache
      const cachedVendor = await db.vendors_cache.get(vendorId)
      if (cachedVendor) {
        vendorInfo.value = cachedVendor.data
        if (cachedVendor.data.nom === 'Stand à configurer' || !cachedVendor.data.nom) {
          needsSetup.value = true
          standForm.value = {
            nom: '',
            description: cachedVendor.data.description || '',
            location: cachedVendor.data.location || ''
          }
          loading.value = false
          return
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

const createStand = async () => {
  if (!standForm.value.nom.trim() || !traderVendorId.value) {
    return
  }

  saving.value = true

  try {
    if (!isOnline()) {
      alert('Vous devez être en ligne pour créer votre stand')
      saving.value = false
      return
    }

    const { error: updateError } = await supabase
      .from('vendors')
      .update({
        nom: standForm.value.nom.trim(),
        description: standForm.value.description.trim() || null,
        location: standForm.value.location.trim() || null
      })
      .eq('id', traderVendorId.value)

    if (updateError) {
      throw updateError
    }

    // Refresh vendor cache
    await syncService.syncVendors()

    // Reload page data
    needsSetup.value = false
    await loadOrders()
  } catch (error: any) {
    console.error('Error creating stand:', error)
    alert('Erreur lors de la création du stand: ' + (error.message || 'Erreur inconnue'))
  } finally {
    saving.value = false
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
</style>
