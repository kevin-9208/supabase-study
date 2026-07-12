<template>
  <el-card>
    <template #header>我的申请</template>

    <el-table :data="applications" v-loading="loading" empty-text="暂无申请记录">
      <el-table-column label="请假时间" width="220">
        <template #default="{ row }">{{ row.start_date }} ~ {{ row.end_date }}</template>
      </el-table-column>
      <el-table-column label="天数" width="80" prop="days" />
      <el-table-column label="事由">
        <template #default="{ row }">{{ row.reason || '-' }}</template>
      </el-table-column>
      <el-table-column label="状态" width="110">
        <template #default="{ row }">
          <el-tag :type="statusType(row.status)">{{ statusLabel(row.status) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="提交时间" width="180">
        <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="100" fixed="right">
        <template #default="{ row }">
          <el-button
            v-if="row.status === 'pending'"
            size="small"
            @click="onWithdraw(row)"
          >撤回</el-button>
        </template>
      </el-table-column>
    </el-table>
  </el-card>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useLeaveWorkflow } from '@/modules/workflow/composables/useLeaveWorkflow'

const { loading, fetchMyApplications, withdraw } = useLeaveWorkflow()
const applications = ref([])

const statusMap = {
  draft: { label: '草稿', type: 'info' },
  pending: { label: '审批中', type: 'warning' },
  approved: { label: '已通过', type: 'success' },
  rejected: { label: '已拒绝', type: 'danger' },
  cancelled: { label: '已撤回', type: 'info' }
}

function statusLabel(s) {
  return statusMap[s]?.label || s
}
function statusType(s) {
  return statusMap[s]?.type || 'info'
}
function formatTime(t) {
  if (!t) return '-'
  return new Date(t).toLocaleString('zh-CN')
}

async function load() {
  applications.value = await fetchMyApplications()
}

async function onWithdraw(row) {
  try {
    await ElMessageBox.confirm('确认撤回该请假申请？', '提示')
    await withdraw(row.instance.id, '发起人主动撤回')
    ElMessage.success('已撤回')
    load()
  } catch (e) {
    if (e !== 'cancel') ElMessage.error(e.message || String(e))
  }
}

onMounted(load)
</script>
