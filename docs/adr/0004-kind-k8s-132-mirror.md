# ADR-0004：实验集群定为 kind + K8s 1.32.0（arm64 原生镜像 + 节点内镜像加速）

> ⚠️ **本 ADR 的「K8s 版本」条款已被 [ADR-0005](0005-k8s-127-baseline.md) 修订：
> 实验集群版本现为 `1.27.16`（`kindest/node:v1.27.16`），不再是 `1.32.0`。**
> 本文其余结论——**节点内 containerd 镜像加速的两条插件路径、回源兜底的能力边界、
> 同名撞车保护、"宿主机直连 vs 节点内直连"的实测差异**——**继续有效**，
> 阅读时把文中的 `kindest/node:v1.32.0` 替换成 `kindest/node:v1.27.16` 即可
> （两者都是 containerd 1.x，认领同一条插件路径）。

- **状态**：提议 → **部分被 [ADR-0005](0005-k8s-127-baseline.md) 取代（仅 K8s 版本条款）**
- **日期**：2026-10-05
- **决策人**：（填名字 —— 跑通环境的人）
- **参与讨论**：全组
- **影响范围**：所有人的环境搭建、实验记录里的「环境快照」、`baseline.md` §3

## 背景

`baseline.md` §3.1 把 K8s 版本留成 `待定`，§3.2 留了一个问题：「Apple Silicon（arm64）上这些镜像是否有原生 arm64 版本」。这两个空档不填，5 个人的实验数据就没法横向比较。

2026-10-05 在 macOS 15.6 / Apple Silicon 上把 `scripts/setup-kind.sh` 真跑了一遍（证据见下），过程中暴露出 3 件必须固化成口径的事：

1. **K8s 版本必须定死**：节点 kubelet 版本会写进每个人的实验记录，不定就是各测各的。
2. **镜像加速要配，但说法要精确**：宿主机直连 `registry-1.docker.io` 8 秒无响应；而 Docker Desktop 的 `registry-mirrors` 只对宿主机 dockerd 生效，**管不到 kind 节点里的 containerd**。不过实测**节点内直连 docker.io 是通的**（HTTP 401），所以加速站是「更快 + 给连不通的网络兜底」，不是本机跑通的必要条件。真正必须做对的是**配置的插件路径要匹配节点里的 containerd 版本，否则静默失效**（第一次就踩了：只写了 containerd 2.x 的路径，而 `kindest/node:v1.32.0` 里是 1.7.24，整段被忽略、配置等于没写，好在节点直连能拉所以没暴露）。
3. **kind 集群名是全机器共享的**：本机已存在一个 5 天前建的同名 `volcano-lab`（k8s 1.20.15，别的项目）。默认同名会把 Volcano 装到 1.20 上（超出上游兼容矩阵 1.23–1.35，基线直接失效），而且 `down` 会把那个集群删掉。

## 决策

**全组统一：kind v0.31.0 + K8s 1.32.0（节点镜像 `kindest/node:v1.32.0`）+ 1 控制面 2 工作节点 + Volcano chart/tag 均为 v1.15.3，并在 kind 配置里给节点内 containerd 配 docker.io 镜像加速。**

照着执行的三条：

- 建环境：`bash scripts/setup-kind.sh`（默认值已是这套，默认带 `REGISTRY_MIRRORS=https://docker.m.daocloud.io,https://docker.nju.edu.cn`，并在末尾自动补 `https://registry-1.docker.io` 回源）。
- 集群名默认 `volcano-lab`；**本机若该名字已被别的集群占用，用 `CLUSTER_NAME=volcano-lab-132`**，不要删别人的集群（脚本会拦住并给出这两条建议）。
- 每份实验记录的「环境快照」里贴：`kind version`、`kubectl get nodes`（含 kubelet 版本与 arch）、`git -C ~/learn/volcano rev-parse HEAD`。

## 备选方案

| 方案 | 优点 | 缺点 | 为什么不选 |
| --- | --- | --- | --- |
| A. K8s **1.32.0** + kind v0.31.0（选中） | 落在上游兼容矩阵 1.23–1.35 中段；kind 支持成熟；**已实测跑通**，arm64 原生 | 比 1.33/1.34 少几个新特性 | — |
| B. K8s 1.31 / 1.33 | 同样在兼容区间内 | 没有任何实测证据 | 换版本收益为零，成本是全体重搭环境 |
| C. 完全不配镜像加速 | 配置最少 | 连不通 docker.io 的网络会 ImagePullBackOff；本机节点虽能直连，但那是运气（VM 网络路径好） | 零成本兜底没理由不要，且末尾有回源、不会更差 |
| D. amd64 镜像 + Rosetta / emulation | 不用管 arm64 | 慢，且会直接污染性能类数据 | 本组有「调度性能与规模」方向，emulation 会让这类结论不可信 |

## 理由

