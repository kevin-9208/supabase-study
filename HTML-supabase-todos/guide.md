先来看整体架构和数据结构，再逐步实现。整体分三块来讲：数据库结构、核心实现代码、以及实时同步机制。先看数据结构。四张表是核心：`profiles` 存用户信息（由 Auth 自动触发创建），`workspaces` 是"团队空间"，`workspace_members` 管理成员角色，`todos` 是任务本体，支持指派给任意成员。

---

## 第一步：Supabase 建表 SQL

```sql
-- 用户资料表（Auth 注册时自动创建）
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  display_name text,
  avatar_url text
);

-- 注册触发器
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- 工作区（团队空间）
create table workspaces (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  owner_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now()
);

-- 成员关系
create type member_role as enum ('owner', 'editor', 'viewer');
create table workspace_members (
  workspace_id uuid references workspaces(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  role member_role default 'editor',
  primary key (workspace_id, user_id)
);

-- 任务表
create table todos (
  id uuid default gen_random_uuid() primary key,
  workspace_id uuid references workspaces(id) on delete cascade,
  created_by uuid references profiles(id),
  assigned_to uuid references profiles(id),
  title text not null,
  is_done boolean default false,
  priority int default 0,  -- 0 普通 1 重要 2 紧急
  due_at timestamptz,
  created_at timestamptz default now()
);
```

---

## 第二步：RLS 权限策略

RLS 是这个应用最关键的部分——它让你不用写任何后端 API，安全直接由数据库保证。

```sql
-- 开启 RLS
alter table workspaces enable row level security;
alter table workspace_members enable row level security;
alter table todos enable row level security;

-- workspaces：只能看到自己参与的
create policy "members can view workspace"
  on workspaces for select
  using (
    id in (
      select workspace_id from workspace_members
      where user_id = auth.uid()
    )
  );

-- workspace_members：只有成员能查看成员列表
create policy "members can view members"
  on workspace_members for select
  using (
    workspace_id in (
      select workspace_id from workspace_members
      where user_id = auth.uid()
    )
  );

-- todos：只有同一工作区的成员能看
create policy "members can view todos"
  on todos for select
  using (
    workspace_id in (
      select workspace_id from workspace_members
      where user_id = auth.uid()
    )
  );

-- todos：成员可以增删改（viewer 角色除外，可按需收紧）
create policy "members can insert todos"
  on todos for insert
  with check (
    workspace_id in (
      select workspace_id from workspace_members
      where user_id = auth.uid()
        and role in ('owner', 'editor')
    )
  );

create policy "members can update todos"
  on todos for update
  using (
    workspace_id in (
      select workspace_id from workspace_members
      where user_id = auth.uid()
        and role in ('owner', 'editor')
    )
  );

create policy "only creator or owner can delete"
  on todos for delete
  using (
    created_by = auth.uid()
    or workspace_id in (
      select workspace_id from workspace_members
      where user_id = auth.uid() and role = 'owner'
    )
  );
```

---

## 第三步：前端完整实现

下面是一个可直接运行的单页 HTML，涵盖登录、任务增删改查、实时同步。

