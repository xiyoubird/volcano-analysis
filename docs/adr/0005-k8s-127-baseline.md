# ADR-0005：实验集群的 K8s 版本由 1.32.0 改为 1.27.16

- **状态**：提议（等组会确认后转「已接受」）
- **日期**：2026-10-05
- **决策人**：（填名字 —— 执行改版并重跑环境的人）
- **参与讨论**：全组
- **影响范围**：所有人的环境搭建、实验记录里的「环境快照」、`baseline.md` §3。
  **本 ADR 只取代 [ADR-0004](0004-kind-k8s-132-mirror.md) 的「K8s 版本」条款**；该 ADR 关于
  节点内 containerd 镜像加速、同名撞车保护的结论**继续有效**。

## 背景

1. **版本要求变了**：`baseline.md` §3 原定 `K8s 1.32.0`（[ADR-0004](0004-kind-k8s-132-mirror.md)）。
   现在要求本组的实验集群统一到 **1.27**。按 `baseline.md` §4 的冻结规则，换版本不能私下改：
   必须写 ADR → 组会通过 → 更新 `baseline.md` + `scripts/setup-kind.sh` → 全体重搭环境。
2. **兼容性不是阻塞项**：上游兼容矩阵里，`Volcano v1.15` 与 `Kubernetes 1.27` 是 ✓
   （证据见下 §兼容性证据），所以 1.27 不是"换了就跑不起来"的版本，问题只剩**选哪个补丁**。
3. **补丁版本必须定死**：节点 kubelet 版本会写进每个人的实验记录，只写"1.27"等于没定。
   kind 官方节点镜像（`kindest/node`）的 1.27 线**只有 8 个 tag**：
   `1.27.0 / 1.27.1 / 1.27.2 / 1.27.3 / 1.27.10 / 1.27.11 / 1.27.13 / 1.27.16`（查询方式见证据）。
   → 1.27 线能钉的**最新补丁就是 1.27.16**。
4. **本机旧状态要一起清掉**：改版前本机有**两个** 1.32.0 集群（`volcano-lab`、`volcano-lab-132`），
   都装着 Volcano。脚本的同名撞车保护会拦住默认名重建，所以必须先删旧集群再建新的
   ——否则会出现"脚本写的是 1.27、实际跑的还是 1.32"，实验记录各写各的。

## 决策

**全组统一：kind v0.31.0 + Kubernetes `1.27.16`（节点镜像 `kindest/node:v1.27.16`）
+ 1 控制面 2 工作节点 + Volcano chart / 镜像 tag 均为 `v1.15.3`
+ 节点内 containerd 镜像加速（沿用 [ADR-0004](0004-kind-k8s-132-mirror.md) 的配置）。**

照着执行的三条：

- 建环境：`bash scripts/setup-kind.sh`（默认值已是这套）。
  ⚠️ **本机若还留着 1.32 的旧集群**，脚本会拦住并要求先删：
  `bash scripts/setup-kind.sh down`（同名旧集群）后重建。
- 集群名默认 `volcano-lab`；名字被别的项目占用时用
  `CLUSTER_NAME=volcano-lab-127 bash scripts/setup-kind.sh`，不要删别人的集群。
- 每份实验记录的「环境快照」里贴：`kind version`、`kubectl get nodes -o wide`
  （含 kubelet 版本与 arch）、`git -C ~/learn/volcano rev-parse HEAD`。

## 备选方案

| 方案 | 优点 | 缺点 | 为什么不选 |
| --- | --- | --- | --- |
| A. K8s **1.27.16**（选中） | 1.27 线最后一个补丁（含该线全部安全修复）；kind 官方镜像 **arm64 原生**、确认存在 | 比 1.32 少 5 个小版本的新特性；`kubectl v1.35.3` 超出 ±1 版本偏差 | — |
| B. K8s **1.27.0** | 与本仓库原先"钉 `.0` 补丁"（1.32.0）的写法一致 | 缺 1.27 线后续 15 个补丁的修复，且没有任何收益 | 同一个镜像源里 1.27.16 就是现成的最新补丁，没理由挑旧的 |
| C. 保留 1.32.0 不动 | 已有实测证据，零成本 | 不满足"改为 1.27"的要求 | — |
| D. 改成 1.27 但保留旧 1.32 集群 | 不删任何东西 | 旧集群继续占内存；实际环境与 `baseline.md` 口径不一致，最坏结果是两组数据混进同一张表 | 与环境口径唯一性冲突，代价远大于重建成本 |
| E. 1.27 + amd64 镜像 + emulation | 不用管 arm64 | 慢，且会污染性能类数据 | 1.27.16 有原生 arm64，没有理由引入 emulation |

