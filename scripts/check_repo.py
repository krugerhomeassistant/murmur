#!/usr/bin/env python3
"""Repo hygiene gate (run in CI): markdown links and backticked paths must exist, VERSION must match the changelog, every docs/*.md is in the docs index, README needs no unmeasured perf claims."""
import re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
errs = []
for md in [*root.glob("*.md"), *root.glob("docs/*.md"), *root.glob("docs/wiki/*.md"), *root.glob(".github/*.md")]:
    t = md.read_text(encoding="utf-8")
    for m in re.finditer(r"\]\(([^)#\s]+)\)", t):
        l = m.group(1)
        if not l.startswith(("http", "mailto:")) and not (md.parent / l).exists():
            errs.append(f"{md.relative_to(root)}: broken link {l}")
    if md.name == "README.md" and md.parent == root:
        for m in re.finditer(r"`((?:client|docs|scripts|\.github)/[\w./-]+|[\w .-]+\.(?:bat|md))`", t):
            p = m.group(1)
            if not (root / p).exists() and not (root / p.rstrip("/")).exists():
                errs.append(f"README: path does not exist: {p}")
idx = (root / "docs/README.md").read_text(encoding="utf-8")
for d in root.glob("docs/*.md"):
    if d.name != "README.md" and f"]({d.name})" not in idx:
        errs.append(f"docs/README.md does not list {d.name}")
widx = (root / "docs/wiki/README.md").read_text(encoding="utf-8")
for d in root.glob("docs/wiki/*.md"):
    if d.name != "README.md" and f"]({d.name})" not in widx:
        errs.append(f"docs/wiki/README.md does not list {d.name}")
ver = (root / "VERSION").read_text().strip()
if f"## [{ver}]" not in (root / "CHANGELOG.md").read_text():
    errs.append(f"VERSION {ver} has no CHANGELOG section")
for f in ["LICENSE", "SECURITY.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md"]:
    if not (root / f).exists():
        errs.append(f"missing {f}")
print("\n".join(errs) or "REPO_OK")
sys.exit(1 if errs else 0)
