#!/usr/bin/env bash
#
# 用 kind + Helm 搭一套本组统一的 Volcano 实验环境。
#
#   用法：
#     bash scripts/setup-kind.sh            # 建集群 + 部署 Volcano
#     bash scripts/setup-kind.sh status     # 查看当前状态
#     bash scripts/setup-kind.sh smoke      # 冒烟测试：真跑一个 VolcanoJob
#     bash scripts/setup-kind.sh down       # 删除集群
#
#   可覆盖的环境变量：
#     CLUSTER_NAME=volcano-lab      kind 集群名
#     K8S_VERSION=1.27.16           Kubernetes 版本（→ kindest/node:v${K8S_VERSION}）
#     WORKERS=2                     工作节点数量
#     VOLCANO_SRC=$HOME/learn/volcano   Volcano 源码目录（必须是基线 commit）
#     REGISTRY_MIRRORS=...          kind 节点里 containerd 的镜像加速站（逗号分隔）
#                                   默认 daocloud + 南大；置空则不加加速配置。
#                                   末尾会自动补 registry-1.docker.io 回源兜底。
#
# ✅ 状态说明：2026-10-05 已在 macOS 15.6 / Apple Silicon（arm64）上真跑通：
#    kind v0.31.0 + K8s 1.27.16（1 控制面 + 2 工作节点）→ Volcano v1.15.3 三个 Pod 全
#    1/1 Running → smoke 冒烟测试两个 Pod 由 volcano 调度成功。
#    节点实测：arm64 / kubelet v1.27.16 / containerd 1.7.18 / Debian 12 (bookworm)。
#    口径与证据见 docs/adr/0005-k8s-127-baseline.md（K8s 版本，取代 ADR-0004 的 1.32.0）
#    与 docs/adr/0004-kind-k8s-132-mirror.md（镜像加速），实测值已回填 baseline.md §3。
#
#    跑通路上踩到的三个坑（都已在脚本里处理，别再踩）：
#      1. 变量后面紧跟中文 → macOS 自带 bash 3.2 报 unbound variable（见下方 ⚠️）；
#      2. kind 节点里的 containerd **不读** Docker Desktop 的 registry-mirrors（那套只管
#         宿主机 dockerd），要让节点走镜像站只能这么配。本机实测节点内直连
#         registry-1.docker.io 是通的（HTTP 401 = 握手正常），所以加速站是"更快/更稳"，
#         不是"必须"——但对连不通 docker.io 的网络它是救命的。镜像站抽风时用
#         `REGISTRY_MIRRORS= bash scripts/setup-kind.sh down` 关掉直连；
#      3. kind 集群名是全机器共享的 → 本机若已有同名集群（例如别的项目留下的 k8s 1.20
#         集群，或改版本前留下的 1.32 集群），脚本会拦住并要求换名字/先删掉，
#         不会把 Volcano 装到错误的 K8s 版本上。
#
# ⚠️ 本文件里的变量一律写成 ${VAR}（带花括号），不要让 $VAR 直接跟中文/全角符号。
#    原因（已实测）：macOS 自带 /bin/bash 是 3.2.57，在 UTF-8 locale（LANG=zh_CN.UTF-8、
#    LC_ALL=en_US.UTF-8 等）下，bash 3.2 会把变量名后面那个多字节字符当成变量名的一部分，
#    于是 `$VAR` 后面紧跟「（」时被解析成 ${VAR（}，报：
#        scripts/setup-kind.sh: line 78: CLUSTER_NAME?: unbound variable
#    再被 `set -u` 放大成整个脚本退出。同样的代码在 LC_ALL=C 下却能跑通，所以极难查。
#    静态自查：bash scripts/check-unbraced-vars.sh

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-volcano-lab}"
K8S_VERSION="${K8S_VERSION:-1.27.16}"
WORKERS="${WORKERS:-2}"
VOLCANO_SRC="${VOLCANO_SRC:-$HOME/learn/volcano}"
REGISTRY_MIRRORS="${REGISTRY_MIRRORS:-https://docker.m.daocloud.io,https://docker.nju.edu.cn}"
REGISTRY_FALLBACK="${REGISTRY_FALLBACK:-https://registry-1.docker.io}"

