<template>
    <div class="trader-current-market">
        <TraderHeader title="🏪 Marché en cours" />

        <div v-if="loading" class="loading">Chargement...</div>

        <div v-else-if="error" class="error-message">
            <p>{{ error }}</p>
            <button @click="loadCurrentMarket" class="btn-primary">Réessayer</button>
        </div>

        <!-- Sélecteur de session -->
        <div v-else-if="allActiveSessions.length > 0" class="session-selector-section">
            <label class="selector-label">Sélectionner une session:</label>
            <select v-model="selectedSessionId" @change="onSessionChange" class="session-selector">
                <option value="">-- Sélectionner une session --</option>
                <option v-for="session in allActiveSessions" :key="session.id" :value="session.id">
                    {{ (Array.isArray(session.markets) ? session.markets[0] : session.markets)?.name || 'Marché' }} - {{
                        formatDate(session.date) }}
                </option>
            </select>
            <button @click="showStartSessionModal = true" class="btn-add-session" :disabled="!isOnline()">
                + Nouvelle session
            </button>
        </div>

        <div v-else-if="!currentMarketSession && allActiveSessions.length === 0" class="empty-state">
            <div class="empty-content">
                <h2>Aucune session active</h2>
                <p>Commencez une session de commandes pour un marché à une date donnée.</p>
                <button @click="showStartSessionModal = true" class="btn-start-session" :disabled="!isOnline()">
                    🚀 Commencer les commandes
                </button>
            </div>
        </div>

        <div v-else-if="currentMarketSession" class="market-session">
            <!-- Market Info -->
            <div class="market-info-card">
                <div class="market-header">
                    <div>
                        <h2 class="market-name">{{ currentMarketSession.market.name }}</h2>
                        <span class="market-place">📍 {{ currentMarketSession.market.place }}</span>
                    </div>
                    <button @click="deleteSession" class="btn-delete-session" :disabled="saving || !isOnline()">
                        🗑️ Supprimer la session
                    </button>
                </div>
                <div class="market-dates">
                    <div class="date-item">
                        <span class="date-label">📅 Date du marché:</span>
                        <span class="date-value">{{ formatDate(currentMarketSession.date) }}</span>
                    </div>
                    <div class="date-item">
                        <span class="date-label">⏰ Fermeture des commandes:</span>
                        <span class="date-value closure-date">{{ formatDateTime(currentMarketSession.orderClosureDate)
                        }}</span>
                    </div>
                </div>
            </div>

            <!-- Tabbar pour les produits -->
            <div class="products-tabs">
                <div class="tabs-header">
                    <button :class="['tab-button', activeTab === 'available' ? 'active' : '']"
                        @click="activeTab = 'available'">
                        Produits disponibles ({{ currentMarketSession.products.length }})
                    </button>
                    <button :class="['tab-button', activeTab === 'all' ? 'active' : '']" @click="activeTab = 'all'">
                        Tous les produits ({{ allProducts.length }})
                    </button>
                </div>

                <div class="tabs-content">
                    <!-- Tab: Produits disponibles -->
                    <div v-if="activeTab === 'available'" class="tab-panel">
                        <div v-if="currentMarketSession.products.length === 0" class="no-products">
                            <p>Aucun produit disponible pour cette session</p>
                        </div>
                        <div v-else class="products-grid">
                            <div v-for="product in currentMarketSession.products" :key="product.id"
                                class="product-card">
                                <div class="product-header">
                                    <h4 class="product-name">{{ product.data.nom || product.data.name }}</h4>
                                    <span class="product-price">{{ formatPrice(product.data.prix || product.data.price)
                                    }}</span>
                                </div>
                                <p v-if="product.data.description" class="product-description">{{
                                    product.data.description }}
                                </p>
                                <div class="product-status">
                                    <span
                                        :class="['status-badge', product.data.available !== false ? 'available' : 'unavailable']">
                                        {{ product.data.available !== false ? '✅ Disponible' : '❌ Indisponible' }}
                                    </span>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Tab: Tous les produits (avec checkboxes pour modifier) -->
                    <div v-if="activeTab === 'all'" class="tab-panel">
                        <div class="products-selection">
                            <div v-if="allProducts.length === 0" class="no-products-hint">
                                <p>Aucun produit disponible. Créez d'abord des produits dans la section "Product".</p>
                            </div>
                            <div v-else class="products-checkbox-list">
                                <label v-for="product in allProducts" :key="product.id" class="product-checkbox-item"
                                    :class="{ 'unavailable': product.data.available === false }">
                                    <input type="checkbox" :value="product.id" :checked="isProductInSession(product.id)"
                                        @change="toggleProductInSession(product.id)"
                                        :disabled="saving || product.data.available === false || !isOnline()"
                                        class="product-checkbox" />
                                    <div class="product-checkbox-content">
                                        <span class="product-checkbox-name">{{ product.data.nom || product.data.name
                                        }}</span>
                                        <span class="product-checkbox-price">{{ formatPrice(product.data.prix ||
                                            product.data.price) }}</span>
                                    </div>
                                    <span v-if="product.data.available === false"
                                        class="product-unavailable-badge">Indisponible</span>
                                </label>
                            </div>
                        </div>
                        <div class="tab-actions">
                            <button @click="saveProductsToSession" class="btn-save-products"
                                :disabled="saving || !isOnline()">
                                {{ saving ? 'Enregistrement...' : 'Enregistrer les modifications' }}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Modal pour démarrer une session -->
        <div v-if="showStartSessionModal" class="modal-overlay" @click="closeStartSessionModal">
            <div class="modal-content" @click.stop>
                <button class="close-btn" @click="closeStartSessionModal">×</button>
                <h2>Commencer une session de commandes</h2>

                <form @submit.prevent="startMarketSession" class="session-form">
                    <div class="form-group">
                        <label>Marché *</label>
                        <select v-model="sessionForm.marketId" required class="form-select" :disabled="saving">
                            <option value="">Sélectionner un marché</option>
                            <option v-for="market in marketsWithoutActiveSession" :key="market.id" :value="market.id">
                                {{ market.name }} - {{ market.place }}
                            </option>
                        </select>
                        <small v-if="marketsWithoutActiveSession.length === 0" class="form-hint"
                            style="color: #dc2626;">
                            Tous vos marchés ont déjà une session active
                        </small>
                    </div>

                    <div class="form-group">
                        <label>Date du marché *</label>
                        <input v-model="sessionForm.date" type="date" required class="form-input" :min="minDate"
                            :disabled="saving || !sessionForm.marketId" />
                        <small v-if="sessionForm.marketId" class="form-hint">
                            Date calculée automatiquement selon les jours du marché
                        </small>
                    </div>

                    <div class="form-group">
                        <label>Date de fermeture des commandes *</label>
                        <input v-model="sessionForm.orderClosureDate" type="datetime-local" required class="form-input"
                            :min="minDateTime"
                            :max="sessionForm.date ? (() => { const d = new Date(sessionForm.date); d.setDate(d.getDate() - 1); d.setHours(23, 59, 59); return d.toISOString().slice(0, 16); })() : undefined"
                            :disabled="saving || !sessionForm.marketId" />
                        <small class="form-hint">Doit être antérieure à la date du marché. Par défaut : veille du marché
                            à 20h</small>
                        <small
                            v-if="sessionForm.date && sessionForm.orderClosureDate && new Date(sessionForm.orderClosureDate) >= new Date(sessionForm.date)"
                            class="form-hint" style="color: #dc2626; display: block; margin-top: 4px;">
                            ⚠️ La date de fermeture doit être antérieure à la date du marché
                        </small>
                    </div>

                    <div class="form-actions">
                        <button type="button" @click="closeStartSessionModal" class="btn-secondary" :disabled="saving">
                            Annuler
                        </button>
                        <button type="submit" class="btn-primary"
                            :disabled="saving || !sessionForm.marketId || !sessionForm.date || !sessionForm.orderClosureDate">
                            {{ saving ? 'Création...' : 'Créer la session' }}
                        </button>
                    </div>
                </form>
            </div>
        </div>

        <BottomMenuBar />
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase, isOnline } from '../lib/supabase'
import { syncService } from '../services/syncService'
import { db } from '../db/database'
import type { ProductCache } from '../db/database'
import TraderHeader from '../components/TraderHeader.vue'
import BottomMenuBar from '../components/BottomMenuBar.vue'

