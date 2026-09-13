#!/usr/bin/env python3
"""Insert /// doc lines before Swift func/init that lack a preceding /// comment."""
from __future__ import annotations

import re
import sys
from pathlib import Path

# 常见前缀 → 中文摘要（Reading 包为主，可扩展）
PREFIX_HINTS: list[tuple[str, str]] = [
    ("load", "加载"),
    ("save", "保存"),
    ("open", "打开"),
    ("close", "关闭"),
    ("restore", "恢复"),
    ("persist", "持久化"),
    ("sync", "同步"),
    ("update", "更新"),
    ("remove", "移除"),
    ("delete", "删除"),
    ("append", "追加"),
    ("clear", "清空"),
    ("reset", "重置"),
    ("handle", "处理"),
    ("fetch", "请求并获取"),
    ("send", "发送"),
    ("build", "构建"),
    ("repaginate", "重新分页"),
    ("align", "对齐"),
    ("explain", "讲解"),
    ("read", "朗读"),
    ("speak", "语音播报"),
    ("stop", "停止"),
    ("start", "开始"),
    ("ensure", "确保已初始化"),
    ("guard", "校验并在不通过时拦截"),
    ("schedule", "调度"),
    ("record", "记录"),
    ("revert", "回滚"),
    ("apply", "应用"),
    ("split", "拆分"),
    ("lock", "锁定"),
    ("unlock", "解锁"),
    ("enter", "进入"),
    ("exit", "退出"),
    ("turn", "翻页"),
    ("capture", "捕获"),
    ("complete", "完成"),
    ("cancel", "取消"),
    ("begin", "开始"),
    ("finish", "结束"),
    ("select", "选中或切换"),
    ("generate", "生成"),
    ("refine", "在已有结果上修订"),
    ("supplement", "补充"),
    ("pin", "置顶"),
    ("skip", "跳过"),
    ("analyze", "分析"),
    ("evolution", "进化流程"),
]


def guess_summary(name: str) -> str:
    for prefix, verb in PREFIX_HINTS:
        if name.startswith(prefix):
            rest = name[len(prefix) :]
            if rest:
                return f"{verb}{rest}相关逻辑。"
            return f"{verb}。"
    return f"{name}。"


FUNC_RE = re.compile(
    r"^(\s+)(?:(?:private|fileprivate|internal|public)\s+)*"
    r"(?:(?:mutating\s+)?func\s+(\w+)|(?:init\b))"
)


def process_file(path: Path) -> int:
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    out: list[str] = []
    added = 0
    for line in lines:
        m = FUNC_RE.match(line)
        if m:
            indent = m.group(1)
            name = m.group(2) or "init"
            summary = "初始化并连接宿主与会话。" if name == "init" else guess_summary(name)
            j = len(out) - 1
            while j >= 0 and out[j].strip() == "":
                j -= 1
            has_doc = j >= 0 and "///" in out[j]
            if not has_doc:
                prev = out[j].strip() if j >= 0 else ""
                if not prev.startswith("///"):
                    out.append(f"{indent}/// {summary}\n")
                    added += 1
        out.append(line)
    if added:
        path.write_text("".join(out), encoding="utf-8")
    return added


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    targets = [Path(p) for p in sys.argv[1:]] if len(sys.argv) > 1 else list(
        (root / "Sources/AIBook/Reading").glob("*.swift")
    )
    total = 0
    for path in targets:
        if path.is_file():
            total += process_file(path)
    print(f"Added {total} /// lines across {len(targets)} files")


if __name__ == "__main__":
    main()
