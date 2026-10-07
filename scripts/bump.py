#!/usr/bin/env python3
"""Bump the version and cut the changelog section.

    python scripts/bump.py 0.2.0
    git commit -am "Release v0.2.0" && git push && git tag v0.2.0 && git push --tags
"""

import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main(version: str) -> None:
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        sys.exit("usage: bump.py X.Y.Z")
    (ROOT / "VERSION").write_text(version + "\n")
    pg = ROOT / "client/project.godot"
    t = pg.read_text()
    if "config/version=" in t:
        t = re.sub(r'config/version="[^"]*"', f'config/version="{version}"', t)
    else:
        t = t.replace('config/name="Murmur"', f'config/name="Murmur"\nconfig/version="{version}"', 1)
    pg.write_text(t)
    cl = ROOT / "CHANGELOG.md"
    text = cl.read_text()
    if "## [Unreleased]" not in text:
        sys.exit("CHANGELOG.md has no [Unreleased] section")
    cl.write_text(text.replace("## [Unreleased]", f"## [Unreleased]\n\n## [{version}] - {date.today()}", 1))
    print(f"bumped to {version}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "")