const router = useRouter()
const route = useRoute()
const loading = ref(true)
const error = ref<string | null>(null)
const saving = ref(false)
const showStartSessionModal = ref(false)
const activeTab = ref<'available' | 'all'>('available')
const allMarkets = ref<any[]>([])
const marketsWithActiveSessions = ref<string[]>([]) // IDs des marchés avec sessions actives
const allProducts = ref<ProductCache[]>([]) // Tous les produits du stand
const sessionProductIds = ref<Set<string>>(new Set()) // IDs des produits dans la session (pour modification)
const allActiveSessions = ref<Array<{
    id: string
    market_id: string
    date: string
    order_closure_date: string
    markets: { id: string; name: string; place: string; days: string[] }
}>>([])
const selectedSessionId = ref<string>('')
const currentMarketSession = ref<{
    id: string
    market: { id: string; name: string; place: string; days: string[] }
    date: string
    orderClosureDate: string
    products: ProductCache[]
} | null>(null)

const sessionForm = ref({
    marketId: '',
    date: '',
    orderClosureDate: ''
})

// Filtrer les marchés sans session active
const marketsWithoutActiveSession = computed(() => {
    return allMarkets.value.filter(market => !marketsWithActiveSessions.value.includes(market.id))
})

// Calculer la date minimale (aujourd'hui)
const minDate = new Date().toISOString().split('T')[0]
const minDateTime = new Date().toISOString().slice(0, 16)

