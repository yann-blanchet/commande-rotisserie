import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'
import { syncService } from './services/syncService'

const app = createApp(App)
app.use(router)

// Initialize sync service
syncService.initializeSync()

app.mount('#app')
