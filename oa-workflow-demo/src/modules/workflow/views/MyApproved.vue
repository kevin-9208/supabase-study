<template>
  <el-card>
    <template #header>我审批的</template>

    <el-table :data="records" v-loading="loading" empty-text="暂无审批记录">
      <el-table-column label="请假时间" width="220">
        <template #default="{ row }">{{ row.leave?.start_date }} ~ {{ row.leave?.end_date }}</template>
      </el-table-column>
      <el-table-column label="天数" width="80" prop="leave.days" />
      <el-table-column label="事由">
        <template #default="{ row }">{{ row.leave?.reason || '-' }}</template>
      </el-table-column>
      <el-table-column label="我的动作" width="110">
        <template #default="{ row }">
          <el-tag :type="row.action === 'approve' ? 'success' : 'danger'">
            {{ row.action === 'approve' ? '同意' : '拒绝' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="意见">
        <template #default="{ row }">{{ row.comment || '-' }}</template>
      </el-table-column>
      <el-table-column label="处理时间" width="180">
        <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
      </el-table-column>
    </el-table>
  </el-card>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useLeaveWorkflow } from '@/modules/workflow/composables/useLeaveWorkflow'

const { loading, fetchMyApproved } = useLeaveWorkflow()
const records = ref([])

function formatTime(t) {
  if (!t) return '-'
  return new Date(t).toLocaleString('zh-CN')
}

onMounted(async () => {
  records.value = await fetchMyApproved()
})
</script>
