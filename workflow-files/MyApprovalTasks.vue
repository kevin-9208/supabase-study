<!--
  MyApprovalTasks.vue
  「我的待办」列表：展示所有分配给当前登录用户、状态为 pending 的审批任务。
  点击通过/拒绝直接调用 process_approval_action RPC。
-->
<script setup>
import { ref, onMounted } from 'vue'
import { useWorkflow } from '../composables/useWorkflow'

const { fetchMyPendingTasks, processApproval, loading } = useWorkflow()

const tasks = ref([])
const actingTaskId = ref(null)
const commentDraft = ref('')

async function load() {
  tasks.value = await fetchMyPendingTasks()
}

async function handleAction(task, action) {
  actingTaskId.value = task.id
  try {
    const result = await processApproval({
      taskId: task.id,
      action,
      comment: commentDraft.value,
    })
    commentDraft.value = ''
    await load() // 处理完刷新列表
    if (result?.result === 'waiting_others') {
      alert('已提交，该节点为会签，等待其他审批人处理')
    } else if (result?.result === 'rejected') {
      alert('已拒绝，流程终止')
    } else {
      alert('已提交，流程已推进到下一节点')
    }
  } catch (e) {
    alert('操作失败：' + e.message)
  } finally {
    actingTaskId.value = null
  }
}

onMounted(load)
</script>

<template>
  <div class="my-tasks">
    <h2>我的待办</h2>

    <div v-if="loading && tasks.length === 0">加载中...</div>
    <div v-else-if="tasks.length === 0" class="empty">暂无待办事项</div>

    <div v-for="task in tasks" :key="task.id" class="task-card">
      <div class="task-header">
        <span class="business-type">{{ task.instance?.business_type }}</span>
        <span class="task-time">{{ new Date(task.created_at).toLocaleString() }}</span>
      </div>

      <div class="form-data">
        <pre>{{ JSON.stringify(task.instance?.form_data, null, 2) }}</pre>
      </div>

      <textarea
        v-model="commentDraft"
        placeholder="审批意见（选填）"
        rows="2"
      ></textarea>

      <div class="task-actions">
        <button
          class="btn-approve"
          :disabled="actingTaskId === task.id"
          @click="handleAction(task, 'approve')"
        >
          通过
        </button>
        <button
          class="btn-reject"
          :disabled="actingTaskId === task.id"
          @click="handleAction(task, 'reject')"
        >
          拒绝
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.my-tasks {
  max-width: 560px;
  margin: 0 auto;
  padding: 20px;
}
.empty {
  color: #999;
  padding: 40px 0;
  text-align: center;
}
.task-card {
  border: 1px solid #e2e2e2;
  border-radius: 10px;
  padding: 14px;
  margin-bottom: 12px;
}
.task-header {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  color: #666;
  margin-bottom: 8px;
}
.business-type {
  font-weight: 600;
  color: #4f46e5;
}
.form-data {
  background: #fafafa;
  border-radius: 6px;
  padding: 8px;
  font-size: 12px;
  color: #444;
  margin-bottom: 8px;
  overflow-x: auto;
}
textarea {
  width: 100%;
  border: 1px solid #ddd;
  border-radius: 6px;
  padding: 6px 8px;
  resize: vertical;
  margin-bottom: 8px;
  box-sizing: border-box;
}
.task-actions {
  display: flex;
  gap: 10px;
}
.btn-approve {
  padding: 6px 16px;
  border: none;
  border-radius: 6px;
  background: #16a34a;
  color: #fff;
  cursor: pointer;
}
.btn-reject {
  padding: 6px 16px;
  border: none;
  border-radius: 6px;
  background: #e11d48;
  color: #fff;
  cursor: pointer;
}
button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
