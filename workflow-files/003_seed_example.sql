-- ============================================================
-- 003_seed_example.sql
-- 示例：搭一个「请假审批」模板 —— start -> 部门负责人审批 -> 指定HR审批 -> end
-- 请把下面的 user_id 换成你自己数据库里真实存在的 auth.users id
-- ============================================================

-- 1) 建模板
insert into workflow_templates (id, name, business_type, is_active, version)
values ('11111111-1111-1111-1111-111111111111', '请假审批流程', 'leave_request', true, 1);

-- 2) 建节点：start -> 部门负责人(或签,其实只有一人) -> HR指定人(或签) -> end
insert into workflow_nodes (id, template_id, node_order, node_type, approver_type, approver_config, approval_mode)
values
  ('21111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 1, 'start', null, '{}', 'any'),
  ('22222222-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 2, 'approval', 'dept_leader', '{}', 'any'),
  ('23333333-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 3, 'approval', 'specific_user',
    jsonb_build_object('user_id', '00000000-0000-0000-0000-000000000000'), -- TODO: 换成真实 HR 的 user id
    'any'),
  ('24444444-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 4, 'end', null, '{}', 'any');

-- 3) 可选：补一条部门 + 负责人，方便测试 dept_leader 类型
-- insert into departments (id, name, leader_id) values (
--   'd1111111-1111-1111-1111-111111111111', '技术部', '<部门负责人的user id>'
-- );
-- insert into user_profiles (id, display_name, department_id) values (
--   '<申请人的user id>', '张三', 'd1111111-1111-1111-1111-111111111111'
-- );

-- 使用方式（在前端或 SQL 编辑器里测试）：
-- select start_workflow_instance(
--   '11111111-1111-1111-1111-111111111111',   -- template_id
--   gen_random_uuid(),                           -- business_id（真实场景传具体请假单的 id）
--   'leave_request',
--   '{"days": 2, "reason": "感冒"}'::jsonb
-- );
