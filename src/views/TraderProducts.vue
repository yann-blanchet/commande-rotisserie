<template>
    <div class="trader-products">
        <TraderHeader title="Produits" />

        <!-- Products List -->
        <div class="products-section">
            <div class="section-header">
                <button @click="showAddProduct = true" class="btn-add">
                    + Ajouter un produit
                </button>
            </div>

            <div v-if="loading" class="loading">Chargement des produits...</div>

            <div v-else-if="products.length === 0" class="empty-state">
                <p>Aucun produit pour le moment</p>
                <button @click="showAddProduct = true" class="btn-primary">
                    Créer votre premier produit
                </button>
            </div>

            <div v-else class="products-grid">
                <div v-for="product in products" :key="product.id" class="product-card"
                    :class="{ 'unavailable': !product.data.available }">
                    <div class="product-header">
                        <h3>{{ product.data.nom || product.data.name }}</h3>
                        <div class="product-actions">
                            <button @click="editProduct(product)" class="btn-edit">✏️</button>
                            <button @click="deleteProduct(product.id)" class="btn-delete">🗑️</button>
                        </div>
                    </div>

                    <div class="product-info">
                        <p v-if="product.data.description" class="product-description">
                            {{ product.data.description }}
                        </p>
                        <div class="product-price">
                            <strong>{{ formatPrice(product.data.prix || product.data.price) }}</strong>
                        </div>
                    </div>

                    <div class="product-availability">
                        <label class="availability-toggle">
                            <input type="checkbox" :checked="product.data.available !== false"
                                @change="toggleAvailability(product)" :disabled="savingProducts.has(product.id)" />
                            <span>{{ product.data.available !== false ? '✅ Disponible' : '❌ Indisponible' }}</span>
                        </label>
                    </div>

                    <div v-if="product.data.next_market_day" class="product-market-day">
                        📅 Disponible le: {{ formatDate(product.data.next_market_day) }}
                    </div>

                    <div v-if="product.data.stock_quantity !== null && product.data.stock_quantity !== undefined"
                        class="product-stock">
                        📦 Stock: {{ product.data.stock_quantity }}
                    </div>
                </div>
            </div>
        </div>

        <!-- Add/Edit Product Modal -->
        <div v-if="showAddProduct || editingProduct" class="modal-overlay" @click="closeModal">
            <div class="modal-content" @click.stop>
                <button class="close-btn" @click="closeModal">×</button>
                <h2>{{ editingProduct ? 'Modifier le produit' : 'Nouveau produit' }}</h2>

                <form @submit.prevent="saveProduct" class="product-form">
                    <div class="form-group">
                        <label>Nom du produit *</label>
                        <input v-model="productForm.nom" type="text" required placeholder="Ex: Poulet entier"
                            :disabled="saving" />
                    </div>

                    <div class="form-group">
                        <label>Description</label>
                        <textarea v-model="productForm.description" placeholder="Décrivez votre produit..." rows="3"
                            :disabled="saving"></textarea>
                    </div>

                    <div class="form-row">
                        <div class="form-group">
                            <label>Prix (€) *</label>
                            <input v-model.number="productForm.prix" type="number" step="0.01" min="0" required
                                placeholder="12.50" :disabled="saving" />
                        </div>

                        <div class="form-group">
                            <label>Stock (optionnel)</label>
                            <input v-model.number="productForm.stock_quantity" type="number" min="0"
                                placeholder="Quantité" :disabled="saving" />
                        </div>
                    </div>

                    <div class="form-group">
                        <label>Disponible le (optionnel)</label>
                        <input v-model="productForm.next_market_day" type="date" :disabled="saving" />
                        <small class="form-hint">Laissez vide pour toujours disponible</small>
                    </div>

                    <div class="form-group">
                        <label class="checkbox-label">
                            <input v-model="productForm.available" type="checkbox" :disabled="saving" />
                            <span>Produit disponible</span>
                        </label>
                    </div>

                    <div class="form-actions">
                        <button type="button" @click="closeModal" class="btn-secondary" :disabled="saving">
                            Annuler
                        </button>
                        <button type="submit" class="btn-primary" :disabled="saving">
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
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { db } from '../db/database'
import { syncService } from '../services/syncService'
import { supabase, isOnline } from '../lib/supabase'
import type { ProductCache } from '../db/database'
import BottomMenuBar from '../components/BottomMenuBar.vue'
import TraderHeader from '../components/TraderHeader.vue'

