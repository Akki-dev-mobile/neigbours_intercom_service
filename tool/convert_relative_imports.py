#!/usr/bin/env python3
"""
Convert relative imports/exports in lib/*.dart to package:neigbours_intercom_service/...
Skips: package:, dart:, part directives.
"""
from __future__ import annotations

import pathlib
import re
import sys

PACKAGE = "neigbours_intercom_service"
ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

LINE_RE = re.compile(
    r"^(?P<indent>\s*)(?P<kw>import|export)\s+"
    r"(?P<q>['\"])(?P<path>[^'\"]+)(?P=q)"
    r"(?P<suffix>\s*(?:;.*|show\s+[^;]+;|hide\s+[^;]+;|deferred\s+as\s+\w+\s*;)?\s*)$"
)


def resolve_relative(from_file: pathlib.Path, rel: str) -> pathlib.Path | None:
    if rel.startswith("package:") or rel.startswith("dart:"):
        return None
    try:
        target = (from_file.parent / rel).resolve()
    except (OSError, ValueError):
        return None
    try:
        target.relative_to(LIB)
    except ValueError:
        return None
    return target


def to_package_uri(target: pathlib.Path) -> str:
    return f"package:{PACKAGE}/{target.relative_to(LIB).as_posix()}"


def process_file(path: pathlib.Path) -> bool:
    text = path.read_text(encoding="utf-8")
    out_lines: list[str] = []
    changed = False

    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\n")
        if raw.strip().startswith("part "):
            out_lines.append(line)
            continue

        m = LINE_RE.match(raw)
        if not m:
            out_lines.append(line)
            continue

        rel_path = m.group("path")
        if rel_path.startswith("package:") or rel_path.startswith("dart:"):
            out_lines.append(line)
            continue

        target = resolve_relative(path, rel_path)
        if target is None:
            out_lines.append(line)
            continue

        new_uri = to_package_uri(target)
        suffix = m.group("suffix")
        if not suffix.endswith(";"):
            suffix = suffix.rstrip() + ";"
        new_line = (
            f"{m.group('indent')}{m.group('kw')} "
            f"{m.group('q')}{new_uri}{m.group('q')}{suffix}\n"
        )
        if new_line != line:
            changed = True
        out_lines.append(new_line)

    if changed:
        path.write_text("".join(out_lines), encoding="utf-8")
    return changed


def main() -> int:
    if not LIB.is_dir():
        print("lib/ not found", file=sys.stderr)
        return 1
    n = 0
    for path in sorted(LIB.rglob("*.dart")):
        if process_file(path):
            print("updated:", path.relative_to(ROOT))
            n += 1
    print(f"Done. Updated {n} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
