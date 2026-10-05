# 术语表（Glossary）

> **共享文件。** 任何人在自己的报告里用到一个新术语，先来这里加一条，再引用它。
> 不要在个人报告里各自定义一遍 —— 五个人五个定义是汇总报告最难看的死法。
>
> ⚠️ 下表的解释是**工作定义**，用于本组内部对齐口径。
> 正式引用（写进报告、答辩时）之前，请对着 `v1.15.3` 的代码或上游文档核一遍，
> 并把"核实人"填上。**没有核实过的定义不要直接抄进最终报告。**

| 术语 | 英文 / 缩写 | 本组工作定义 | 代码位置 | 核实人 |
| --- | --- | --- | --- | --- |
| PodGroup | PG | 需要**一起调度**的一组 Pod 的逻辑分组，是 gang 调度的最小单位。Volcano 通过 CRD 引入。 | `pkg/scheduler/api/`、`volcano.sh/apis` | 待填 |
| `minMember` | — | PodGroup 中被判定为"可调度"的 Pod 数下限；达不到则整组不调度。 | 同上 | 待填 |
| Queue | — | 资源队列，CRD。`weight` 决定多队列竞争资源时的相对份额，`capability` 限制队列资源上限。 | `pkg/scheduler/api/`、`pkg/scheduler/plugins/capacity` | 待填 |
| VolcanoJob | vcjob | Volcano 自有的作业 CRD，包含多个 task（ps / worker 等），并携带生命周期策略与插件配置。 | `pkg/controllers/job`、`volcano.sh/apis` | 待填 |
| JobFlow | — | 用于编排多个作业之间依赖关系的 CRD。 | `pkg/controllers/jobflow` | 待填 |
| Session | — | 一次调度周期内的集群状态快照与缓存容器，Action 与 Plugin 都在 Session 上操作。 | `pkg/scheduler/framework/` | 待填 |
| Action | — | 调度动作。一个调度周期内按配置顺序依次执行。v1.15.3 默认：`enqueue, allocate, backfill`。 | `pkg/scheduler/actions/` | 待填 |
| Plugin | — | 调度扩展点实现，按 tier 分层参与决策。 | `pkg/scheduler/plugins/` | 待填 |
| Tier | — | 插件的分层组织方式。层内插件如何交互、层间是否串行 —— **待核实后写准确**。 | 默认配置 `installer/helm/chart/volcano/config/volcano-scheduler.conf` | 待填 |
| Gang Scheduling | 帮派调度 | "要么全给、要么都不给"的调度语义。 | `pkg/scheduler/plugins/gang`、`pkg/scheduler/actions/allocate` | 待填 |
| Preempt | 抢占 | **跨队列**的抢占：高优先级队列抢走低优先级队列已占用的资源。 | `pkg/scheduler/actions/preempt` | 待填 |
| Reclaim | 回收 | **队列内 / 层级间**的资源回收，与 preempt 的边界是最容易被搞混的点，**必须写清楚**。 | `pkg/scheduler/actions/reclaim` | 待填 |
| Backfill | 回填 | 在 gang 调度之后，把不需要 gang 约束的零散 Pod 填补进空闲资源。 | `pkg/scheduler/actions/backfill` | 待填 |
| Deserved | 应得资源 | proportion 插件按队列 `weight` 计算出的、该队列"应该"拿到的资源量。 | `pkg/scheduler/plugins/proportion` | 待填 |
| DRF | Dominant Resource Fairness | 按各用户的**主导资源**（占用比例最高的那种资源）份额做公平分配。 | `pkg/scheduler/plugins/drf` | 待填 |
| Binpack | — | 尽量把 Pod 压到少数节点上，腾出整块空闲节点（便于缩容或给大作业让路）。与 spread 相反。 | `pkg/scheduler/plugins/binpack` | 待填 |
| NodeOrder | — | 节点打分与排序，决定同一个 Pod 最终落到哪个节点。 | `pkg/scheduler/plugins/nodeorder` | 待填 |
| Predicates | — | 节点过滤（预选），把不满足条件的节点剔除。 | `pkg/scheduler/plugins/predicates` | 待填 |
| Overcommit | — | 超卖相关配置与校验。 | `pkg/scheduler/plugins/overcommit` | 待填 |
| NUMA Aware | — | 感知 NUMA 拓扑的资源分配。 | `pkg/scheduler/plugins/numaaware` | 待填 |
| Device Share | — | GPU 等设备的共享与分配。 | `pkg/scheduler/plugins/deviceshare` | 待填 |
| SLA | — | 面向作业 SLA 等级的调度插件（新特性，注意核实引入版本）。 | `pkg/scheduler/plugins/sla` | 待填 |
| TDM | — | 待核实全称与用途。 | `pkg/scheduler/plugins/tdm` | 待填 |
| Resource Strategy Fit | — | 按资源策略打分（如 least-requested / most-requested）。 | `pkg/scheduler/plugins/resource-strategy-fit` | 待填 |

## 可能还需要补充的术语

<!-- 用到就加，别客气。 -->

- Volcano Agent / colocation（混部）
- 调度器配置文件与热加载（filewatcher）
- `enablePreemptable` 的真实语义
- 与 kube-scheduler 的关系（Volcano 是替换还是协作？`schedulerName`）
- Job 的 lifecycle policy：`--` 各阶段动作

## 相关上游文档（在源码仓库里）

| 文档 | 位置 |
| --- | --- |
| 设计文档 | `volcano/docs/design/` |
| 用户指南 | `volcano/docs/user-guide/` |
| 故障排查 | `volcano/docs/troubleshooting/` |
| 入门 | `volcano/docs/getting-started/` |
| 开发者文档 | `volcano/docs/development/` |
| 整体架构图 | `volcano/docs/images/volcano-architecture.png` |
| 官方站点 | https://volcano.sh/en/docs/ |
