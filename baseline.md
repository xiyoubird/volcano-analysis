# 基线锁定（Baseline）

> **这是一份会被反复引用的文件。冻结之后，任何改动都要写 ADR（放 `docs/adr/`）并在组会上说明。**
>
> 原因很直接：如果张三在 K8s 1.31 上测、李四在 1.35 上测、王五跟着 `master` 跑，
> 三个人的数据放在同一张表里是**没有意义的**，汇总报告也会被一眼看穿。

---

## 1. 分析对象

| 项 | 值 |
| --- | --- |
| 上游仓库 | https://github.com/volcano-sh/volcano |
| 代码基线 | tag **`v1.15.3`** |
| **commit SHA** | **`d2dd7024f4af3070f9d99d68a78973893908a743`** |
| 发布日期 | 2026-09-30 |
| License | Apache-2.0 |
| 项目定位 | CNCF incubating 项目，Kubernetes 原生批调度系统 |
| 本组代码 fork | https://github.com/xiyoubird/volcano （**只放代码 / 补丁 / 测试用例，不放报告**） |
| 本地代码路径（参考） | `~/learn/volcano` |
| 冻结日期 | 2026-10-05 |

选 `v1.15.3` 而不是 `master` 的理由：它是撰写本仓库时上游最新的**正式 release**（非 pre-release）。
跟着 `master` 跑意味着你下个月重跑同一个实验可能得到不同结果，结论无法被第三方复现。

---

## 2. 怎么拿到完全一致的代码

```bash
git clone https://github.com/volcano-sh/volcano.git volcano
cd volcano
git fetch --tags --all
git checkout d2dd7024f4af3070f9d99d68a78973893908a743

# 自检：必须打印 d2dd7024f4af3070f9d99d68a78973893908a743
git rev-parse HEAD
```

或者用仓库里的脚本：

```bash
bash scripts/fetch-baseline.sh          # 默认 clone 到 ~/learn/volcano
bash scripts/fetch-baseline.sh /tmp/vol # 或者指定路径
```

**每份实验记录里都要贴一次 `git rev-parse HEAD` 的输出。** 这是复现的锚点。

---

## 3. 运行环境

每个人**必须**按下表配置，并在自己的报告里填上"我的实际值"这一列。
没有填的，评审时直接打回。

| 项 | 本组规定值 | 我的实际值 |
| --- | --- | --- |
| Kubernetes 版本 | **1.27.16 —— 见 §3.1 / [ADR-0005](docs/adr/0005-k8s-127-baseline.md)** | 待填 |
| 集群创建方式 | `kind`（`scripts/setup-kind.sh`），kind v0.31.0 | 待填 |
| Volcano 部署方式 | 源码内 Helm chart：`installer/helm/chart/volcano` | 待填 |
| Volcano chart version | `1.15.3` | 待填 |
| Volcano 镜像 tag | `v1.15.3` | 待填 |
| 节点数量 / 规格 | 1 控制面 + 2 工作节点（kind 默认容器规格，实验记录里写实际 CPU/内存） | 待填 |
| 是否有 GPU | 无（本组不涉及 GPU 相关结论；有 GPU 的同学在报告里单独说明） | 待填 |
| 主机平台 | macOS / arm64（Apple Silicon）—— 镜像为 **arm64 原生**，见 §3.2 | 待填 |
| Go 版本（仅当你要改代码） | 见 `volcano/go.mod` 的 `go` 指令（v1.15.3 为 `go 1.25.0`） | 待填 |

> 集群名：默认 `volcano-lab`。**本机若该名字已被别的集群占用，用 `CLUSTER_NAME=volcano-lab-127`**，
> 不要为了腾名字去删别人的集群（`scripts/setup-kind.sh` 会拦住并提示）。
> ⚠️ 改版本（1.32 → 1.27）后，**旧的 1.32 集群要自己删掉**再重建，否则脚本会拦住，
> 而"脚本写 1.27、实际跑 1.32"会让实验记录里的环境快照互相矛盾：`bash scripts/setup-kind.sh down`。

