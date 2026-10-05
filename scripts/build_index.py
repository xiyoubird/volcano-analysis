#!/usr/bin/env python3
"""扫描 reports/*/meta.yml，重新生成根 README.md 里的报告索引表与模块覆盖情况。

用法：
    python3 scripts/build_index.py            # 更新 README.md
    python3 scripts/build_index.py --check    # 只检查是否最新（CI / 组长自查用），不写文件

设计约束：
  * 只用标准库（组员机器上不一定有 PyYAML）
  * meta.yml 只支持「扁平的 key: value」，不支持嵌套、列表、多行
  * 只认下面这些字段，其余字段会被忽略（不报错，方便以后扩展）
        name / github / title / module / status / updated
  * 以 _ 或 . 开头的目录会被跳过（例如 reports/_example/）
  * 模块覆盖情况由 docs/01-architecture.md §3 的「代码模块地图」推导；
    那张表的格式被改动后，覆盖统计会自动跳过（不会报错）
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPORTS_DIR = ROOT / "reports"
README = ROOT / "README.md"
ARCH_DOC = ROOT / "docs" / "01-architecture.md"

BEGIN_MARK = "<!-- INDEX:BEGIN -->"
END_MARK = "<!-- INDEX:END -->"

REQUIRED_FIELDS = ("name", "title", "status")
ALLOWED_STATUS = ("规划中", "进行中", "待评审", "已完成")
STATUS_ORDER = {"进行中": 0, "待评审": 1, "规划中": 2, "已完成": 3}

# 单个文件超过这个大小就提醒（和 .gitignore / CONTRIBUTING.md 里的 5MB 规则一致）
MAX_TRACKED_BYTES = 5 * 1024 * 1024

BACKTICK = re.compile(r"`([^`]+)`")


def parse_flat_yaml(path: Path) -> dict[str, str]:
    """解析只有 key: value 的极简 YAML。解析不了的行走 stderr 警告。"""
    data: dict[str, str] = {}
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            print(f"  ! {path}:{lineno} 不是 key: value 格式，已忽略：{line!r}", file=sys.stderr)
            continue
        key, _, value = line.partition(":")
        data[key.strip()] = value.strip().strip('"').strip("'")
    return data


def collect_entries() -> tuple[list[dict[str, str]], list[str]]:
    """返回 (条目列表, 问题列表)。"""
    entries: list[dict[str, str]] = []
    problems: list[str] = []

    if not REPORTS_DIR.is_dir():
        return entries, [f"找不到目录 {REPORTS_DIR}"]

    for member_dir in sorted(REPORTS_DIR.iterdir()):
        if not member_dir.is_dir() or member_dir.name.startswith(("_", ".")):
            continue

        meta_path = member_dir / "meta.yml"
        rel = member_dir.relative_to(ROOT)
        if not meta_path.is_file():
            problems.append(f"{rel}/ 缺少 meta.yml（这个目录不会出现在索引里）")
            continue

        meta = parse_flat_yaml(meta_path)
        missing = [f for f in REQUIRED_FIELDS if not meta.get(f)]
        if missing:
            problems.append(f"{rel}/meta.yml 缺少必填字段：{', '.join(missing)}")
            continue

        status = meta["status"]
        if status not in ALLOWED_STATUS:
            problems.append(
                f"{rel}/meta.yml 的 status={status!r} 不是允许值，"
                f"只能是：{' / '.join(ALLOWED_STATUS)}"
            )
            status = "规划中"

        report_path = member_dir / "report.md"
        if not report_path.is_file():
            problems.append(f"{rel}/ 缺少 report.md")

        exp_dir = member_dir / "experiments"
        exp_count = (
            len([p for p in exp_dir.glob("*.md") if p.name.lower() != "readme.md"])
            if exp_dir.is_dir()
            else 0
        )

        entries.append(
            {
                "dir": member_dir.name,
                "name": meta.get("name", member_dir.name),
                "github": meta.get("github", ""),
                "title": meta.get("title", ""),
                "module": meta.get("module", ""),
                "status": status,
                "updated": meta.get("updated", "—"),
                "experiments": str(exp_count),
                "report_link": f"{rel}/report.md",
            }
        )

    entries.sort(key=lambda e: (STATUS_ORDER.get(e["status"], 9), e["dir"]))
    return entries, problems


def parse_module_map() -> list[tuple[str, list[str]]]:
    """从 docs/01-architecture.md §3 读出模块清单。

    返回 [(显示名, [模块前缀, ...]), ...]；解析不到就返回空列表。
    """
    if not ARCH_DOC.is_file():
        return []
    rows: list[tuple[str, list[str]]] = []
    for line in ARCH_DOC.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        cells = line.split("|")
        # "| a | b | c |" -> ['', ' a ', ' b ', ' c ', '']
        if len(cells) != 5 or not cells[1].strip().startswith("`"):
            continue
        tokens = [t.rstrip("/") for t in BACKTICK.findall(cells[1])]
        if tokens:
            rows.append((cells[1].strip(), tokens))
    return rows


def match_module(module: str, rows: list[tuple[str, list[str]]]) -> int | None:
    """把认领的 module 归到模块地图的某一行（最长前缀匹配）。"""
    if not module:
        return None
    best, best_len = None, -1
    for i, (_, tokens) in enumerate(rows):
        for t in tokens:
            if (module == t or module.startswith(t + "/")) and len(t) > best_len:
                best, best_len = i, len(t)
    return best


def render_coverage(
    entries: list[dict[str, str]], rows: list[tuple[str, list[str]]]
) -> list[str]:
    if not rows:
        return []

    claimers: dict[int, list[str]] = {}
    unmatched: list[str] = []
    for e in entries:
        idx = match_module(e["module"], rows)
        if idx is None:
            if e["module"]:
                unmatched.append(f"{e['name']}（`{e['module']}`）")
            continue
        claimers.setdefault(idx, []).append(e["name"])

    lines = [f"**模块覆盖**：已认领 **{len(claimers)} / {len(rows)}** 个模块。", ""]

    missing = [
        tok
        for i, (_, tokens) in enumerate(rows)
        if i not in claimers
        for tok in tokens
    ]
    if missing:
        lines += [
            "未被认领的模块（组长兜底清单的来源）："
            + "、".join(f"`{t}/`" for t in missing),
            "",
        ]
    else:
        lines += ["所有模块都已被认领。", ""]

    if unmatched:
        lines += [
            "⚠️ 以下认领的 `module` 不在模块地图里（可能是笔误，或是一个更细的子模块）："
            + "、".join(unmatched),
            "",
        ]

    lines += ["<details><summary>展开完整覆盖情况</summary>", ""]
    lines += ["| 模块 | 认领人 |", "| --- | --- |"]
    for i, (name, _) in enumerate(rows):
        who = "、".join(claimers.get(i, [])) or "—"
        lines.append(f"| {name} | {who} |")
    lines += ["", "</details>", ""]
    return lines


def esc(text: str) -> str:
    """转义会破坏 Markdown 表格的字符。"""
    return text.replace("|", "\\|").replace("\n", " ").strip()


def render_block(entries: list[dict[str, str]], rows: list[tuple[str, list[str]]]) -> str:
    lines = [
        BEGIN_MARK,
        "<!-- 本区块由 scripts/build_index.py 自动生成，请勿手改。",
        "     要改内容：编辑 reports/<你的名字>/meta.yml，然后重新运行脚本。 -->",
        "",
    ]

    if not entries:
        lines += [
            "> 暂无成员目录。",
            ">",
            "> 开始写报告：复制 `templates/report.md` 到 `reports/<你的名字>/report.md`，",
            "> 写好 `reports/<你的名字>/meta.yml`，然后运行 `python3 scripts/build_index.py`。",
            "> 具体步骤见 [CONTRIBUTING.md](CONTRIBUTING.md) §1。",
            "",
        ]
    else:
        lines += [
            "| 组员 | 主题 | 模块 | 状态 | 运行记录 | 最后更新 | 报告 |",
            "| --- | --- | --- | --- | ---: | --- | --- |",
        ]
        for e in entries:
            who = esc(e["name"])
            if e["github"]:
                who = f"{who} (@{esc(e['github'])})"
            lines.append(
                f"| {who} | {esc(e['title'])} | `{esc(e['module']) or '—'}` | {esc(e['status'])} "
                f"| {e['experiments']} | {esc(e['updated'])} | [{e['dir']}]({e['report_link']}) |"
            )
        lines += [
            "",
            f"共 {len(entries)} 人。状态说明：进行中 → 待评审 → 已完成；"
            "`规划中` 表示尚未开始。",
            "",
        ]

    lines += render_coverage(entries, rows)
    lines += [END_MARK]
    return "\n".join(lines)


def apply_block(text: str, block: str) -> str:
    start = text.find(BEGIN_MARK)
    end = text.find(END_MARK)
    if start == -1 or end == -1 or end < start:
        raise SystemExit(
            f"README.md 里找不到索引标记。请确认同时存在 {BEGIN_MARK} 和 {END_MARK}，"
            "且顺序正确。"
        )
    return text[:start] + block + text[end + len(END_MARK):]


def check_tracked_sizes() -> list[str]:
    """提醒仓库里被 git 跟踪的超大文件。"""
    try:
        out = subprocess.run(
            ["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=True
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return []

    oversized = []
    for name in out.decode("utf-8", "replace").split("\0"):
        if not name:
            continue
        try:
            size = (ROOT / name).stat().st_size
        except OSError:
            continue
        if size > MAX_TRACKED_BYTES:
            oversized.append(f"{name}（{size / 1024 / 1024:.1f} MB）")
    return oversized


def main() -> int:
    ap = argparse.ArgumentParser(description="生成 README.md 中的报告索引表与模块覆盖情况")
    ap.add_argument("--check", action="store_true", help="只检查，不写文件；过期则退出码为 1")
    args = ap.parse_args()

    if not README.is_file():
        print(f"错误：找不到 {README}", file=sys.stderr)
        return 2

    entries, problems = collect_entries()
    rows = parse_module_map()
    if not rows:
        print(
            "提示：未能从 docs/01-architecture.md 解析出模块地图，跳过模块覆盖统计。",
            file=sys.stderr,
        )

    block = render_block(entries, rows)
    current = README.read_text(encoding="utf-8")
    updated = apply_block(current, block)

    if problems:
        print("发现以下问题（不影响索引生成，但请修掉）：", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        print("", file=sys.stderr)

    oversized = check_tracked_sizes()
    if oversized:
        print("警告：以下文件已被 git 跟踪且超过 5MB，请移出仓库（见 data/MANIFEST.md）：", file=sys.stderr)
        for o in oversized:
            print(f"  - {o}", file=sys.stderr)
        print("", file=sys.stderr)

    if args.check:
        if updated != current:
            print("README.md 的索引表已过期。请运行：python3 scripts/build_index.py", file=sys.stderr)
            return 1
        print(f"索引已是最新（{len(entries)} 位成员）。")
        return 0

    if updated == current:
        print(f"索引无变化（{len(entries)} 位成员）。")
    else:
        README.write_text(updated, encoding="utf-8")
        print(f"已更新 README.md 索引（{len(entries)} 位成员）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
