# Volcano 项目理解报告 —— 小组协作仓库

> 课程：复旦大学《软件分析与测试》
> 作业：面向对象与开源项目分析（AI 辅助代码理解）
> 分析对象：**Volcano** `volcano-sh/volcano` @ `v1.15.3`
> 教师材料：[docs/elearn/](docs/elearn/)

| 我需要… | 去这里 |
| --- | --- |
| 搞清楚**老师到底要什么、怎么评分** | [docs/00-教师要求解读.md](docs/00-教师要求解读.md) ← **先读这个** |
| 知道怎么提交、怎么评审、分支怎么命名 | [CONTRIBUTING.md](CONTRIBUTING.md) |
| 挑一个模块认领 | [docs/01-architecture.md §3 / §3.1](docs/01-architecture.md) |
| 知道我们分析的是哪个版本、环境怎么定 | [baseline.md](baseline.md) |
| 看已经写了哪些报告、哪些模块没人认领 | 本页下面的 [报告索引](#报告索引) |
| 查术语 / 看整体架构 / 看调度流程 | [glossary](docs/glossary.md) · [架构](docs/01-architecture.md) · [调度流程](docs/02-scheduling-flow.md) |
| 组长专用：走流程、兜底、评审 | [docs/组长手册.md](docs/组长手册.md) |
| 搭实验环境 | [scripts/setup-kind.sh](scripts/setup-kind.sh) |
| 模板：报告 / 工作底稿 / 运行记录 / Issue 卡 | [templates/](templates/) |

---

## 组员

| 姓名 | 目录 | 角色 |
| --- | --- | --- |
| 李鹏飞 | [reports/lipengfei/](reports/lipengfei/) | **组长** —— 兜底全部未认领模块与必交成果 |
| 张又文 | [reports/zhangyouwen/](reports/zhangyouwen/) | 组员 |
| 童天宇 | [reports/tongtianyu/](reports/tongtianyu/) | 组员 |
| 谈宁远 | [reports/tanninyuan/](reports/tanninyuan/) | 组员 |
| 颜秉丽 | [reports/yanbingli/](reports/yanbingli/) | 组员 |

> 实际认领情况以下方 [报告索引](#报告索引) 为准（由 `meta.yml` 自动汇总，勿手改）。
>
> **交付形态**：目标是**每人一份独立报告**（5 份），各满足五件必交成果。
> 教师对"是否每人一份"的答复是"尽量"（软要求），执行口径见
> [ADR-0003](docs/adr/0003-report-granularity.md) —— 允许进度落后时降级，
> 但**"一条自己跑通的端到端调用链"和"一份自己的证据矩阵"不能省**，
> 因为答辩 5 问全是第一人称。

---

## 老师要什么（速览）

> 完整解读见 **[docs/00-教师要求解读.md](docs/00-教师要求解读.md)**。这里只放结论。

### 五件必交成果（缺一件扣对应分）

| # | 交付物 | 硬性要求 |
| --- | --- | --- |
| ① | 一页项目地图 | 根目录、核心包、配置、测试、入口 |
| ② | 一张领域对象图 | **≥5 个核心类型**，区分继承与关联 |
| ③ | 一张业务调用链图 | 端到端，**必须含失败路径** |
| ④ | 一张证据矩阵 | **≥8 个**重要判断及其证据（A/B/C/D 分级） |
| ⑤ | 一页 AI 使用反思 | ≥2 个 AI 帮助 + **≥1 个被代码纠正** |

### 评分量表（100 分）

| 维度 | 分值 | 高分特征 |
| --- | ---: | --- |
| 项目结构分析 | 15 | 地图准确，能解释阅读顺序 |
| 核心类与关系 | 15 | 关系类型准确，有代码证据 |
| 调用链分析 | 20 | 端到端、顺序清楚、包含失败路径 |
| 代码证据与验证 | 15 | 重要判断可追溯 |
| 测试理解 | 10 | 能从测试反推边界 |
| AI 使用方法 | 10 | 有验证、有纠错、有反思 |
| 图表与报告 | 15 | 结构清楚、可复用、表达专业 |

> 每份报告的骨架里都内置了这张**自查表**，提 PR 前自评低于 80 分不要提。

### 报告的 8 节结构

项目简介 → 项目地图 → 领域对象 → 业务调用链 → 测试与边界 →
代码证据与 AI 使用 → 维护观察 → 学习反思

骨架见 [templates/report.md](templates/report.md)，5 位组员的 `report.md` **已预建**。

### 一条贯穿全篇的纪律：AI 证据分级

| 等级 | 来源 | 原则 |
| --- | --- | --- |
| **A** | 实际运行 / 断点 / 自动测试 | 确认动态行为 |
| **B** | 当前仓库源码与配置 | 确认静态结构与实现细节 |
| **C** | 当前版本官方 README / 文档 | 确认使用方式 |
| **D** | AI 自然语言解释 | **仅作假设，必须核验** |

重要结论**至少要到 B 级**，涉及实际行为时**尽量升到 A 级**。
→ 所以每份报告都要真跑一次 Volcano，见 [快速开始](#快速开始)。

---

## 报告索引

<!-- INDEX:BEGIN -->
<!-- 本区块由 scripts/build_index.py 自动生成，请勿手改。
     要改内容：编辑 reports/<你的名字>/meta.yml，然后重新运行脚本。 -->

| 组员 | 主题 | 模块 | 状态 | 运行记录 | 最后更新 | 报告 |
| --- | --- | --- | --- | ---: | --- | --- |
| 李鹏飞 (@xiyoubird) | 待认领 —— 请从上表挑一个模块并写清你要回答的问题 | `—` | 规划中 | 0 | 2026-10-05 | [lipengfei](reports/lipengfei/report.md) |
| 谈宁远 | 待认领 —— 请从上表挑一个模块并写清你要回答的问题 | `—` | 规划中 | 0 | 2026-10-05 | [tanninyuan](reports/tanninyuan/report.md) |
| 童天宇 | 待认领 —— 请从上表挑一个模块并写清你要回答的问题 | `—` | 规划中 | 0 | 2026-10-05 | [tongtianyu](reports/tongtianyu/report.md) |
| 颜秉丽 | 待认领 —— 请从上表挑一个模块并写清你要回答的问题 | `—` | 规划中 | 0 | 2026-10-05 | [yanbingli](reports/yanbingli/report.md) |
| 张又文 | 待认领 —— 请从上表挑一个模块并写清你要回答的问题 | `—` | 规划中 | 0 | 2026-10-05 | [zhangyouwen](reports/zhangyouwen/report.md) |

共 5 人。状态说明：进行中 → 待评审 → 已完成；`规划中` 表示尚未开始。

**模块覆盖**：已认领 **0 / 21** 个模块。

未被认领的模块（组长兜底清单的来源）：`pkg/scheduler/`、`pkg/scheduler/actions/`、`pkg/scheduler/plugins/`、`pkg/scheduler/framework/`、`pkg/scheduler/cache/`、`pkg/scheduler/api/`、`pkg/scheduler/conf/`、`pkg/scheduler/metrics/`、`pkg/scheduler/unschedulable/`、`pkg/scheduler/gate/`、`pkg/controllers/`、`pkg/webhooks/admission/`、`pkg/cli/`、`pkg/agent/`、`pkg/agentscheduler/`、`pkg/networkqos/`、`pkg/metriccollect/`、`pkg/resourceusage/`、`pkg/kube/`、`pkg/util/`、`pkg/config/`、`pkg/features/`、`pkg/filewatcher/`、`pkg/signals/`、`pkg/version/`、`cmd/`、`installer/`、`test/e2e/`、`benchmark/`

<details><summary>展开完整覆盖情况</summary>

| 模块 | 认领人 |
| --- | --- |
| `pkg/scheduler/` | — |
| `pkg/scheduler/actions/` | — |
| `pkg/scheduler/plugins/` | — |
| `pkg/scheduler/framework/` | — |
| `pkg/scheduler/cache/` | — |
| `pkg/scheduler/api/` | — |
| `pkg/scheduler/conf/` | — |
| `pkg/scheduler/metrics/` | — |
| `pkg/scheduler/unschedulable/` | — |
| `pkg/scheduler/gate/` | — |
| `pkg/controllers/` | — |
| `pkg/webhooks/admission/` | — |
| `pkg/cli/` | — |
| `pkg/agent/`、`pkg/agentscheduler/` | — |
| `pkg/networkqos/` | — |
| `pkg/metriccollect/`、`pkg/resourceusage/` | — |
| `pkg/kube/`、`pkg/util/`、`pkg/config/`、`pkg/features/`、`pkg/filewatcher/`、`pkg/signals/`、`pkg/version/` | — |
| `cmd/` | — |
| `installer/` | — |
| `test/e2e/` | — |
| `benchmark/` | — |

</details>

<!-- INDEX:END -->

---

## 选一个模块认领

**完整模块清单与认领规则在 [docs/01-architecture.md §3 / §3.1](docs/01-architecture.md)。**

认领方式（**不要改共享表格**，5 个人同时改必然冲突）：

```bash
# 编辑你自己目录下的 meta.yml
vim reports/<你的名字>/meta.yml
#   title:  你要回答的具体问题
#   module: 从模块地图里挑，建议下沉到具体插件 / Action / 控制器
#   status: 规划中 → 进行中

python3 scripts/build_index.py    # 刷新本页索引与模块覆盖情况
```

**可重复认领**：同一个模块允许 2 个人做（交叉验证），但 `title` 必须写清各自的角度。

### 推荐切入点

下面是 13 个已经落地的方向（模块路径均已对照 `v1.15.3` 核实存在）。
它们比目录名更好下手，**但没有限制** —— 你也可以从模块地图里自选。

| # | 方向 | 主要代码位置 | 可能的可验证问题 |
| --- | --- | --- | --- |
| 1 | gang 调度与饥饿 | `pkg/scheduler/plugins/gang`、`actions/allocate` | 资源碎片下为何出现 PodGroup 长期 Pending |
| 2 | 队列公平性 | `plugins/proportion`、`plugins/capacity` | 多队列按 weight 竞争时实际分配比是否偏离 |
| 3 | 主导资源公平 | `plugins/drf` | 异构资源需求下的份额如何计算 |
| 4 | 装箱与碎片 | `plugins/binpack`、`plugins/nodeorder` | 开关 binpack 对利用率的影响 |
| 5 | 抢占 | `actions/preempt`、`plugins/priority` | 高优作业抢占的触发条件与延迟 |
| 6 | 资源回收 | `actions/reclaim` | 与 preempt 的边界（最易混淆点） |
| 7 | 作业生命周期控制器 | `pkg/controllers/` | vcjob 各阶段策略的边界行为 |
| 8 | 准入校验 | `pkg/webhooks/admission/` | 非法 PodGroup / Queue 是否被正确拒绝 |
| 9 | 不可调度作业缓存 | `pkg/scheduler/unschedulable/` | 缓存命中与唤醒的正确性 |
| 10 | 调度性能与规模 | `pkg/scheduler/cache`、`benchmark/` | 大量 Pod 下的调度时延与吞吐 |
| 11 | 拓扑感知调度 | `plugins/task-topology`、`network-topology-aware` | 拓扑约束是否被严格遵守 |
| 12 | 可观测性 | `pkg/scheduler/metrics` | 指标是否足以定位一次调度失败 |
| 13 | 文档与代码一致性 | 全仓库 | README / `docs/design/` 与实际代码的出入 |

> ⚠️ **默认只启用 3 个 Action 和 9 个插件**。抢占、回收类选题必须自己改调度器配置，
> 否则你测的是"什么都没发生"。详见
> [docs/01-architecture.md §4](docs/01-architecture.md#4-默认调度配置v1153-实测核对值)。

---

## 快速开始

```bash
git clone <本仓库地址> && cd volcano-analysis

# 1. 搭环境（第一次约 10 分钟）
bash scripts/fetch-baseline.sh          # 拉取 Volcano v1.15.3 基线源码
bash scripts/setup-kind.sh              # 建 kind 集群 + 部署 Volcano
bash scripts/setup-kind.sh smoke        # 冒烟测试：确认真跑起来了一个作业

# 2. 认领模块（改你自己目录下的 meta.yml，见上一节）
vim reports/<你的名字>/meta.yml

# 3. 边做边填工作底稿（对应教材附录 B 的五张表）
cp templates/workbook.md reports/<你的名字>/workbook.md

# 4. 跑一次真实调用链，留下 A 级证据
cp templates/experiment.md reports/<你的名字>/experiments/001-<主题>.md

# 5. 写报告（骨架已预建，按 8 节填）
vim reports/<你的名字>/report.md

# 6. 刷新索引，提 PR
python3 scripts/build_index.py
```

---

## 阶段里程碑

对齐教材的 8 个实训单元：

| 阶段 | 对应实训 | 目标 | 完成标志 |
| --- | --- | --- | --- |
| M0 环境就绪 | — | 全员能跑通 smoke | 每人贴一次环境快照 |
| M1 定题 | — | 全员认领模块（分析对象**已确认 ✅**）；补问评分口径 | 索引表无 `待认领`；[ADR-0003](docs/adr/0003-report-granularity.md) 的残留问题得到答复 |
| M2 结构分析 | 实训 1–3 | 报告 §1 项目简介、§2 项目地图、§3 领域对象 | 交付物 ①② 完成 |
| M3 动态行为 | 实训 4 | 报告 §4 调用链（成功 + **失败**路径） | 交付物 ③ 完成，且含 ≥2 条 A 级证据 |
| M4 验证与维护 | 实训 5–7 | 报告 §5 测试与边界、§6 证据与 AI、§7 维护观察 | 交付物 ④⑤ 完成 |
| M5 定稿 | 综合实训 | 报告 §8 学习反思；自评 ≥80；通过评审 | 索引表全部「已完成」 |
| M6 汇总 | — | [reports/00-汇总.md](reports/00-汇总.md) 横向对比 | 含组级结论与问题清单 |

---

## 两个仓库怎么分工

| 仓库 | 放什么 | 可见性 |
| --- | --- | --- |
| [xiyoubird/volcano](https://github.com/xiyoubird/volcano) | 上游 fork。**只放代码、补丁、测试用例**；`master` 保持与上游一致 | 只能是 public |
| **本仓库** | 报告、工作底稿、运行记录、共享文档、脚本。组员加成 Collaborator，走分支 + PR | 建议 **private** |

**为什么不把报告写进 Volcano 的 fork：**

1. **可见性改不了。** GitHub 规定 fork 的可见性跟随上游，Volcano 是公开仓库，
   所以 fork 只能是 public，**无法单独设为 private**（[官方文档](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/what-happens-to-forks-when-a-repository-is-deleted-or-changes-visibility)）。
2. **fork 网络共享 Git 数据。** 上游所有者可读取网络内所有 fork 的内容，
   即使 fork 被删除，数据仍可能从网络内其他仓库访问到。
3. **基线会被污染。** fork 的 `master` 现在正好等于 `upstream/master`，是最干净的基线；
   报告提交一旦落上去，就再也不能 `merge --ff-only` 同步上游。
4. **太重。** 完整 clone 约 160MB，同学为了写文档不该拉一整个 Go 仓库。

---

## 目录结构

```
volcano-analysis/
├── README.md                    # 本文件（索引与覆盖情况由脚本生成，勿手改）
├── CONTRIBUTING.md              # 协作规范 —— 新人先读
├── baseline.md                  # 版本与环境基线（冻结后改动需 ADR）
├── docs/
│   ├── 00-教师要求解读.md        # ★老师要什么、怎么评分、Java→Go 映射
│   ├── 01-architecture.md       # 共享：模块地图（选题清单）+ 认领规则 + 默认调度配置
│   ├── 02-scheduling-flow.md    # 共享：调度流程
│   ├── glossary.md              # 共享：术语表
│   ├── 组长手册.md               # 组长：流程演练 + 兜底清单 + 评审 SOP
│   ├── elearn/                  # 老师的原始材料（PDF，勿改）
│   └── adr/                     # 口径决策记录
├── templates/
│   ├── report.md                # ★报告骨架（对齐老师 8 节 + 评分自查）
│   ├── workbook.md              # ★工作底稿（教材附录 B 的五张表）
│   ├── experiment.md            # 运行验证记录（产生 A 级证据）
│   ├── issue-card.md            # Issue 分析卡（报告 §7）
│   └── bug.md                   # 缺陷记录
├── reports/
│   ├── 00-汇总.md               # 组级汇总（收尾阶段）
│   ├── _example/                # 示例，不参与索引
│   └── <组员>/                   # 每人一个目录，只有本人能改
│       ├── meta.yml             # 认领信息（索引与覆盖统计的数据源）
│       ├── report.md            # 主报告（骨架已预建）
│       ├── workbook.md          # 工作底稿（自己从 templates 复制）
│       ├── experiments/         # 运行验证记录 / 缺陷 / Issue 卡
│       └── assets/              # 导出的图
├── scripts/
│   ├── build_index.py           # 生成索引 + 模块覆盖；--check 只校验
│   ├── check-unbraced-vars.sh   # 自查：变量后面别直接跟中文（bash 3.2 会报 unbound variable）
│   ├── fetch-baseline.sh        # 拉取 v1.15.3 基线源码
│   └── setup-kind.sh            # 建集群 + 部署 + smoke
├── data/MANIFEST.md             # 大文件登记表（>5MB 不进 git）
└── .github/                     # CODEOWNERS / PR 与 issue 模板
```

---

## 常见问题

**老师说报告要自包含，那共享 `docs/` 还有意义吗？**
有，但规则要改。**图必须各自画** —— 项目地图、领域对象图、调用链图都要自己走一遍，
因为评分和答辩考的是"你从哪里知道"（答辩第 2、3、5 问）。共享的 `docs/` 只提供
**术语口径、模块清单、决策记录**，不提供可以直接抄进报告的成品。
5 个人的图长得像甚至一样是正常的（分析同一个项目），但你必须能解释每一笔。

**我能直接 push 到 `main` 吗？**
不能。见 [CONTRIBUTING.md](CONTRIBUTING.md) §0 铁律 3。

**我的运行验证失败了，还要记吗？**
要。失败的记录和排查过程是报告里的加分项，也是 §7 维护观察的素材。

**我要测的 Action 默认没启用怎么办？**
改调度器配置，然后在运行记录里**贴出改动后的完整配置**。默认值见
[docs/01-architecture.md §4](docs/01-architecture.md#4-默认调度配置v1153-实测核对值)。

**跑脚本报 `unbound variable`（例如 `CLUSTER_NAME?: unbound variable`）怎么办？**
这不是环境坏了，是**脚本写法**撞上了 macOS 自带的老 bash：`/bin/bash` 是 3.2.57，
在 UTF-8 locale（`LANG=zh_CN.UTF-8` 等）下会把变量名**后面紧跟的中文/全角符号**
当成变量名的一部分，于是 `$VAR（` 被解析成 `${VAR（}`，配合 `set -u` 直接退出。
仓库里的脚本已改好（变量一律写 `${VAR}`）；你自己新写脚本时跑
`bash scripts/check-unbraced-vars.sh` 自查。应急替代：`LC_ALL=C bash scripts/setup-kind.sh`。

**`describe pod` 里看到 ImagePullBackOff，或拉取报 EOF 怎么办？**
kind **节点里的 containerd** 和宿主机 Docker 的镜像配置是两套东西（Docker Desktop 的
`registry-mirrors` 管不到节点）。`scripts/setup-kind.sh` 默认给节点配了镜像加速
（`REGISTRY_MIRRORS`，末尾自动补 `registry-1.docker.io` 回源）。如果镜像站的 CDN 抽风
（实测 daocloud 对个别镜像稳定 EOF），关掉它直连重建即可：

```bash
REGISTRY_MIRRORS= bash scripts/setup-kind.sh down
REGISTRY_MIRRORS= bash scripts/setup-kind.sh
```

> 配置写在**节点**里，所以要重建集群才生效，改 Pod 没用。取舍与实测数据见
> [ADR-0004](docs/adr/0004-kind-k8s-132-mirror.md)（其 K8s 版本条款已被
> [ADR-0005](docs/adr/0005-k8s-127-baseline.md) 取代，其余结论仍有效）。

**实验集群用哪个 K8s 版本？**
统一 **`1.27.16`**（节点镜像 `kindest/node:v1.27.16`），由
[ADR-0005](docs/adr/0005-k8s-127-baseline.md) 定；依据是上游兼容矩阵里
`Volcano v1.15` × `Kubernetes 1.27` = ✓，且 `1.27.16` 是 kind 官方 1.27 线最后一个补丁。
⚠️ 版本从 1.32.0 改过来，**本机旧的 1.32 集群要先 `down` 掉再重建**，
否则 `scripts/setup-kind.sh` 的同名撞车保护会拦住你 —— 那是保护，不是 bug。

**发现分歧（指标怎么算、用哪个 K8s 版本）怎么办？**
写 ADR，模板在 [docs/adr/0000-template.md](docs/adr/0000-template.md)。

**能不能把 Volcano 源码提交到本仓库？**
不能。用 [scripts/fetch-baseline.sh](scripts/fetch-baseline.sh) 在本地获取。
