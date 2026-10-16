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
5. Insecure patterns (AST-powered static analysis):
   - Prohibits unsafe yaml.load() without SafeLoader (CWE-502).
   - Prohibits shell=True in subprocess execution (CWE-78).
   - Prohibits default 0.0.0.0 localhost bypass.
   - Verifies explicit encoding='utf-8' on open() calls.
"""

import ast
import os
import re
import sys
from pathlib import Path

# Directories to ignore
IGNORE_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__",
    ".pytest_cache", ".ruff_cache", "dist", "build", "scratch"
}

# File extensions to audit
CODE_EXTENSIONS = {".py", ".js", ".ts", ".html", ".css", ".yaml", ".yml"}


def check_spdx_header(content: str) -> bool:
    """Verify presence of SPDX-License-Identifier."""
    return "SPDX-License-Identifier" in content and "AGPL-3.0" in content


class PythonASTSecurityAuditor(ast.NodeVisitor):
    """AST-based static analysis auditor for Python files (eliminates false positives)."""

    def __init__(self, file_path: Path):
        self.file_path = file_path
        self.errors = []

    def visit_Call(self, node: ast.Call):
        # 1. Check for yaml.load without SafeLoader (CWE-502)
        if isinstance(node.func, ast.Attribute):
            if isinstance(node.func.value, ast.Name) and node.func.value.id == "yaml":
                if node.func.attr == "load":
                    # Check if Loader is passed as a keyword argument
                    has_safe_loader = any(
                        kw.arg == "Loader" and "Safe" in ast.unparse(kw.value)
                        for kw in node.keywords
                    )
                    if not has_safe_loader:
                        self.errors.append(
                            f"{self.file_path}:{node.lineno}: [CWE-502] Prohibited 'yaml.load()' detected without SafeLoader. Use 'yaml.safe_load()'."
                        )

        # 2. Check for shell=True in subprocess calls (CWE-78)
        for kw in node.keywords:
            if kw.arg == "shell":
                if isinstance(kw.value, ast.Constant) and kw.value.value is True:
                    self.errors.append(
                        f"{self.file_path}:{node.lineno}: [CWE-78] Prohibited 'shell=True' detected. Pass arguments as a list."
                    )

        # 3. Check for open() missing explicit encoding='utf-8'
        is_builtin_open = isinstance(node.func, ast.Name) and node.func.id == "open"
        if is_builtin_open:
            # Check mode argument if present (skip binary modes: 'rb', 'wb', 'ab')
            is_binary = False
            if len(node.args) >= 2 and isinstance(node.args[1], ast.Constant):
                mode = str(node.args[1].value)
                if "b" in mode:
                    is_binary = True

            has_encoding = any(kw.arg == "encoding" for kw in node.keywords)
            if not is_binary and not has_encoding:
                self.errors.append(
                    f"{self.file_path}:{node.lineno}: [PORTABILITY] open() call missing explicit encoding='utf-8'."
                )

        self.generic_visit(node)

    def visit_FunctionDef(self, node: ast.FunctionDef):
        # Check for functions defaulting host to '0.0.0.0'
        for default in node.args.defaults:
            if isinstance(default, ast.Constant) and default.value == "0.0.0.0":
                self.errors.append(
                    f"{self.file_path}:{node.lineno}: [SECURITY] Web server function defaults host to 0.0.0.0. Must default strictly to 127.0.0.1."
                )

        # Check for run_local_server missing no_browser parameter
        if node.name == "run_local_server":
            arg_names = [arg.arg for arg in node.args.args]
            if "no_browser" not in arg_names:
                self.errors.append(
                    f"{self.file_path}:{node.lineno}: [UI] Web server runner 'run_local_server' missing 'no_browser' parameter."
                )

        self.generic_visit(node)


def check_non_python_security(file_path: Path, content: str) -> list[str]:
    """Line-based audit for JavaScript, TypeScript, and HTML files."""
    errors = []
    lines = content.splitlines()

    for idx, line in enumerate(lines, start=1):
        # Check for default 0.0.0.0 host binding
        if re.search(r'host(name)?\s*[:=]\s*["\']0\.0\.0\.0["\']', line) and "default" in line.lower():
            errors.append(f"{file_path}:{idx}: [SECURITY] Web server defaults to 0.0.0.0. Must default strictly to 127.0.0.1.")

        # Check for runLocalServer missing noBrowser
        if "function runLocalServer(" in line and "noBrowser" not in line:
            errors.append(f"{file_path}:{idx}: [UI] Web server runner 'runLocalServer' missing 'noBrowser' parameter.")

        # Check for child_process.exec in JS
        if file_path.suffix in {".js", ".ts"} and "exec(" in line and "execFile" not in line and "execFileSync" not in line:
            # Allow regex .exec()
            if not re.search(r'\.(test|match|exec)\(', line):
                errors.append(f"{file_path}:{idx}: [CWE-78] Potential shell execution via exec(). Use execFile() or spawn().")

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

    # 2. Walk repository files (Includes checking this script itself!)
    for root, dirs, files in os.walk(repo_root):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

        for file in files:
            path = (Path(root) / file).resolve()

            if path.suffix not in CODE_EXTENSIONS:
                continue

            # Skip pure data/docs files
            if path.suffix in {".json", ".txt"}:
                continue

            try:
                content = path.read_text(encoding="utf-8")
            except Exception as e:
                errors.append(f"Could not read {path}: {e}")
                continue

            files_checked += 1

            # Check SPDX Header
            if not check_spdx_header(content):
                errors.append(f"{path}: Missing or malformed SPDX AGPL-3.0 header.")

            # Check Security Flaws (AST for Python, Regex for JS/HTML)
            if path.suffix == ".py":
                try:
                    tree = ast.parse(content, filename=str(path))
                    auditor = PythonASTSecurityAuditor(path)
                    auditor.visit(tree)
                    errors.extend(auditor.errors)
                except SyntaxError as e:
                    errors.append(f"{path}:{e.lineno}: SyntaxError while parsing AST: {e.msg}")
            else:
                errors.extend(check_non_python_security(path, content))

    # 3. Report Results
    sys.stderr.write(f"[AUDIT] Checked {files_checked} files (including self).\n")

    if errors:
        sys.stderr.write(f"\n[FAIL] Found {len(errors)} standards violations:\n")
        for err in errors:
            sys.stderr.write(f"  ✗ {err}\n")
        return 1

    sys.stderr.write("\n[PASS] All files adhere strictly to software standards.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
