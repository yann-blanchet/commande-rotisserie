<template>
    <div class="vendor-products">
        <header class="header">
            <button @click="$router.push('/')" class="back-btn">← Retour</button>
            <h1>{{ vendorName }}</h1>
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
                        <input v-model="orderForm.pickup_time" type="datetime-local" required />
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
const orderForm = ref({
    customer_name: '',
    pickup_time: ''
})

const loadProducts = async () => {
    loading.value = true

    // Load vendor info
    const vendor = await db.vendors_cache.get(vendorId)
    if (vendor) {
        vendorName.value = vendor.data.nom || vendor.data.name || 'Stand'
    }

    // Sync products if online
    await syncService.syncProducts(vendorId)

    // Load from cache
    const cachedProducts = await db.products_cache
        .where('vendor_id')
        .equals(vendorId)
        .toArray()

    products.value = cachedProducts
    loading.value = false
}

const selectProduct = (product: ProductCache) => {
    selectedProduct.value = product
    // Set default pickup time to 1 hour from now
    const now = new Date()
    now.setHours(now.getHours() + 1)
    orderForm.value.pickup_time = now.toISOString().slice(0, 16)
}

const closeModal = () => {
    selectedProduct.value = null
    orderForm.value = { customer_name: '', pickup_time: '' }
    orderSuccess.value = false
}

const submitOrder = async () => {
    if (!selectedProduct.value) return

    try {
        await syncService.createOfflineOrder({
            vendor_id: vendorId,
            product_id: selectedProduct.value.id,
            customer_name: orderForm.value.customer_name,
            pickup_time: orderForm.value.pickup_time
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
}
</style>
