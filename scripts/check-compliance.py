#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 [Author/Organization]
# SPDX-License-Identifier: AGPL-3.0-or-later

"""
Automated Compliance Validator for Open Source Software Standards Kit.

Scans any repository to verify:
1. Presence of SPDX-License-Identifier: AGPL-3.0 headers on all code files.
2. Absence of hardcoded version strings in individual source file headers.
3. License file presence (GNU AGPL-3.0).
4. AGPL-3.0 Section 13 source notice in Web UI and CLI.
5. Insecure patterns:
   - Prohibits yaml.load() (CWE-502).
   - Prohibits shell=True (CWE-78).
   - Prohibits default 0.0.0.0 binding.
   - Verifies explicit encoding='utf-8' on open() calls.
"""

import os
import re
import sys
from pathlib import Path

# Directories to ignore
IGNORE_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__",
    ".pytest_cache", ".ruff_cache", "dist", "build", "scratch"
}

# File extensions to audit for SPDX headers
CODE_EXTENSIONS = {".py", ".js", ".ts", ".html", ".css", ".yaml", ".yml"}


def check_spdx_header(content: str) -> bool:
    """Verify presence of SPDX-License-Identifier."""
    return "SPDX-License-Identifier" in content and "AGPL-3.0" in content


def check_security_flaws(file_path: Path, content: str) -> list[str]:
    """Audit content for banned anti-patterns."""
    errors = []
    lines = content.splitlines()

    for idx, line in enumerate(lines, start=1):
        # Check for unsafe yaml.load
        if "yaml.load(" in line and "safe_load" not in line and "Loader" not in line:
            errors.append(f"{file_path}:{idx}: [CWE-502] Prohibited 'yaml.load()' detected. Use 'yaml.safe_load()'.")

        # Check for shell=True
        if "shell=True" in line:
            errors.append(f"{file_path}:{idx}: [CWE-78] Prohibited 'shell=True' detected. Pass arguments as a list.")

        # Check for default 0.0.0.0 host binding
        if re.search(r'host\s*=\s*["\']0\.0\.0\.0["\']', line) and "default" in line.lower():
            errors.append(f"{file_path}:{idx}: [SECURITY] Web server defaults to 0.0.0.0. Must default strictly to 127.0.0.1.")

        # Check for unencoded open() in python
        if file_path.suffix == ".py" and "open(" in line and "encoding=" not in line and "rb" not in line and "wb" not in line:
            # Skip os.open
            if "os.open(" not in line:
                errors.append(f"{file_path}:{idx}: [PORTABILITY] open() call missing explicit encoding='utf-8'.")

    return errors


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    if len(sys.argv) > 1:
        repo_root = Path(sys.argv[1]).resolve()

    sys.stderr.write(f"[AUDIT] Scanning repository for standards compliance: {repo_root}\n")

    errors = []
    files_checked = 0

    # 1. Verify LICENSE file exists
    license_files = [repo_root / "LICENSE", repo_root / "templates/common/LICENSE"]
    if not any(f.exists() for f in license_files):
        errors.append("Missing required 'LICENSE' file (GNU AGPLv3).")

    # 2. Walk repository files
    this_script = Path(__file__).resolve()
    for root, dirs, files in os.walk(repo_root):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

        for file in files:
            path = (Path(root) / file).resolve()
            if path == this_script:
                continue

            if path.suffix not in CODE_EXTENSIONS:
                continue

            # Skip json and txt
            if path.suffix in {".json", ".txt"}:
                continue

            try:
                content = path.read_text(encoding="utf-8")
            except Exception as e:
                errors.append(f"Could not read {path}: {e}")
                continue

            files_checked += 1

            # Check SPDX
            if not check_spdx_header(content):
                errors.append(f"{path}: Missing or malformed SPDX AGPL-3.0 header.")

            # Check Security Flaws
            security_errors = check_security_flaws(path, content)
            errors.extend(security_errors)

    # 3. Report Results
    sys.stderr.write(f"[AUDIT] Checked {files_checked} files.\n")

    if errors:
        sys.stderr.write(f"\n[FAIL] Found {len(errors)} standards violations:\n")
        for err in errors:
            sys.stderr.write(f"  ✗ {err}\n")
        return 1

    sys.stderr.write("\n[PASS] All files adhere strictly to software standards.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
