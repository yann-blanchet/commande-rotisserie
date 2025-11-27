<template>
  <div class="vendor-list">
    <header class="header">
      <h1>🍗 Marché - Poulet Rôti</h1>
      <p class="subtitle">Choisissez votre stand</p>
      <router-link to="/trader/login" class="trader-link">Espace commerçant</router-link>
    </header>

    <div v-if="loading" class="loading">Chargement...</div>
    
    <div v-else class="vendors-grid">
      <div
        v-for="vendor in vendors"
        :key="vendor.id"
        class="vendor-card"
        @click="goToVendor(vendor.id)"
      >
        <div class="vendor-info">
          <h2>{{ vendor.data.nom || vendor.data.name }}</h2>
          <p v-if="vendor.data.description">{{ vendor.data.description }}</p>
          <div class="vendor-meta">
            <span v-if="vendor.data.location">📍 {{ vendor.data.location }}</span>
          </div>
        </div>
        <button class="btn-primary">Voir les produits →</button>
      </div>
    </div>

    <div v-if="vendors.length === 0 && !loading" class="empty-state">
      <p>Aucun stand disponible pour le moment</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import type { VendorCache } from '../db/database'

const router = useRouter()
const vendors = ref<VendorCache[]>([])
const loading = ref(true)

const loadVendors = async () => {
  loading.value = true
  // Try to sync first if online
  await syncService.syncVendors()
  
  // Load from cache
  const cachedVendors = await db.vendors_cache.toArray()
  vendors.value = cachedVendors
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

.trader-link {
  display: inline-block;
  margin-top: 10px;
  padding: 8px 16px;
  background: var(--color-secondary);
  color: white;
  text-decoration: none;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
}

.trader-link:hover {
  background: var(--color-secondary-hover);
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

