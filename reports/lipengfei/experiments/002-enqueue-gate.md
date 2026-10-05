# 运行验证 002：enqueue 门控失败 —— PodGroup 永远 Pending，且一个 Pod 都没被创建

| 项 | 内容 |
| --- | --- |
| 执行人 | 李鹏飞 |
| 日期 | 2026-10-05 |
| 状态 | **成功**（成功复现了失败路径） |
| **验证的是哪个判断** | 调用链失败路径 A；证据矩阵第 2、3、4 条 |
| 关联报告章节 | `reports/lipengfei/report.md` §4.4 |

## 1. 环境快照

同 [实验 001](001-success-path.md) §1（同一集群、同一会话内连续执行）。补充：

```bash
$ git -C ~/learn/volcano rev-parse HEAD
d2dd7024f4af3070f9d99d68a78973893908a743

$ kubectl get queue exp-queue-fail -o jsonpath='{.status.state}'
Open            # ← 前置条件：Queue 已经 Open 才提交 Job，排除 webhook 干扰
```

## 2. 我要验证的假设

**假设**：当作业的 `minResources` 超过队列的有效配额时，作业会停在 `Pending`，
**Pod 根本不会被创建**（而不是"Pod 被创建后一直 Pending"）。

**如果假设成立，我应该看到**：`kubectl get pods` 返回空；PodGroup 停在 `Pending`；
调度器日志里**完全没有**这个作业。

**如果假设不成立，我应该看到**：4 个 Pod 处于 Pending，PodGroup 处于 `Inqueue`。

## 3. 变量

| 项 | 对照组 | 实验组 |
| --- | --- | --- |
| 自变量 | 实验 001：minReq 1 CPU ≤ 队列有效配额 | minReq **32 CPU** > 队列有效配额（≈30 CPU） |
| 控制变量（保持不变） | Queue 先 Open 再提交 Job、镜像 tag、调度器配置 | 同左 |

**输入文件**：[`002-enqueue-gate.yaml`](002-enqueue-gate.yaml)
（Queue capability `cpu: 40`；vcjob `minAvailable: 4`，4 × 8 CPU = 32 CPU）

另见 [`002b-enqueue-gate-no-capability.yaml`](002b-enqueue-gate-no-capability.yaml)：
**Queue 完全不设 capability**，同样被拒绝 —— 这条用于证据矩阵第 3 条。

## 4. 步骤

```bash
# 前置：先建 Queue，轮询等它变 Open
kubectl apply -f - <<'EOF'   # Queue exp-queue-fail, capability cpu 40
...
EOF
while [ "$(kubectl get queue exp-queue-fail -o jsonpath='{.status.state}')" != "Open" ]; do sleep 1; done

# 再提交 Job
kubectl apply -f 002-enqueue-gate.yaml
sleep 40

kubectl get vcjob exp-fail
kubectl get podgroups.scheduling.volcano.sh -A
kubectl get pods -n default -o wide
kubectl get events -A --sort-by=.lastTimestamp | grep exp-fail
kubectl -n volcano-system logs deploy/volcano-scheduler  --since=3m | grep exp-fail
kubectl -n volcano-system logs deploy/volcano-controllers --since=3m | grep exp-fail
```

## 5. 观察到的原始输出

完整原始输出见 [`002-enqueue-gate.log`](002-enqueue-gate.log)。关键片段：

```text
$ kubectl get vcjob exp-fail
NAME       STATUS    MINAVAILABLE   RUNNINGS   AGE
exp-fail   Pending   4                         45s

$ kubectl get podgroups.scheduling.volcano.sh -A
default   exp-fail-5eeb1767-...   Pending   4

$ kubectl get pods -n default -o wide
No resources found in default namespace.       ← 关键：一个 Pod 都没有
```

**事件（真正的拒绝原因）：**

```text
Normal  Unschedulable  podgroup/exp-fail-...  queue resource quota insufficient: insufficient cpu
Warning Unschedulable  podgroup/exp-fail-...  0/0 tasks in gang unschedulable: pod group is not ready, 4 minAvailable
```

