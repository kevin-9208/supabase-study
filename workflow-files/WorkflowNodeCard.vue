<!--
  WorkflowNodeCard.vue
  代表工作流中的一个节点（start / approval / end）。
  start 和 end 不需要配置，只有 approval 类型需要展开配置面板。
-->
<script setup>
import ApproverConfigPanel from './ApproverConfigPanel.vue'

const props = defineProps({
  node: { type: Object, required: true },
  index: { type: Number, required: true },
  canRemove: { type: Boolean, default: true },
  userOptions: { type: Array, default: () => [] },
})

const emit = defineEmits(['update:node', 'remove'])

function patchNode(patch) {
  emit('update:node', { ...props.node, ...patch })
}

const nodeTypeLabel = {
  start: '开始',
  approval: '审批',
  end: '结束',
}
</script>

<template>
  <div class="node-card" :class="`node-type-${node.nodeType}`">
    <div class="node-header">
      <span class="node-order">#{{ index + 1 }}</span>
      <span class="node-type-badge">{{ nodeTypeLabel[node.nodeType] }}</span>

      <select
        v-if="node.nodeType === 'approval'"
        :value="node.nodeType"
        @change="patchNode({ nodeType: $event.target.value })"
      >
        <option value="approval">审批节点</option>
      </select>

      <button v-if="canRemove && node.nodeType === 'approval'" class="btn-remove" @click="emit('remove')">
        删除
      </button>
    </div>

    <div v-if="node.nodeType === 'approval'" class="node-body">
      <ApproverConfigPanel
        :approver-type="node.approverType"
        :approver-config="node.approverConfig"
        :user-options="userOptions"
        @update:approver-type="patchNode({ approverType: $event })"
        @update:approver-config="patchNode({ approverConfig: $event })"
      />

      <div class="field-row">
        <label class="field-label">审批方式</label>
        <select :value="node.approvalMode" @change="patchNode({ approvalMode: $event.target.value })">
          <option value="any">或签（一人同意即通过）</option>
          <option value="all">会签（需全部同意）</option>
        </select>
      </div>
    </div>

    <div v-else class="node-body hint">
      {{ node.nodeType === 'start' ? '流程起点，无需配置' : '流程终点，全部审批通过后到达这里' }}
    </div>
  </div>
</template>

<style scoped>
.node-card {
  border: 1px solid #e2e2e2;
  border-radius: 10px;
  padding: 12px 14px;
  background: #fff;
}
.node-type-start,
.node-type-end {
  background: #fafafa;
}
.node-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.node-order {
  font-weight: 600;
  color: #333;
}
.node-type-badge {
  font-size: 12px;
  padding: 2px 8px;
  border-radius: 999px;
  background: #eef2ff;
  color: #4f46e5;
}
.btn-remove {
  margin-left: auto;
  border: none;
  background: none;
  color: #e11d48;
  cursor: pointer;
  font-size: 13px;
}
.field-row {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-top: 10px;
}
.field-label {
  font-size: 13px;
  color: #666;
}
.hint {
  font-size: 13px;
  color: #999;
}
select {
  padding: 6px 8px;
  border: 1px solid #ddd;
  border-radius: 6px;
}
</style>