```html
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<title>协作待办</title>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: system-ui, sans-serif; background: #f5f5f4; color: #1c1c1a; }
  
  #auth-page { max-width: 360px; margin: 80px auto; padding: 32px;
    background: #fff; border-radius: 12px; border: 0.5px solid #e0ddd5; }
  #auth-page h1 { font-size: 18px; font-weight: 500; margin-bottom: 20px; }
  input { width: 100%; padding: 9px 12px; border: 0.5px solid #ccc;
    border-radius: 8px; font-size: 14px; margin-bottom: 10px; }
  button { width: 100%; padding: 9px; background: #1c1c1a; color: #fff;
    border: none; border-radius: 8px; font-size: 14px; cursor: pointer; }
  button:hover { opacity: 0.85; }

  #app { display: none; max-width: 680px; margin: 0 auto; padding: 24px; }
  .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
  .header h2 { font-size: 16px; font-weight: 500; }
  .logout-btn { padding: 6px 14px; background: transparent;
    border: 0.5px solid #ccc; border-radius: 8px; color: #666;
    font-size: 13px; width: auto; }

  .add-row { display: flex; gap: 8px; margin-bottom: 16px; }
  .add-row input { margin: 0; flex: 1; }
  .add-row button { width: auto; padding: 9px 18px; }

  .todo-list { display: flex; flex-direction: column; gap: 6px; }
  .todo-item { display: flex; align-items: center; gap: 10px;
    background: #fff; border: 0.5px solid #e0ddd5; border-radius: 10px;
    padding: 12px 14px; transition: opacity 0.2s; }
  .todo-item.done { opacity: 0.5; }
  .todo-item.done .todo-title { text-decoration: line-through; color: #888; }
  .todo-title { flex: 1; font-size: 14px; }
  .todo-meta { font-size: 12px; color: #999; white-space: nowrap; }
  .delete-btn { background: transparent; border: none; color: #bbb;
    font-size: 16px; cursor: pointer; width: auto; padding: 0 4px; }
  .delete-btn:hover { color: #e24b4a; }

  .priority-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
  .p0 { background: #d3d1c7; }
  .p1 { background: #EF9F27; }
  .p2 { background: #E24B4A; }

  .realtime-badge { display: inline-flex; align-items: center; gap: 5px;
    font-size: 12px; color: #0F6E56; background: #E1F5EE;
    padding: 3px 9px; border-radius: 20px; }
  .realtime-dot { width: 6px; height: 6px; border-radius: 50%; background: #1D9E75;
    animation: pulse 2s ease-in-out infinite; }
  @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }

  .ws-selector { margin-bottom: 16px; display: flex; gap: 8px; align-items: center; }
  .ws-selector select { flex: 1; padding: 8px 10px; border: 0.5px solid #ccc;
    border-radius: 8px; font-size: 14px; background: #fff; }
  .ws-selector button { width: auto; padding: 8px 14px; }
</style>
</head>
<body>

<!-- 登录页 -->
<div id="auth-page">
  <h1>协作待办</h1>
  <input id="email" type="email" placeholder="邮箱">
  <input id="password" type="password" placeholder="密码">
  <button onclick="signIn()">登录 / 注册</button>
  <p id="auth-msg" style="font-size:13px;color:#888;margin-top:10px;text-align:center"></p>
</div>

<!-- 主应用 -->
<div id="app">
  <div class="header">
    <h2>协作待办</h2>
    <span class="realtime-badge">
      <span class="realtime-dot"></span>实时同步
    </span>
    <button class="logout-btn" onclick="signOut()">退出</button>
  </div>

  <div class="ws-selector">
    <select id="ws-select" onchange="switchWorkspace()">
      <option value="">— 选择工作区 —</option>
    </select>
    <button onclick="createWorkspace()">+ 新建</button>
  </div>

  <div class="add-row">
    <input id="new-todo" placeholder="添加任务，按 Enter 提交"
      onkeydown="if(event.key==='Enter') addTodo()">
    <button onclick="addTodo()">添加</button>
  </div>

  <div class="todo-list" id="todo-list">
    <p style="color:#aaa;font-size:14px;text-align:center;padding:20px">
      先选择或创建一个工作区
    </p>
  </div>
</div>

<script>
const SUPABASE_URL = 'https://你的项目.supabase.co'
const SUPABASE_KEY = '你的 anon key'
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY)

let currentUser = null
let currentWorkspace = null
let realtimeChannel = null

// ── 认证 ──────────────────────────────────────
async function signIn() {
  const email = document.getElementById('email').value
  const password = document.getElementById('password').value

  // 先尝试登录，失败则注册
  let { data, error } = await sb.auth.signInWithPassword({ email, password })
  if (error) {
    ;({ data, error } = await sb.auth.signUp({ email, password }))
    if (error) { document.getElementById('auth-msg').textContent = error.message; return }
    document.getElementById('auth-msg').textContent = '注册成功，请查收确认邮件'
    return
  }
  onLogin(data.user)
}

async function signOut() {
  await sb.auth.signOut()
  currentUser = null
  currentWorkspace = null
  if (realtimeChannel) sb.removeChannel(realtimeChannel)
  document.getElementById('app').style.display = 'none'
  document.getElementById('auth-page').style.display = 'block'
}

function onLogin(user) {
  currentUser = user
  document.getElementById('auth-page').style.display = 'none'
  document.getElementById('app').style.display = 'block'
  loadWorkspaces()
}

// 页面加载时恢复会话
sb.auth.getSession().then(({ data: { session } }) => {
  if (session) onLogin(session.user)
})

// ── 工作区 ────────────────────────────────────
async function loadWorkspaces() {
  const { data } = await sb
    .from('workspaces')
    .select('id, name')
    .order('created_at')

  const sel = document.getElementById('ws-select')
  sel.innerHTML = '<option value="">— 选择工作区 —</option>'
  data?.forEach(ws => {
    const opt = document.createElement('option')
    opt.value = ws.id
    opt.textContent = ws.name
    sel.appendChild(opt)
  })
  // 自动选中第一个
  if (data?.length) {
    sel.value = data[0].id
    switchWorkspace()
  }
}

async function createWorkspace() {
  const name = prompt('工作区名称（可邀请成员共用）')
  if (!name) return
  const { data, error } = await sb
    .from('workspaces')
    .insert({ name, owner_id: currentUser.id })
    .select()
    .single()
  if (error) { alert(error.message); return }

  // 创建者自动成为 owner 成员
  await sb.from('workspace_members').insert({
    workspace_id: data.id,
    user_id: currentUser.id,
    role: 'owner'
  })
  loadWorkspaces()
}

function switchWorkspace() {
  const id = document.getElementById('ws-select').value
  if (!id) return
  currentWorkspace = id
  loadTodos()
  subscribeRealtime()
}

// ── 任务 CRUD ─────────────────────────────────
async function loadTodos() {
  const { data } = await sb
    .from('todos')
    .select(`
      id, title, is_done, priority, due_at, created_at,
      profiles!todos_assigned_to_fkey(display_name, email)
    `)
    .eq('workspace_id', currentWorkspace)
    .order('is_done')
    .order('priority', { ascending: false })
    .order('created_at')

  renderTodos(data || [])
}

function renderTodos(todos) {
  const list = document.getElementById('todo-list')
  if (!todos.length) {
    list.innerHTML = '<p style="color:#aaa;font-size:14px;text-align:center;padding:20px">还没有任务，添加一个吧</p>'
    return
  }
  list.innerHTML = todos.map(t => `
    <div class="todo-item ${t.is_done ? 'done' : ''}" id="todo-${t.id}">
      <span class="priority-dot p${t.priority}"></span>
      <input type="checkbox" ${t.is_done ? 'checked' : ''}
        onchange="toggleTodo('${t.id}', this.checked)">
      <span class="todo-title">${escHtml(t.title)}</span>
      <span class="todo-meta">
        ${t.profiles?.display_name || t.profiles?.email?.split('@')[0] || '未指派'}
      </span>
      <button class="delete-btn" onclick="deleteTodo('${t.id}')">×</button>
    </div>
  `).join('')
}

async function addTodo() {
  const input = document.getElementById('new-todo')
  const title = input.value.trim()
  if (!title || !currentWorkspace) return

  const { error } = await sb.from('todos').insert({
    workspace_id: currentWorkspace,
    created_by: currentUser.id,
    title
  })
  if (error) { alert(error.message); return }
  input.value = ''
  // Realtime 会自动触发重新渲染，无需手动 reload
}

async function toggleTodo(id, isDone) {
  await sb.from('todos').update({ is_done: isDone }).eq('id', id)
}

async function deleteTodo(id) {
  await sb.from('todos').delete().eq('id', id)
}

// ── 实时订阅（核心） ───────────────────────────
function subscribeRealtime() {
  // 先取消上一个频道
  if (realtimeChannel) sb.removeChannel(realtimeChannel)

  realtimeChannel = sb
    .channel(`todos:${currentWorkspace}`)
    .on(
      'postgres_changes',
      {
        event: '*',          // INSERT | UPDATE | DELETE
        schema: 'public',
        table: 'todos',
        filter: `workspace_id=eq.${currentWorkspace}`
      },
      (payload) => {
        // 任何变更都重新拉一次列表
        // 生产环境可根据 payload.eventType 做局部更新，减少请求
        loadTodos()
      }
    )
    .subscribe()
}

// ── 工具函数 ──────────────────────────────────
function escHtml(str) {
  return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
}
</script>
</body>
</html>
```

