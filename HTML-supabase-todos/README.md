四张表是核心：profiles 存用户信息（由 Auth 自动触发创建），workspaces 是"团队空间"，workspace_members 管理成员角色，todos 是任务本体，支持指派给任意成员。

HTML + Supabase 是一套非常好玩的组合，核心原因是 Supabase 把后端的难活都包了——数据库、用户认证、文件存储、实时订阅——你只需要写 HTML/JS 就能做出功能完整的 Web 应用。
为什么这个组合特别适合快速开发？
Supabase 提供一个 JS SDK，一行代码就能查数据库、监听变更、上传文件，不需要自己搭服务器。配合原生 HTML + 少量 JS，或者 Tailwind CSS 做样式，几百行代码就能做出真实可用的应用。
几个值得特别关注的能力：
Realtime 是最有趣的部分。Supabase 底层用 PostgreSQL 的 Change Data Capture，你在前端订阅某张表，任何人写入/更新数据都会通过 WebSocket 推到你的页面，完全不需要轮询。做聊天、协作、实时榜单非常顺手。
RLS（行级安全）解决了权限问题。不需要自己写 API 层来过滤数据，直接在数据库层面写规则，比如"用户只能读自己的订单"，前端直接查，数据库自动过滤。
PostGIS 是个彩蛋。Supabase 支持 PostgreSQL 的地理扩展，可以做"附近的 X"这类功能，配合 Leaflet.js 就是一个完整的地图应用。