## 理由

- **兼容性有 B/C 级证据**：本地基线源码 `~/learn/volcano/README.md` 第 186 行（`Volcano v1.15` 行）
  的 `Kubernetes 1.27` 列是 `✓`，即上游明确背书 1.15 与 1.27 兼容；不是靠推测。
- **补丁选择的证据是"查过镜像仓库"而不是"猜"**：宿主机直连 Docker Hub 在本机不可用，
  于是在 kind 节点里查 Docker Hub API，拿到 1.27 线全部 8 个 tag 及其架构
  （每个 tag 都含 `amd64` + `arm64`），其中 `v1.27.16`（2024-11-08）是最后一个。
- **已知代价 1 —— kubectl skew**：本机 `kubectl v1.35.3`，与 1.27 集群差 8 个小版本，
  超出官方"±1 个小版本"的支持范围。本组用到的 `get / describe / logs / apply / rollout status`
  已在本轮重建中实测可用（见 §验证证据），但**如果出现诡异报错，先怀疑 kubectl 版本偏新**，
  而不是先怀疑 Volcano。
- **已知代价 2 —— 客户端库 skew（本 ADR 最该在组会上讲清的风险）**：Volcano v1.15.3 的二进制
  是用 `k8s.io/client-go v0.35.3` 编译的（`~/learn/volcano/go.mod:40`），比 1.27 的 API 新 8 个小版本。
  上游矩阵说兼容，但**这是 C 级证据**；本组的对策是每次实验前先跑一遍 `smoke`，
  用 A 级证据（组件就绪 + 作业真被调度）代替对矩阵的信任。本轮已跑通（见 §验证证据）。
- **1.27 已过社区维护期**：本组只用它做代码分析，不承载生产负载，安全面风险可接受；
  这也是"选 1.27 线最后一个补丁"而不是 `.0` 的直接原因。
- **镜像加速沿用不重新决策**：ADR-0004 的结论与 K8s 版本无关，且脚本已按 containerd 两条插件路径
  都写的方式实现；1.27.16 节点里是 containerd 1.7.x，认领的是 `io.containerd.grpc.v1.cri` 那条（实测）。
- **牺牲了什么**：全体要重搭一次环境；改版前做过的实验记录（环境快照写的是 1.32.0）要么重跑、
  要么在报告里明确标注"环境已变更"。换来的是"口径唯一"——5 个人的数据能放进同一张表。

## 兼容性证据（B / C 级，改版前的静态核对）

```bash
# 上游兼容矩阵（本地基线源码，就是我们要分析的那个 commit）
sed -n '183,187p' ~/learn/volcano/README.md
#     | ... | Kubernetes 1.27 | ... |
#     | Volcano v1.15 | ✓（1.27 列） |
#     | Volcano v1.14 | ✓ |

# Volcano 二进制是用哪套 client-go 编的（skew 风险来源）
grep -n 'k8s.io/client-go ' ~/learn/volcano/go.mod      # → v0.35.3

# kind 为 1.27 提供哪些节点镜像（宿主机直连 Docker Hub 不通，改在 kind 节点里查）
docker exec <kind 节点> curl -sS "https://hub.docker.com/v2/repositories/kindest/node/tags?page_size=100&name=1.27"
#     → v1.27.16(2024-11-08) v1.27.13 v1.27.11 v1.27.10 v1.27.3 v1.27.2 v1.27.1 v1.27.0
#       每个 tag 的 images[] 里都有 amd64 与 arm64
```

## 验证证据（A 级，2026-10-05 重建后实测）

> 原始输出全文：同目录 [`0005-evidence-kind-127.log`](0005-evidence-kind-127.log)
> （含删旧集群 → 拉节点镜像 → 建集群 → 部署 Volcano → 冒烟 → 清理的全过程）。