// Fonction pour charger une session par son ID
const loadSessionById = async (sessionId: string, vendorId: string | null) => {
    if (!vendorId) return

    try {
        const { data: session, error: sessionError } = await supabase
            .from('market_sessions')
            .select(`
                id,
                market_id,
                date,
                order_closure_date,
                markets!inner(id, name, place, days)
            `)
            .eq('id', sessionId)
            .eq('is_active', true)
            .single()

        if (sessionError || !session) {
            currentMarketSession.value = null
            return
        }

        const market = Array.isArray(session.markets) ? session.markets[0] : session.markets
        if (!market) {
            currentMarketSession.value = null
            return
        }

        // Load products for this session
        const { data: sessionProducts } = await supabase
            .from('market_session_products')
            .select('product_id')
            .eq('market_session_id', session.id)

        const productIds = sessionProducts?.map((sp: any) => sp.product_id) || []

        // Stocker les IDs des produits de la session pour la modification
        sessionProductIds.value = new Set(productIds)

        // Filter products that are in the session and available
        const availableProducts = allProducts.value.filter(
            (p) => productIds.includes(p.id) && p.data.available !== false
        )

        currentMarketSession.value = {
            id: session.id,
            market: {
                id: market.id,
                name: market.name,
                place: market.place,
                days: market.days || []
            },
            date: session.date,
            orderClosureDate: session.order_closure_date,
            products: availableProducts
        }
    } catch (err: any) {
        console.error('Error loading session:', err)
        currentMarketSession.value = null
    }
}

// Fonction appelée quand on change de session
const onSessionChange = async () => {
    if (!selectedSessionId.value) {
        currentMarketSession.value = null
        return
    }

    const sessionStr = localStorage.getItem('trader_session')
    if (!sessionStr) return

    try {
        const session = JSON.parse(sessionStr)
        const vendorId = session.vendor_id

        if (vendorId) {
            await loadSessionById(selectedSessionId.value, vendorId)
            // Mettre à jour l'URL avec le paramètre session
            router.replace({ query: { ...route.query, session: selectedSessionId.value } })
        }
    } catch (err) {
        console.error('Error changing session:', err)
    }
}

// Fonction pour charger tous les produits du stand
const loadAllProducts = async (vendorId: string) => {
    if (isOnline()) {
        await syncService.syncProducts(vendorId)
    }

    const cachedProducts = await db.products_cache
        .where('vendor_id')
        .equals(vendorId)
        .toArray()

    allProducts.value = cachedProducts.sort((a, b) =>
        (a.data.nom || a.data.name || '').localeCompare(b.data.nom || b.data.name || '')
    )

}

