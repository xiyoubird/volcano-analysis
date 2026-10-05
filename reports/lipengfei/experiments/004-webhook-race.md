# 运行验证 004：admission webhook 竞态 —— 同文件提交 Queue+Job 会随机被拒

| 项 | 内容 |
| --- | --- |
| 执行人 | 李鹏飞 |
| 日期 | 2026-10-05 |
| 状态 | **成功**（复现率 7/8） |
| **验证的是哪个判断** | 证据矩阵第 8 条；调用链失败路径 C（最早的一个失败点） |
| 关联报告章节 | `reports/lipengfei/report.md` §4.4 / §7 |

## 1. 环境快照

同 [实验 001](001-success-path.md) §1。

```bash
$ git -C ~/learn/volcano rev-parse HEAD
d2dd7024f4af3070f9d99d68a78973893908a743
```

## 2. 我要验证的假设

**假设**：把 Queue 与引用它的 Job 写在**同一个 YAML** 里一次性 `kubectl apply`，
会因为"Queue 控制器还没把 `status.state` 刷成 `Open`"而被 admission webhook 拒绝，
且**时好时坏**（竞态）。

**如果假设成立，我应该看到**：多次同样操作，结果不稳定；报错文本含
`only submit job to queue with state 'Open'`。

**如果假设不成立，我应该看到**：8 次全部成功，或全部失败（说明是确定性规则而非竞态）。

## 3. 变量

| 项 | 对照组 | 实验组 |
| --- | --- | --- |
| 自变量 | 实验 002/003：先建 Queue、轮询等 `Open`，再提交 Job | **Queue 与 Job 同一文件同时提交** |
| 控制变量（保持不变） | Job 规模、镜像、调度器配置 | 同左 |

**输入文件**：内联 heredoc（见下），作业规格同 [`002-enqueue-gate.yaml`](002-enqueue-gate.yaml)。

## 4. 步骤

```bash
for i in $(seq 1 8); do
  kubectl apply -f - <<EOF
apiVersion: scheduling.volcano.sh/v1beta1
kind: Queue
metadata: {name: race$i}
spec: {weight: 1}
---
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata: {name: race$i-job}
spec:
  minAvailable: 1
  schedulerName: volcano
  queue: race$i
  tasks:
    - replicas: 1
      name: worker
      template:
        spec:
          containers:
            - name: worker
              image: busybox:1.36
              command: ["sh", "-c", "echo ok"]
              resources: {requests: {cpu: 100m, memory: 32Mi}}
          restartPolicy: Never
EOF
done
```

## 5. 观察到的原始输出

完整原始输出见 [`004-webhook-race.log`](004-webhook-race.log)。

**首次撞到的原始报错：**

```text
$ kubectl apply -f 002-enqueue-gate.yaml
queue.scheduling.volcano.sh/exp-queue-fail created
Error from server: error when creating "002-enqueue-gate.yaml": admission webhook "validatejob.volcano.sh"
denied the request: can only submit job to queue with state `Open`, queue `exp-queue-fail` status is ``;
```

**8 次连续试验结果：**

```text
[1] ❌ webhook 拒绝
[2] ❌ webhook 拒绝
[3] ❌ webhook 拒绝
[4] ❌ webhook 拒绝
[5] ❌ webhook 拒绝
[6] ❌ webhook 拒绝
[7] ❌ webhook 拒绝
[8] ✅ 通过

结果：拒绝 7 / 通过 1 （共 8 次）＝ 复现率 87.5%
```

| 关键指标 | 值 | 采集方式 |
| --- | --- | --- |
| 复现率 | **7/8 = 87.5%** | 连续 8 次同构试验计数 |
| 失败阶段 | **admission**（比 enqueue 更早） | 报错来自 `validatejob.volcano.sh` |

## 6. 结论

- **假设是否成立**：**成立**（且第 8 次通过，恰好证明它是**竞态**而非确定性规则）。
- **依据**：7 次拒绝、1 次通过的分布 + 报错文本。
- **这条证据的等级**：**A**
- **它修正了哪个判断**：修正了证据矩阵第 8 条 —— 我原本以为"提交顺序不影响结果，
  只是对象创建有先后"。实际上**同一个 `apply` 里的对象没有顺序保证**，
  Job 的准入校验可能先于 Queue 控制器刷新 status 完成。

**代码位置（B 级）：**

```go
// pkg/webhooks/admission/jobs/validate/admit_job.go:202-207
queue, err := config.QueueLister.Get(job.Spec.Queue)     // ← 读 informer 本地缓存
if err != nil {
    msg += fmt.Sprintf(" unable to find job queue: %v;", err)
} else {
    if queue.Status.State != schedulingv1beta1.QueueStateOpen {
        msg += fmt.Sprintf(" can only submit job to queue with state `Open`, "+
            "queue `%s` status is `%s`;", queue.Name, queue.Status.State)
    }
    ...
}
```

校验读的是 **informer 本地缓存**里的 `queue.Status.State`，而该字段由
volcano-controllers 的 Queue 控制器异步写入。两条路径没有同步点 ⇒ 竞态。

## 7. 异常与排查

- 现象：第一次以为是 YAML 写错了，反复检查 `queue:` 字段拼写与 namespace。
- 排查过程：`kubectl get queue` 显示 Queue 明明存在，`status.state` 稍后才变 `Open`；
  把 Queue 与 Job 拆成两步后 100% 成功（实验 002、003 均如此），反证是时序问题。
- 结论：**这不是配置错误，是可用性缺陷**。
- **是否值得写进报告 §7 维护观察**：**是**（这是本报告最主要的一条维护建议）。

## 8. 局限与下一步

- 本次验证**不能**说明：87.5% 这个数字在其他机器 / 负载下是否稳定
  （它取决于控制器 reconcile 的时延，属于环境相关量）。
- 不能说明：Volcano 上游是否已有相关 Issue（**尚未检索**，见报告 §7 待办）。
- 下一步：
  - [ ] 到 `volcano-sh/volcano` 检索是否已有同类 Issue；若有，引用其编号
  - [ ] 若确认无人报告，按 `templates/issue-card.md` 整理成一张卡，考虑提给上游
