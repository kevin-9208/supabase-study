<!--
  WorkflowTemplateEditor.vue
  工作流模板编辑主页面。
  结构：基本信息 + 节点列表（start 固定在最前，end 固定在最后，
  中间可以自由增删 approval 节点）。
  MVP 暂不支持拖拽排序，靠"上移/下移"按钮控制顺序，先保证能用。
-->
<script setup>
import { ref, onMounted } from 'vue'
import WorkflowNodeCard from './WorkflowNodeCard.vue'
import { useWorkflow } from '../composables/useWorkflow'

const props = defineProps({
  templateId: { type: String, default: null }, // 传入则是编辑模式，否则是新建
})

const { saveTemplate, fetchTemplateWithNodes, loading, error } = useWorkflow()

const name = ref('')
const businessType = ref('')
const nodes = ref([
  { nodeType: 'start' },
  { nodeType: 'approval', approverType: 'specific_user', approverConfig: {}, approvalMode: 'any' },
  { nodeType: 'end' },
])

// 简化：真实项目里应该从 user_profiles 查询并支持搜索/分页
const userOptions = ref([])

onMounted(async () => {
  if (props.templateId) {
    const tpl = await fetchTemplateWithNodes(props.templateId)
    name.value = tpl.name
    businessType.value = tpl.business_type
    nodes.value = tpl.nodes.map((n) => ({
      nodeType: n.node_type,
      approverType: n.approver_type,
      approverConfig: n.approver_config || {},
      approvalMode: n.approval_mode,
    }))
  }
})

function addApprovalNode() {
  // 新节点插在 end 节点之前
  const endIndex = nodes.value.findIndex((n) => n.nodeType === 'end')
  nodes.value.splice(endIndex, 0, {
    nodeType: 'approval',
    approverType: 'specific_user',
    approverConfig: {},
    approvalMode: 'any',
  })
}

function removeNode(index) {
  nodes.value.splice(index, 1)
}

function moveNode(index, direction) {
  // direction: -1 上移 / 1 下移，start/end 不可移动
  const target = index + direction
  if (target <= 0 || target >= nodes.value.length - 1) return
  if (index <= 0 || index >= nodes.value.length - 1) return
  const arr = nodes.value
  ;[arr[index], arr[target]] = [arr[target], arr[index]]
}

async function handleSave() {
  if (!name.value.trim()) {
    alert('请填写模板名称')
    return
  }
  if (!businessType.value.trim()) {
    alert('请填写业务类型标识')
    return
  }
  const approvalNodes = nodes.value.filter((n) => n.nodeType === 'approval')
  for (const n of approvalNodes) {
    if (n.approverType === 'specific_user' && !n.approverConfig?.user_id) {
      alert('存在未选择审批人的节点，请检查')
      return
    }
  }

  try {
    const id = await saveTemplate({
      id: props.templateId,
      name: name.value,
      businessType: businessType.value,
      nodes: nodes.value,
    })
    alert('保存成功')
    return id
  } catch (e) {
    alert('保存失败：' + e.message)
  }
}
</script>

<template>
  <div class="template-editor">
    <h2>{{ templateId ? '编辑工作流模板' : '新建工作流模板' }}</h2>

    <div class="basic-info">
      <div class="field-row">
        <label>模板名称</label>
        <input v-model="name" placeholder="如：请假审批流程" />
      </div>
      <div class="field-row">
        <label>业务类型标识</label>
        <input v-model="businessType" placeholder="如：leave_request（需与业务表单代码里的标识一致）" />
      </div>
    </div>

    <div class="node-list">
      <template v-for="(node, idx) in nodes" :key="idx">
        <WorkflowNodeCard
          :node="node"
          :index="idx"
          :can-remove="node.nodeType === 'approval'"
          :user-options="userOptions"
          @update:node="nodes[idx] = $event"
          @remove="removeNode(idx)"
        />
        <div v-if="node.nodeType === 'approval'" class="node-actions">
          <button @click="moveNode(idx, -1)">↑ 上移</button>
          <button @click="moveNode(idx, 1)">↓ 下移</button>
        </div>
        <div v-if="idx < nodes.length - 1" class="arrow">↓</div>
      </template>
    </div>

    <button class="btn-add" @click="addApprovalNode">+ 添加审批节点</button>

    <div class="footer">
      <button class="btn-save" :disabled="loading" @click="handleSave">
        {{ loading ? '保存中...' : '保存模板' }}
      </button>
      <span v-if="error" class="error-text">{{ error.message }}</span>
    </div>
  </div>
</template>

<style scoped>
.template-editor {
  max-width: 640px;
  margin: 0 auto;
  padding: 20px;
}
.basic-info {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 20px;
}
.field-row {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.field-row label {
  font-size: 13px;
  color: #666;
}
.field-row input {
  padding: 8px 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
}
.node-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.node-actions {
  display: flex;
  gap: 8px;
  padding-left: 8px;
}
.node-actions button {
  font-size: 12px;
  padding: 2px 8px;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
}
.arrow {
  text-align: center;
  color: #bbb;
}
.btn-add {
  margin-top: 12px;
  padding: 8px 14px;
  border: 1px dashed #999;
  border-radius: 8px;
  background: none;
  cursor: pointer;
}
.footer {
  margin-top: 24px;
  display: flex;
  align-items: center;
  gap: 12px;
}
.btn-save {
  padding: 10px 20px;
  border: none;
  border-radius: 8px;
  background: #4f46e5;
  color: #fff;
  cursor: pointer;
}
.btn-save:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.error-text {
  color: #e11d48;
  font-size: 13px;
}
</style>
