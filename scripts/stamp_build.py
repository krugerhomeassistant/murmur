#!/usr/bin/env python3
"""Writes client/build_info.json (git commit and time) so an exported build can say which commit it came from. Run before exporting."""
import json
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True).stdout.strip()
(root / "client" / "build_info.json").write_text(json.dumps({"commit": commit, "built": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())}) + "\n")
print("stamped", commit[:7])
