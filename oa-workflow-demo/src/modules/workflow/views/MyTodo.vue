<template>
  <el-card>
    <template #header>我的待办</template>

    <el-table :data="todos" v-loading="loading" empty-text="暂无待办">
      <el-table-column label="申请人" width="120">
        <template #default="{ row }">{{ row.initiator?.full_name || row.initiator?.email }}</template>
      </el-table-column>
      <el-table-column label="请假时间" width="220">
        <template #default="{ row }">{{ row.leave?.start_date }} ~ {{ row.leave?.end_date }}</template>
      </el-table-column>
      <el-table-column label="天数" width="80" prop="leave.days" />
      <el-table-column label="事由">
        <template #default="{ row }">{{ row.leave?.reason || '-' }}</template>
      </el-table-column>
      <el-table-column label="提交时间" width="180">
        <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="160" fixed="right">
        <template #default="{ row }">
          <el-button size="small" type="success" @click="onApprove(row)">同意</el-button>
          <el-button size="small" type="danger" @click="onReject(row)">拒绝</el-button>
        </template>
      </el-table-column>
    </el-table>
  </el-card>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useLeaveWorkflow } from '@/modules/workflow/composables/useLeaveWorkflow'

const { loading, fetchMyTodos, approve, reject } = useLeaveWorkflow()
const todos = ref([])

function formatTime(t) {
  if (!t) return '-'
  return new Date(t).toLocaleString('zh-CN')
}

async function load() {
  todos.value = await fetchMyTodos()
}

async function onApprove(row) {
  try {
    await ElMessageBox.confirm('确认同意该请假申请？', '提示')
    await approve(row.instance.id, '')
    ElMessage.success('已同意')
    load()
  } catch (e) {
    if (e !== 'cancel') ElMessage.error(e.message || String(e))
  }
}

async function onReject(row) {
  try {
    const { value } = await ElMessageBox.prompt('请输入拒绝理由（可选）', '拒绝申请', {
      confirmButtonText: '确认拒绝',
      cancelButtonText: '取消'
    })
    await reject(row.instance.id, value || '')
    ElMessage.success('已拒绝')
    load()
  } catch (e) {
    if (e !== 'cancel') ElMessage.error(e.message || String(e))
  }
}

onMounted(load)
</script>
