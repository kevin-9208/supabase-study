# Supabase Realtime 功能详解

## 概述

Supabase Realtime 是一个全球分布式的实时通信服务，让应用能够即时展示数据变化，而无需频繁轮询 API。Realtime 允许应用即时显示实时更新，而不需要频繁发起 API 调用——例如在一个消息量很大的聊天窗口中，每隔几秒轮询一次接口去检查新消息是低效的。

Realtime 的服务端是用 Elixir 结合 Phoenix 框架构建的服务器，通过 WebSocket 与客户端通信。

## 三大核心能力

### 1. Broadcast（广播）
用于在客户端之间发送低延迟的临时消息。适合实时消息传递、数据库变更通知、光标位置追踪、游戏事件以及自定义通知等场景。典型例子是协作工具中追踪用户光标位置。消息本身不会持久化存储，是"过一次就消失"的事件流。

### 2. Presence（在线状态同步）
用于追踪和同步多个客户端之间的共享状态。可以构建协作类应用，让用户实时看到彼此的在线状态、操作行为或任何自定义状态信息。具体特性包括：
- 基于事件的追踪：监听 'sync'、'join'、'leave' 事件
- 自定义状态定义：可以共享任意类型的状态信息
- 通过自动生成或自定义 key 唯一标识客户端
- 按频道（channel）组织用户及其状态，形成不同的"房间"

典型应用：显示"当前有多少人在线"、协作文档里显示其他人的光标和头像。

### 3. Postgres Changes（数据库变更监听）
直接监听 Postgres 数据库的变化并推送给授权客户端，是 Supabase 相比其他 Realtime 方案最具特色的能力，因为它直接对接数据库的逻辑复制（replication）。特性包括：
- 基于事件监听：可订阅 INSERT、UPDATE、DELETE 或全部（*）事件
- 可针对特定 schema 或表进行监听
- 支持细粒度过滤，只接收相关的变更
- 同一个频道中可以组合监听多种事件、schema 和表
- 与 Row Level Security 集成，广播时会遵循数据库权限
- 让客户端数据与数据库保持同步，无需持续调用 API

代码示例（订阅 messages 表的新增记录）：
```js
import { createClient } from '@supabase/supabase-js'
const supabase = createClient('URL', 'ANON_KEY')

const channel = supabase
  .channel('db-changes')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'messages',
  }, (payload) => {
    console.log('New message:', payload.new)
  })
  .subscribe()
```

## 核心概念

Channel（频道）是 Realtime 的基础单位，可以理解为客户端通信和监听事件的"房间"，通过 topic 名称以及是公开还是私有来标识。

- **Topic**：频道的名称，是用来识别频道的字符串
- **Event**：可以发送和接收的消息类型
- **Payload**：实际传输、供用户处理的数据
- **私有频道**：需要使用 Realtime Authorization 来控制访问权限及发送消息的权限，并可以在项目设置中配置只允许私有频道，或同时允许公开和私有频道

底层实现上，Postgres Changes 依赖复制槽（replication slot）追踪某个表的 publication，从而将变更广播给已连接的客户端；此外还有一个 `realtime.broadcast_changes` 函数，可以借助 `realtime.send` 以兼容 Postgres Changes 的格式广播变更。

## 典型应用场景

| 场景 | 用到的功能 |
|---|---|
| 聊天 / IM 应用 | Broadcast + Postgres Changes |
| 协作文档 / 白板（光标同步） | Broadcast + Presence |
| 在线状态显示（谁在线） | Presence |
| 实时看板 / Dashboard 数据刷新 | Postgres Changes |
| 多人游戏、实时排行榜 | Broadcast |
| 实时通知（订单状态、审批流） | Postgres Changes |

常见适用场景包括聊天应用、协作工具和实时通知；而在交互较少、数据量很大或涉及复杂事务处理的系统中则不太适合使用 Realtime。

## 使用注意事项

- Presence 数据表有清理机制，会删除超过 3 天未活跃的记录，适合临时状态而非长期存储。
- Realtime 会占用多个数据库连接：Authorization 用于校验 join 权限的连接池、Broadcast from database 固定占用一条连接来接收复制槽数据、Postgres Changes 则需要多个连接池，且只有在实际使用该功能时才会启动；最多会使用 2 个复制槽，这些连接数和池大小是可以在项目配置中调整的。
- 高并发、高频写入的场景中，Postgres Changes 依赖逻辑复制，量级较大时需要评估数据库负载。
- 若只是想广播消息而不需要落库，用 Broadcast 更轻量；只想反映数据库真实变化时用 Postgres Changes。

如果你有具体要做的项目（比如聊天室、协作看板、实时排行榜等），我可以针对场景给出更具体的实现建议或代码示例。
