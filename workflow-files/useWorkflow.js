// useWorkflow.js
// 统一封装工作流模板 / 审批任务相关的 supabase 调用
// 假设项目里已经有一个初始化好的 supabase client，路径按你实际项目调整
import { ref } from 'vue'
import { supabase } from '@/lib/supabaseClient'

export function useWorkflow() {
  const loading = ref(false)
  const error = ref(null)

  // ---------- 模板管理 ----------

  async function fetchTemplates(businessType = null) {
    let query = supabase.from('workflow_templates').select('*').order('created_at', { ascending: false })
    if (businessType) query = query.eq('business_type', businessType)
    const { data, error: err } = await query
    if (err) throw err
    return data
  }

  async function fetchTemplateWithNodes(templateId) {
    const { data: template, error: e1 } = await supabase
      .from('workflow_templates')
      .select('*')
      .eq('id', templateId)
      .single()
    if (e1) throw e1

    const { data: nodes, error: e2 } = await supabase
      .from('workflow_nodes')
      .select('*')
      .eq('template_id', templateId)
      .order('node_order', { ascending: true })
    if (e2) throw e2

    return { ...template, nodes }
  }

  // 保存模板：新建模板 + 节点（简化版，先整体重写节点，不做增量 diff）
  async function saveTemplate({ id, name, businessType, nodes }) {
    loading.value = true
    error.value = null
    try {
      let templateId = id

      if (!templateId) {
        const { data, error: err } = await supabase
          .from('workflow_templates')
          .insert({ name, business_type: businessType })
          .select()
          .single()
        if (err) throw err
        templateId = data.id
      } else {
        const { error: err } = await supabase
          .from('workflow_templates')
          .update({ name, business_type: businessType })
          .eq('id', templateId)
        if (err) throw err

        // 简化处理：先删掉旧节点再整体插入新节点
        // 注意：这种方式在有正在流转的实例引用旧 node_id 时会有风险，
        // 生产环境建议改成"新建版本"而不是原地覆盖，这里先做 MVP
        await supabase.from('workflow_nodes').delete().eq('template_id', templateId)
      }

      const nodesToInsert = nodes.map((n, idx) => ({
        template_id: templateId,
        node_order: idx + 1,
        node_type: n.nodeType,
        approver_type: n.nodeType === 'approval' ? n.approverType : null,
        approver_config: n.nodeType === 'approval' ? n.approverConfig : {},
        approval_mode: n.approvalMode || 'any',
      }))

      const { error: err } = await supabase.from('workflow_nodes').insert(nodesToInsert)
      if (err) throw err

      return templateId
    } finally {
      loading.value = false
    }
  }

  // ---------- 发起审批 ----------

  async function startWorkflow({ templateId, businessId, businessType, formData }) {
    const { data, error: err } = await supabase.rpc('start_workflow_instance', {
      p_template_id: templateId,
      p_business_id: businessId,
      p_business_type: businessType,
      p_form_data: formData || {},
    })
    if (err) throw err
    return data // instance id
  }

  // ---------- 我的待办 ----------

  async function fetchMyPendingTasks() {
    const { data, error: err } = await supabase
      .from('approval_tasks')
      .select(`
        id, status, comment, created_at,
        instance:approval_instances (
          id, business_type, business_id, form_data, status,
          applicant:applicant_id ( id )
        )
      `)
      .eq('status', 'pending')
      .order('created_at', { ascending: true })
    if (err) throw err
    return data
  }

  // 查看某个实例的完整审批历史（用于时间线展示）
  async function fetchInstanceHistory(instanceId) {
    const { data, error: err } = await supabase
      .from('approval_tasks')
      .select('*, node:workflow_nodes(node_order, approval_mode)')
      .eq('instance_id', instanceId)
      .order('created_at', { ascending: true })
    if (err) throw err
    return data
  }

  async function processApproval({ taskId, action, comment }) {
    const { data, error: err } = await supabase.rpc('process_approval_action', {
      p_task_id: taskId,
      p_action: action,
      p_comment: comment || null,
    })
    if (err) throw err
    return data
  }

  return {
    loading,
    error,
    fetchTemplates,
    fetchTemplateWithNodes,
    saveTemplate,
    startWorkflow,
    fetchMyPendingTasks,
    fetchInstanceHistory,
    processApproval,
  }
}