---

## 实时同步的工作原理

Supabase Realtime 底层走 PostgreSQL 的 WAL（Write-Ahead Log）。每当数据库有 INSERT / UPDATE / DELETE，Postgres 会把变更写入 WAL，Supabase 的 Realtime 服务读取 WAL 并通过 WebSocket 推送到所有订阅的客户端。

你在代码里调用的 `.channel()` 本质上是建立了一条 WebSocket 长连接，`filter: workspace_id=eq.xxx` 让服务端只推送当前工作区的变更，不同团队的消息不会互串。

---

## 进阶方向

这个基础版跑通之后，可以沿几个方向扩展：

**成员邀请**：给 `workspace_members` 表加一条 `insert` RLS，允许 owner 插入新成员记录；前端做一个"输入邮箱邀请"的 UI，查 `profiles` 表找到用户 id 后插入。

**乐观更新**：点击 checkbox 后不等服务端响应，先在本地把 UI 改成勾选状态，Realtime 收到确认后再做最终同步，体验更流畅。

**优先级与截止日期**：`priority` 和 `due_at` 字段已经在表里了，前端加个下拉和日期选择器即可，SQL 的 `order by priority desc, due_at` 自动排序。

**Presence（在线状态）**：Supabase Realtime 还有一个 `presence` API，可以显示"哪些成员正在看这个列表"，几行代码就能做出"小头像正在编辑"的效果。

