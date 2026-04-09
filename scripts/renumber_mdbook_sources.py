#!/usr/bin/env python3
"""
按 src/SUMMARY.md 中各章目录下的出现顺序，将 Markdown 重命名为 NN-slug.md（NN 为 00–99），
并更新内部相对链接。

  python3 scripts/renumber_mdbook_sources.py          # 干跑
  python3 scripts/renumber_mdbook_sources.py --apply
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from os.path import relpath as os_relpath

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
SUMMARY = SRC / "SUMMARY.md"


def canonical_stem(stem: str) -> str:
    if stem == "index":
        return "index"
    m = re.match(r"^\d{2}-(.+)$", stem)
    if m:
        return m.group(1)
    return stem


def parse_summary_paths() -> list[str]:
    text = SUMMARY.read_text(encoding="utf-8")
    paths = re.findall(r"\(([^)]+\.md)\)", text)
    out: list[str] = []
    seen: set[str] = set()
    for p in paths:
        p = p.split("#")[0].strip()
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def build_full_map() -> dict[str, str]:
    """Every SUMMARY path -> new path (identity if unchanged)."""
    order = parse_summary_paths()
    by_dir: dict[str, list[str]] = {}
    for p in order:
        parts = p.split("/")
        d = "." if len(parts) == 1 else "/".join(parts[:-1])
        by_dir.setdefault(d, []).append(p)

    full: dict[str, str] = {}
    for d, paths in by_dir.items():
        for seq, rel in enumerate(paths):
            stem = Path(rel).stem
            can = canonical_stem(stem)
            new_name = f"{seq:02d}-{can}.md"
            new_rel = new_name if d == "." else f"{d}/{new_name}"
            full[rel] = new_rel
    return full


LINK_RE = re.compile(r"(\]\()([^)]*)(\))")


def resolve_md_href(current_rel: str, href: str) -> tuple[str | None, str]:
    """Resolve href to src-relative 'dir/file.md'; return (path, anchor)."""
    anchor = ""
    raw = href.strip()
    if "#" in raw:
        hash_pos = raw.find("#")
        if raw.rfind(".md", 0, len(raw)) != -1 and hash_pos > raw.rfind(".md"):
            raw = raw[:hash_pos]
            anchor = href[hash_pos:]

    if not raw.endswith(".md"):
        return None, ""

    cur = SRC / current_rel
    target = (cur.parent / raw).resolve()
    try:
        rel = target.relative_to(SRC.resolve())
    except ValueError:
        return None, ""
    return str(rel).replace("\\", "/"), anchor


def rewrite_links(content: str, current_rel: str, full: dict[str, str]) -> str:
    """Rewrite .md links using full map (old -> new paths)."""

    def repl(m: re.Match) -> str:
        pre, href, post = m.group(1), m.group(2), m.group(3)
        resolved, anchor = resolve_md_href(current_rel, href)
        if resolved is None:
            return m.group(0)
        if resolved not in full:
            return m.group(0)
        new_target_rel = full[resolved]
        from_dir = (SRC / current_rel).parent
        to_file = SRC / new_target_rel
        new_href = os_relpath(str(to_file), str(from_dir)).replace("\\", "/") + anchor
        return f"{pre}{new_href}{post}"

    return LINK_RE.sub(repl, content)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    full = build_full_map()
    changes = {k: v for k, v in full.items() if k != v}
    print(f"Paths in SUMMARY: {len(full)}, renames needed: {len(changes)}")
    for k in sorted(changes.keys()):
        print(f"  {k} -> {changes[k]}")

    if not args.apply:
        print("\nDry run. Pass --apply to write files.")
        return

    # Load all sources first (avoid a->b then b->c overwrite)
    blobs: dict[str, str] = {}
    for old_rel in full:
        old_p = SRC / old_rel
        if not old_p.exists():
            print(f"ERROR: missing {old_p}", file=sys.stderr)
            sys.exit(1)
        blobs[old_rel] = old_p.read_text(encoding="utf-8")

    out: dict[str, str] = {}
    for old_rel, new_rel in full.items():
        text = rewrite_links(blobs[old_rel], old_rel, full)
        out[new_rel] = text

    # Remove old paths that will move or be replaced
    for old_rel, new_rel in full.items():
        if old_rel != new_rel:
            (SRC / old_rel).unlink(missing_ok=True)

    for new_rel, text in out.items():
        new_p = SRC / new_rel
        new_p.parent.mkdir(parents=True, exist_ok=True)
        new_p.write_text(text, encoding="utf-8")

    # SUMMARY
    s = SUMMARY.read_text(encoding="utf-8")
    for old, new in sorted(full.items(), key=lambda x: -len(x[0])):
        if old == new:
            continue
        s = s.replace(f"]({old})", f"]({new})")
        s = s.replace(f"]({old}#", f"]({new}#")
    SUMMARY.write_text(s, encoding="utf-8")

    print("Done.")


if __name__ == "__main__":
    main()
