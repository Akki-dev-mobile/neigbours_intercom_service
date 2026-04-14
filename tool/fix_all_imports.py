#!/usr/bin/env python3
"""Convert any remaining relative import/export paths to package URIs."""
from __future__ import annotations

import pathlib
import re
import sys

PACKAGE = "neigbours_intercom_service"
ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

# import 'path' ... ; export 'path' ...
IMP_RE = re.compile(
    r"^(?P<indent>\s*)(?P<kw>import|export)\s+"
    r"(?P<q>['\"])(?P<path>[^'\"]+)(?P=q)"
    r"(?P<rest>.*)$"
)


def resolve(file: pathlib.Path, rel: str) -> pathlib.Path | None:
    if rel.startswith("package:") or rel.startswith("dart:"):
        return None
    try:
        t = (file.parent / rel).resolve()
        t.relative_to(LIB)
    except (ValueError, OSError):
        return None
    return t


def process_file(path: pathlib.Path) -> bool:
    changed = False
    out: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines(keepends=True):
        raw = line.rstrip("\n")
        if raw.strip().startswith("part "):
            out.append(line)
            continue
        m = IMP_RE.match(raw)
        if not m:
            out.append(line)
            continue
        rel_path = m.group("path")
        if rel_path.startswith("package:") or rel_path.startswith("dart:"):
            out.append(line)
            continue
        if not m.group("rest").strip().endswith(";"):
            out.append(line)
            continue
        target = resolve(path, rel_path)
        if target is None:
            out.append(line)
            continue
        new_uri = f"package:{PACKAGE}/{target.relative_to(LIB).as_posix()}"
        new_line = (
            f"{m.group('indent')}{m.group('kw')} "
            f"{m.group('q')}{new_uri}{m.group('q')}{m.group('rest')}\n"
        )
        if new_line != line:
            changed = True
        out.append(new_line)

    if changed:
        path.write_text("".join(out), encoding="utf-8")
    return changed


def main() -> int:
    n = 0
    for path in sorted(LIB.rglob("*.dart")):
        if process_file(path):
            print("fixed", path.relative_to(ROOT))
            n += 1
    print(f"Updated {n} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