const router = useRouter()
const route = useRoute()
const products = ref<ProductCache[]>([])
const loading = ref(true)
const saving = ref(false)
const savingProducts = ref<Set<string>>(new Set())
const showAddProduct = ref(false)
const editingProduct = ref<ProductCache | null>(null)
const traderVendorId = ref<string | null>(null)

const productForm = ref({
    nom: '',
    description: '',
    prix: 0,
    available: true,
    next_market_day: '',
    stock_quantity: null as number | null
})

const loadData = async () => {
    loading.value = true

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

        // Sync products if online
        if (isOnline()) {
            await syncService.syncProducts(vendorId)
        }

        // Load from cache
        const cachedProducts = await db.products_cache
            .where('vendor_id')
            .equals(vendorId)
            .toArray()

        products.value = cachedProducts.sort((a, b) =>
            (a.data.nom || a.data.name || '').localeCompare(b.data.nom || b.data.name || '')
        )
    } catch (error) {
        console.error('Error loading data:', error)
    } finally {
        loading.value = false
    }
}

const editProduct = (product: ProductCache) => {
    editingProduct.value = product
    productForm.value = {
        nom: product.data.nom || product.data.name || '',
        description: product.data.description || '',
        prix: product.data.prix || product.data.price || 0,
        available: product.data.available !== false,
        next_market_day: product.data.next_market_day || '',
        stock_quantity: product.data.stock_quantity ?? null
    }
    showAddProduct.value = true
}

const closeModal = () => {
    showAddProduct.value = false
    editingProduct.value = null
    productForm.value = {
        nom: '',
        description: '',
        prix: 0,
        available: true,
        next_market_day: '',
        stock_quantity: null
    }
}

const saveProduct = async () => {
    if (!productForm.value.nom || !traderVendorId.value) return

    saving.value = true

    try {
        if (!isOnline()) {
            alert('Vous devez être en ligne pour créer/modifier un produit')
            saving.value = false
            return
        }

        const productData: any = {
            vendor_id: traderVendorId.value,
            nom: productForm.value.nom.trim(),
            description: productForm.value.description.trim() || null,
            prix: productForm.value.prix,
            available: productForm.value.available,
            next_market_day: productForm.value.next_market_day || null,
            stock_quantity: productForm.value.stock_quantity || null,
            updated_at: new Date().toISOString()
        }

        if (editingProduct.value) {
            // Update existing product
            const { error } = await supabase
                .from('products')
                .update(productData)
                .eq('id', editingProduct.value.id)

            if (error) throw error
        } else {
            // Create new product
            const { error } = await supabase
                .from('products')
                .insert(productData)

            if (error) throw error
        }

        await syncService.syncProducts(traderVendorId.value)
        await loadData()
        closeModal()
    } catch (error: any) {
        console.error('Error saving product:', error)
        alert('Erreur lors de l\'enregistrement: ' + (error.message || 'Erreur inconnue'))
    } finally {
        saving.value = false
    }
}

const toggleAvailability = async (product: ProductCache) => {
    if (!traderVendorId.value) return

    savingProducts.value.add(product.id)

    try {
        const newAvailability = !(product.data.available !== false)

        if (isOnline()) {
            const { error } = await supabase
                .from('products')
                .update({
                    available: newAvailability,
                    updated_at: new Date().toISOString()
                })
                .eq('id', product.id)

            if (error) throw error

            await syncService.syncProducts(traderVendorId.value)
        }

        // Update local cache immediately
        await db.products_cache.update(product.id, {
            data: { ...product.data, available: newAvailability },
            updated_at: new Date().toISOString()
        })

        await loadData()
    } catch (error: any) {
        console.error('Error toggling availability:', error)
        alert('Erreur lors de la mise à jour')
    } finally {
        savingProducts.value.delete(product.id)
    }
}

const deleteProduct = async (productId: string) => {
    if (!confirm('Êtes-vous sûr de vouloir supprimer ce produit ?')) return

    savingProducts.value.add(productId)

    try {
        if (!isOnline()) {
            alert('Vous devez être en ligne pour supprimer un produit')
            savingProducts.value.delete(productId)
            return
        }

        const { error } = await supabase
            .from('products')
            .delete()
            .eq('id', productId)

        if (error) throw error

        await db.products_cache.delete(productId)
        await syncService.syncProducts(traderVendorId.value!)
        await loadData()
    } catch (error: any) {
        console.error('Error deleting product:', error)
        alert('Erreur lors de la suppression: ' + (error.message || 'Erreur inconnue'))
    } finally {
        savingProducts.value.delete(productId)
    }
}

