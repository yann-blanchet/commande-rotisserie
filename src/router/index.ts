import { createRouter, createWebHistory } from 'vue-router'
import VendorList from '../views/VendorList.vue'
import VendorProducts from '../views/VendorProducts.vue'
import TraderLogin from '../views/TraderLogin.vue'
import TraderRegister from '../views/TraderRegister.vue'
import TraderOrders from '../views/TraderOrders.vue'
import TraderProducts from '../views/TraderProducts.vue'

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
    }
  ]
})

export default router

