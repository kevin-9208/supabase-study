# OA 审批工作流 Demo（第一步：请假单人审批闭环）

范围：请假模块的「提交 → 审批（同意/拒绝）→ 撤回 → 通知」全链路，
Vue3 + Element Plus + Supabase（Postgres + Auth + RLS）。

---

## 一、Supabase 端准备

1. 在 [supabase.com](https://supabase.com) 新建一个项目（或使用已有项目）。
2. 打开 SQL Editor，把 `supabase/migrations/0001_init.sql` 的全部内容粘贴进去并执行。
   - 这一步会创建：`profiles / leave_requests / workflow_instances /
     workflow_instance_nodes / approval_tasks / approval_records / notifications`
     七张表、对应的 RLS 策略，以及三个核心函数：
     `submit_leave_request` / `handle_leave_approval` / `withdraw_leave_request`。
   - 同时会创建一个触发器：新用户注册后自动写入 `profiles` 表
     （用于「选择审批人」下拉框展示姓名）。
3. **（建议，方便本地测试）** 关闭邮箱验证：
   Authentication -> Providers -> Email -> 关闭 "Confirm email"。
   否则注册后需要先去邮箱点确认链接才能登录。
4. 在 Project Settings -> API 中拿到：
   - `Project URL`
   - `anon public` key

---

## 二、前端启动

```bash
# 1. 安装依赖
npm install

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env，填入上一步拿到的 Project URL 和 anon key

# 3. 启动开发服务器
npm run dev
```

打开 http://localhost:5173 即可看到登录/注册页面。

---

## 三、跑通完整闭环的操作步骤（自测清单）

因为审批需要「申请人」和「审批人」两个不同账号，建议准备两个邮箱测试：

1. **注册两个账号**：
   - `alice@test.com`（申请人）
   - `bob@test.com`（审批人）
   - 注册成功后会自动写入 `profiles` 表（触发器完成）。

2. **用 alice 登录**，进入「发起请假」页面：
   - 填写开始/结束日期、天数、事由
   - 审批人下拉框中选择 `bob`
   - 点击「提交申请」，应提示"提交成功"
   - ✅ 检查点：Supabase 表编辑器中 `leave_requests` 出现一条 `status=pending` 的记录；
     `workflow_instances` 出现一条 `status=running`；
     `workflow_instance_nodes` 出现一条 `status=processing`；
     `approval_tasks` 出现一条 `status=pending`；
     `notifications` 出现一条发给 bob 的通知。

3. **退出，用 bob 登录**，进入「我的待办」页面：
   - ✅ 检查点：应该能看到 alice 刚才提交的这条请假申请（RLS 生效：
     bob 能看到是因为他是待办审批人）
   - 点击右上角铃铛，应看到一条未读通知
   - 点击「同意」按钮（或先测试「拒绝」）
   - ✅ 检查点：Supabase 表中 `approval_records` 新增一条 `action=approve` 的记录；
     `approval_tasks` 该条状态变为 `done`；
     `workflow_instance_nodes` 变为 `approved`；
     `workflow_instances` 变为 `approved`；
     `leave_requests` 变为 `approved`；
     `notifications` 出现一条发给 alice 的"已通过"通知。

4. **退出，用 alice 登录**，进入「我的申请」页面：
   - ✅ 检查点：能看到刚才的请假记录，状态显示为「已通过」（绿色标签）
   - 点击右上角铃铛，应看到"你的请假申请已通过"的通知

5. **测试撤回流程**（重新提交一条新申请，不要审批它）：
   - alice 提交一条新的请假申请
   - 在「我的申请」页面找到这条 `status=审批中` 的记录，点击「撤回」
   - ✅ 检查点：状态变为「已撤回」；
     bob 的「我的待办」中这条记录应消失（因为 `approval_tasks` 已被标记为 `done`）

6. **测试并发安全（可选）**：
   - 用 bob 打开两个浏览器标签页，都进到「我的待办」，对同一条记录，
     一个标签页点「同意」，另一个标签页也点「同意」
   - ✅ 检查点：第二次点击应该报错"你不是该节点的审批人，或任务已被处理"，
     不会出现重复审批、状态错乱的情况（这是 `handle_leave_approval`
     函数里 `for update` 行锁 + 状态校验共同保证的）

---

## 四、目录结构

```
oa-workflow-demo/
├── supabase/
│   └── migrations/
│       └── 0001_init.sql          # 完整后端逻辑：建表 + RLS + 核心函数
├── src/
│   ├── lib/
│   │   └── supabase.js            # Supabase 客户端初始化
│   ├── router/
│   │   └── index.js               # 路由 + 登录守卫
│   ├── modules/workflow/
│   │   ├── composables/
│   │   │   ├── useAuth.js         # 登录/注册/登出
│   │   │   └── useLeaveWorkflow.js  # 提交/审批/撤回/查询，全部走 RPC
│   │   └── views/
│   │       ├── Login.vue          # 登录/注册页
│   │       ├── LeaveApply.vue     # 发起请假
│   │       ├── MyTodo.vue         # 我的待办
│   │       ├── MyApplications.vue # 我的申请（含撤回）
│   │       └── MyApproved.vue     # 我审批的
│   ├── App.vue                    # 主壳：导航 + 通知铃铛
│   └── main.js
├── .env.example
└── package.json
```

---

## 五、这一步之后，下一步可以扩展的方向

- **多级审批 / 条件分支**：引入 `workflow_templates` / `workflow_definitions`
  两张表，把 `handle_leave_approval` 里"审批完直接结束"替换成
  "根据 flow_schema 查找下一个节点"。
- **审批人策略**：目前审批人是提交时手动选的，后续可以改成按组织架构
  （`profiles.manager_id`）自动计算"直属主管"。
- **通用化**：把 `leave_requests` 换成任意业务表，
  `workflow_instances.business_type` 区分不同业务模块，
  审批引擎本身（`workflow_instances/nodes/tasks/records`）完全复用。
- **迁移到 Edge Function**：当审批人策略、条件表达式变复杂时，
  把编排逻辑从 Postgres 函数挪到 Edge Function，Postgres 只保留原子性强的
  状态写入。

---

## 六、安全说明

- `leave_requests` / `workflow_instances` 等表**没有开放 insert/update 的 RLS
  policy**，所有状态变更必须通过 `security definer` 函数（RPC）完成，
  前端无法绕过引擎逻辑直接改表。
- 三个核心函数都做了权限校验：`submit_leave_request` 校验不能选自己作为
  审批人；`handle_leave_approval` 校验操作者确实是当前节点的待办审批人；
  `withdraw_leave_request` 校验操作者必须是流程发起人。