**调度器日志：完全为空 —— 调度器从未看到这个作业**

```text
$ kubectl -n volcano-system logs deploy/volcano-scheduler --since=3m | grep -c exp-fail
0
```

**控制器日志：反复 SyncJob，但因 `syncTask=false` 从不创建 Pod**

```text
I1005 11:10:34.335954 job_controller_actions.go:346] Starting to sync up Job <default/exp-fail>, current version 0
I1005 11:10:34.335970 job_controller_actions.go:287] Starting to initiate Job <default/exp-fail>
I1005 11:10:34.336019 job_controller_actions.go:421] Job <default/exp-fail> has not updated for no changing
I1005 11:10:34.336025 job_controller_actions.go:626] Finished Job <default/exp-fail> sync up, current version 0
```

## 6. 结论

- **假设是否成立**：**成立**，且比预期更彻底 —— 不是"Pod Pending"，而是**根本没有 Pod**。
- **依据**：`kubectl get pods` 为空 + 调度器日志 0 命中 + 控制器日志显示 `syncTask=false` 分支。
- **这条证据的等级**：**A**
- **它修正了哪个判断**：**修正了证据矩阵第 2 条** —— 我原本以为"gang 调度失败"必然表现为
  "若干 Pod 长期 Pending"。实际存在一个**更早的失败点**：作业在 `enqueue` 就被拒，
  Pod 从未被创建，`allocate` 连看都没看到它。

**因果链（代码级，B 级佐证）：**

| # | 环节 | 代码位置 | 事实 |
| ---: | --- | --- | --- |
| 1 | 控制器建 PodGroup，phase 初始为空→`Pending` | `pkg/controllers/job/` | PodGroup 存在，STATUS=Pending |
| 2 | 控制器判断是否建 Pod | `job_controller_actions.go:407-409` | `if pg.Status.Phase != "" && pg.Status.Phase != PodGroupPending { syncTask = true }` ⇒ **false** |
| 3 | 不满足 ⇒ 直接返回，不建 Pod | `job_controller_actions.go:421` | 打印 `has not updated for no changing`（**与实测日志逐字一致**） |
| 4 | PodGroup 变 `Inqueue` 的唯一途径 | `actions/enqueue/enqueue.go:95-97` | `if ... ssn.JobEnqueueable(job) { JobEnqueued(job); PodGroup.Status.Phase = PodGroupInqueue }` |
| 5 | 配额判定 | `plugins/proportion/proportion.go:434-438` | `minReq(32) > realCapability(30)` ⇒ `RecordPodGroupEvent(... "queue resource quota insufficient" ...)` + `return util.Reject`（**事件文本逐字一致**） |
| 6 | 结果 | —— | 无 Pod ⇒ 调度器无对象可调 ⇒ **死锁** |

## 7. 异常与排查

- 现象：第 1 次尝试时，Queue 与 Job 写在同一个 YAML 里一次性 `apply`，
  **Job 被 admission webhook 拒绝**：`can only submit job to queue with state 'Open', queue ... status is ''`。
- 排查过程：把 Queue 与 Job 拆成两步、轮询等 `state=Open` 后重跑，失败点才表现成 enqueue 门控。
  该竞态已单独记录为 [实验 004](004-webhook-race.md)，复现率 7/8。
- 结论：**同一个 YAML 里同时提交 Queue 和 Job 是不可靠的**，必须先建 Queue 并等它 `Open`。
- **是否值得写进报告 §7 维护观察**：**是**（作为"文档缺失导致的高频踩坑点"）。

## 8. 局限与下一步

- 本次验证**不能**说明：真实生产里 `realCapability` 的具体数值；
  本次 30 CPU 的结论依赖"3 节点 × 10 CPU"这一本机拓扑。
- 不能说明：`capacity` 插件（默认未启用）会给出不同结果。
- 下一步：
  - [x] 用实验 003 补上"Pod 确实被创建但 gang 凑不齐"的另一种失败
  - [ ] 在 Kubernetes 官方文档层面确认 `PodGroup` phase 语义（升到 C 级交叉验证）
