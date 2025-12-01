import Dexie, { type Table } from 'dexie'

export interface Favorite {
  id?: number
  stand: string
  nomDuStand: string
}

export interface OfflineOrder {
  id_temporaire?: number
  vendor_id: string
  product_id: string
  customer_name: string
  pickup_time: string
  created_at: string
  sync_status: 'pending' | 'synced' | 'error'
}

export interface VendorCache {
  id: string
  data: any
  updated_at: string
}

export interface ProductCache {
  id: string
  vendor_id: string
  data: any
  updated_at: string
}

export interface OrderCache {
  id: string
  vendor_id: string
  data: any
  updated_at: string
}

export interface MarketCache {
  id: string
  data: {
    id: string
    name: string
    place: string
    days: string[]
    created_at?: string
    updated_at?: string
  }
  updated_at: string
}

export class RotisserieDatabase extends Dexie {
  favorites!: Table<Favorite>
  offline_orders!: Table<OfflineOrder>
  vendors_cache!: Table<VendorCache>
  products_cache!: Table<ProductCache>
  orders_cache!: Table<OrderCache>
  markets_cache!: Table<MarketCache>

  constructor() {
    super('RotisserieDB')
    this.version(2).stores({
      favorites: '++id, stand, nomDuStand',
      offline_orders: '++id_temporaire, vendor_id, product_id, sync_status, created_at',
      vendors_cache: 'id, updated_at',
      products_cache: 'id, vendor_id, updated_at',
      orders_cache: 'id, vendor_id, updated_at',
      markets_cache: 'id, updated_at'
    })
  }
}

export const db = new RotisserieDatabase()

