#!/usr/bin/env python3
"""Fix ../ depth for core/ imports after folder moves."""
from __future__ import annotations

import pathlib

PACKAGE = "neigbours_intercom_service"
ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
PREFIX = f"package:{PACKAGE}/"


def rewrite_file(path: pathlib.Path) -> bool:
    t = path.read_text(encoding="utf-8")
    orig = t
    # Any relative import to core/, models under core, utils, widgets, services, layout, network, providers, storage, theme
    for sub in (
        "core/",
        "utils/",
        "screens/",
        "features/",
        "src/",
        "models/",
        "society_feed/",
    ):
        # Replace longest chains first (tabs/widgets deep paths)
        for n in (6, 5, 4, 3, 2):
            dots = "../" * n
            needle = f"import '{dots}{sub}"
            repl = f"import '{PREFIX}{sub}"
            t = t.replace(needle, repl)
            needle = f'import "{dots}{sub}'
            repl = f'import "{PREFIX}{sub}'
            t = t.replace(needle, repl)
    if t != orig:
        path.write_text(t, encoding="utf-8")
        return True
    return False


def main() -> None:
    n = 0
    for path in sorted(LIB.rglob("*.dart")):
        if rewrite_file(path):
            print("normalized", path.relative_to(ROOT))
            n += 1
    print(f"Done, {n} files.")


if __name__ == "__main__":
    main()
