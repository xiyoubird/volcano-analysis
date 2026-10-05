#!/usr/bin/env bash
#
# 拉取并检出本组锁定的 Volcano 基线版本。
#
#   用法：bash scripts/fetch-baseline.sh [目标目录]
#   默认目标目录：$HOME/learn/volcano
#
# 这个脚本存在的唯一目的：让所有人手里的源码是**字节一致**的。
# 报告里的每一个文件路径和行号，都只在基线 commit 上有效。

set -euo pipefail

BASELINE_TAG="v1.15.3"
BASELINE_COMMIT="d2dd7024f4af3070f9d99d68a78973893908a743"
UPSTREAM_URL="https://github.com/volcano-sh/volcano.git"
DEST="${1:-$HOME/learn/volcano}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "没有找到 git，请先安装。"

if [ -d "$DEST/.git" ]; then
  info "目标已存在且是 git 仓库：$DEST"
  cd "$DEST"
  info "从 upstream 拉取 tag 与提交（可能有几秒延迟）..."
  if ! git fetch --tags "$UPSTREAM_URL" 2>/dev/null; then
    warn "从 $UPSTREAM_URL 拉取失败，尝试使用已有的 origin/upstream 远端。"
    git fetch --tags || warn "拉取失败，将使用本地已有的对象。"
  fi
elif [ -e "$DEST" ]; then
  die "$DEST 已存在但不是 git 仓库。请换一个目标目录，或先自行处理该路径。"
else
  info "浅克隆到 $DEST ..."
  mkdir -p "$(dirname "$DEST")"
  # 先只拉基线 tag 附近的历史，省时间；后面如果要做 git log 分析再自行 unshallow
  git clone --filter=blob:none --no-checkout "$UPSTREAM_URL" "$DEST"
  cd "$DEST"
  git fetch --tags origin
fi

info "检出基线 commit ..."
if git cat-file -e "${BASELINE_COMMIT}^{commit}" 2>/dev/null; then
  git checkout --detach "$BASELINE_COMMIT"
else
  warn "本地没有 $BASELINE_COMMIT，尝试按 tag $BASELINE_TAG 检出。"
  git checkout --detach "$BASELINE_TAG"
fi

HEAD_SHA="$(git rev-parse HEAD)"
echo
if [ "$HEAD_SHA" = "$BASELINE_COMMIT" ]; then
  info "基线校验通过 ✅"
else
  die "基线校验失败！期望 $BASELINE_COMMIT，实际 $HEAD_SHA。
     请不要继续做实验 —— 你的结果和别人的不可比。"
fi

cat <<EOF

当前状态
  目录      : $DEST
  HEAD      : $HEAD_SHA
  tag       : $BASELINE_TAG
  检出方式  : detached HEAD（这是故意的，防止你误提交到基线）

下一步
  1. 把下面这行贴进你的实验记录「环境快照」一节：
       $HEAD_SHA
  2. 搭建集群：bash scripts/setup-kind.sh
  3. 如果你想改代码做实验，请在**自己的 fork** 上开分支，不要在这里提交：
       git remote add mine git@github.com:<你的用户名>/volcano.git
       git switch -c test/<你的名字>/<主题>

EOF