// Fonction pour vérifier si un produit est dans la session
const isProductInSession = (productId: string): boolean => {
    return sessionProductIds.value.has(productId)
}

// Fonction pour cocher/décocher un produit dans la session
const toggleProductInSession = (productId: string) => {
    if (sessionProductIds.value.has(productId)) {
        sessionProductIds.value.delete(productId)
    } else {
        sessionProductIds.value.add(productId)
    }
}

// Fonction pour sauvegarder les modifications des produits de la session
const saveProductsToSession = async () => {
    if (!currentMarketSession.value || !isOnline()) {
        return
    }

    saving.value = true

    try {
        const sessionId = currentMarketSession.value.id

        // Supprimer tous les produits actuels de la session
        const { error: deleteError } = await supabase
            .from('market_session_products')
            .delete()
            .eq('market_session_id', sessionId)

        if (deleteError) throw deleteError

        // Ajouter les nouveaux produits sélectionnés
        if (sessionProductIds.value.size > 0) {
            const productInserts = Array.from(sessionProductIds.value).map((productId) => ({
                market_session_id: sessionId,
                product_id: productId
            }))

            const { error: insertError } = await supabase
                .from('market_session_products')
                .insert(productInserts)

            if (insertError) throw insertError
        }

        // Recharger la session
        await loadCurrentMarket()
        alert('Produits mis à jour avec succès')
    } catch (err: any) {
        console.error('Error saving products to session:', err)
        alert('Erreur lors de la mise à jour: ' + (err.message || 'Erreur inconnue'))
    } finally {
        saving.value = false
    }
}

// Fonction pour supprimer la session
const deleteSession = async () => {
    if (!currentMarketSession.value) return

    if (!confirm('Êtes-vous sûr de vouloir supprimer cette session ? Cette action est irréversible.')) {
        return
    }

    if (!isOnline()) {
        alert('Vous devez être en ligne pour supprimer une session')
        return
    }

    saving.value = true

    try {
        const sessionId = currentMarketSession.value.id

        // Option 1: Désactiver la session (recommandé pour garder l'historique)
        const { error: updateError } = await supabase
            .from('market_sessions')
            .update({ is_active: false })
            .eq('id', sessionId)

        if (updateError) throw updateError

        // Option 2: Supprimer complètement (décommenter si vous préférez)
        // const { error: deleteError } = await supabase
        //   .from('market_sessions')
        //   .delete()
        //   .eq('id', sessionId)
        // if (deleteError) throw deleteError

        // Recharger
        await loadCurrentMarket()

        // Si la session supprimée était sélectionnée, sélectionner une autre ou vider
        if (selectedSessionId.value === sessionId) {
            if (allActiveSessions.value.length > 0 && allActiveSessions.value[0]) {
                selectedSessionId.value = allActiveSessions.value[0].id
                await onSessionChange()
            } else {
                selectedSessionId.value = ''
                currentMarketSession.value = null
            }
        }

        alert('Session supprimée avec succès')
    } catch (err: any) {
        console.error('Error deleting session:', err)
        alert('Erreur lors de la suppression: ' + (err.message || 'Erreur inconnue'))
    } finally {
        saving.value = false
    }
}

// Watcher pour calculer automatiquement la date du marché quand on sélectionne un marché
watch(() => sessionForm.value.marketId, (marketId) => {
    if (marketId) {
        const selectedMarket = allMarkets.value.find(m => m.id === marketId)
        if (selectedMarket && selectedMarket.days) {
            // Calculer la prochaine date de marché
            const nextDate = findNextMarketDate(selectedMarket.days)
            if (nextDate) {
                // Formater la date pour l'input date (YYYY-MM-DD)
                const dateStr = nextDate.toISOString().split('T')[0]
                if (dateStr) {
                    sessionForm.value.date = dateStr
                }

                // Mettre la date de fermeture par défaut à la veille du marché à 20h
                const closureDate = new Date(nextDate)
                closureDate.setDate(closureDate.getDate() - 1) // Veille
                closureDate.setHours(20, 0, 0, 0) // 20h
                const closureDateStr = closureDate.toISOString().slice(0, 16)
                if (closureDateStr) {
                    sessionForm.value.orderClosureDate = closureDateStr
                }
            }
        }
    }
})

