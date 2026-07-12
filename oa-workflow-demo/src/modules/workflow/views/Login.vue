<template>
  <div class="login-page">
    <el-card class="login-card">
      <template #header>
        <div class="login-title">OA 审批工作流 Demo</div>
        <div class="login-sub">请假模块 · 单人审批闭环</div>
      </template>

      <el-tabs v-model="activeTab">
        <el-tab-pane label="登录" name="login">
          <el-form :model="loginForm" label-width="70px" @submit.prevent>
            <el-form-item label="邮箱">
              <el-input v-model="loginForm.email" placeholder="you@example.com" />
            </el-form-item>
            <el-form-item label="密码">
              <el-input v-model="loginForm.password" type="password" show-password />
            </el-form-item>
          </el-form>
          <el-button type="primary" style="width: 100%" :loading="loading" @click="onLogin">
            登录
          </el-button>
        </el-tab-pane>

        <el-tab-pane label="注册" name="register">
          <el-form :model="registerForm" label-width="70px" @submit.prevent>
            <el-form-item label="姓名">
              <el-input v-model="registerForm.fullName" placeholder="张三" />
            </el-form-item>
            <el-form-item label="邮箱">
              <el-input v-model="registerForm.email" placeholder="you@example.com" />
            </el-form-item>
            <el-form-item label="密码">
              <el-input v-model="registerForm.password" type="password" show-password />
            </el-form-item>
          </el-form>
          <el-button type="primary" style="width: 100%" :loading="loading" @click="onRegister">
            注册
          </el-button>
          <p class="hint">
            注册后若开启了邮箱验证，需要先去邮箱确认才能登录；
            也可以在 Supabase 控制台的 Auth 设置里关闭邮箱验证，方便本地测试。
          </p>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAuth } from '@/modules/workflow/composables/useAuth'

const router = useRouter()
const { signIn, signUp } = useAuth()

const activeTab = ref('login')
const loading = ref(false)

const loginForm = reactive({ email: '', password: '' })
const registerForm = reactive({ email: '', password: '', fullName: '' })

async function onLogin() {
  loading.value = true
  try {
    await signIn(loginForm.email, loginForm.password)
    ElMessage.success('登录成功')
    router.push('/leave/apply')
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}

async function onRegister() {
  loading.value = true
  try {
    await signUp(registerForm.email, registerForm.password, registerForm.fullName)
    ElMessage.success('注册成功，请登录（若开启邮箱验证请先前往邮箱确认）')
    activeTab.value = 'login'
    loginForm.email = registerForm.email
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f7fa;
}
.login-card {
  width: 420px;
}
.login-title {
  font-size: 18px;
  font-weight: 600;
}
.login-sub {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}
.hint {
  font-size: 12px;
  color: #909399;
  margin-top: 10px;
  line-height: 1.6;
}
</style>
