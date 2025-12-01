<template>
    <div class="vendor-products">
        <header class="header">
            <button @click="$router.push('/')" class="back-btn">← Retour</button>
            <div class="header-title">
                <div class="header-main">
                    <h1>{{ vendorName }}</h1>
                    <div v-if="marketInfo" class="market-place-info">
                        <span class="market-place-label">📍 Lieu du marché :</span>
                        <span class="market-place-value">{{ marketInfo.place }}</span>
                    </div>
                </div>
                <button
                    @click="toggleFavorite"
                    class="favorite-btn"
                    :class="{ 'is-favorite': isFavorite }"
                    :title="isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'"
                >
                    {{ isFavorite ? '⭐' : '☆' }}
                </button>
            </div>
        </header>

        <div v-if="loading" class="loading">Chargement des produits...</div>

        <div v-else class="products-section">
            <div class="products-grid">
                <div v-for="product in products" :key="product.id" class="product-card" @click="selectProduct(product)">
                    <div class="product-info">
                        <h3>{{ product.data.nom || product.data.name }}</h3>
                        <p v-if="product.data.description">{{ product.data.description }}</p>
                        <div class="product-price">
                            <strong>{{ formatPrice(product.data.prix || product.data.price) }}</strong>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Order Modal -->
        <div v-if="selectedProduct" class="modal-overlay" @click="closeModal">
            <div class="modal-content" @click.stop>
                <button class="close-btn" @click="closeModal">×</button>
                <h2>Commander {{ selectedProduct.data.nom || selectedProduct.data.name }}</h2>
                <form @submit.prevent="submitOrder" class="order-form">
                    <div class="form-group">
                        <label>Votre nom</label>
                        <input v-model="orderForm.customer_name" type="text" required placeholder="Entrez votre nom" />
                    </div>
                    <div class="form-group">
                        <label>Heure de retrait</label>
                        <div class="pickup-info">
                            <p class="pickup-title">Prochain marchés</p>
                            <p v-if="nextMarketDateDisplay" class="pickup-date-info">
                                📅 Date : <strong>{{ nextMarketDateDisplay }}</strong>
                            </p>
                            <p v-else class="pickup-date-warning">
                                ⚠️ Aucune date de marché disponible. Veuillez contacter le stand.
                            </p>
                            <input 
                                v-model="orderForm.pickup_time" 
                                type="time" 
                                required 
                                :disabled="!nextMarketDate"
                            />
                        </div>
                    </div>
                    <div class="form-actions">
                        <button type="button" @click="closeModal" class="btn-secondary">Annuler</button>
                        <button type="submit" class="btn-primary">Commander</button>
                    </div>
                </form>
            </div>
        </div>

        <div v-if="orderSuccess" class="success-message">
            ✅ Commande enregistrée ! {{ isOnline() ? 'Synchronisée' : 'Sera synchronisée quand vous serez en ligne' }}
        </div>

        <div v-if="favoriteAdded" class="success-message favorite-message">
            ⭐ Stand ajouté aux favoris !
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import { isOnline } from '../lib/supabase'
import type { ProductCache } from '../db/database'

const route = useRoute()
const vendorId = route.params.id as string

const products = ref<ProductCache[]>([])
const vendorName = ref('Stand')
const loading = ref(true)
const selectedProduct = ref<ProductCache | null>(null)
const orderSuccess = ref(false)
const favoriteAdded = ref(false)
const isFavorite = ref(false)
const nextMarketDate = ref<Date | null>(null)
const nextMarketDateDisplay = ref('')
const marketInfo = ref<{ name: string; place: string } | null>(null)
const orderForm = ref({
    customer_name: '',
    pickup_time: ''
})

