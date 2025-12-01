<template>
  <div class="vendor-list">
    <header class="header">
      <h1>🍗 Mes stands favoris</h1>
      <p class="subtitle">Accédez rapidement à vos stands préférés</p>
      <div class="header-links">
        <router-link to="/favorites" class="favorites-link">⭐ Gérer mes favoris</router-link>
        <router-link to="/trader/login" class="trader-link">Espace commerçant</router-link>
        <router-link to="/admin/login" class="admin-link">Espace admin</router-link>
      </div>
    </header>

    <div v-if="loading" class="loading">Chargement...</div>
    
    <div v-else-if="favoriteVendors.length > 0" class="vendors-grid">
      <div
        v-for="vendor in favoriteVendors"
        :key="vendor.id"
        class="vendor-card"
        @click="goToVendor(vendor.id)"
      >
        <div class="vendor-info">
          <h2>{{ vendor.data.stand_nom || vendor.data.nom || vendor.data.name || 'Stand' }}</h2>
          <p v-if="vendor.data.stand_description || vendor.data.description">{{ vendor.data.stand_description || vendor.data.description }}</p>
          <div class="vendor-meta">
            <span v-if="vendor.data.location" class="location">📍 {{ vendor.data.location }}</span>
            <div v-if="vendor.data.markets" class="market-info">
              <span class="market-name">🏪 {{ vendor.data.markets.name }}</span>
              <span class="market-place">📍 {{ vendor.data.markets.place }}</span>
            </div>
          </div>
        </div>
        <button class="btn-primary">Voir les produits →</button>
      </div>
    </div>

    <div v-else class="empty-state">
      <p>Vous n'avez pas encore de stand favori.</p>
      <p class="empty-hint">
        Scannez le QR code d'un stand ou ouvrez un lien direct pour l'ajouter automatiquement à vos favoris.
      </p>
      <router-link to="/favorites" class="btn-primary">
        Gérer mes favoris
      </router-link>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import type { VendorCache, Favorite } from '../db/database'

const router = useRouter()
const vendors = ref<VendorCache[]>([])
const favorites = ref<Favorite[]>([])
const loading = ref(true)

const favoriteVendors = computed(() =>
  vendors.value.filter(vendor =>
    favorites.value.some(fav => fav.stand === vendor.id)
  )
)

const loadVendors = async () => {
  loading.value = true

  // Try to sync vendors first if online
  await syncService.syncVendors()
  
  // Load vendors from cache
  const cachedVendors = await db.vendors_cache.toArray()
  vendors.value = cachedVendors

  // Load favorites from local DB
  const cachedFavorites = await db.favorites.toArray()
  favorites.value = cachedFavorites

  loading.value = false
}

const goToVendor = (vendorId: string) => {
  router.push(`/vendor/${vendorId}`)
}

onMounted(() => {
  loadVendors()
})
</script>

<style scoped>
.vendor-list {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  text-align: center;
  margin-bottom: 30px;
}

.header h1 {
  font-size: 2rem;
  margin-bottom: 10px;
}

.subtitle {
  color: var(--color-text-secondary);
  font-size: 1.1rem;
  margin-bottom: 15px;
}

.header-links {
  display: flex;
  gap: 10px;
  justify-content: center;
  margin-top: 10px;
}

.favorites-link,
.trader-link,
.admin-link {
  display: inline-block;
  padding: 8px 16px;
  color: white;
  text-decoration: none;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
}

.favorites-link {
  background: var(--color-primary);
}

.favorites-link:hover {
  background: var(--color-primary-hover);
}

.trader-link {
  background: var(--color-secondary);
}

.trader-link:hover {
  background: var(--color-secondary-hover);
}

.admin-link {
  background: var(--color-warning-dark);
}

.admin-link:hover {
  background: var(--color-warning);
  color: white;
}

.loading {
  text-align: center;
  padding: 40px;
  color: var(--color-text-secondary);
}

.vendors-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
}

.vendor-card {
  background: var(--color-bg-white);
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
}

.vendor-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.vendor-info h2 {
  margin: 0 0 10px 0;
  color: var(--color-text-primary);
  font-size: 1.5rem;
}

.vendor-info p {
  color: var(--color-text-secondary);
  margin: 10px 0;
}

.vendor-meta {
  margin-top: 15px;
  font-size: 0.9rem;
  color: var(--color-text-tertiary);
  display: flex;
  flex-direction: column;
  gap: 5px;
}

.market-info {
  display: flex;
  flex-direction: column;
  gap: 5px;
  margin-top: 5px;
  padding: 8px;
  background: var(--color-info-light);
  border-radius: 6px;
}

.market-name {
  color: var(--color-text-primary);
  font-weight: 600;
  font-size: 0.95rem;
}

.market-place {
  color: var(--color-text-secondary);
  font-size: 0.9rem;
}

.btn-primary {
  margin-top: 15px;
  width: 100%;
  padding: 12px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  font-weight: 600;
}

.btn-primary:hover {
  background: var(--color-primary-hover);
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: var(--color-text-secondary);
}
</style>

