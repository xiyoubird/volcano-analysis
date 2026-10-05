# 运行验证 003：gang 回滚 —— Statement.Discard() 把已记录的决策整组撤掉

| 项 | 内容 |
| --- | --- |
| 执行人 | 李鹏飞 |
| 日期 | 2026-10-05 |
| 状态 | **成功**（成功复现了失败路径） |
| **验证的是哪个判断** | 调用链失败路径 B；证据矩阵第 5、6、7 条 |
| 关联报告章节 | `reports/lipengfei/report.md` §4.4 / §3.4 |

## 1. 环境快照

同 [实验 001](001-success-path.md) §1。关键前置：Queue `exp-queue-rollback` **不设 capability**。

```bash
$ git -C ~/learn/volcano rev-parse HEAD
d2dd7024f4af3070f9d99d68a78973893908a743
```

## 2. 我要验证的假设

**假设**：`allocate` 先把决策**记录**进 `Statement`（只改 Session 内存），
只有当 `JobReady()` 成立时才 `Commit()`；否则 `Discard()` 按**逆序**撤销。
因此 gang 凑不齐时，已经"看中"某个节点的 Pod 也应该被撤回，且**不写回 etcd**。

**如果假设成立，我应该看到**：
1. Pod 被真正创建（说明过了 enqueue 门），但全部 Pending、`spec.nodeName` 为空；
2. PodGroup 处于 `Inqueue`（不是 `Pending`）；
3. 调度器日志里出现"先 Binding Task X → 再 Discarding operations → 再 Remove Task X"的序列，
   且**每秒重复一次**；
4. 事件里出现"worker-0 可调度，但等 minAvailable 满足"这类 gang 语义措辞。

**如果假设不成立，我应该看到**：worker-0 被单独绑定并 Running（破坏 gang 语义）。

## 3. 变量

| 项 | 对照组 | 实验组 |
| --- | --- | --- |
| 自变量 | 实验 001：单节点可容纳全部 task | **nodeSelector 圈定 1 个节点**，但要求 2 个 task 各 8 CPU |
| 控制变量（保持不变） | minReq 必须 ≤ 队列有效配额（否则会退化到实验 002 的门控失败） | minReq = 16 CPU ≤ ≈30 CPU ✅ |

**输入文件**：[`003-gang-discard.yaml`](003-gang-discard.yaml)
Queue 无 capability；vcjob `exp-rollback`：`minAvailable: 2`，2 × 8 CPU，
`nodeSelector: kubernetes.io/hostname=volcano-lab-worker`（该节点空闲 ≈9.5 CPU）。

## 4. 步骤

```bash
kubectl apply -f 003-gang-discard.yaml
for i in $(seq 1 14); do
  kubectl get pods -l volcano.sh/job-name=exp-rollback --no-headers | grep -c Pending
  sleep 5
done
kubectl get pods -l volcano.sh/job-name=exp-rollback -o jsonpath='{range .items[*]}{.metadata.name}{"\tscheduler="}{.spec.schedulerName}{"\tnode="}{.spec.nodeName}{"\n"}{end}'
kubectl get events -A --sort-by=.lastTimestamp | grep exp-rollback
kubectl -n volcano-system logs deploy/volcano-scheduler --since=4m \
  | grep -E "exp-rollback|Discarding|Committing"
```

## 5. 观察到的原始输出

完整原始输出见 [`003-gang-discard.log`](003-gang-discard.log)。关键片段：

**① 2 个 Pod 存在，但 `node` 为空 —— 从未绑定：**

```text
NAME                    READY   STATUS    RESTARTS   AGE   IP       NODE
exp-rollback-worker-0   0/1     Pending   0          78s   <none>   <none>
exp-rollback-worker-1   0/1     Pending   0          78s   <none>   <none>

exp-rollback-worker-0	scheduler=volcano	node=
exp-rollback-worker-1	scheduler=volcano	node=
```

**② PodGroup 处于 `Inqueue`（区别于实验 002 的 `Pending`）：**

```text
NAMESPACE   NAME                                                STATUS    MINMEMBER   RUNNINGS
default     exp-rollback-bc91e44f-...-c9111c3dd3cc              Inqueue   2
```

**③ 事件里的 gang 语义措辞（这是"整组语义"最直白的证据）：**

```text
Warning FailedScheduling  pod/exp-rollback-worker-0  Pod default/exp-rollback-worker-0 can possibly be assigned to
                                                     volcano-lab-worker, once minAvailable is satisfied
Warning FailedScheduling  pod/exp-rollback-worker-1  0/3 nodes are unavailable: 1 Insufficient cpu,
                                                     2 node(s) didn't match Pod's node affinity/selector.
Warning PodGroupPending   job/exp-rollback          PodGroup default:exp-rollback unschedulable, reason:
                                                     1/2 tasks in gang unschedulable: ... Pending: 1 Schedulable, 1 Unschedulable.
```

注意 `1 Schedulable, 1 Unschedulable` —— **worker-0 明明放得下，却被整组扣住**。

**④ 调度器日志：记录 → 失败 → 回滚，每秒重复（这是核心证据）：**

