#!/usr/bin/env bash
#
# 静态自查：禁止「变量后面紧跟非 ASCII 字符」的写法，变量一律加花括号 ${VAR}。
#
#   用法：bash scripts/check-unbraced-vars.sh
#   退出码：0 = 干净；1 = 有需要修的地方（输出 文件:行号:原文）
#
# 为什么要有这个检查（本项目真实踩过的坑，不是理论风险）：
#   macOS 自带 /bin/bash 是 3.2.57。在 UTF-8 locale（LANG=zh_CN.UTF-8 / LC_ALL=en_US.UTF-8）
#   下，bash 3.2 会把变量名后面那个多字节字符的字节当成变量名的一部分，于是
#       step "创建集群 $CLUSTER_NAME（K8s ...）"
#   被解析成 ${CLUSTER_NAME（}，配合脚本开头的 set -u 报错并直接退出：
#       scripts/setup-kind.sh: line 78: CLUSTER_NAME?: unbound variable
#   同一个脚本在 LC_ALL=C 下却能正常跑完 —— 这就是它难查的原因。
#   修法只有一句：写成 ${CLUSTER_NAME}。

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"
SELF="$SELF_DIR/$(basename "${BASH_SOURCE[0]}")"

# LC_ALL=C 让 grep 按字节匹配：[^ -~] = 不在 0x20..0x7E 之间的任意字节（含中文/全角符号）
PATTERN='\$[A-Za-z_][A-Za-z0-9_]*[^ -~]'

hits=0
while IFS= read -r f; do
  [ "$f" = "$SELF" ] && continue          # 本文件注释里就有反面示例，跳过自检
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s\n' "${f#"$ROOT"/}:$line"
    hits=$((hits + 1))
  done < <(LC_ALL=C grep -nE "$PATTERN" "$f" || true)
done < <(find "$ROOT" -type f -name '*.sh' ! -path '*/.git/*' | LC_ALL=C sort)

echo
if [ "$hits" -gt 0 ]; then
  echo "[x] 发现 ${hits} 处：变量后面直接跟了多字节字符。" >&2
  echo "    在 macOS 自带的 bash 3.2 + UTF-8 locale 下会报 unbound variable 并退出。" >&2
  echo "    修法：给变量加花括号，例如改成 \${VAR}。" >&2
  exit 1
fi

echo "[√] 检查通过：scripts 下没有「变量紧跟多字节字符」的写法。"
