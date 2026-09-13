#!/usr/bin/env python3
"""Append trailing // Chinese comments to Swift lines missing them (draft for human edit)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

SKIP_STARTS = (
    "import ",
    "@MainActor",
    "///",
    "// MARK:",
    "#",
)
SKIP_STRIP = frozenset({"{", "}"})


def has_trailing_comment(line: str) -> bool:
    stripped = line.rstrip()
    if stripped.strip().startswith("//"):
        return True
    return bool(re.search(r"\s//\s*\S", stripped))


def should_skip(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return True
    if stripped in SKIP_STRIP:
        return True
    for prefix in SKIP_STARTS:
        if stripped.startswith(prefix):
            return True
    return has_trailing_comment(line)


def guess_comment(line: str) -> str:
    s = line.strip()
    if s.startswith("return "):
        return "返回本步结果"
    if s.startswith("guard "):
        return "不满足条件则提前退出"
    if s.startswith("defer "):
        return "作用域结束时执行"
    if s.startswith("throw "):
        return "向上抛出错误"
    if s.startswith("try await ") or s.startswith("await "):
        return "等待异步完成"
    if s.startswith("try "):
        return "调用可能失败的方法"
    if s.startswith("case ") or s.startswith("} else if"):
        return "分支处理"
    if s.startswith("if ") or s.startswith("} else"):
        return "条件分支"
    if s.startswith("for ") or s.startswith("while "):
        return "循环一步"
    if s.startswith("break") or s.startswith("continue"):
        return "控制循环"
    if s.startswith("@Published") or s.startswith("private ") or s.startswith("var ") or s.startswith("let "):
        if "=" in s:
            return "声明或更新局部/成员状态"
    if ".sink" in s or ".store" in s:
        return "订阅并保存 Combine 引用"
    if s.endswith("{") and ("didSet" in s or "willSet" in s):
        return "属性观察器入口"
    if "host." in s or "self." in s:
        return "读写编排宿主或本会话状态"
    if "=" in s:
        return "赋值"
    if "(" in s and ")" in s:
        return "调用方法或初始化"
    return "执行本步逻辑"


def process_file(path: Path) -> int:
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    out: list[str] = []
    added = 0
    in_multiline = False
    for line in lines:
        if '"""' in line:
            q = line.count('"""')
            if q == 1:
                in_multiline = not in_multiline
            else:
                in_multiline = False
            out.append(line)
            continue
        if in_multiline:
            out.append(line)
            continue
        if should_skip(line):
            out.append(line)
            continue
        core = line.rstrip("\n\r")
        comment = guess_comment(core)
        if core.rstrip().endswith("\\"):
            out.append(line)
            continue
        out.append(f"{core.rstrip()} // {comment}\n")
        added += 1
    if added:
        path.write_text("".join(out), encoding="utf-8")
    return added


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    targets = [Path(p) for p in sys.argv[1:]] if len(sys.argv) > 1 else []
    if not targets:
        print("Usage: add_swift_trailing_line_comments.py <file.swift> ...")
        sys.exit(1)
    total = 0
    for path in targets:
        if path.is_file():
            n = process_file(path)
            print(f"{path.name}: +{n} trailing comments")
            total += n
    print(f"Total: {total}")


if __name__ == "__main__":
    main()
