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
#     K8S_VERSION=1.32.0            Kubernetes 版本（→ kindest/node:v$K8S_VERSION）
#     WORKERS=2                     工作节点数量
#     VOLCANO_SRC=$HOME/learn/volcano   Volcano 源码目录（必须是基线 commit）
#
# ⚠️ 状态说明：本脚本由脚手架生成，**尚未在真实机器上跑通验证**。
#    第一个跑通的人请负责：
#      1. 把实际使用的 K8s 版本写进 baseline.md §3.1，并补一份 ADR；
#      2. 如果 arm64（Apple Silicon）上镜像拉取或调度有问题，把结论写进 docs/adr/；
#      3. 把本脚本跑通后遇到的坑补成注释，方便后面的人。

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-volcano-lab}"
K8S_VERSION="${K8S_VERSION:-1.32.0}"
WORKERS="${WORKERS:-2}"
VOLCANO_SRC="${VOLCANO_SRC:-$HOME/learn/volcano}"

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

cmd_up() {
  require_tools
  verify_baseline_src

  step "1/4 创建 kind 集群 $CLUSTER_NAME（K8s $K8S_VERSION，1 控制面 + $WORKERS 工作节点）"
  if cluster_exists; then
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

  step "3/4 部署 Volcano（chart $IMAGE_TAG / 镜像 tag $IMAGE_TAG）"
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

  kubectl delete job smoke-test-job
  kubectl delete queue smoke-test

如果 Pod 一直 Pending，按顺序排查：
  1. kubectl -n volcano-system logs deploy/volcano-scheduler --tail=100
  2. kubectl get podgroup smoke-test-job -o yaml        # 看 phase / conditions
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
