# 动态工作流模板 MVP

## 目录结构

```
sql/
  001_schema.sql       表结构 + RLS
  002_functions.sql    审批引擎 RPC 函数
  003_seed_example.sql 示例种子数据（两级请假审批）
src/
  composables/useWorkflow.js   封装 supabase 调用
  components/
    WorkflowTemplateEditor.vue 模板编辑器
    WorkflowNodeCard.vue       单节点卡片
    ApproverConfigPanel.vue    审批人配置子面板
    MyApprovalTasks.vue        我的待办列表
```

## 跑通步骤

1. 在 Supabase SQL Editor 里依次执行 `001_schema.sql` → `002_functions.sql`。
   （如果你的项目里 `departments` / `user_profiles` 已经存在同名表，先对照字段看是否冲突，
   建议改成 `create table if not exists`，脚本里已经加了这个保护。）

2. 打开 `003_seed_example.sql`，把里面的占位 `user_id`
   （`00000000-0000-0000-0000-000000000000`）替换成你数据库里真实存在的用户 id，再执行。

3. 把 `src/composables` 和 `src/components` 拷到你项目对应目录，
   把 `useWorkflow.js` 里的 `import { supabase } from '@/lib/supabaseClient'`
   换成你项目里真实的 supabase client 路径。

4. 在页面里挂载 `<WorkflowTemplateEditor />` 试着建一个模板，
   或者直接用种子数据里已经建好的模板，在 SQL Editor 里跑：

   ```sql
   select start_workflow_instance(
     '11111111-1111-1111-1111-111111111111',
     gen_random_uuid(),
     'leave_request',
     '{"days": 2, "reason": "感冒"}'::jsonb
   );
   ```

5. 用被指定为审批人的账号登录前端，打开 `<MyApprovalTasks />`，应该能看到一条待办，
   点"通过"后再看 `approval_tasks` 表，应该能看到流程推进到下一节点、生成了新任务。

## 已知的 TODO（留给下一阶段）

- `workflow_templates` / `workflow_nodes` 的管理员权限策略现在写得比较宽松（TODO 注释已标出），
  上线前务必换成你项目里真实的角色判断。
- 模板编辑保存时是"删旧节点重建"，如果已有实例正在跑，节点 id 会变化导致历史记录里的
  `node_id` 悬空引用旧节点。生产环境建议改成"新建版本"而不是原地覆盖模板。
- 条件分支（按金额分级审批等）还没做，等这版验证完可以在此基础上加
  `workflow_node_transitions` 表。
- `fetchMyPendingTasks` 里没做分页，任务多了需要加。