- **选「验证过的」而不是「更新的」**：1.32.0 是本次全流程跑通、smoke 调度成功的版本。符合本仓库「一条结论追一条证据」的纪律。
- **arm64 原生已证实**：三个镜像在节点内 `crictl inspecti` 都报 `architecture: arm64`，这直接消掉 §3.2 的 ⚠️——**不需要 emulation**。
- **镜像加速：配，但要把话说准**。实测数据是「宿主机直连超时、节点内直连正常」，所以它在本机不是必需项；它的价值是给连不通 docker.io 的网络兜底。**真正的坑是版本**：`kindest/node:v1.32.0` 用 containerd **1.7.24**（路径 `io.containerd.grpc.v1.cri`），containerd **2.x** 的节点镜像改用 `io.containerd.cri.v1.images`；写错的那条会被**静默忽略**（不报错、不告警，只是不生效）。因此脚本两条都写——已分别用 containerd 1.7.24 与 2.2.0 执行 `config dump` 验证：两边都不报错，且各自认领自己那条。
- **回源兜底的能力边界（实测）**：末尾补 `registry-1.docker.io` 只能覆盖「镜像站接入点不可达」；**覆盖不了「镜像站给了 manifest、但它的 CDN 下载失败」**——blob URL 是镜像站给的绝对地址，containerd 不会改回源站。实测 `alpine:3.21` 在 daocloud 的 CDN（`image-mirror.r2.daocloud.vip`）上稳定 `EOF`（连试 3 次），而同一节点直连 docker.io 正常。所以脚本注释里写明了逃生口：`REGISTRY_MIRRORS= bash scripts/setup-kind.sh down` 再重建即回到直连。
- **牺牲了什么**：配置多了一段（两条路径），且多了一个对第三方镜像站的依赖。镜像站出问题时最坏情况是「某个镜像拉不下来」，此时按上面的逃生口关掉即可；已经把镜像拉下来的集群不受影响。

## 验证证据（2026-10-05，macOS 15.6 / Apple Silicon / arm64）

```bash
# 1. 两条网络路径不一样（这是本 ADR 最容易被想当然的地方）
curl -sS --max-time 8 -o /dev/null -w 'http=%{http_code}\n' https://registry-1.docker.io/v2/
#    宿主机 → curl: (28) Connection timed out，http=000
docker exec volcano-lab-132-worker2 curl -sS --max-time 8 -o /dev/null \
  -w 'http=%{http_code}\n' https://registry-1.docker.io/v2/
#    节点内 → http=401（握手正常，说明节点直连 docker.io 是通的）

# 2. 节点里到底是哪个 containerd + 配置有没有被认领
docker exec volcano-lab-132-worker2 /usr/local/bin/containerd --version   # → v1.7.24
docker exec volcano-lab-132-worker2 grep -A2 'registry.mirrors' /etc/containerd/config.toml
#    → [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
#        endpoint = ["https://docker.m.daocloud.io", "https://docker.nju.edu.cn", "https://registry-1.docker.io"]
#    （两条路径的配置段都写进去了；1.7.24 认领 1.x 那条）

# 3. 镜像站真的在干活（不是「配置写了但没生效」）
docker exec <node> sh -c 'echo "127.0.0.1 registry-1.docker.io" >> /etc/hosts'   # 把源站黑洞掉
docker exec <node> crictl pull docker.io/library/alpine:3.21
#    → 报错信息里的 URL 是 https://docker.m.daocloud.io/... → 请求确实打到了镜像站（源站已被黑洞）
#    → 但 blob 下载在 daocloud 的 CDN 上 EOF（连试 3 次都 EOF，恢复源站后同样 EOF）
#    结论：配置生效 ✓；回源只覆盖接入点不可达，覆盖不了 CDN 层失败 ✗

# 4. 重新按最终配置整集群重建 + 部署 + 冒烟（脚本原文，无手工步骤）
CLUSTER_NAME=volcano-lab-132 bash scripts/setup-kind.sh down
CLUSTER_NAME=volcano-lab-132 bash scripts/setup-kind.sh
#    → 三个 Pod 全 1/1 Running；事件里三个镜像均 Successfully pulled
#      （vc-controller-manager 26MB / vc-webhook-manager 44MB / vc-scheduler 31MB）
bash scripts/setup-kind.sh smoke
#    → 有两个 Pod 处于 Running —— 调度器工作正常 ✅
#    （冒烟用的 busybox:1.36 是 kind 节点镜像自带的，不依赖网络/镜像站）

# 5. arm64 原生（回答 baseline.md §3.2）
docker exec volcano-lab-132-worker2 crictl inspecti docker.io/volcanosh/vc-scheduler:v1.15.3 \
  | grep architecture
#    → "architecture": "arm64"   （vc-webhook-manager / vc-controller-manager 同样）
kubectl get nodes -o custom-columns='NAME:.metadata.name,ARCH:.status.nodeInfo.architecture,KUBELET:.status.nodeInfo.kubeletVersion'
#    → 三个节点均 arm64 / v1.32.0
```

> 原始日志属于「A 级证据」，按 `CONTRIBUTING.md` §4 由**跑的人**放进自己的
> `reports/<名字>/experiments/00X-*.log`，并写明对应证据矩阵第几条。本 ADR 只固化口径。

## 后果

- **好的后果**：环境口径唯一、可复现；arm64 原生（性能类实验不被 emulation 污染）；连不通 docker.io 的网络也能拉到镜像（且有回源兜底）；同名撞车不会再悄悄把 Volcano 装到错误的 K8s 版本上。
- **坏的后果 / 代价**：依赖第三方镜像站（有回源，最坏是变慢）；脚本比脚手架版本复杂了（多了镜像加速生成与同名撞车保护两块逻辑）；1.32.0 这个选择以后升级要全体重搭。
- **需要同步更新的文件**：`baseline.md` §3.1/§3.2/§3.3（已更新）、`scripts/setup-kind.sh`（已更新）、各人实验记录的环境快照（每次自己贴）。

## 复审条件

- 上游兼容矩阵下限抬高到 1.32 以上，或 1.33+ 出现本组选题必需的调度特性；
- 镜像站长期不可用，或改用内网 registry（`REGISTRY_MIRRORS` 换成内网地址即可，其余不变）；
- kind 不再为 1.32 提供节点镜像。
