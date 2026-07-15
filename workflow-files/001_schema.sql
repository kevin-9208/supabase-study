-- ============================================================
-- 001_schema.sql
-- 动态工作流模板 MVP —— 表结构
-- 覆盖范围：链式节点（无分支），审批人类型 specific_user / dept_leader，
--          会签(all) / 或签(any)
-- ============================================================

-- ---------- 组织架构（如果已存在同名表，请按需 skip） ----------

create table if not exists departments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  parent_id uuid references departments(id) on delete set null,
  leader_id uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

create table if not exists user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  department_id uuid references departments(id) on delete set null,
  manager_id uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

-- ---------- 工作流模板 ----------

create table workflow_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  business_type text not null,        -- 如 'leave_request' / 'expense_claim'
  is_active boolean not null default true,
  version int not null default 1,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

-- 节点：node_type = 'start' | 'approval' | 'end'
-- 链式结构：靠 node_order 决定先后顺序，同一 template 内不允许重复 order
create table workflow_nodes (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references workflow_templates(id) on delete cascade,
  node_order int not null,
  node_type text not null default 'approval'
      check (node_type in ('start', 'approval', 'end')),

  -- 仅 node_type = 'approval' 时有意义
  approver_type text
      check (approver_type in ('specific_user', 'dept_leader') or approver_type is null),
  approver_config jsonb not null default '{}'::jsonb,
      -- specific_user: { "user_id": "uuid" }
      -- dept_leader:   { }  （直接取发起人所在部门的 leader_id）
  approval_mode text not null default 'any'
      check (approval_mode in ('any', 'all')),  -- any=或签 all=会签

  created_at timestamptz default now(),
  unique (template_id, node_order)
);

-- ---------- 运行实例 ----------

create table approval_instances (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references workflow_templates(id),
  business_id uuid not null,          -- 关联具体业务单据 id（如请假单 id）
  business_type text not null,
  applicant_id uuid not null references auth.users(id),
  form_data jsonb not null default '{}'::jsonb,  -- 冗余存一份表单快照，方便审批人解析规则读取字段
  current_node_id uuid references workflow_nodes(id),
  status text not null default 'pending'
      check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table approval_tasks (
  id uuid primary key default gen_random_uuid(),
  instance_id uuid not null references approval_instances(id) on delete cascade,
  node_id uuid not null references workflow_nodes(id),
  approver_id uuid not null references auth.users(id),
  status text not null default 'pending'
      check (status in ('pending', 'approved', 'rejected')),
  comment text,
  acted_at timestamptz,
  created_at timestamptz default now()
);

create index idx_approval_tasks_approver on approval_tasks(approver_id, status);
create index idx_approval_tasks_instance on approval_tasks(instance_id);
create index idx_workflow_nodes_template on workflow_nodes(template_id, node_order);

-- ---------- RLS ----------

alter table departments enable row level security;
alter table user_profiles enable row level security;
alter table workflow_templates enable row level security;
alter table workflow_nodes enable row level security;
alter table approval_instances enable row level security;
alter table approval_tasks enable row level security;

-- 简化版策略：登录用户可读所有基础配置数据（模板/部门等一般不敏感）
create policy "authenticated can read departments"
  on departments for select to authenticated using (true);

create policy "authenticated can read profiles"
  on user_profiles for select to authenticated using (true);

create policy "authenticated can read templates"
  on workflow_templates for select to authenticated using (true);

create policy "authenticated can read nodes"
  on workflow_nodes for select to authenticated using (true);

-- 模板的增删改建议只开放给管理员角色，这里先用一个简单占位策略，
-- 实际项目中请替换成你自己的角色判断（如 user_profiles.role = 'admin'）
create policy "admin can manage templates"
  on workflow_templates for all to authenticated
  using (auth.uid() in (select id from user_profiles where department_id is not null))
  with check (true);
  -- TODO: 上线前务必换成真实的管理员权限判断，这里先放宽以便你先跑通流程

create policy "admin can manage nodes"
  on workflow_nodes for all to authenticated using (true) with check (true);
  -- TODO: 同上，先放宽

-- 审批实例：申请人能看自己发起的；审批人能看自己有任务的
create policy "applicant can view own instances"
  on approval_instances for select to authenticated
  using (applicant_id = auth.uid());

create policy "approver can view related instances"
  on approval_instances for select to authenticated
  using (
    exists (
      select 1 from approval_tasks t
      where t.instance_id = approval_instances.id
        and t.approver_id = auth.uid()
    )
  );

-- 实例的写入统一走 RPC（security definer），这里不开放直接 insert/update 给前端
create policy "no direct insert on instances"
  on approval_instances for insert to authenticated with check (false);

-- 审批任务：只能看分配给自己的任务，或者是自己发起单据下的全部任务（方便看进度）
create policy "approver can view own tasks"
  on approval_tasks for select to authenticated
  using (
    approver_id = auth.uid()
    or exists (
      select 1 from approval_instances i
      where i.id = approval_tasks.instance_id
        and i.applicant_id = auth.uid()
    )
  );

-- 任务状态更新同样只走 RPC，不开放直接 update
create policy "no direct update on tasks"
  on approval_tasks for update to authenticated using (false);