# 为什么要把镜像站写进 kind 配置（实测坑）：
#   Docker Desktop 的 registry-mirrors 只对宿主机 dockerd 生效，**管不到 kind 节点里的 containerd**，
#   所以要让节点走镜像站，只能通过 containerdConfigPatches 写进节点配置。
#   ⚠️ 插件路径随 containerd 版本变：kindest/node:v1.27.16 里是 containerd **1.7.18**，路径为
#   io.containerd.grpc.v1.cri；更新的 node 镜像（containerd 2.x）改成了 io.containerd.cri.v1.images。
#   两条都写，谁的版本认哪条就用哪条（已分别用 containerd 1.7.24 / 2.2.0 的 `config dump` 验证：
#   两边都不报错，各自认领自己那条）。写错的那条**不报错、静默失效**——所以必须两条都有。
#   末尾补 registry-1.docker.io 回源：镜像站的接入点不可达时还能直连。
#   ⚠️ 回源只覆盖「接入点不可达」，**覆盖不了「镜像站给了 manifest、但它的 CDN 下载失败」**：
#   实测 alpine:3.21 在 daocloud 的 CDN（image-mirror.r2.daocloud.vip）上稳定 EOF，此时
#   containerd 不会改用源站（blob URL 是镜像站给的绝对地址）。
#   遇到 EOF / 拉取卡住就把镜像站关掉重来（注意要在建集群时就改，配在节点里）：
#       REGISTRY_MIRRORS= bash scripts/setup-kind.sh down && REGISTRY_MIRRORS= bash scripts/setup-kind.sh
CONTAINERD_ENDPOINTS=""
_seen=","
for _mirror in ${REGISTRY_MIRRORS//,/ } ${REGISTRY_FALLBACK//,/ }; do
  [ -n "$_mirror" ] || continue
  case "$_seen" in *",${_mirror},"*) continue;; esac
  _seen="${_seen}${_mirror},"
  if [ -n "$CONTAINERD_ENDPOINTS" ]; then CONTAINERD_ENDPOINTS="${CONTAINERD_ENDPOINTS}, "; fi
  CONTAINERD_ENDPOINTS="${CONTAINERD_ENDPOINTS}\"${_mirror}\""
done
unset _mirror _seen

