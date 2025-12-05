<template>
  <nav class="bottom-menu-bar">
    <router-link to="/trader/home" class="menu-item" :class="{ active: $route.name === 'trader-home' }">
      <span class="menu-icon">🏠</span>
      <span class="menu-label">Home</span>
    </router-link>
    <router-link to="/trader/orders" class="menu-item" :class="{ active: $route.name === 'trader-orders' }">
      <span class="menu-icon">📦</span>
      <span class="menu-label">Orders</span>
    </router-link>
    <router-link to="/trader/current-market" class="menu-item" :class="{ active: $route.name === 'trader-current-market' }">
      <span class="menu-icon">🏪</span>
      <span class="menu-label">Marché</span>
    </router-link>
    <router-link to="/trader/products" class="menu-item" :class="{ active: $route.name === 'trader-products' }">
      <span class="menu-icon">🛍️</span>
      <span class="menu-label">Product</span>
    </router-link>
    <router-link to="/trader/user" class="menu-item" :class="{ active: $route.name === 'trader-user' }">
      <span class="menu-icon">👤</span>
      <span class="menu-label">User</span>
    </router-link>
  </nav>
</template>

<script setup lang="ts">
</script>

<style scoped>
.bottom-menu-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  border-top: 2px solid #e2e8f0;
  display: flex;
  justify-content: space-around;
  align-items: center;
  padding: 8px 0;
  z-index: 1000;
  box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
}

.menu-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 8px 8px;
  text-decoration: none;
  color: #64748b;
  transition: all 0.2s ease;
  border-radius: 8px;
  min-width: 0;
  flex: 1;
}

.menu-item:hover {
  background: #f1f5f9;
  color: #334155;
}

.menu-item.active {
  color: #667eea;
  background: #f0f4ff;
}

.menu-icon {
  font-size: 1.5rem;
}

.menu-label {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
</style>


