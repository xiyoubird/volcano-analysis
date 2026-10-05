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
| Kubernetes 版本 | **待定 —— 见 §3.1** | 待填 |
| 集群创建方式 | `kind`（`scripts/setup-kind.sh`） | 待填 |
| Volcano 部署方式 | 源码内 Helm chart：`installer/helm/chart/volcano` | 待填 |
| Volcano chart version | `1.15.3` | 待填 |
| Volcano 镜像 tag | `v1.15.3` | 待填 |
| 节点数量 / 规格 | 待定（CPU 核数、内存 GiB 必须写） | 待填 |
| 是否有 GPU | 待定 | 待填 |
| 主机平台 | 参考：macOS / arm64（Apple Silicon） | 待填 |
| Go 版本（仅当你要改代码） | 见 `volcano/go.mod` 的 `go` 指令 | 待填 |

### 3.1 Kubernetes 版本

上游 `v1.15.3` 的 README 兼容性矩阵标注：**Volcano v1.15 与 Kubernetes 1.23 – 1.35 完全兼容**
（1.21 / 1.22 标为 `-`，即 Volcano 用不到这些版本的特性）。

**本组统一使用：`待定`** —— 建议在 **1.31 / 1.32 / 1.33** 中选一个，理由是 kind 对这档版本支持成熟，
且足够新。定下来之后：
1. 把值写进这一行；
2. 把实际用的 kind 节点镜像写进 `scripts/setup-kind.sh` 的默认值；
3. 写一份 ADR 记录这个选择。

### 3.2 镜像

```
docker.io/volcanosh/vc-webhook-manager:v1.15.3
docker.io/volcanosh/vc-controller-manager:v1.15.3
docker.io/volcanosh/vc-scheduler:v1.15.3
```

⚠️ **待验证**：在 Apple Silicon（arm64）上这些镜像是否有原生 arm64 版本。
上游 README 称 YAML 安装方式"available for x86_64 and arm64"，但 `hack/local-up-volcano.sh`
明确标注"only available for x86_64 temporarily"，所以本组走 **kind + Helm** 路线。
**第一个搭好环境的人负责把结论写进 `docs/adr/`**（有则记"有"，没有则记"用 emulate 还是换机器"）。

### 3.3 本项目使用的工具链

| 工具 | 参考版本 | 检查命令 |
| --- | --- | --- |
| docker | 待填 | `docker version` |
| kind | 待填 | `kind version` |
| kubectl | 待填 | `kubectl version --client` |
| helm | 待填 | `helm version` |
| go | 待填 | `go version` |

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
|  |  |  |  |
