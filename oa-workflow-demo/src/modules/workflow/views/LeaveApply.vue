<template>
  <el-card>
    <template #header>发起请假申请</template>

    <el-form :model="form" label-width="90px" style="max-width: 480px">
      <el-form-item label="开始日期">
        <el-date-picker v-model="form.startDate" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
      </el-form-item>
      <el-form-item label="结束日期">
        <el-date-picker v-model="form.endDate" type="date" value-format="YYYY-MM-DD" style="width: 100%" />
      </el-form-item>
      <el-form-item label="天数">
        <el-input-number v-model="form.days" :min="0.5" :step="0.5" style="width: 100%" />
      </el-form-item>
      <el-form-item label="事由">
        <el-input v-model="form.reason" type="textarea" :rows="3" />
      </el-form-item>
      <el-form-item label="审批人">
        <el-select v-model="form.approverId" placeholder="选择审批人" style="width: 100%" filterable>
          <el-option
            v-for="u in candidates"
            :key="u.id"
            :label="u.full_name || u.email"
            :value="u.id"
          />
        </el-select>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" :loading="loading" @click="onSubmit">提交申请</el-button>
      </el-form-item>
    </el-form>
  </el-card>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { useLeaveWorkflow } from '@/modules/workflow/composables/useLeaveWorkflow'

const { loading, submitLeave, fetchApproverCandidates } = useLeaveWorkflow()

const form = reactive({
  startDate: '',
  endDate: '',
  days: 1,
  reason: '',
  approverId: ''
})

const candidates = ref([])

async function loadCandidates() {
  candidates.value = await fetchApproverCandidates()
}

async function onSubmit() {
  if (!form.startDate || !form.endDate || !form.approverId) {
    ElMessage.warning('请完整填写日期和审批人')
    return
  }
  try {
    await submitLeave(form)
    ElMessage.success('提交成功，等待审批')
    form.reason = ''
  } catch (e) {
    ElMessage.error(e.message)
  }
}

onMounted(loadCandidates)
</script>