### 3.1 Kubernetes 版本

上游 `v1.15.3` 的 README 兼容性矩阵标注：**Volcano v1.15 与 Kubernetes 1.23 – 1.35 完全兼容**
（1.21 / 1.22 标为 `-`，即 Volcano 用不到这些版本的特性）。其中 `Volcano v1.15` 行的
`Kubernetes 1.27` 列是 `✓`（本地基线源码 `~/learn/volcano/README.md:183-186`）。

**本组统一使用：`1.27.16`**（节点镜像 `kindest/node:v1.27.16`）。

- 版本由 `1.32.0` 改为 `1.27.16` 的理由、备选方案与代价（kubectl / client-go 两个方向的
  版本 skew）见 [ADR-0005](docs/adr/0005-k8s-127-baseline.md)；镜像加速与同名撞车保护见
  [ADR-0004](docs/adr/0004-kind-k8s-132-mirror.md)（**其 K8s 版本条款已被 ADR-0005 取代，其余结论仍有效**）。
- 为什么钉 `1.27.16` 而不是 `1.27.0`：kind 官方节点镜像的 1.27 线**只有 8 个 tag**
  （`.0 / .1 / .2 / .3 / .10 / .11 / .13 / .16`，均含 arm64），`.16` 是该线最后一个补丁。
- **实测证据（A 级）**：2026-10-05 在 macOS 15.6 / Apple Silicon 上按本基线**重建**环境：
  `kubectl version` 报 `Server Version: v1.27.16`；三个节点均为 `v1.27.16 / arm64 /
  containerd 1.7.18 / Debian 12 (bookworm)`；Volcano v1.15.3 三个组件 `1/1 Running`；
  `scripts/setup-kind.sh smoke` 的两个 Pod 由 volcano 调度成功并跑完（vcjob `Completed`）。
  完整原始输出：[docs/adr/0005-evidence-kind-127.log](docs/adr/0005-evidence-kind-127.log)。
- ⚠️ 本机 `kubectl` 是 `v1.35.3`，比集群新 8 个小版本，**超出官方 ±1 的 skew 范围**。
  本组用到的 `get / describe / logs / apply / rollout status` 实测正常；
  遇到诡异报错时先怀疑它，再怀疑 Volcano。
- ⚠️ Volcano v1.15.3 的二进制用 `k8s.io/client-go v0.35.3` 编译（`~/learn/volcano/go.mod:40`），
  也比 1.27 的 API 新。上游矩阵说兼容（C 级证据），所以**每次实验前先跑一次 `smoke`**，
  用 A 级证据代替对矩阵的信任。


### 3.2 镜像

```
docker.io/volcanosh/vc-webhook-manager:v1.15.3
docker.io/volcanosh/vc-controller-manager:v1.15.3
docker.io/volcanosh/vc-scheduler:v1.15.3
```

✅ **已验证（2026-10-05，macOS 15.6 / Apple Silicon）**：三个镜像都有**原生 arm64 版本**，
不需要 emulation。节点内 `crictl inspecti` 的输出：

```
docker.io/volcanosh/vc-scheduler:v1.15.3           "architecture": "arm64"
docker.io/volcanosh/vc-controller-manager:v1.15.3  "architecture": "arm64"
docker.io/volcanosh/vc-webhook-manager:v1.15.3     "architecture": "arm64"
```

（三个节点 `architecture` 均为 arm64、kubelet `v1.27.16`、containerd `1.7.18`。）

⚠️ **拉取路径的实测结论（别想当然）**：

