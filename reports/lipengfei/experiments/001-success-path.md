# 运行验证 001：一次成功调度周期 —— Session 开、allocate 提交、Pod 绑定写回

| 项 | 内容 |
| --- | --- |
| 执行人 | 李鹏飞 |
| 日期 | 2026-10-05 |
| 状态 | **成功** |
| **验证的是哪个判断** | 调用链成功路径第 1–7 步；证据矩阵第 1、2、5 条 |
| 关联报告章节 | `reports/lipengfei/report.md` §4.2 / §4.3 |

## 1. 环境快照

```bash
$ git -C ~/learn/volcano rev-parse HEAD
d2dd7024f4af3070f9d99d68a78973893908a743

$ kubectl version
Client Version: v1.35.3
Server Version: v1.27.16

$ kubectl get nodes
NAME                        STATUS   ROLES           AGE   VERSION
volcano-lab-control-plane   Ready    control-plane   14m   v1.27.16
volcano-lab-worker          Ready    <none>          13m   v1.27.16
volcano-lab-worker2         Ready    <none>          13m   v1.27.16

$ kubectl -n volcano-system get deploy -o jsonpath=...   # 镜像 tag
volcano-admission     docker.io/volcanosh/vc-webhook-manager:v1.15.3
volcano-controllers   docker.io/volcanosh/vc-controller-manager:v1.15.3
volcano-scheduler     docker.io/volcanosh/vc-scheduler:v1.15.3
```

| 项 | 值 |
| --- | --- |
| K8s 版本 | v1.27.16（3 节点，各 10 CPU / 8024852Ki） |
| Volcano 镜像 tag | `v1.15.3` |
| 生效的调度器配置 | `actions: "enqueue, allocate, backfill"`；2 个 tier、9 个插件（与 [docs/01-architecture.md §4](../../../docs/01-architecture.md) 逐字一致） |
| **调度器启动参数** | `--schedule-period=1s` `--node-worker-threads=20` `-v=3` |

**输入文件**：[`001-success-path.yaml`](001-success-path.yaml)
Queue `exp-queue`（capability cpu 4）+ vcjob `exp-success`（`minAvailable: 2`，2×500m CPU）。

## 2. 我要验证的假设

**假设**：一次调度周期由**定时器**驱动；`Session` 在周期内构建集群快照，`allocate` 决策先记录在 `Statement` 里，`Commit()` 才把绑定请求交给 cache 异步写回。

**如果假设成立，我应该看到**：
1. 调度器日志里 `Open Session` 以稳定的 ~1s 间隔出现；
2. `Open Session ... with <1> Job and <3> Queues` —— 快照里出现我的作业；
3. 出现 `After allocated Task <...>` 与 Pod 最终拿到 `spec.nodeName`。

**如果假设不成立，我应该看到**：间隔是无规律的（事件驱动），或 Pod 长时间 Pending。

## 3. 变量

| 项 | 对照组 | 实验组 |
| --- | --- | --- |
| 自变量 | ——（本实验只验证成功路径，不设对照） | 提交一个资源充足的 vcjob |
| 控制变量（保持不变） | 调度器配置、节点数量、镜像 tag | 同左 |

## 4. 步骤

```bash
kubectl apply -f 001-success-path.yaml
for i in $(seq 1 18); do
  kubectl get pods -l volcano.sh/job-name=exp-success --no-headers | grep -c Running
  sleep 5
done
kubectl get pods -l volcano.sh/job-name=exp-success -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.schedulerName}{"\t"}{.spec.nodeName}{"\n"}{end}'
kubectl -n volcano-system logs deploy/volcano-scheduler --since=3m | grep -E "Open Session|Close Session|allocated Task"
```

## 5. 观察到的原始输出

完整原始输出见 [`001-success-path.log`](001-success-path.log)。关键片段：

**① 两个 Pod 在 ~20s 内 Running，`spec.nodeName` 已写回：**

```text
exp-success-worker-0	volcano	volcano-lab-worker2
exp-success-worker-1	volcano	volcano-lab-worker

NAME                                               PHASE     MINMEMBER   RUNNING
exp-success-d197da68-3d77-4fd6-a5ce-997a7bd932b0   Running   2           2
```

**② Session 以 ~1.001s 的稳定间隔开闭**（这是判断"定时驱动"的直接证据）：

```text
I1005 11:02:06.796246 session.go:279] Open Session 530ab83c-... with <1> Job and <3> Queues. HyperNodesReadyToSchedule: true
I1005 11:02:06.797305 session.go:577] Close Session 530ab83c-...
I1005 11:02:07.797797 session.go:279] Open Session 283f2d08-... with <1> Job and <3> Queues. ...
I1005 11:02:07.798759 session.go:577] Close Session 283f2d08-...
I1005 11:02:08.800852 session.go:279] Open Session 46bdf9b3-... with <1> Job and <3> Queues. ...
```

相邻两次 `Open Session` 的时间差：`06.796 → 07.797 → 08.800 → 09.806 → 10.812`，
**恒为 ~1.001s**，与 `--schedule-period=1s` 一致。每个 Session 的 UID 都不同。

**③ 决策记录发生在 `statement.go`，不是 `session.go`：**

```text
I1005 11:02:00.752629 statement.go:277] After allocated Task <default/exp-success-worker-0> to Node <volcano-lab-worker2>: idle <cpu 9400.00, ...>, used <cpu 600.00, ...>
I1005 11:02:00.753155 statement.go:277] After allocated Task <default/exp-success-worker-1> to Node <volcano-lab-worker>: idle <cpu 9400.00, ...>, used <cpu 600.00, ...>
```

| 关键指标 | 值 | 采集方式 |
| --- | --- | --- |
| Session 周期 | ~1.001 s | 相邻 `Open Session` 时间戳之差 |
| 提交 → Running | ~20 s | vcjob condition：`11:02:01Z` Pending → `11:02:18Z` Running |
| 决策记录点 | `statement.go:277` | `grep "allocated Task"` |

## 6. 结论

- **假设是否成立**：**成立**
- **依据**：①~③ 三条独立观察互相印证；Session 间隔恒定 1.001s 排除了"事件驱动"的解释。
- **这条证据的等级**：**A**（真跑出来了；日志为调度器进程原始输出）
- **它修正了哪个判断**：修正了证据矩阵第 1 条 —— 我原本按 `session.go:755 Session.Allocate`
  理解分配流程，运行日志证明实际走的是 `statement.go:246 Statement.Allocate`
  （见实验 003 的 `Discard` 证据，把这条链闭环）。

## 7. 异常与排查

- 现象：`kubectl get pods -n volcano` 报 `No resources found`。
- 排查过程：确认 Volcano 部署在 **`volcano-system`**，不是 `volcano`。
- 结论：命令用词问题，非故障。
- **是否值得写进报告 §7 维护观察**：否（属于常识性坑，`README.md` 已提示）。

## 8. 局限与下一步

- 本次验证**不能**说明：只有 1 个 job、2 个 task 时的行为；
  不能外推到多队列竞争、抢占、资源不足等场景。
- 下一步：
  - [x] 跑失败路径（实验 002 / 003）
  - [ ] 用 `-v=4` 复跑一次，观察 tier 内插件的调用顺序