BASELINE_COMMIT="d2dd7024f4af3070f9d99d68a78973893908a743"
BASELINE_TAG="v1.15.3"
IMAGE_TAG="v1.15.3"
CHART_PATH="$VOLCANO_SRC/installer/helm/chart/volcano"
NODE_IMAGE="kindest/node:v${K8S_VERSION}"
NS="volcano-system"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\n\033[1;36m── %s\033[0m\n' "$*"; }

require_tools() {
  local missing=()
  for c in docker kind kubectl helm; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    die "缺少工具：${missing[*]}
     macOS 安装方式：brew install kind kubectl helm
     docker 请安装 Docker Desktop 并确保已启动。"
  fi
  docker info >/dev/null 2>&1 || die "docker 没有在运行，请先启动 Docker Desktop。"
}

verify_baseline_src() {
  [ -d "$VOLCANO_SRC/.git" ] || die "找不到 Volcano 源码：$VOLCANO_SRC
    先运行：bash scripts/fetch-baseline.sh $VOLCANO_SRC"
  local head_sha
  head_sha="$(git -C "$VOLCANO_SRC" rev-parse HEAD)"
  if [ "$head_sha" != "$BASELINE_COMMIT" ]; then
    die "源码不是基线版本！
    期望 $BASELINE_COMMIT ($BASELINE_TAG)
    实际 $head_sha
    修正：bash scripts/fetch-baseline.sh $VOLCANO_SRC"
  fi
  [ -d "$CHART_PATH" ] || die "找不到 Helm chart：$CHART_PATH"
  info "基线源码校验通过：$head_sha"
}

cluster_exists() {
  kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"
}

# 已有集群的节点镜像（去重，一行一个）。用来识别"同名但不是本脚本建的"集群。
cluster_node_images() {
  docker ps -a \
    --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}" \
    --format '{{.Image}}' 2>/dev/null | LC_ALL=C sort -u
}

cmd_up() {
  require_tools
  verify_baseline_src

  step "1/4 创建 kind 集群 ${CLUSTER_NAME}（K8s ${K8S_VERSION}，1 控制面 + ${WORKERS} 工作节点）"
  if [ -n "$CONTAINERD_ENDPOINTS" ]; then
    info "节点内 containerd 镜像加速：${CONTAINERD_ENDPOINTS}"
  else
    warn "REGISTRY_MIRRORS 为空：节点直接访问 registry-1.docker.io（连不通的网络会 ImagePullBackOff）。"
  fi
  if cluster_exists; then
    # 同名撞车保护：kind 集群名是全机器共享的。如果已有同名集群不是本脚本建的
    # （节点镜像对不上，比如别的项目留着的 k8s 1.20 集群，或本仓库改版本前留下的
    # 1.32 集群），继续跑会把 Volcano 装到错误的 K8s 版本上（基线失效），
    # 而 `down` 又会把别人的集群直接删掉。
    local existing_images
    existing_images="$(cluster_node_images | tr '\n' ' ')"
    existing_images="${existing_images% }"
    if [ "$existing_images" != "$NODE_IMAGE" ]; then
      die "集群 ${CLUSTER_NAME} 已存在，但节点镜像不是 ${NODE_IMAGE}
     实际：${existing_images:-（查不到节点容器）}
     这个集群不是当前参数（K8S_VERSION=${K8S_VERSION}）建的：要么是别的项目占了这个名字，
     要么是本仓库改版本前留下的旧址。二选一：
       1) 换个集群名继续（不动老集群）：
            CLUSTER_NAME=volcano-lab-127 bash scripts/setup-kind.sh
       2) 确认老集群可以删（删了就没了）：
            bash scripts/setup-kind.sh down && bash scripts/setup-kind.sh"
    fi
    warn "集群 $CLUSTER_NAME 已存在，跳过创建。"
    warn "想重建请先执行：bash scripts/setup-kind.sh down"
  else
    local cfg
    cfg="$(mktemp -t kind-volcano-XXXXXX.yaml)"
    {
      echo "kind: Cluster"
      echo "apiVersion: kind.x-k8s.io/v1alpha4"
      echo "nodes:"
      echo "- role: control-plane"
      for _ in $(seq 1 "$WORKERS"); do echo "- role: worker"; done
      if [ -n "$CONTAINERD_ENDPOINTS" ]; then
        echo "containerdConfigPatches:"
        echo "  - |-"
        # containerd 1.x（kindest/node:v1.27.16 就是这档）
        echo "    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"]"
        echo "      endpoint = [${CONTAINERD_ENDPOINTS}]"
        # containerd 2.x（插件被拆成 io.containerd.cri.v1.images）
        echo "    [plugins.\"io.containerd.cri.v1.images\".registry.mirrors.\"docker.io\"]"
        echo "      endpoint = [${CONTAINERD_ENDPOINTS}]"
      fi
    } >"$cfg"
    kind create cluster --name "$CLUSTER_NAME" --image "$NODE_IMAGE" --config "$cfg"
    rm -f "$cfg"
  fi

  step "2/4 准备 Helm chart 依赖"
  kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null
  if [ ! -d "$CHART_PATH/charts" ]; then
    info "chart 依赖未就绪，执行 helm dependency build ..."
    helm dependency build "$CHART_PATH"
  else
    info "chart 依赖已就绪。"
  fi

  step "3/4 部署 Volcano（chart ${IMAGE_TAG} / 镜像 tag ${IMAGE_TAG}）"
  helm upgrade --install volcano "$CHART_PATH" \
    --namespace "$NS" --create-namespace \
    --set basic.image_tag_version="$IMAGE_TAG" \
    --wait --timeout 10m

  step "4/4 等待组件就绪"
  for d in volcano-scheduler volcano-controllers volcano-admission; do
    info "等待 deploy/$d ..."
    kubectl -n "$NS" rollout status "deploy/$d" --timeout=300s
  done

  cmd_status
  cat <<EOF

