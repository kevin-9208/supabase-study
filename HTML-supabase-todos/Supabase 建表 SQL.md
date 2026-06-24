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