// Watcher pour s'assurer que la date de fermeture reste antérieure à la date du marché
watch(() => sessionForm.value.date, (marketDate) => {
    if (marketDate && sessionForm.value.orderClosureDate) {
        const marketDateObj = new Date(marketDate)
        const closureDateObj = new Date(sessionForm.value.orderClosureDate)

        // Si la date de fermeture est après ou égale à la date du marché, la réajuster
        if (closureDateObj >= marketDateObj) {
            const newClosureDate = new Date(marketDateObj)
            newClosureDate.setDate(newClosureDate.getDate() - 1)
            newClosureDate.setHours(20, 0, 0, 0)
            sessionForm.value.orderClosureDate = newClosureDate.toISOString().slice(0, 16)
        }
    }
})

// Fonction pour trouver la prochaine date de marché
const findNextMarketDate = (days: string[]): Date | null => {
    if (!days || days.length === 0) return null

    const dayMap: Record<string, number> = {
        monday: 1,
        tuesday: 2,
        wednesday: 3,
        thursday: 4,
        friday: 5,
        saturday: 6,
        sunday: 0
    }

    const today = new Date()
    const dayNumbers = days
        .map(d => dayMap[d.toLowerCase()])
        .filter((d): d is number => d !== undefined)
        .sort((a, b) => a - b)

    if (dayNumbers.length === 0) return null

    // Trouver le prochain jour de marché
    for (let i = 0; i < 7; i++) {
        const checkDate = new Date(today)
        checkDate.setDate(today.getDate() + i)
        const checkDay = checkDate.getDay()

        if (dayNumbers.includes(checkDay)) {
            return checkDate
        }
    }

    return null
}

const loadCurrentMarket = async () => {
    loading.value = true
    error.value = null

    const sessionStr = localStorage.getItem('trader_session')
    if (!sessionStr) {
        router.push('/trader/login')
        return
    }

    try {
        const session = JSON.parse(sessionStr)
        if (!session.authenticated || !session.profile_id) {
            error.value = 'Session invalide. Veuillez vous reconnecter.'
            loading.value = false
            return
        }

        const profileId = session.profile_id
        let vendorId: string | null = session.vendor_id || null

        // Load vendor and markets
        if (isOnline()) {
            await syncService.syncVendors()
            const { data: vendor } = await supabase
                .from('vendors')
                .select('id, vendor_markets(market_id, markets(*))')
                .eq('profile_id', profileId)
                .maybeSingle()

            if (vendor) {
                vendorId = vendor.id
                const vendorMarkets = Array.isArray(vendor.vendor_markets) ? vendor.vendor_markets : []
                const markets = vendorMarkets.map((vm: any) => vm.markets).filter((m: any) => m)
                allMarkets.value = markets

                // Load all active market sessions to filter markets
                const marketIds = markets.map((m: any) => m.id)
                const { data: activeSessions } = await supabase
                    .from('market_sessions')
                    .select('market_id')
                    .eq('is_active', true)
                    .in('market_id', marketIds)

                // Stocker les IDs des marchés avec sessions actives
                marketsWithActiveSessions.value = activeSessions?.map((s: any) => s.market_id) || []

                // Synchroniser les sessions avant de charger
                if (vendorId) {
                    await syncService.syncMarketSessions(vendorId)
                }

                // Load all active market sessions
                const { data: allSessions, error: sessionsError } = await supabase
                    .from('market_sessions')
                    .select(`
            id,
            market_id,
            date,
            order_closure_date,
            markets!inner(id, name, place, days)
          `)
                    .eq('is_active', true)
                    .in('market_id', marketIds)
                    .order('date', { ascending: true })

                if (!sessionsError && allSessions) {
                    // Transformer les sessions pour avoir un format cohérent
                    allActiveSessions.value = allSessions.map((s: any) => ({
                        id: s.id,
                        market_id: s.market_id,
                        date: s.date,
                        order_closure_date: s.order_closure_date,
                        markets: Array.isArray(s.markets) ? s.markets[0] : s.markets
                    }))

                    // Mettre à jour le cache local avec les sessions
                    for (const session of allSessions) {
                        await db.market_sessions_cache.put({
                            id: session.id,
                            market_id: session.market_id,
                            data: {
                                id: session.id,
                                market_id: session.market_id,
                                date: session.date,
                                order_closure_date: session.order_closure_date,
                                is_active: true
                            },
                            updated_at: new Date().toISOString()
                        })
                    }

                    // Sélectionner la première session par défaut ou celle passée en paramètre
                    const sessionIdFromRoute = route.query.session as string | undefined

                    if (sessionIdFromRoute && allActiveSessions.value.find((s) => s.id === sessionIdFromRoute)) {
                        selectedSessionId.value = sessionIdFromRoute
                    } else if (allActiveSessions.value.length > 0 && allActiveSessions.value[0]) {
                        selectedSessionId.value = allActiveSessions.value[0].id
                    }
                }

                // Load all products
                if (vendorId) {
                    await loadAllProducts(vendorId)
                }

                // Charger la session sélectionnée
                if (selectedSessionId.value && vendorId) {
                    await loadSessionById(selectedSessionId.value, vendorId)
                }
            }
        } else {
            // Offline: use cache
            const cachedVendors = await db.vendors_cache.toArray()
            const cachedVendor = cachedVendors.find(v => v.data.profile_id === profileId)

            if (cachedVendor) {
                vendorId = cachedVendor.id
                const vendorMarkets = cachedVendor.data.vendor_markets || []
                const markets = vendorMarkets.map((vm: any) => vm.markets).filter((m: any) => m)
                allMarkets.value = markets
                // En mode offline, on ne peut pas vérifier les sessions actives
                marketsWithActiveSessions.value = []
            }
        }
    } catch (err: any) {
        console.error('Error loading current market:', err)
        error.value = err.message || 'Erreur lors du chargement'
    } finally {
        loading.value = false
    }
}