const formatPrice = (price: number) => {
    return new Intl.NumberFormat('fr-FR', {
        style: 'currency',
        currency: 'EUR'
    }).format(price)
}

const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return new Intl.DateTimeFormat('fr-FR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric'
    }).format(date)
}

onMounted(() => {
    loadData()
})
</script>

<style scoped>
.trader-products {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
    padding-bottom: 80px;
    /* Space for bottom menu */
}

.products-section {
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
    background: #4caf50;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    cursor: pointer;
    font-weight: 600;
}

.btn-add:hover {
    background: #45a049;
}

.loading {
    text-align: center;
    padding: 40px;
    color: #666;
}

.empty-state {
    text-align: center;
    padding: 60px 20px;
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.empty-state p {
    color: #666;
    margin-bottom: 20px;
    font-size: 1.1rem;
}

.products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 20px;
}

.product-card {
    background: white;
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border-left: 4px solid #4caf50;
    transition: transform 0.2s, box-shadow 0.2s;
}

.product-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.product-card.unavailable {
    opacity: 0.7;
    border-left-color: #999;
}

.product-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 15px;
}

.product-header h3 {
    margin: 0;
    font-size: 1.3rem;
    color: #333;
    flex: 1;
}

.product-actions {
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
    background: #e3f2fd;
}

.btn-delete:hover {
    background: #ffebee;
}

.product-info {
    margin-bottom: 15px;
}

.product-description {
    color: #666;
    margin: 10px 0;
    font-size: 0.95rem;
}

.product-price {
    font-size: 1.5rem;
    color: #ff6b35;
    font-weight: bold;
    margin-top: 10px;
}

.product-availability {
    margin: 15px 0;
    padding: 10px;
    background: #f9f9f9;
    border-radius: 8px;
}

.availability-toggle {
    display: flex;
    align-items: center;
    gap: 10px;
    cursor: pointer;
    font-weight: 600;
}

.availability-toggle input[type="checkbox"] {
    width: 20px;
    height: 20px;
    cursor: pointer;
}

.product-market-day,
.product-stock {
    margin-top: 10px;
    padding: 8px;
    background: #e3f2fd;
    border-radius: 6px;
    font-size: 0.9rem;
    color: #1976d2;
}

.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.modal-content {
    background: white;
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
    color: #666;
    line-height: 1;
}

.close-btn:hover {
    color: #333;
}

.modal-content h2 {
    margin: 0 0 25px 0;
    font-size: 1.8rem;
}

.product-form {
    display: flex;
    flex-direction: column;
    gap: 20px;
}

.form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 15px;
}

.form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.form-group label {
    font-weight: 600;
    color: #333;
}

.form-group input,
.form-group textarea {
    padding: 12px;
    border: 1px solid #ddd;
    border-radius: 8px;
    font-size: 1rem;
    font-family: inherit;
}

.form-group textarea {
    resize: vertical;
}

.form-group input:disabled,
.form-group textarea:disabled {
    background: #f5f5f5;
    cursor: not-allowed;
}

.form-hint {
    color: #666;
    font-size: 0.85rem;
    margin-top: -5px;
}

.checkbox-label {
    display: flex;
    align-items: center;
    gap: 10px;
    cursor: pointer;
    font-weight: normal;
}

.checkbox-label input[type="checkbox"] {
    width: 20px;
    height: 20px;
    cursor: pointer;
}

.form-actions {
    display: flex;
    gap: 10px;
    margin-top: 10px;
}

.btn-secondary {
    flex: 1;
    padding: 12px;
    background: #f0f0f0;
    color: #333;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    cursor: pointer;
    font-weight: 600;
}

.btn-secondary:hover:not(:disabled) {
    background: #e0e0e0;
}

.btn-secondary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.btn-primary {
    flex: 1;
    padding: 12px;
    background: #ff6b35;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    cursor: pointer;
    font-weight: 600;
}

.btn-primary:hover:not(:disabled) {
    background: #e55a2b;
}

.btn-primary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

@media (max-width: 768px) {
    .form-row {
        grid-template-columns: 1fr;
    }

    .section-header {
        flex-direction: column;
        align-items: flex-start;
    }
}
</style>