| 从哪拉 | registry-1.docker.io 直连 | 说明 |
| --- | --- | --- |
| macOS 宿主机（`docker` CLI / `curl`） | ❌ 超时（8s 无响应） | Docker Desktop 的 `registry-mirrors` 只对宿主机 dockerd 生效，守护进程拉取走镜像站，所以 `docker pull` 这类宿主侧操作仍可能受凭据/网络影响 |
| kind 节点里的 containerd | ✅ 通（HTTP 401 = 握手正常） | 节点在 Docker Desktop 的 VM 里，网络路径和宿主机不同 |

结论：**镜像加速不是本机跑通的必要条件**（实测三个镜像就是节点直连拉下来的），但它是
连不通 docker.io 的网络下的兜底，而且**配置必须写成节点那个 containerd 版本认的插件路径**：

- `kindest/node:v1.27.16` 里是 **containerd 1.7.18** → 路径 `io.containerd.grpc.v1.cri`
- containerd **2.x** 的节点镜像 → 路径 `io.containerd.cri.v1.images`

写错版本**不报错、静默失效**（第一次就是这么踩的：只写了 2.x 路径，在 containerd 1.x 上整段被忽略，
配置等于没写）。`scripts/setup-kind.sh` 现在**两条都写**，并自动在末尾补
`https://registry-1.docker.io` 回源。细节见 [ADR-0004](docs/adr/0004-kind-k8s-132-mirror.md)。

**本轮（K8s 1.27.16 重建）新增两条实测，供后来者估时间：**

- **最慢的一步是节点镜像，不是 Volcano**：`kindest/node:v1.27.16` 约 1.5GB，在**宿主机 dockerd**
  侧经 `registry-mirrors` 拉取，实测耗时约 **15 分钟**（这一步与 K8s 版本无关，纯粹是镜像大小 + 镜像站速度）。
- **Volcano 三个镜像仍由节点内 containerd 拉取**：事件里是
  `Successfully pulled image ... in 19.8s / 22.7s / 24.8s`，说明镜像加速在 1.27.16 节点上同样生效
  （节点 containerd **1.7.18** 认领的是 `io.containerd.grpc.v1.cri` 那条，两条都写的策略继续有效）。

### 3.3 本项目使用的工具链

| 工具 | 参考版本 | 检查命令 |
| --- | --- | --- |
| docker | 29.1.3（Docker Desktop） | `docker version` |
| kind | v0.31.0 | `kind version` |
| kubectl | v1.35.3 | `kubectl version --client` |
| helm | v4.1.3 | `helm version` |
| go | go 1.25.6（darwin/arm64；`go.mod` 要求 ≥ 1.25.0） | `go version` |

---

## 4. 冻结规则

- 冻结后，**不允许**任何人单方面把基线换成别的 tag / commit。
- 如果确实需要换（例如发现 v1.15.3 有个阻塞性 bug），流程是：
  1. 写一份 ADR，说明为什么换、换成什么、已完成的工作是否需要重做；
  2. 组会通过；
  3. 更新本文件 + 更新 `scripts/setup-kind.sh` 的镜像 tag；
  4. 全体在下次实验前重新搭建环境，并在自己的报告里更新"我的实际值"。

---

## 5. 变更记录

| 日期 | 改了什么 | 谁 | 对应 ADR |
| --- | --- | --- | --- |
| 2026-10-05 | 初始冻结：`v1.15.3` / `d2dd7024` | （填名字） | [0001](docs/adr/0001-pin-baseline-version.md) |
| 2026-10-05 | 环境口径落地：K8s 定为 `1.32.0`（kind v0.31.0）；确认三个镜像有原生 arm64；补节点内 containerd 镜像加速与同名撞车保护 | （填名字） | [0004](docs/adr/0004-kind-k8s-132-mirror.md) |
| 2026-10-05 | **K8s 版本由 `1.32.0` 改为 `1.27.16`**（kind 官方 1.27 线最后一个补丁）；删掉两个 1.32 旧集群并重建、复跑 smoke；镜像加速与同名撞车保护沿用 ADR-0004 | （填名字） | [0005](docs/adr/0005-k8s-127-baseline.md) |
|  |  |  |  |