const addToFavoritesIfDirectLink = async () => {
    // Check if user arrived via direct link (QR code)
    // If document.referrer is empty or doesn't contain the app URL, it's likely a direct link
    const referrer = document.referrer
    const currentOrigin = window.location.origin
    const isDirectLink = !referrer || !referrer.startsWith(currentOrigin)

    if (!isDirectLink) {
        return // User navigated from within the app, don't auto-add to favorites
    }

    try {
        // Check if already in favorites
        const existingFavorite = await db.favorites
            .where('stand')
            .equals(vendorId)
            .first()

        if (existingFavorite) {
            return // Already in favorites
        }

        // Get vendor name
        const vendor = await db.vendors_cache.get(vendorId)
        const vendorNom = vendor?.data.stand_nom || vendor?.data.nom || vendor?.data.name || 'Stand'

        // Add to favorites
        await db.favorites.add({
            stand: vendorId,
            nomDuStand: vendorNom
        })

        // Update favorite status
        isFavorite.value = true

        // Show notification
        favoriteAdded.value = true
        setTimeout(() => {
            favoriteAdded.value = false
        }, 3000)
    } catch (error) {
        console.error('Error adding to favorites:', error)
        // Silently fail - don't interrupt user experience
    }
}

const checkFavoriteStatus = async () => {
    try {
        const favorite = await db.favorites
            .where('stand')
            .equals(vendorId)
            .first()
        isFavorite.value = !!favorite
    } catch (error) {
        console.error('Error checking favorite status:', error)
    }
}

