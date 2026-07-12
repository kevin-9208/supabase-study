<template>
  <div v-if="route.meta.public">
    <router-view />
  </div>

  <el-container v-else class="layout">
    <el-header class="header">
      <div class="brand">OA 审批工作流 Demo</div>
      <div class="header-right">
        <el-popover placement="bottom-end" width="320" trigger="click">
          <template #reference>
            <el-badge :value="unreadCount" :hidden="unreadCount === 0" class="bell">
              <el-icon :size="20"><Bell /></el-icon>
            </el-badge>
          </template>
          <div class="notif-list">
            <div v-if="!notifications.length" class="notif-empty">暂无通知</div>
            <div
              v-for="n in notifications"
              :key="n.id"
              class="notif-item"
              :class="{ unread: !n.is_read }"
              @click="onReadNotification(n)"
            >
              <div class="notif-title">{{ n.title }}</div>
              <div class="notif-content">{{ n.content }}</div>
              <div class="notif-time">{{ formatTime(n.created_at) }}</div>
            </div>
          </div>
        </el-popover>

        <span class="username">{{ currentUser?.email }}</span>
        <el-button size="small" @click="onLogout">退出</el-button>
      </div>
    </el-header>

    <el-container>
      <el-aside width="180px" class="aside">
        <el-menu :default-active="route.path" router>
          <el-menu-item index="/leave/apply">发起请假</el-menu-item>
          <el-menu-item index="/leave/todo">我的待办</el-menu-item>
          <el-menu-item index="/leave/applications">我的申请</el-menu-item>
          <el-menu-item index="/leave/approved">我审批的</el-menu-item>
        </el-menu>
      </el-aside>

      <el-main>
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Bell } from '@element-plus/icons-vue'
import { useAuth } from '@/modules/workflow/composables/useAuth'
import { useLeaveWorkflow } from '@/modules/workflow/composables/useLeaveWorkflow'

const route = useRoute()
const router = useRouter()
const { currentUser, initAuth, signOut } = useAuth()
const { fetchNotifications, markNotificationRead } = useLeaveWorkflow()

const notifications = ref([])
const unreadCount = computed(() => notifications.value.filter(n => !n.is_read).length)

function formatTime(t) {
  if (!t) return '-'
  return new Date(t).toLocaleString('zh-CN')
}

async function loadNotifications() {
  if (!currentUser.value) return
  try {
    notifications.value = await fetchNotifications()
  } catch {
    notifications.value = []
  }
}

async function onReadNotification(n) {
  if (!n.is_read) {
    await markNotificationRead(n.id)
    n.is_read = true
  }
}

async function onLogout() {
  await signOut()
  router.push('/login')
}

onMounted(async () => {
  await initAuth()
  await loadNotifications()
})

watch(() => route.path, loadNotifications)
</script>

<style scoped>
.layout {
  min-height: 100vh;
}
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #ebeef5;
}
.brand {
  font-weight: 600;
  font-size: 16px;
}
.header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}
.bell {
  cursor: pointer;
}
.username {
  font-size: 13px;
  color: #606266;
}
.aside {
  border-right: 1px solid #ebeef5;
}
.notif-list {
  max-height: 360px;
  overflow-y: auto;
}
.notif-empty {
  text-align: center;
  color: #909399;
  padding: 20px 0;
}
.notif-item {
  padding: 8px 4px;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;
}
.notif-item.unread {
  background: #f5f9ff;
}
.notif-title {
  font-size: 13px;
  font-weight: 600;
}
.notif-content {
  font-size: 12px;
  color: #606266;
  margin-top: 2px;
}
.notif-time {
  font-size: 11px;
  color: #c0c4cc;
  margin-top: 2px;
}
</style>