```bash
# 1. 集群/节点版本、架构、运行时（三个节点一致）
kubectl get nodes -o wide
#   volcano-lab-control-plane  Ready  control-plane  2m46s  v1.27.16  172.19.0.4  ...  containerd://1.7.18
#   volcano-lab-worker         Ready  <none>         2m23s  v1.27.16  172.19.0.3  ...  containerd://1.7.18
#   volcano-lab-worker2        Ready  <none>         2m23s  v1.27.16  172.19.0.2  ...  containerd://1.7.18
#   architecture=arm64；OS=Debian GNU/Linux 12 (bookworm)；kernel 6.12.54-linuxkit

kubectl version
#   Server Version: v1.27.16
#   Warning: version difference between client (1.35) and server (1.27) exceeds the supported
#            minor version skew of +/-1        ← 这就是"已知代价 1"的原文，不是故障

# 2. Volcano v1.15.3 在 1.27.16 上就绪（这一步同时否掉"client-go 0.35 跑不动 1.27"的担心）
kubectl -n volcano-system get deploy
#   volcano-admission    1/1     volcano-controllers  1/1     volcano-scheduler  1/1

# 3. 冒烟：gang（minAvailable=2）满足，两个 Pod 由 volcano 调度并跑完
bash scripts/setup-kind.sh smoke
#   ==> 有两个 Pod 处于 Running —— 调度器工作正常 ✅
kubectl get pods -l volcano.sh/job-name=smoke-test-job -o wide
#   smoke-test-job-worker-0  1/1  Running  volcano-lab-worker2   （schedulerName=volcano）
#   smoke-test-job-worker-1  1/1  Running  volcano-lab-worker2   （schedulerName=volcano）
kubectl get vcjob smoke-test-job          # → state=Completed（两个 Pod 都跑完了）
#   PodGroup 实测名为 <作业名>-<Job UID>（如 podgroup-probe-368fbef0-…），不是作业名本身；
#   源码 pkg/controllers/job/job_controller_actions.go:64 generateRelatedPodGroupName()。
#   → 脚本里 `kubectl get podgroup smoke-test-job` 的排查提示是错的，已一并修正。

# 4. 节点内 containerd 版本 → 认领哪条镜像加速插件路径
docker exec volcano-lab-control-plane /usr/local/bin/containerd --version   # → v1.7.18
docker exec volcano-lab-control-plane grep -A2 'registry.mirrors' /etc/containerd/config.toml
#   → 1.7.18 生效的是 [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
#     endpoint = ["https://docker.m.daocloud.io", "https://docker.nju.edu.cn", "https://registry-1.docker.io"]

# 5. 三个 Volcano 镜像在 1.27 节点上仍是 arm64 原生（不需要 emulation）
docker exec volcano-lab-worker crictl inspecti docker.io/volcanosh/vc-controller-manager:v1.15.3 | grep architecture
#   → "architecture": "arm64"    （vc-scheduler / vc-webhook-manager 同样）
```

**实测耗时（供组会排期用）**：最慢的一步不是 Volcano，而是宿主机侧拉 `kindest/node:v1.27.16`
（约 1.5GB，经 `registry-mirrors` 约 **15 分钟**）；集群创建 + Helm 部署 + 冒烟合计约 **4 分钟**
（node 内拉三个 Volcano 镜像各 20–25s）。

## 后果

- **好的后果**：实验集群版本满足 1.27 的要求且补丁钉死在 1.27 线最后一个版本；本机两个旧 1.32
  集群与随之而来的口径混淆被清掉；`scripts/setup-kind.sh` 的默认值、错误提示、注释与
  `baseline.md` 重新对齐。
- **坏的后果 / 代价**：全体需要重搭环境（`down` + `up` 约十几分钟，主要是拉节点镜像）；
  改版前留下的实验记录需要重跑或标注；kubectl 与 client-go 两个方向都存在版本 skew，
  排查问题时多一层干扰项。
- **需要同步更新的文件**：`baseline.md` §3/§3.1/§3.2/§5（已更新）、`scripts/setup-kind.sh`（默认值、
  注释、撞车提示已更新；**冒烟排查提示也一并修正**：PodGroup 名是 `<作业名>-<Job UID>`，
  原写法 `kubectl get podgroup smoke-test-job` 必然 NotFound）、
  [ADR-0004](0004-kind-k8s-132-mirror.md) 加"版本条款被本 ADR 修订"的标注（已加）、
  `README.md` 的环境 FAQ（已加指向）、`docs/01-architecture.md` 的基线表（已更新）、
  各人实验记录的环境快照（每次自己贴；**改版前写的记录要重跑或在报告里标注**）。

## 复审条件

- 组会 / 老师另有版本要求（例如要求与某台真机集群对齐）；
- 实测发现 1.27 上有阻塞性问题（重点盯：client-go 0.35 与 1.27 apiserver 的兼容、
  新调度特性在旧 API 上不可用）；
- 选题需要 ≥1.28 才有的调度/API 特性；
- kind 不再提供 1.27 节点镜像（届时只能自建镜像或换版本）。