const toggleFavorite = async () => {
    try {
        if (isFavorite.value) {
            // Remove from favorites
            const favorite = await db.favorites
                .where('stand')
                .equals(vendorId)
                .first()
            if (favorite && favorite.id) {
                await db.favorites.delete(favorite.id)
                isFavorite.value = false
            }
        } else {
            // Add to favorites
            const vendor = await db.vendors_cache.get(vendorId)
            const vendorNom = vendor?.data.stand_nom || vendor?.data.nom || vendor?.data.name || 'Stand'
            
            await db.favorites.add({
                stand: vendorId,
                nomDuStand: vendorNom
            })
            isFavorite.value = true
            favoriteAdded.value = true
            setTimeout(() => {
                favoriteAdded.value = false
            }, 3000)
        }
    } catch (error) {
        console.error('Error toggling favorite:', error)
        alert('Erreur lors de la mise à jour des favoris')
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
    const todayName = Object.keys(dayMap).find(key => dayMap[key] === currentDay) || ''

    // Get market day numbers
    const marketDayNumbers = marketDays.map(day => dayMap[day.toLowerCase()]).sort((a, b) => a - b)

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
        const daysUntil = 7 - currentDay + firstDayNum
        const nextDate = new Date(today)
        nextDate.setDate(today.getDate() + daysUntil)
        return nextDate
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

const loadProducts = async () => {
    loading.value = true

    // Load vendor info
    const vendor = await db.vendors_cache.get(vendorId)
    if (vendor) {
        vendorName.value = vendor.data.stand_nom || vendor.data.nom || vendor.data.name || 'Stand'
        
        // Store market info
        if (vendor.data.markets) {
            marketInfo.value = {
                name: vendor.data.markets.name || '',
                place: vendor.data.markets.place || ''
            }
        }
        
        // Calculate next market date
        if (vendor.data.markets && vendor.data.markets.days) {
            const nextDate = calculateNextMarketDate(vendor.data.markets.days)
            if (nextDate) {
                nextMarketDate.value = nextDate
                nextMarketDateDisplay.value = formatMarketDate(nextDate)
            }
        }
    }

    // Check favorite status
    await checkFavoriteStatus()

    // Sync products if online
    await syncService.syncProducts(vendorId)

    // Load from cache
    const cachedProducts = await db.products_cache
        .where('vendor_id')
        .equals(vendorId)
        .toArray()

    products.value = cachedProducts
    loading.value = false

    // Add to favorites if user arrived via direct link (QR code)
    await addToFavoritesIfDirectLink()
    
    // Update favorite status after potential auto-add
    await checkFavoriteStatus()
}

const selectProduct = (product: ProductCache) => {
    selectedProduct.value = product
    // Set default pickup time to 12:00 (noon) if next market date is available
    if (nextMarketDate.value) {
        orderForm.value.pickup_time = '12:00'
    } else {
        // Fallback: use current time + 1 hour if no market date
        const now = new Date()
        now.setHours(now.getHours() + 1)
        orderForm.value.pickup_time = now.toTimeString().slice(0, 5) // Format HH:mm
    }
}

const closeModal = () => {
    selectedProduct.value = null
    orderForm.value = { customer_name: '', pickup_time: '' }
    orderSuccess.value = false
}

const submitOrder = async () => {
    if (!selectedProduct.value) return

    if (!nextMarketDate.value) {
        alert('Impossible de déterminer la date de marché. Veuillez réessayer plus tard.')
        return
    }

    try {
        // Combine next market date with selected time
        const pickupDateTime = new Date(nextMarketDate.value)
        const [hours, minutes] = orderForm.value.pickup_time.split(':').map(Number)
        pickupDateTime.setHours(hours, minutes, 0, 0)

        await syncService.createOfflineOrder({
            vendor_id: vendorId,
            product_id: selectedProduct.value.id,
            customer_name: orderForm.value.customer_name,
            pickup_time: pickupDateTime.toISOString()
        })

        orderSuccess.value = true
        closeModal()

        setTimeout(() => {
            orderSuccess.value = false
        }, 5000)
    } catch (error) {
        console.error('Error creating order:', error)
        alert('Erreur lors de la création de la commande')
    }
}

const formatPrice = (price: number) => {
    return new Intl.NumberFormat('fr-FR', {
        style: 'currency',
        currency: 'EUR'
    }).format(price)
}

onMounted(() => {
    loadProducts()
})
</script>

<style scoped>
.vendor-products {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

.header {
    margin-bottom: 30px;
}

.header-title {
    display: flex;
    align-items: flex-start;
    gap: 15px;
    width: 100%;
}

.header-main {
    flex: 1;
}

.header-title h1 {
    margin: 0 0 8px 0;
}

.market-place-info {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 8px;
    padding: 8px 12px;
    background: var(--color-info-light);
    border-radius: 8px;
    font-size: 0.9rem;
}

.market-place-label {
    color: var(--color-text-secondary);
    font-weight: 500;
}

.market-place-value {
    color: var(--color-text-primary);
    font-weight: 600;
}

.favorite-btn {
    background: none;
    border: 2px solid var(--color-border-medium);
    border-radius: 8px;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 8px 12px;
    transition: all 0.2s;
    line-height: 1;
}

.favorite-btn:hover {
    background: var(--color-bg-gray);
    border-color: var(--color-primary);
}

.favorite-btn.is-favorite {
    border-color: var(--color-primary);
    background: var(--color-primary-light);
    transform: scale(1.1);
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

.products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
    gap: 20px;
}

.product-card {
    background: var(--color-bg-white);
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
}

.product-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.product-info h3 {
    margin: 0 0 10px 0;
    color: var(--color-text-primary);
    font-size: 1.3rem;
}

.product-info p {
    color: var(--color-text-secondary);
    margin: 10px 0;
}

.product-price {
    margin-top: 15px;
    font-size: 1.5rem;
    color: var(--color-primary);
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
    max-width: 500px;
    width: 90%;
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
    margin: 0 0 20px 0;
}

.order-form {
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
}

.pickup-info {
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.pickup-title {
    margin: 0;
    font-weight: 600;
    color: var(--color-text-primary);
    font-size: 0.95rem;
}

.pickup-date-info {
    margin: 0;
    padding: 10px;
    background: var(--color-info-light);
    border-radius: 8px;
    color: var(--color-text-primary);
    font-size: 0.95rem;
}

.pickup-date-info strong {
    color: var(--color-primary);
}

.pickup-date-warning {
    margin: 0;
    padding: 10px;
    background: var(--color-warning-light);
    border-radius: 8px;
    color: var(--color-warning-dark);
    font-size: 0.95rem;
}

.pickup-info input:disabled {
    opacity: 0.6;
    cursor: not-allowed;
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

.btn-secondary:hover {
    background: var(--color-bg-gray-hover);
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

.btn-primary:hover {
    background: var(--color-primary-hover);
}

.success-message {
    position: fixed;
    bottom: 20px;
    right: 20px;
    background: var(--color-success);
    color: white;
    padding: 15px 20px;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    z-index: 1001;
    animation: slideIn 0.3s ease-out;
}

.favorite-message {
    background: var(--color-primary);
}

@keyframes slideIn {
    from {
        transform: translateX(100%);
        opacity: 0;
    }
    to {
        transform: translateX(0);
        opacity: 1;
    }
}
</style>