```text
I1005 11:07:37.703518 allocate.go:328] "Try to allocate resource" queue="exp-queue-rollback" job="default/exp-rollback-bc91..." taskNum=2
I1005 11:07:37.703549 allocate.go:777] There are <3> nodes for Job <default/exp-rollback-bc91...>
I1005 11:07:37.704056 predicate_helper.go:115] Predicates failed: task .../exp-rollback-worker-0 on node volcano-lab-control-plane fit failed: node(s) didn't match Pod's node affinity/selector
I1005 11:07:37.704106 allocate.go:956] Binding Task <default/exp-rollback-worker-0> to node <volcano-lab-worker>      ← 决策已记录
I1005 11:07:37.704132 statement.go:277] After allocated Task <default/exp-rollback-worker-0> to Node <volcano-lab-worker>: idle <cpu 1900.00, ...>
I1005 11:07:37.704374 allocate.go:777] There are <3> nodes for Job <default/exp-rollback-bc91...>
I1005 11:07:37.704448 predicate_helper.go:115] Predicates failed: task .../exp-rollback-worker-1 on node volcano-lab-worker fit failed: Insufficient cpu   ← 第 2 个放不下
I1005 11:07:37.704499 statement.go:366] Discarding operations ...                                                   ← 整组回滚
I1005 11:07:37.704517 statement.go:347] Remove Task <exp-rollback-worker-0> on node <volcano-lab-worker>            ← 撤销 worker-0
I1005 11:07:37.713279 cache.go:1101] Updating pod condition for default/exp-rollback-worker-0 to (PodScheduled==False)
I1005 11:07:38.727690 allocate.go:328] "Try to allocate resource" ...                                              ← 下一周期重来
I1005 11:07:38.728351 statement.go:366] Discarding operations ...
I1005 11:07:39.730924 allocate.go:328] "Try to allocate resource" ...                                              ← 再来
```

| 关键指标 | 值 | 采集方式 |
| --- | --- | --- |
| 观测时长 | 78 s 仍全 Pending | `kubectl get pods` |
| 重试周期 | ~1.02 s | `allocate.go:328` 相邻时间戳 |
| 每次 `Discard` 撤销的操作数 | 1 | `statement.go:347` 出现次数 |

## 6. 结论

- **假设是否成立**：**成立**，四条预期全部命中。
- **依据**：`statement.go:366 Discarding operations` + `statement.go:347 Remove Task` 成对出现，
  且发生在 `allocate.go:956 Binding Task` **之后** —— 证明"先记录、后回滚"。
- **这条证据的等级**：**A**
- **它修正了哪个判断**：**修正了证据矩阵第 5 条** —— 见下。

**关键结论：决策的"记录"与"写回"是分离的。**

| 阶段 | 代码位置 | 是否碰 etcd |
| --- | --- | --- |
| 记录决策 | `Statement.Allocate()` → `statement.go:246`，日志 `:277` | **否**（只改 Session 内存） |
| 提交 | `Statement.Commit()` → `statement.go:392` → `Statement.allocate()` `:317` → `cache.AddBindTask()` `:320` | 否（只是入队 `bindTaskQueue`） |
| 真正绑定 | `cache.go:874` 独立 goroutine 每 **20ms** 轮询 → `processBindTask()` `:1379` → `BindTask()` `:1454` | **是**（此处才写 `Pod.spec.nodeName`） |
| 回滚 | `Statement.Discard()` → `statement.go:365`，**逆序**遍历操作，调用 `unevict`/`unPipeline`/`unallocate` | 否（且不会入队） |

> 也就是说：**调度器的调度周期本身不直接写 etcd**。写回是 cache 侧一个异步 worker 干的。
> 这一点我一开始判断错了（证据矩阵第 5 条）。

## 7. 异常与排查

- 现象：**Queue 不设 `capability`，仍被 enqueue 拒绝**（本实验准备阶段撞到）。
- 排查过程：读 `proportion.go:132-138`，发现 `attr.realCapability = realCapability`
  在 `if attr.capability == nil` 的**两个分支里都执行**；因此 `:413` 的
  `if attr.realCapability == nil { return util.Permit }` 实际上不可达。
- 结论：**代码注释 `proportion.go:412`"If no capability is set, always enqueue the job"与实现不符**，
  这是证据矩阵第 3 条。
- **是否值得写进报告 §7 维护观察**：**是**（文档与实现不一致，且注释会主动误导读者）。

## 8. 局限与下一步

- 本次验证**不能**说明：多队列竞争下 `Discard` 的代价；
  也不知道 `Discard` 逆序撤销在嵌套 Statement / `Merge()` 场景下是否仍然正确
  （`statement.go:423 Merge`、`:447 RecoverOperations` 本次未被触发）。
- 不能说明：`preempt` / `reclaim` 的 `Evict` 操作回滚行为（默认未启用这两个 Action）。
- 下一步：
  - [ ] 读 `statement_recover_test.go`（2.1 KB）与 `statement_test.go`（11.6 KB），
        看作者自己怎么断言回滚（报告 §5.2）
  - [ ] 用 `-v=4` 复跑，确认 `Committing operations ...`（`statement.go:393`）在成功路径出现
