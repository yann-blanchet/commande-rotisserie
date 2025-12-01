<template>
    <div class="favorites">
        <header class="header">
            <button @click="$router.push('/')" class="back-btn">← Retour</button>
            <h1>⭐ Mes Stands Favoris</h1>
        </header>

        <div v-if="loading" class="loading">Chargement des favoris...</div>

        <div v-else-if="favorites.length === 0" class="empty-state">
            <div class="empty-icon">⭐</div>
            <p>Aucun stand favori pour le moment</p>
            <p class="empty-hint">Les stands que vous visitez via QR code seront automatiquement ajoutés ici</p>
            <button @click="$router.push('/')" class="btn-primary">Découvrir les stands</button>
        </div>

        <div v-else class="favorites-grid">
            <div v-for="favorite in favoritesWithDetails" :key="favorite.id" class="favorite-card">
                <div class="favorite-content" @click="goToVendor(favorite.stand)">
                    <div class="favorite-header">
                        <h2>{{ favorite.nomDuStand }}</h2>
                        <button @click.stop="removeFavorite(favorite.id!)" class="remove-btn" :disabled="removing"
                            title="Retirer des favoris">
                            ❌
                        </button>
                    </div>

                    <div v-if="favorite.vendorDetails" class="favorite-details">
                        <p v-if="favorite.vendorDetails.description" class="description">
                            {{ favorite.vendorDetails.description }}
                        </p>
                        <div class="vendor-meta">
                            <span v-if="favorite.vendorDetails.location" class="location">
                                📍 {{ favorite.vendorDetails.location }}
                            </span>
                            <div v-if="favorite.vendorDetails.markets" class="market-info">
                                <span class="market-name">🏪 {{ favorite.vendorDetails.markets.name }}</span>
                                <span class="market-place">📍 {{ favorite.vendorDetails.markets.place }}</span>
                            </div>
                        </div>
                    </div>
                </div>

                <button @click="goToVendor(favorite.stand)" class="btn-primary">
                    Voir les produits →
                </button>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { db } from '../db/database'
import type { Favorite, VendorCache } from '../db/database'

const router = useRouter()
const favorites = ref<Favorite[]>([])
const loading = ref(true)
const removing = ref(false)

interface FavoriteWithDetails extends Favorite {
    vendorDetails?: VendorCache['data']
}

const favoritesWithDetails = computed<FavoriteWithDetails[]>(() => {
    return favorites.value.map(fav => {
        // We'll load vendor details separately
        return fav as FavoriteWithDetails
    })
})

const loadFavorites = async () => {
    loading.value = true
    try {
        const allFavorites = await db.favorites.toArray()
        favorites.value = allFavorites

        // Load vendor details for each favorite
        for (const favorite of favorites.value) {
            const vendor = await db.vendors_cache.get(favorite.stand)
            if (vendor) {
                const favoriteWithDetails = favorites.value.find(f => f.id === favorite.id) as FavoriteWithDetails
                if (favoriteWithDetails) {
                    favoriteWithDetails.vendorDetails = vendor.data
                }
            }
        }
    } catch (error) {
        console.error('Error loading favorites:', error)
    } finally {
        loading.value = false
    }
}

const removeFavorite = async (favoriteId: number) => {
    if (!confirm('Retirer ce stand de vos favoris ?')) return

    removing.value = true
    try {
        await db.favorites.delete(favoriteId)
        await loadFavorites()
    } catch (error) {
        console.error('Error removing favorite:', error)
        alert('Erreur lors de la suppression')
    } finally {
        removing.value = false
    }
}

const goToVendor = (vendorId: string) => {
    router.push(`/vendor/${vendorId}`)
}

onMounted(() => {
    loadFavorites()
})
</script>

<style scoped>
.favorites {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

.header {
    margin-bottom: 30px;
}

.back-btn {
    background: none;
    border: none;
    color: var(--color-text-secondary);
    cursor: pointer;
    font-size: 1rem;
    margin-bottom: 10px;
    padding: 5px 0;
}

.back-btn:hover {
    color: var(--color-text-primary);
}

.header h1 {
    font-size: 2rem;
    margin: 0;
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

.empty-icon {
    font-size: 4rem;
    margin-bottom: 20px;
}

.empty-state p {
    color: var(--color-text-secondary);
    margin: 10px 0;
    font-size: 1.1rem;
}

.empty-hint {
    font-size: 0.9rem !important;
    color: var(--color-text-tertiary) !important;
    font-style: italic;
}

.btn-primary {
    margin-top: 20px;
    padding: 12px 24px;
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

.favorites-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 20px;
}

.favorite-card {
    background: var(--color-bg-white);
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    transition: transform 0.2s, box-shadow 0.2s;
    border-left: 4px solid var(--color-primary);
}

.favorite-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.favorite-content {
    cursor: pointer;
    margin-bottom: 15px;
}

.favorite-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 10px;
}

.favorite-header h2 {
    margin: 0;
    color: var(--color-text-primary);
    font-size: 1.5rem;
    flex: 1;
}

.remove-btn {
    background: none;
    border: none;
    font-size: 1.2rem;
    cursor: pointer;
    padding: 5px 10px;
    border-radius: 4px;
    transition: background 0.2s;
    opacity: 0.6;
}

.remove-btn:hover:not(:disabled) {
    background: var(--color-error-light);
    opacity: 1;
}

.remove-btn:disabled {
    opacity: 0.3;
    cursor: not-allowed;
}

.favorite-details {
    margin-top: 10px;
}

.description {
    color: var(--color-text-secondary);
    margin: 10px 0;
    font-size: 0.95rem;
}

.vendor-meta {
    margin-top: 15px;
    font-size: 0.9rem;
    color: var(--color-text-tertiary);
    display: flex;
    flex-direction: column;
    gap: 5px;
}

.location {
    color: var(--color-text-secondary);
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

.favorite-card .btn-primary {
    width: 100%;
    margin-top: 15px;
}

@media (max-width: 768px) {
    .favorites-grid {
        grid-template-columns: 1fr;
    }
}
</style>
