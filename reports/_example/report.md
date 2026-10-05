# 示例目录（不参与汇总）

这是为了让新同学看到"一份**填好的**报告长得什么样"，尤其是**结论和证据之间怎么建立链接**。
`scripts/build_index.py` 会跳过所有以 `_` 开头的目录，所以这里的示例不会出现在根 README 的索引表里。

**你要做的不是抄它，而是照着自己写。**

---

## 示例：一条结论是怎么被证据支撑的

### 摘要（节选）

> 本报告分析 `pkg/scheduler/plugins/gang` 在资源碎片场景下的行为。
> 在 3 节点 kind 集群上构造 4 个 PodGroup 竞争 6 个可用 CPU 核的场景，
> 观察到 gang 插件在碎片率超过 33% 时出现**长期饥饿**：等待 300s 后仍有 2 个 PodGroup 未被调度，
> 而集群空闲资源达 2 核（足够单个 PodGroup 的 `minMember` 需求）。
> 对应代码位置：`pkg/scheduler/plugins/gang/gang.go:XX`。

注意这段话里每一个可被质疑的点，都有一个可点击的来源：

| 结论里的说法 | 证据在哪 |
| --- | --- |
| "3 节点 kind 集群" | [experiments/001-场景搭建.md](experiments/001-场景搭建.md) §1 环境快照 |
| "碎片率超过 33%" | §4 原始数据表，附 `00X-*.log` |
| "等待 300s 仍未调度" | `kubectl get podgroup -w` 的原始输出，见 log |
| "空闲 2 核" | `kubectl describe node` 输出，见 log |
| "代码位置 gang.go:XX" | 对 v1.15.3 的引用，行号在基线 commit 上有效 |

### 反面例子（不要这么写）

> ~~gang 插件在高负载下表现不佳。~~

问题：高负载是多少？不佳指什么？谁测的？能不能重跑？
这种句子在评审阶段会被直接打回，也是答辩时第一个被问倒的地方。

---

## 目录里还有什么

- `meta.yml` —— 索引表的数据来源，字段说明见 [CONTRIBUTING.md §1](../../CONTRIBUTING.md)
- `experiments/` —— 每个实验一份记录
- `assets/` —— 导出的图（mermaid 源码写在报告里，导出的 PNG 放这里）
