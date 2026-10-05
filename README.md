# Volcano 源码分析与测试 —— 小组协作仓库

本仓库是课程项目的**唯一协作载体**：所有分析报告、实验记录、共享脚本都在这里维护。

| 我需要… | 去这里 |
| --- | --- |
| 知道我们分析的是哪个版本、环境怎么定 | [baseline.md](baseline.md) |
| 知道怎么提交、怎么评审、分支怎么命名 | [CONTRIBUTING.md](CONTRIBUTING.md) |
| 看已经写了哪些报告 | 本页下面的 [报告索引](#报告索引) |
| 查一个术语是什么意思 | [docs/glossary.md](docs/glossary.md) |
| 了解 Volcano 的整体架构 | [docs/01-architecture.md](docs/01-architecture.md) |
| 看最后的组级结论 | [reports/00-汇总.md](reports/00-汇总.md) |
| 搭实验环境 | [scripts/setup-kind.sh](scripts/setup-kind.sh) |
| 要一份报告的空白模板 | [templates/report.md](templates/report.md) |

---

## 两个仓库怎么分工

| 仓库 | 放什么 | 可见性 |
| --- | --- | --- |
| [xiyoubird/volcano](https://github.com/xiyoubird/volcano) | 上游 fork。**只放代码、补丁、测试用例**；`master` 保持与上游一致，实验走单独分支 | 只能是 public |
| **本仓库** | 报告、实验记录、共享文档、脚本。组员加成 Collaborator，走分支 + PR | 建议设为 **private** |

**为什么不把报告写进 Volcano 的 fork：**

1. **可见性改不了。** GitHub 明确规定 fork 的可见性跟随上游，`Volcano` 是公开仓库，
   所以 fork 只能是 public，**无法单独设为 private**（[官方文档](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/what-happens-to-forks-when-a-repository-is-deleted-or-changes-visibility)）。
   报告草稿、实验日志、对项目的评价都会变成公开可读。
2. **fork 网络共享 Git 数据。** 上游所有者可以读取网络内所有 fork 的内容，
   即使 fork 被删除，数据仍可能从网络内其他仓库访问到。
3. **基线会被污染。** fork 的 `master` 现在正好等于 `upstream/master`，这是最干净的基线；
   一旦报告提交落上去，就再也不能 `merge --ff-only` 同步上游。
4. **太重。** 完整 clone 约 160MB，同学为了写文档不该拉一整个 Go 仓库。

---

## 快速开始

```bash
git clone <本仓库地址> && cd volcano-analysis

# 1. 搭环境（第一次做，约 10 分钟）
bash scripts/fetch-baseline.sh          # 拉取 Volcano v1.15.3 基线源码
bash scripts/setup-kind.sh              # 建 kind 集群 + 部署 Volcano
bash scripts/setup-kind.sh smoke        # 冒烟测试，确认调度器真的在工作

# 2. 建自己的报告目录（详细步骤见 CONTRIBUTING.md §1）
mkdir -p reports/<你的名字>/experiments reports/<你的名字>/assets
cp templates/report.md     reports/<你的名字>/report.md
cp reports/_example/meta.yml reports/<你的名字>/meta.yml

# 3. 刷新本页的索引表
python3 scripts/build_index.py
```

---

## 选题矩阵

**先认领，再动手。** 把名字填进「认领人」列，提一个 PR 就算完成认领。
没被认领的选题可能在组会上被指派。

以下是候选方向（模块路径均已对照 `v1.15.3` 核实存在）：

| # | 候选方向 | 主要代码位置 | 可做的测试 | 认领人 |
| --- | --- | --- | --- | --- |
| 1 | gang 调度语义与饥饿问题 | `pkg/scheduler/plugins/gang`、`actions/allocate` | 构造资源碎片，观察 PodGroup 长期 Pending | 待认领 |
| 2 | 队列公平性与权重 | `plugins/proportion`、`plugins/capacity` | 多队列按 weight 竞争，测实际分配比 | 待认领 |
| 3 | 主导资源公平（DRF / HDRF） | `plugins/drf` | 异构资源需求下的份额分配 | 待认领 |
| 4 | 装箱与碎片 | `plugins/binpack`、`plugins/nodeorder` | 对比 binpack 开关下的资源利用率 | 待认领 |
| 5 | 抢占机制 | `actions/preempt`、`plugins/priority` | 高优作业抢占低优作业的时延与正确性 | 待认领 |
| 6 | 资源回收机制 | `actions/reclaim`、`plugins/capacity` | 队列内回收的触发条件与行为 | 待认领 |
| 7 | 作业生命周期控制器 | `pkg/controllers/` | vcjob 各阶段策略（`--`）的能力与边界 | 待认领 |
| 8 | 准入校验 | `pkg/webhooks/admission/` | 构造非法 PodGroup / Queue，看是否被正确拒绝 | 待认领 |
| 9 | 不可调度作业缓存 | `pkg/scheduler/unschedulable/` | 缓存命中与唤醒的正确性、性能收益 | 待认领 |
| 10 | 调度性能与规模 | `pkg/scheduler/cache`、`benchmark/` | 大量 Pod 下的调度吞吐与时延 | 待认领 |
| 11 | 拓扑感知调度 | `plugins/task-topology`、`plugins/network-topology-aware` | 拓扑约束是否被严格遵守 | 待认领 |
| 12 | 可观测性 | `pkg/scheduler/metrics`、`installer/volcano-monitoring.yaml` | 指标是否足以定位一次调度失败 | 待认领 |
| 13 | 文档与代码一致性 | 全仓库 | 抽查 README / `docs/design/` 与实际代码是否一致 | 待认领 |

> ⚠️ 选题时注意：**默认只启用 3 个 Action 和 9 个插件**。
> 抢占、回收类选题必须自己改调度器配置，详见
> [docs/01-architecture.md §4](docs/01-architecture.md#4-默认调度配置v1153-实测核对值)。

---

## 报告索引

<!-- INDEX:BEGIN -->
<!-- 本区块由 scripts/build_index.py 自动生成，请勿手改。
     要改内容：编辑 reports/<你的名字>/meta.yml，然后重新运行脚本。 -->

> 暂无成员目录。
>
> 开始写报告：复制 `templates/report.md` 到 `reports/<你的名字>/report.md`，
> 写好 `reports/<你的名字>/meta.yml`，然后运行 `python3 scripts/build_index.py`。
> 具体步骤见 [CONTRIBUTING.md](CONTRIBUTING.md) §1。

<!-- INDEX:END -->

---

## 阶段里程碑

| 阶段 | 目标 | 完成标志 | 截止 |
| --- | --- | --- | --- |
| M0 环境就绪 | 所有人都能跑通 `setup-kind.sh smoke` | 每人贴一次 smoke 通过的环境快照 | 待定 |
| M1 定题 | 选题矩阵填满，无重复无空缺 | 本页「认领人」列无「待认领」 | 待定 |
| M2 代码分析 | 各人完成报告第 2 章 + 第 3 章（测试设计） | 提 PR 并通过评审 | 待定 |
| M3 实验执行 | 各人完成报告第 4 章，实验记录齐全 | 实验记录数量 ≥ 计划数 | 待定 |
| M4 定稿 | 各人报告通过评审，状态改为「已完成」 | 索引表全部为「已完成」 | 待定 |
| M5 汇总 | `reports/00-汇总.md` 完成 | 含横向对比表与组级结论 | 待定 |

---

## 目录结构

```
volcano-analysis/
├── README.md              # 本文件（索引表由脚本生成，勿手改）
├── CONTRIBUTING.md        # 协作规范 —— 新人先读这个
├── baseline.md            # 版本与环境基线（冻结后改动需 ADR）
├── docs/                  # 共享章节，只写一遍，个人报告引用
│   ├── 01-architecture.md
│   ├── 02-scheduling-flow.md
│   ├── glossary.md
│   └── adr/               # 口径决策记录
├── templates/             # 报告 / 实验 / 缺陷 三种模板
├── reports/
│   ├── 00-汇总.md         # 组级汇总（收尾阶段）
│   ├── _example/          # 示例，不参与索引（下划线开头会被跳过）
│   └── <组员>/            # 每人一个目录，只有本人能改
│       ├── meta.yml       # 索引数据来源
│       ├── report.md      # 主报告
│       ├── experiments/   # 一次实验一份记录
│       └── assets/        # 导出的图
├── scripts/               # 共享脚本
│   ├── build_index.py     # 生成本页索引表（--check 只校验不写文件）
│   ├── fetch-baseline.sh  # 拉取 v1.15.3 基线源码
│   └── setup-kind.sh      # 建集群 + 部署 Volcano
├── data/MANIFEST.md       # 大文件登记表（>5MB 的文件不进 git）
└── .github/               # CODEOWNERS / PR 与 issue 模板
```

---

## 常见问题

**我能直接 push 到 `main` 吗？**
不能。见 [CONTRIBUTING.md](CONTRIBUTING.md) §0 铁律 3。请开分支提 PR。

**我的实验失败了，还要记吗？**
要，而且很重要。失败的实验和排查过程是报告里的加分项。见
[templates/experiment.md](templates/experiment.md) 第 6 节。

**我要测的 Action 默认没启用怎么办？**
改调度器配置，然后在实验记录里**贴出改动后的完整配置**。默认值见
[docs/01-architecture.md §4](docs/01-architecture.md#4-默认调度配置v1153-实测核对值)。

**我想改 `docs/` 里的共享章节可以吗？**
可以，但要走 PR 并 @ 组长，因为改它会影响所有人的报告。

**老师要求交 Word / PDF 怎么办？**
Markdown 始终是唯一真相源。定稿时用 pandoc 转换，例如：

```bash
pandoc reports/<名字>/report.md -o report.docx --toc
```

如果要求每份报告自包含（包含架构、术语等共享章节），用 `--include-before-body`
把 `docs/` 的内容拼进去，**不要靠复制粘贴**。

**能不能把 Volcano 源码直接提交到本仓库？**
不能。源码有自己的仓库，用 [scripts/fetch-baseline.sh](scripts/fetch-baseline.sh) 在本地获取。

**发现分歧（比如指标怎么算）怎么办？**
写 ADR，模板在 [docs/adr/0000-template.md](docs/adr/0000-template.md)。
