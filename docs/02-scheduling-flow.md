# Volcano 调度流程（共享章节）

> **共享文件。** 个人报告请引用本章，不要复制。
> 状态：`骨架已建，内容待全组补充`。

---

## 1. 一个调度周期的骨架

<!-- TODO：把下面这张图的省略号补全。核实位置：
       pkg/scheduler/scheduler.go（主循环、周期触发）
       pkg/scheduler/framework/（Session 生命周期）
       pkg/scheduler/actions/*/  （各 Action 的 Execute）
     关键问题（必须回答）：
       1. 调度周期由什么触发？（定时 / 事件 / 两者）
       2. Session 在每个周期开始时如何构建快照？构建成本有多大？
       3. Action 之间是否共享同一份 Session？前一个 Action 的决策如何影响后一个？
-->

```mermaid
sequenceDiagram
    participant Loop as 调度主循环<br/>pkg/scheduler/scheduler.go
    participant Sess as Session<br/>pkg/scheduler/framework
    participant Act as Actions<br/>enqueue → allocate → backfill
    participant Plugins as Plugins<br/>tier1 / tier2
    participant API as kube-apiserver

    Loop->>Sess: 新建 Session，打开缓存快照
    Loop->>Act: 按配置顺序执行
    Act->>Plugins: 逐 Job/Queue 调用扩展点
    Plugins-->>Act: 返回可行节点 / 打分
    Act->>Sess: 记录调度决策
    Act->>API: 绑定 Pod 到节点
    Loop->>Sess: 关闭 Session，提交缓存
```

<!-- 负责人：待填 -->

## 2. 各 Action 的职责与顺序

**v1.15.3 默认启用：`enqueue, allocate, backfill`**（已在源码中核对，见
[01-architecture.md §4](01-architecture.md#4-默认调度配置v1153-实测核对值)）。

| Action | 默认启用 | 职责（待核实细化） | 负责人 |
| --- | --- | --- | --- |
| `enqueue` | ✅ | 把队列中满足条件的 Job 放入待调度集合 | 待填 |
| `allocate` | ✅ | 主调度动作，处理 gang 语义下的整组分配 | 待填 |
| `backfill` | ✅ | 回填零散 Pod | 待填 |
| `preempt` | ❌ | 跨队列抢占 | 待填 |
| `reclaim` | ❌ | 队列内 / 层级间资源回收 | 待填 |
| `gangpreempt` | ❌ | gang 感知的抢占 | 待填 |
| `gangreclaim` | ❌ | gang 感知的回收 | 待填 |
| `shuffle` | ❌ | 打散，改善分布 | 待填 |

> ⚠️ **写报告时务必先确认你要测的 Action 是否默认启用。**
> 如果没启用，你的实验实际上测的是"什么都没发生"。
> 改配置的方法见 `docs/user-guide/how_to_configure_scheduler.md`。

<!-- 负责人：待填 -->

## 3. preempt 与 reclaim 的区别

<!-- 这是全组最容易搞混、也最容易被老师追问的点。这里必须给出一个所有人认可的、准确的表述。
     起点：docs/design/preempt-action.md、docs/design/reclaim-action.md、docs/design/reclaim-design.md
     提示（待你核实）：两者触发的资源来源不同（其他队列占用 vs 本队列/层级内占用），
     因此"谁抢谁"的语义完全不同。不要凭直觉写，去读代码里的 Trigger 条件。 -->

<!-- 负责人：待填 -->

## 4. 队列与公平性

<!-- TODO：Queue 的 weight / capability / deserved 三者关系；
     proportion 与 capacity 两个插件的定位差异；
     DRF / HDRF / fairshare 分别在什么场景下使用。
     这一节是"资源利用率""公平性"类选题的理论基础。 -->

<!-- 负责人：待填 -->

## 5. Gang 语义的实现路径

<!-- TODO：从 PodGroup 的 minMember 出发，说明一次 gang 调度判定
     经过了哪些插件、哪些 Action。这是所有 gang 相关选题的公共前置知识。 -->

<!-- 负责人：待填 -->

## 6. 与 kube-scheduler 的边界

<!-- TODO：哪些 Pod 会被 Volcano 接管？schedulerName 怎么配？
     两个调度器同时存在时会不会冲突？ -->

<!-- 负责人：待填 -->
