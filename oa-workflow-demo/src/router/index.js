import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '@/lib/supabase'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/modules/workflow/views/Login.vue'),
    meta: { public: true }
  },
  {
    path: '/leave/apply',
    name: 'leave-apply',
    component: () => import('@/modules/workflow/views/LeaveApply.vue')
  },
  {
    path: '/leave/todo',
    name: 'my-todo',
    component: () => import('@/modules/workflow/views/MyTodo.vue')
  },
  {
    path: '/leave/applications',
    name: 'my-applications',
    component: () => import('@/modules/workflow/views/MyApplications.vue')
  },
  {
    path: '/leave/approved',
    name: 'my-approved',
    component: () => import('@/modules/workflow/views/MyApproved.vue')
  },
  { path: '/', redirect: '/leave/apply' }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach(async (to) => {
  if (to.meta.public) return true
  const { data } = await supabase.auth.getSession()
  if (!data.session) {
    return { name: 'login' }
  }
  return true
})

export default router
