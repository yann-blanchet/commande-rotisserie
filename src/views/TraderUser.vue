<template>
  <div class="trader-user">
    <header class="header">
      <h1>👤 Mon Profil</h1>
      <div class="header-actions">
        <button @click="handleLogout" class="logout-btn">Déconnexion</button>
      </div>
    </header>

    <div class="status-bar">
      <span :class="['status-indicator', isOnline() ? 'online' : 'offline']">
        {{ isOnline() ? '🟢 En ligne' : '🔴 Hors ligne' }}
      </span>
      <button @click="loadData" class="refresh-btn" :disabled="!isOnline() || loading">
        Actualiser
      </button>
    </div>

    <div v-if="loading" class="loading">Chargement...</div>

    <div v-else-if="error" class="error-message">
      <p>{{ error }}</p>
      <button @click="loadData" class="btn-primary">Réessayer</button>
    </div>

    <div v-else class="content">
      <!-- Stand Info -->
      <div v-if="stand" class="stand-info-card">
        <h2 class="stand-title">🍗 {{ stand.stand_nom || 'Mon Stand' }}</h2>
        <p v-if="stand.stand_description" class="stand-description">{{ stand.stand_description }}</p>
      </div>

      <!-- Products List -->
      <div class="products-section">
        <h2 class="section-title">📦 Tous mes produits</h2>
        <div v-if="products.length === 0" class="empty-state">
          <p>Aucun produit pour le moment</p>
        </div>
        <div v-else class="products-list">
          <div v-for="product in products" :key="product.id" class="product-item">
            <div class="product-info">
              <h3 class="product-name">{{ product.data.nom || product.data.name }}</h3>
              <p v-if="product.data.description" class="product-description">{{ product.data.description }}</p>
              <div class="product-details">
                <span class="product-price">{{ formatPrice(product.data.prix || product.data.price) }}</span>
                <span class="product-status" :class="{ available: product.data.available !== false, unavailable: product.data.available === false }">
                  {{ product.data.available !== false ? '✅ Disponible' : '❌ Indisponible' }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <BottomMenuBar />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import { supabase, isOnline } from '../lib/supabase'
import type { ProductCache } from '../db/database'
import BottomMenuBar from '../components/BottomMenuBar.vue'

const router = useRouter()
const stand = ref<any>(null)
const products = ref<ProductCache[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

const loadData = async () => {
  loading.value = true
  error.value = null

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

    const profileId = session.profile_id
    if (!profileId) {
      error.value = 'Session invalide'
      loading.value = false
      return
    }

    // Load stand info
    if (isOnline()) {
      const { data: vendor, error: vendorError } = await supabase
        .from('vendors')
        .select('*, profiles(stand_nom, stand_description)')
        .eq('profile_id', profileId)
        .maybeSingle()

      if (vendorError) {
        throw vendorError
      }

      if (vendor) {
        stand.value = {
          ...vendor,
          stand_nom: vendor.stand_nom || vendor.profiles?.stand_nom || null,
          stand_description: vendor.stand_description || vendor.profiles?.stand_description || null
        }
      }
    } else {
      // Offline: use cache
      const cachedVendors = await db.vendors_cache.toArray()
      const cachedVendor = cachedVendors.find(v => v.data.profile_id === profileId)
      if (cachedVendor) {
        stand.value = cachedVendor.data
      }
    }

    // Load products
    if (isOnline() && stand.value?.id) {
      await syncService.syncProducts(stand.value.id)
    }

    // Load from cache
    const cachedProducts = await db.products_cache.toArray()
    products.value = cachedProducts.sort((a, b) => 
      (a.data.nom || a.data.name || '').localeCompare(b.data.nom || b.data.name || '')
    )
  } catch (err: any) {
    console.error('Error loading data:', err)
    error.value = err.message || 'Erreur lors du chargement'
  } finally {
    loading.value = false
  }
}

const formatPrice = (price: number): string => {
  return new Intl.NumberFormat('fr-FR', {
    style: 'currency',
    currency: 'EUR'
  }).format(price)
}

const handleLogout = () => {
  localStorage.removeItem('trader_session')
  router.push('/trader/login')
}

onMounted(() => {
  loadData()
})
</script>

<style scoped>
.trader-user {
  max-width: 1200px;
  margin: 0 auto;
  padding: 16px;
  padding-bottom: 80px; /* Space for bottom menu */
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

.error-message {
  text-align: center;
  padding: 40px;
  color: #f44336;
}

.stand-info-card {
  background: white;
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  border: 2px solid #e2e8f0;
}

.stand-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #1a202c;
  margin: 0 0 12px 0;
}

.stand-description {
  color: #64748b;
  margin: 0;
  line-height: 1.6;
}

.products-section {
  background: white;
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  border: 2px solid #e2e8f0;
}

.section-title {
  font-size: 1.3rem;
  font-weight: 700;
  color: #1a202c;
  margin: 0 0 20px 0;
}

.empty-state {
  text-align: center;
  padding: 40px;
  color: #64748b;
}

.products-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.product-item {
  padding: 16px;
  background: #f8fafc;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
}

.product-name {
  font-size: 1.1rem;
  font-weight: 600;
  color: #1a202c;
  margin: 0 0 8px 0;
}

.product-description {
  color: #64748b;
  margin: 0 0 12px 0;
  font-size: 0.9rem;
  line-height: 1.5;
}

.product-details {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.product-price {
  font-size: 1.1rem;
  font-weight: 700;
  color: #667eea;
}

.product-status {
  font-size: 0.9rem;
  font-weight: 600;
  padding: 4px 12px;
  border-radius: 12px;
}

.product-status.available {
  background: #d1fae5;
  color: #065f46;
}

.product-status.unavailable {
  background: #fee2e2;
  color: #991b1b;
}
</style>



