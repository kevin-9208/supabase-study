-- ============================================================
-- 002_functions.sql
-- 审批引擎核心逻辑
-- ============================================================

-- ------------------------------------------------------------
-- resolve_approvers
-- 根据节点的 approver_type / approver_config，解析出实际审批人 id 列表
-- 目前只支持 specific_user / dept_leader，后续加新类型只需要在这里加分支
-- ------------------------------------------------------------
create or replace function resolve_approvers(
  p_node_id uuid,
  p_instance_id uuid
) returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_node workflow_nodes%rowtype;
  v_applicant_id uuid;
  v_applicant_dept uuid;
  v_leader_id uuid;
  v_result uuid[];
begin
  select * into v_node from workflow_nodes where id = p_node_id;

  if v_node.approver_type = 'specific_user' then
    v_result := array[(v_node.approver_config->>'user_id')::uuid];

  elsif v_node.approver_type = 'dept_leader' then
    select applicant_id into v_applicant_id
      from approval_instances where id = p_instance_id;

    select department_id into v_applicant_dept
      from user_profiles where id = v_applicant_id;

    select leader_id into v_leader_id
      from departments where id = v_applicant_dept;

    if v_leader_id is null then
      raise exception '部门负责人未配置，无法解析审批人（department_id=%）', v_applicant_dept;
    end if;

    v_result := array[v_leader_id];

  else
    raise exception '不支持的 approver_type: %', v_node.approver_type;
  end if;

  return v_result;
end;
$$;

-- ------------------------------------------------------------
-- create_tasks_for_node
-- 给指定节点生成对应的 approval_tasks（内部函数）
-- ------------------------------------------------------------
create or replace function create_tasks_for_node(
  p_instance_id uuid,
  p_node_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_approvers uuid[];
  v_approver uuid;
begin
  v_approvers := resolve_approvers(p_node_id, p_instance_id);

  foreach v_approver in array v_approvers loop
    insert into approval_tasks (instance_id, node_id, approver_id, status)
    values (p_instance_id, p_node_id, v_approver, 'pending');
  end loop;

  update approval_instances
    set current_node_id = p_node_id, updated_at = now()
    where id = p_instance_id;
end;
$$;

-- ------------------------------------------------------------
-- advance_to_next_node
-- 找到当前节点的下一个节点（按 node_order），
-- 若是 end 节点 -> 整个实例标记 approved
-- 若是 approval 节点 -> 生成新一批任务
-- ------------------------------------------------------------
create or replace function advance_to_next_node(
  p_instance_id uuid,
  p_current_node_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_template_id uuid;
  v_current_order int;
  v_next workflow_nodes%rowtype;
begin
  select template_id into v_template_id
    from workflow_nodes where id = p_current_node_id;

  select node_order into v_current_order
    from workflow_nodes where id = p_current_node_id;

  select * into v_next
    from workflow_nodes
    where template_id = v_template_id
      and node_order > v_current_order
    order by node_order asc
    limit 1;

  if v_next.id is null then
    -- 没有下一个节点了，理论上不应该发生（应该先有 end 节点），兜底当作完成处理
    update approval_instances set status = 'approved', updated_at = now()
      where id = p_instance_id;
    return;
  end if;

  if v_next.node_type = 'end' then
    update approval_instances set status = 'approved', current_node_id = v_next.id, updated_at = now()
      where id = p_instance_id;
  elsif v_next.node_type = 'approval' then
    perform create_tasks_for_node(p_instance_id, v_next.id);
  else
    -- 遇到其它类型节点（如未来的 start/condition），直接跳过继续往下找
    perform advance_to_next_node(p_instance_id, v_next.id);
  end if;
end;
$$;

-- ------------------------------------------------------------
-- start_workflow_instance
-- 发起一个审批实例：创建 instance，从 start 节点之后的第一个 approval 节点开始生成任务
-- ------------------------------------------------------------
create or replace function start_workflow_instance(
  p_template_id uuid,
  p_business_id uuid,
  p_business_type text,
  p_form_data jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_instance_id uuid;
  v_start_node workflow_nodes%rowtype;
begin
  select * into v_start_node
    from workflow_nodes
    where template_id = p_template_id and node_type = 'start'
    order by node_order asc limit 1;

  if v_start_node.id is null then
    raise exception '该模板没有配置 start 节点';
  end if;

  insert into approval_instances (template_id, business_id, business_type, applicant_id, form_data, status)
  values (p_template_id, p_business_id, p_business_type, auth.uid(), p_form_data, 'pending')
  returning id into v_instance_id;

  perform advance_to_next_node(v_instance_id, v_start_node.id);

  return v_instance_id;
end;
$$;

-- ------------------------------------------------------------
-- process_approval_action
-- 审批人处理某个任务：approve / reject
-- ------------------------------------------------------------
create or replace function process_approval_action(
  p_task_id uuid,
  p_action text,
  p_comment text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task approval_tasks%rowtype;
  v_node workflow_nodes%rowtype;
begin
  if p_action not in ('approve', 'reject') then
    raise exception '非法的 action: %', p_action;
  end if;

  select * into v_task from approval_tasks where id = p_task_id;

  if v_task.id is null then
    raise exception '任务不存在';
  end if;

  -- 权限校验：只有本人能处理自己的任务（双保险，RLS 之外再校验一次）
  if v_task.approver_id <> auth.uid() then
    raise exception '无权处理该任务';
  end if;

  if v_task.status <> 'pending' then
    raise exception '该任务已被处理，当前状态: %', v_task.status;
  end if;

  update approval_tasks
    set status = case when p_action = 'approve' then 'approved' else 'rejected' end,
        comment = p_comment,
        acted_at = now()
    where id = p_task_id;

  select * into v_node from workflow_nodes where id = v_task.node_id;

  if p_action = 'reject' then
    update approval_instances set status = 'rejected', updated_at = now()
      where id = v_task.instance_id;
    return jsonb_build_object('result', 'rejected');
  end if;

  -- 会签模式：还有其他人没处理完，先不推进
  if v_node.approval_mode = 'all' then
    if exists (
      select 1 from approval_tasks
      where node_id = v_node.id
        and instance_id = v_task.instance_id
        and status = 'pending'
    ) then
      return jsonb_build_object('result', 'waiting_others');
    end if;
  end if;

  -- 或签模式（或会签已全部通过）：推进到下一节点
  perform advance_to_next_node(v_task.instance_id, v_node.id);

  return jsonb_build_object('result', 'advanced');
end;
$$;