const startMarketSession = async () => {
    if (!sessionForm.value.marketId || !sessionForm.value.date || !sessionForm.value.orderClosureDate) {
        return
    }

    // Validation : la date de fermeture doit être antérieure à la date du marché
    const marketDate = new Date(sessionForm.value.date)
    const closureDate = new Date(sessionForm.value.orderClosureDate)

    if (closureDate >= marketDate) {
        alert('La date de fermeture des commandes doit être antérieure à la date du marché')
        return
    }

    saving.value = true

    try {
        if (!isOnline()) {
            alert('Vous devez être en ligne pour créer une session')
            saving.value = false
            return
        }

        const sessionStr = localStorage.getItem('trader_session')
        if (!sessionStr) {
            router.push('/trader/login')
            return
        }

        const session = JSON.parse(sessionStr)
        if (!session.authenticated || !session.profile_id) {
            error.value = 'Session invalide. Veuillez vous reconnecter.'
            saving.value = false
            return
        }

        const vendorId = session.vendor_id

        if (!vendorId) {
            error.value = 'Vendor ID manquant'
            saving.value = false
            return
        }

        // Convert date to ISO format
        const marketDate = new Date(sessionForm.value.date).toISOString().split('T')[0]
        const closureDateTime = new Date(sessionForm.value.orderClosureDate).toISOString()

        // Create market session
        const { error: createError } = await supabase
            .from('market_sessions')
            .insert({
                market_id: sessionForm.value.marketId,
                date: marketDate,
                order_closure_date: closureDateTime,
                is_active: true
            })

        if (createError) throw createError

        // Les produits seront ajoutés via la tabbar après création

        // Reload the session and update markets list
        await loadCurrentMarket()
        closeStartSessionModal()
    } catch (err: any) {
        console.error('Error starting market session:', err)
        error.value = err.message || 'Erreur lors de la création de la session'
        alert('Erreur: ' + (err.message || 'Erreur inconnue'))
    } finally {
        saving.value = false
    }
}

const closeStartSessionModal = () => {
    showStartSessionModal.value = false
    sessionForm.value = {
        marketId: '',
        date: '',
        orderClosureDate: ''
    }
}

