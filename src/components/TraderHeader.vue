<template>
  <header class="header">
    <h1>{{ title }}</h1>
    <span :class="['status-indicator', onlineStatus ? 'online' : 'offline']">
      {{ onlineStatus ? '🟢 En ligne' : '🔴 Hors ligne' }}
    </span>
  </header>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { isOnline } from '../lib/supabase'

const props = defineProps<{
  title: string
}>()

const onlineStatus = ref<boolean>(isOnline())

let onlineCheckInterval: number | null = null
let updateOnlineStatus: (() => void) | null = null

onMounted(() => {
  // Initialize online status
  onlineStatus.value = isOnline()

  // Listen to online/offline events
  updateOnlineStatus = () => {
    onlineStatus.value = isOnline()
  }

  window.addEventListener('online', updateOnlineStatus)
  window.addEventListener('offline', updateOnlineStatus)

  // Check online status periodically (every 5 seconds) as a fallback
  onlineCheckInterval = window.setInterval(() => {
    onlineStatus.value = isOnline()
  }, 5000)
})

onUnmounted(() => {
  if (updateOnlineStatus) {
    window.removeEventListener('online', updateOnlineStatus)
    window.removeEventListener('offline', updateOnlineStatus)
  }
  if (onlineCheckInterval !== null) {
    clearInterval(onlineCheckInterval)
  }
})
</script>

<style scoped>
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  flex-wrap: wrap;
  gap: 15px;
}

.header h1 {
  font-size: 2rem;
  margin: 0;
}

.status-indicator {
  font-weight: 600;
}

.status-indicator.online {
  color: #4caf50;
}

.status-indicator.offline {
  color: #f44336;
}

@media (max-width: 768px) {
  .header {
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
  }

  .header h1 {
    font-size: 1.5rem;
  }

  .status-indicator {
    font-size: 0.85rem;
  }
}
</style>


