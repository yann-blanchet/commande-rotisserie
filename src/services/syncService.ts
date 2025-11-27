import { db, type OfflineOrder } from '../db/database'
import { supabase, isOnline } from '../lib/supabase'

export class SyncService {
  /**
   * Sync pending offline orders to Supabase
   */
  async syncPendingOrders(): Promise<void> {
    if (!isOnline()) {
      console.log('Offline: Cannot sync orders')
      return
    }

    const pendingOrders = await db.offline_orders
      .where('sync_status')
      .equals('pending')
      .toArray()

    for (const order of pendingOrders) {
      try {
        const { error } = await supabase
          .from('orders')
          .insert({
            vendor_id: order.vendor_id,
            product_id: order.product_id,
            customer_name: order.customer_name,
            pickup_time: order.pickup_time,
            created_at: order.created_at
          })

        if (error) throw error

        // Mark as synced
        await db.offline_orders.update(order.id_temporaire!, {
          sync_status: 'synced'
        })
      } catch (error) {
        console.error('Error syncing order:', error)
        await db.offline_orders.update(order.id_temporaire!, {
          sync_status: 'error'
        })
      }
    }
  }

  /**
   * Sync vendors cache from Supabase
   */
  async syncVendors(): Promise<void> {
    if (!isOnline()) {
      console.log('Offline: Using cached vendors')
      return
    }

    try {
      const { data, error } = await supabase
        .from('vendors')
        .select('*')

      if (error) throw error

      if (data) {
        for (const vendor of data) {
          await db.vendors_cache.put({
            id: vendor.id,
            data: vendor,
            updated_at: new Date().toISOString()
          })
        }
      }
    } catch (error) {
      console.error('Error syncing vendors:', error)
    }
  }

  /**
   * Sync products for a specific vendor
   */
  async syncProducts(vendorId: string): Promise<void> {
    if (!isOnline()) {
      console.log('Offline: Using cached products')
      return
    }

    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .eq('vendor_id', vendorId)
        .order('created_at', { ascending: false })

      if (error) throw error

      if (data) {
        for (const product of data) {
          await db.products_cache.put({
            id: product.id,
            vendor_id: vendorId,
            data: product,
            updated_at: new Date().toISOString()
          })
        }
      }
    } catch (error) {
      console.error('Error syncing products:', error)
    }
  }

  /**
   * Sync orders for a trader (vendor)
   */
  async syncOrdersForVendor(vendorId: string): Promise<void> {
    if (!isOnline()) {
      console.log('Offline: Using cached orders')
      return
    }

    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*')
        .eq('vendor_id', vendorId)
        .order('created_at', { ascending: false })

      if (error) throw error

      if (data) {
        for (const order of data) {
          await db.orders_cache.put({
            id: order.id,
            vendor_id: vendorId,
            data: order,
            updated_at: new Date().toISOString()
          })
        }
      }
    } catch (error) {
      console.error('Error syncing orders:', error)
    }
  }

  /**
   * Create an offline order
   */
  async createOfflineOrder(order: Omit<OfflineOrder, 'id_temporaire' | 'sync_status' | 'created_at'>): Promise<number> {
    const offlineOrder: OfflineOrder = {
      ...order,
      created_at: new Date().toISOString(),
      sync_status: 'pending'
    }

    const id = await db.offline_orders.add(offlineOrder)

    // Try to sync immediately if online
    if (isOnline()) {
      await this.syncPendingOrders()
    }

    return id as number
  }

  /**
   * Initialize sync on app start
   */
  async initializeSync(): Promise<void> {
    if (isOnline()) {
      await this.syncVendors()
      await this.syncPendingOrders()
    }

    // Listen for online event
    window.addEventListener('online', () => {
      this.syncPendingOrders()
      this.syncVendors()
    })
  }
}

export const syncService = new SyncService()