环境就绪。接下来：

  1. 把下面这些值填进 baseline.md 的「我的实际值」一列：
       K8s 版本        : $K8S_VERSION
       kind 节点镜像   : $NODE_IMAGE
       Volcano 镜像 tag: $IMAGE_TAG
       Volcano commit  : $BASELINE_COMMIT

  2. 跑一次冒烟测试，确认调度器真的在工作：
       bash scripts/setup-kind.sh smoke

  3. 开始你的实验前，先读默认调度器配置 —— 很多 Action 默认是关的：
       kubectl -n $NS get cm volcano-scheduler-configmap -o yaml

  4. 用完释放资源（kind 集群会一直占内存）：
       bash scripts/setup-kind.sh down

EOF
}

cmd_status() {
  step "集群状态"
  kind get clusters 2>/dev/null || true
  echo
  step "节点"
  kubectl get nodes -o wide || true
  echo
  step "Volcano 组件"
  if kubectl get ns "$NS" >/dev/null 2>&1; then
    kubectl -n "$NS" get deploy,pod -o wide || true
    echo
    info "正在使用的镜像："
    kubectl -n "$NS" get deploy -o jsonpath='{range .items[*]}{"  "}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}' || true
  else
    warn "命名空间 $NS 不存在，Volcano 尚未部署。"
  fi
}

cmd_smoke() {
  require_tools
  step "冒烟测试：建一个队列 + 提交一个 VolcanoJob"

  kubectl apply -f - <<'EOF'
apiVersion: scheduling.volcano.sh/v1beta1
kind: Queue
metadata:
  name: smoke-test
spec:
  weight: 1
  capability:
    cpu: "2"
    memory: 2Gi
---
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: smoke-test-job
spec:
  minAvailable: 2
  schedulerName: volcano
  queue: smoke-test
  tasks:
    - replicas: 2
      name: worker
      template:
        spec:
          containers:
            - name: worker
              image: busybox:1.36
              command: ["sh", "-c", "echo smoke-ok && sleep 20"]
              resources:
                requests:
                  cpu: 100m
                  memory: 64Mi
              imagePullPolicy: IfNotPresent
          restartPolicy: Never
EOF

  info "等待 Job 状态（最多 120s）..."
  local deadline=$((SECONDS + 120))
  while [ $SECONDS -lt $deadline ]; do
    local running
    running="$(kubectl get pods -l volcano.sh/job-name=smoke-test-job \
      --no-headers 2>/dev/null | grep -c Running || true)"
    if [ "${running:-0}" -ge 2 ]; then
      info "有两个 Pod 处于 Running —— 调度器工作正常 ✅"
      break
    fi
    sleep 5
  done

  kubectl get pods -l volcano.sh/job-name=smoke-test-job -o wide || true
  echo
  cat <<'EOF'
清理冒烟测试资源：

  kubectl delete vcjob smoke-test-job      # 注意是 vcjob（Volcano 的 Job），不是原生 job
  kubectl delete queue smoke-test

如果 Pod 一直 Pending，按顺序排查：
  1. kubectl -n volcano-system logs deploy/volcano-scheduler --tail=100
  2. kubectl get podgroups.scheduling.volcano.sh -A -o wide   # 看 phase / conditions
     ⚠️ 别用 `kubectl get podgroup smoke-test-job`：PodGroup 的名字是
        「<作业名>-<Job 的 UID>」，不是作业名本身
        （源码 pkg/controllers/job/job_controller_actions.go:64 generateRelatedPodGroupName，
         实测 1.27.16 集群上 PodGroup 名为 podgroup-probe-368fbef0-…），按作业名查一定 NotFound。
  3. kubectl describe pod <pending-pod>                  # 看 Events
  4. 确认 Pod 的 spec.schedulerName 是 volcano（不是 default-scheduler）
     —— 如果写成默认调度器，那这次测试根本没经过 Volcano，结论是假的。
EOF
}

cmd_down() {
  require_tools
  if cluster_exists; then
    info "删除 kind 集群 $CLUSTER_NAME ..."
    kind delete cluster --name "$CLUSTER_NAME"
    info "已删除。"
  else
    warn "集群 $CLUSTER_NAME 不存在，无需删除。"
  fi
}

case "${1:-up}" in
  up)     cmd_up ;;
  status) cmd_status ;;
  smoke)  cmd_smoke ;;
  down)   cmd_down ;;
  *)      die "未知子命令：$1（可用：up / status / smoke / down）" ;;
esac
