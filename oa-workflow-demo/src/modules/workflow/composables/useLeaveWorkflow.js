import { ref } from 'vue'
import { supabase } from '@/lib/supabase'

export function useLeaveWorkflow() {
  const loading = ref(false)
  const error = ref(null)

  async function getCurrentUserId() {
    const { data, error: err } = await supabase.auth.getUser()
    if (err) throw err
    if (!data?.user) throw new Error('未登录')
    return data.user.id
  }

  // ---------------- 提交申请 ----------------
  async function submitLeave({ startDate, endDate, days, reason, approverId }) {
    loading.value = true
    error.value = null
    try {
      const { data, error: err } = await supabase.rpc('submit_leave_request', {
        p_start_date: startDate,
        p_end_date: endDate,
        p_days: days,
        p_reason: reason,
        p_approver_id: approverId
      })
      if (err) throw err
      return data // instance_id
    } catch (e) {
      error.value = e.message
      throw e
    } finally {
      loading.value = false
    }
  }

  // ---------------- 审批 ----------------
  async function approve(instanceId, comment = '') {
    return handleApproval(instanceId, 'approve', comment)
  }

  async function reject(instanceId, comment = '') {
    return handleApproval(instanceId, 'reject', comment)
  }

  async function handleApproval(instanceId, action, comment) {
    loading.value = true
    error.value = null
    try {
      const { error: err } = await supabase.rpc('handle_leave_approval', {
        p_instance_id: instanceId,
        p_action: action,
        p_comment: comment
      })
      if (err) throw err
    } catch (e) {
      error.value = e.message
      throw e
    } finally {
      loading.value = false
    }
  }

  // ---------------- 撤回 ----------------
  async function withdraw(instanceId, comment = '') {
    loading.value = true
    error.value = null
    try {
      const { error: err } = await supabase.rpc('withdraw_leave_request', {
        p_instance_id: instanceId,
        p_comment: comment
      })
      if (err) throw err
    } catch (e) {
      error.value = e.message
      throw e
    } finally {
      loading.value = false
    }
  }

  // ---------------- 我的待办 ----------------
  // approval_tasks -> workflow_instances -> leave_requests
  // business_id 不是标准外键（未来要指向多张业务表），所以这里分两步查询，
  // 不依赖 PostgREST 的嵌套外键推断，写法更通用。
  async function fetchMyTodos() {
    const uid = await getCurrentUserId()

    const { data: tasks, error: taskErr } = await supabase
      .from('approval_tasks')
      .select('id, status, created_at, instance_id, instance_node_id')
      .eq('approver_id', uid)
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
    if (taskErr) throw taskErr
    if (!tasks?.length) return []

    const instanceIds = tasks.map(t => t.instance_id)
    const { data: instances, error: instErr } = await supabase
      .from('workflow_instances')
      .select('id, business_id, business_type, status, initiator_id, created_at')
      .in('id', instanceIds)
    if (instErr) throw instErr

    const leaveIds = instances.map(i => i.business_id)
    const { data: leaves, error: leaveErr } = await supabase
      .from('leave_requests')
      .select('*')
      .in('id', leaveIds)
    if (leaveErr) throw leaveErr

    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, full_name, email')
      .in('id', instances.map(i => i.initiator_id))

    return tasks.map(task => {
      const instance = instances.find(i => i.id === task.instance_id)
      const leave = leaves.find(l => l.id === instance?.business_id)
      const initiator = profiles?.find(p => p.id === instance?.initiator_id)
      return { ...task, instance, leave, initiator }
    })
  }

  // ---------------- 我的申请（我发起的） ----------------
  async function fetchMyApplications() {
    const uid = await getCurrentUserId()

    const { data: leaves, error: leaveErr } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('employee_id', uid)
      .order('created_at', { ascending: false })
    if (leaveErr) throw leaveErr
    if (!leaves?.length) return []

    const { data: instances, error: instErr } = await supabase
      .from('workflow_instances')
      .select('id, business_id, status, created_at, finished_at')
      .eq('business_type', 'leave')
      .in('business_id', leaves.map(l => l.id))
    if (instErr) throw instErr

    return leaves.map(leave => ({
      ...leave,
      instance: instances.find(i => i.business_id === leave.id)
    }))
  }

  // ---------------- 我审批过的 ----------------
  async function fetchMyApproved() {
    const uid = await getCurrentUserId()

    const { data: records, error: recErr } = await supabase
      .from('approval_records')
      .select('id, action, comment, created_at, instance_id')
      .eq('approver_id', uid)
      .order('created_at', { ascending: false })
    if (recErr) throw recErr
    if (!records?.length) return []

    const instanceIds = [...new Set(records.map(r => r.instance_id))]
    const { data: instances, error: instErr } = await supabase
      .from('workflow_instances')
      .select('id, business_id')
      .in('id', instanceIds)
    if (instErr) throw instErr

    const leaveIds = instances.map(i => i.business_id)
    const { data: leaves, error: leaveErr } = await supabase
      .from('leave_requests')
      .select('*')
      .in('id', leaveIds)
    if (leaveErr) throw leaveErr

    return records.map(record => {
      const instance = instances.find(i => i.id === record.instance_id)
      const leave = leaves.find(l => l.id === instance?.business_id)
      return { ...record, leave }
    })
  }

  // ---------------- 可选审批人列表（简化：全部 profiles，排除自己） ----------------
  async function fetchApproverCandidates() {
    const uid = await getCurrentUserId()
    const { data, error: err } = await supabase
      .from('profiles')
      .select('id, full_name, email')
      .neq('id', uid)
    if (err) throw err
    return data
  }

  // ---------------- 通知 ----------------
  async function fetchNotifications() {
    const uid = await getCurrentUserId()
    const { data, error: err } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', uid)
      .order('created_at', { ascending: false })
      .limit(20)
    if (err) throw err
    return data
  }

  async function markNotificationRead(id) {
    const { error: err } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id)
    if (err) throw err
  }

  return {
    loading,
    error,
    submitLeave,
    approve,
    reject,
    withdraw,
    fetchMyTodos,
    fetchMyApplications,
    fetchMyApproved,
    fetchApproverCandidates,
    fetchNotifications,
    markNotificationRead
  }
}
