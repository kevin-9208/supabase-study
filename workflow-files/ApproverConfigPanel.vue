<!--
  ApproverConfigPanel.vue
  根据 approverType 渲染不同的配置项。
  MVP 只支持两种类型，后续加新类型时在 template 里加一个 v-if 分支即可，
  不需要改动父组件。
-->
<script setup>
import { computed } from 'vue'

const props = defineProps({
  approverType: { type: String, default: 'specific_user' },
  approverConfig: { type: Object, default: () => ({}) },
  // 简化版：可选用户列表，实际项目里应该从 user_profiles 表查询并支持搜索
  userOptions: { type: Array, default: () => [] },
})

const emit = defineEmits(['update:approverType', 'update:approverConfig'])

const selectedUserId = computed({
  get: () => props.approverConfig?.user_id || '',
  set: (val) => emit('update:approverConfig', { ...props.approverConfig, user_id: val }),
})

function handleTypeChange(e) {
  const newType = e.target.value
  emit('update:approverType', newType)
  // 切换类型时清空旧配置，避免脏数据
  emit('update:approverConfig', {})
}
</script>

<template>
  <div class="approver-config-panel">
    <label class="field-label">审批人类型</label>
    <select :value="approverType" @change="handleTypeChange">
      <option value="specific_user">指定人员</option>
      <option value="dept_leader">申请人部门负责人</option>
    </select>

    <!-- 指定人员：选一个具体的人 -->
    <div v-if="approverType === 'specific_user'" class="sub-field">
      <label class="field-label">选择审批人</label>
      <select v-model="selectedUserId">
        <option value="" disabled>请选择</option>
        <option v-for="u in userOptions" :key="u.id" :value="u.id">
          {{ u.display_name || u.id }}
        </option>
      </select>
    </div>

    <!-- 部门负责人：不需要额外配置，运行时自动解析 -->
    <div v-else-if="approverType === 'dept_leader'" class="sub-field hint">
      将自动取「申请人所在部门」的负责人作为审批人，无需额外配置。
    </div>
  </div>
</template>

<style scoped>
.approver-config-panel {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.field-label {
  font-size: 13px;
  color: #666;
}
.sub-field {
  margin-top: 4px;
}
.hint {
  font-size: 12px;
  color: #999;
}
select {
  padding: 6px 8px;
  border: 1px solid #ddd;
  border-radius: 6px;
}
</style>
