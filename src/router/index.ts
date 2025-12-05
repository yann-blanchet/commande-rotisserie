import { createRouter, createWebHistory } from 'vue-router'
import VendorList from '../views/VendorList.vue'
import VendorProducts from '../views/VendorProducts.vue'
import TraderLogin from '../views/TraderLogin.vue'
import TraderRegister from '../views/TraderRegister.vue'
import TraderHome from '../views/TraderHome.vue'
import TraderOrders from '../views/TraderOrders.vue'
import TraderProducts from '../views/TraderProducts.vue'
import TraderUser from '../views/TraderUser.vue'
import TraderCurrentMarket from '../views/TraderCurrentMarket.vue'
import Markets from '../views/Markets.vue'
import AdminLogin from '../views/AdminLogin.vue'
import AdminRegister from '../views/AdminRegister.vue'
import Favorites from '../views/Favorites.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'home',
      component: VendorList
    },
    {
      path: '/vendor/:id',
      name: 'vendor-products',
      component: VendorProducts,
      props: true
    },
    {
      path: '/favorites',
      name: 'favorites',
      component: Favorites
    },
    {
      path: '/trader/register',
      name: 'trader-register',
      component: TraderRegister
    },
    {
      path: '/trader/login',
      name: 'trader-login',
      component: TraderLogin
    },
    {
      path: '/trader/home',
      name: 'trader-home',
      component: TraderHome,
      meta: { requiresAuth: true }
    },
    {
      path: '/trader/orders',
      name: 'trader-orders',
      component: TraderOrders,
      meta: { requiresAuth: true }
    },
    {
      path: '/trader/products',
      name: 'trader-products',
      component: TraderProducts,
      meta: { requiresAuth: true }
    },
    {
      path: '/trader/user',
      name: 'trader-user',
      component: TraderUser,
      meta: { requiresAuth: true }
    },
    {
      path: '/trader/current-market',
      name: 'trader-current-market',
      component: TraderCurrentMarket,
      meta: { requiresAuth: true }
    },
    {
      path: '/trader/markets',
      redirect: '/admin/markets'
    },
    {
      path: '/admin/login',
      name: 'admin-login',
      component: AdminLogin
    },
    {
      path: '/admin/register',
      name: 'admin-register',
      component: AdminRegister
    },
    {
      path: '/admin/markets',
      name: 'admin-markets',
      component: Markets,
      meta: { requiresAdmin: true }
    }
  ]
})

// Navigation guard pour vérifier l'authentification admin et trader
router.beforeEach((to, _from, next) => {
  const adminSessionRaw = localStorage.getItem('admin_session')
  const traderSessionRaw = localStorage.getItem('trader_session')
  let adminAuthenticated = false
  let traderAuthenticated = false

  if (adminSessionRaw) {
    try {
      const session = JSON.parse(adminSessionRaw)
      adminAuthenticated = !!session.authenticated
    } catch {
      adminAuthenticated = false
    }
  }

  if (traderSessionRaw) {
    try {
      const session = JSON.parse(traderSessionRaw)
      traderAuthenticated = !!session.authenticated
    } catch {
      traderAuthenticated = false
    }
  }

  // Si l'utilisateur est déjà connecté en admin et va sur /admin/login,
  // on le redirige directement vers la page d'admin.
  if (to.name === 'admin-login' && adminAuthenticated) {
    next({ name: 'admin-markets' })
    return
  }

  // Si l'utilisateur est déjà connecté en trader et va sur /trader/login,
  // on le redirige directement vers la page d'accueil trader.
  if (to.name === 'trader-login' && traderAuthenticated) {
    next({ name: 'trader-home' })
    return
  }

  if (to.meta.requiresAdmin) {
    if (adminAuthenticated) {
      next()
    } else {
      next('/admin/login')
    }
  } else if (to.meta.requiresAuth) {
    if (traderAuthenticated) {
      next()
    } else {
      next('/trader/login')
    }
  } else {
    next()
  }
})

export default router