// Charger les produits quand on ouvre la modal
watch(showStartSessionModal, async (isOpen) => {
    if (isOpen) {
        const sessionStr = localStorage.getItem('trader_session')
        if (sessionStr) {
            try {
                const session = JSON.parse(sessionStr)
                const vendorId = session.vendor_id
                if (vendorId) {
                    await loadAllProducts(vendorId)
                }
            } catch (e) {
                console.error('Error loading products for modal:', e)
            }
        }
    }
})


const formatDate = (dateString: string): string => {
    const date = new Date(dateString)
    return new Intl.DateTimeFormat('fr-FR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric'
    }).format(date)
}

const formatDateTime = (dateString: string): string => {
    const date = new Date(dateString)
    return new Intl.DateTimeFormat('fr-FR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }).format(date)
}

const formatPrice = (price: number): string => {
    return new Intl.NumberFormat('fr-FR', {
        style: 'currency',
        currency: 'EUR'
    }).format(price)
}

onMounted(() => {
    loadCurrentMarket()
})
</script>

<style scoped>
.trader-current-market {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
    padding-bottom: 80px;
}

.loading {
    text-align: center;
    padding: 40px;
    color: #666;
}

.error-message {
    text-align: center;
    padding: 40px;
    background: #fee2e2;
    border-radius: 12px;
    color: #dc2626;
    margin-bottom: 20px;
}

.empty-state {
    text-align: center;
    padding: 60px 20px;
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.empty-content h2 {
    font-size: 1.5rem;
    margin-bottom: 10px;
    color: #333;
}

.empty-content p {
    color: #666;
    margin-bottom: 20px;
}

.btn-start-session {
    padding: 14px 28px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    border-radius: 12px;
    font-size: 1.1rem;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.btn-start-session:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
}

.btn-start-session:disabled {
    opacity: 0.6;
    cursor: not-allowed;
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
    border-radius: 16px;
    padding: 30px;
    max-width: 500px;
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
    padding: 0;
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
}

.close-btn:hover {
    color: #333;
}

.modal-content h2 {
    margin: 0 0 25px 0;
    font-size: 1.8rem;
    color: #1a202c;
}

.session-form {
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
    color: #333;
    font-size: 0.95rem;
}

.form-select,
.form-input {
    padding: 12px;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 1rem;
    font-family: inherit;
    transition: all 0.2s ease;
}

.form-select:focus,
.form-input:focus {
    outline: none;
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-select:disabled,
.form-input:disabled {
    background: #f5f5f5;
    cursor: not-allowed;
}

.form-hint {
    color: #666;
    font-size: 0.85rem;
    margin-top: -5px;
}

.form-actions {
    display: flex;
    gap: 12px;
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
    transition: all 0.2s ease;
}

.btn-secondary:hover:not(:disabled) {
    background: #e0e0e0;
}

.btn-secondary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.products-selection {
    max-height: 300px;
    overflow-y: auto;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    padding: 12px;
    background: #f8fafc;
}

.no-products-hint {
    text-align: center;
    padding: 20px;
    color: #666;
}

.products-checkbox-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.product-checkbox-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    background: white;
    border-radius: 8px;
    border: 2px solid #e2e8f0;
    cursor: pointer;
    transition: all 0.2s ease;
}

.product-checkbox-item:hover:not(.unavailable) {
    border-color: #667eea;
    background: #f0f4ff;
}

.product-checkbox-item.unavailable {
    opacity: 0.6;
    cursor: not-allowed;
    background: #f5f5f5;
}

.product-checkbox {
    width: 20px;
    height: 20px;
    cursor: pointer;
    flex-shrink: 0;
}

.product-checkbox-item.unavailable .product-checkbox {
    cursor: not-allowed;
}

.product-checkbox-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex: 1;
    gap: 12px;
}

.product-checkbox-name {
    font-weight: 600;
    color: #1a202c;
    flex: 1;
}

.product-checkbox-price {
    font-weight: 700;
    color: #667eea;
    font-size: 1rem;
}

.product-unavailable-badge {
    padding: 4px 8px;
    background: #fee2e2;
    color: #991b1b;
    border-radius: 4px;
    font-size: 0.75rem;
    font-weight: 600;
}

.market-session {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

.market-info-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 16px;
    padding: 24px;
    color: white;
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.market-header {
    margin-bottom: 20px;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
}

.btn-delete-session {
    padding: 10px 16px;
    background: #fee2e2;
    color: #dc2626;
    border: 2px solid #fecaca;
    border-radius: 8px;
    cursor: pointer;
    font-weight: 600;
    font-size: 0.9rem;
    transition: all 0.2s ease;
    white-space: nowrap;
}

.btn-delete-session:hover:not(:disabled) {
    background: #dc2626;
    color: white;
    border-color: #dc2626;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
}

.btn-delete-session:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.market-name {
    font-size: 1.8rem;
    font-weight: 700;
    margin: 0 0 8px 0;
}

.market-place {
    font-size: 1rem;
    opacity: 0.9;
}

.market-dates {
    display: flex;
    flex-direction: column;
    gap: 12px;
}

.date-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    background: rgba(255, 255, 255, 0.15);
    border-radius: 8px;
    backdrop-filter: blur(10px);
}

.date-label {
    font-weight: 600;
    font-size: 0.95rem;
}

.date-value {
    font-weight: 700;
    font-size: 1.1rem;
}

.closure-date {
    color: #fef3c7;
}

.products-tabs {
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    overflow: hidden;
}

.tabs-header {
    display: flex;
    border-bottom: 2px solid #e2e8f0;
    background: #f8fafc;
}

.tab-button {
    flex: 1;
    padding: 16px 20px;
    background: transparent;
    border: none;
    border-bottom: 3px solid transparent;
    cursor: pointer;
    font-weight: 600;
    font-size: 0.95rem;
    color: #64748b;
    transition: all 0.2s ease;
}

.tab-button:hover {
    background: #f1f5f9;
    color: #334155;
}

.tab-button.active {
    color: #667eea;
    border-bottom-color: #667eea;
    background: white;
}

.tabs-content {
    padding: 24px;
}

.tab-panel {
    min-height: 200px;
}

.tab-actions {
    margin-top: 20px;
    padding-top: 20px;
    border-top: 2px solid #e2e8f0;
    display: flex;
    justify-content: flex-end;
}

.btn-save-products {
    padding: 12px 24px;
    background: #667eea;
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
}

.btn-save-products:hover:not(:disabled) {
    background: #5568d3;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.btn-save-products:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.products-section {
    background: white;
    border-radius: 12px;
    padding: 24px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.section-title {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 0 0 20px 0;
    color: #1a202c;
}

.no-products {
    text-align: center;
    padding: 40px;
    color: #666;
}

.products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 16px;
}

.product-card {
    background: #f8fafc;
    border-radius: 12px;
    padding: 16px;
    border: 2px solid #e2e8f0;
    transition: all 0.2s ease;
}

.product-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    border-color: #cbd5e1;
}

.product-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 12px;
}

.product-name {
    font-size: 1.2rem;
    font-weight: 700;
    color: #1a202c;
    margin: 0;
    flex: 1;
}

.product-price {
    font-size: 1.3rem;
    font-weight: 700;
    color: #667eea;
}

.product-description {
    color: #64748b;
    font-size: 0.9rem;
    margin: 8px 0;
    line-height: 1.5;
}

.product-status {
    margin-top: 12px;
}

.status-badge {
    display: inline-block;
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 0.85rem;
    font-weight: 600;
}

.status-badge.available {
    background: #d1fae5;
    color: #065f46;
}

.status-badge.unavailable {
    background: #fee2e2;
    color: #991b1b;
}

.btn-primary {
    padding: 12px 24px;
    background: #667eea;
    color: white;
    border: none;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
}

.btn-primary:hover {
    background: #5568d3;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

@media (max-width: 768px) {
    .market-dates {
        gap: 8px;
    }

    .date-item {
        flex-direction: column;
        align-items: flex-start;
        gap: 4px;
    }

    .products-grid {
        grid-template-columns: 1fr;
    }
}
</style>
