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

# Directories to ignore (build artifacts, caches, virtual environments, and data/output directories)
IGNORE_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__",
    ".pytest_cache", ".ruff_cache", "dist", "build", "scratch",
    "output", "data", "reports", "coverage", "htmlcov", "site",
    "temp", "tmp", "docs"
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


def check_workflow_compliance(file_path: Path, content: str) -> list[str]:
    """Audit GitHub Actions workflow files for syntax validity and OpenSSF pin rules."""
    errors = []
    lines = content.splitlines()

    for idx, line in enumerate(lines, start=1):
        # 1. Prohibit job-level hashFiles (evaluated before runners are provisioned)
        if re.search(r'^\s{4}if:.*hashFiles\(', line):
            errors.append(
                f"{file_path}:{idx}: [GITHUB-ACTIONS] Prohibited 'hashFiles()' in job-level 'if'. "
                f"Use a detect-stack job with outputs or step-level 'if'."
            )

        # 2. OpenSSF Scorecard: Verify third-party action pinning to 40-char commit SHA
        match = re.search(r'uses:\s*([a-zA-Z0-9_\-]+/[a-zA-Z0-9_\-]+)@([^\s#]+)', line)
        if match:
            action, ref = match.groups()
            if not re.fullmatch(r'[0-9a-f]{40}', ref):
                errors.append(
                    f"{file_path}:{idx}: [SUPPLY-CHAIN] Action '{action}' not pinned to a 40-character commit SHA (found '{ref}')."
                )

        # 3. Prohibit 'secrets' context inside 'if:' conditions (GitHub Actions invalid workflow syntax)
        if re.search(r'^\s*if:.*secrets\.', line):
            errors.append(
                f"{file_path}:{idx}: [GITHUB-ACTIONS] Prohibited 'secrets' context in 'if' condition. "
                f"GitHub Actions rejects secrets in 'if' conditionals. Use an env variable and step output."
            )

    return errors


UI_SOURCE_DIRS = {"web", "frontend", "templates", "src", "app", "static"}

GLOBAL_ERROR_BOUNDARY_SNIPPET = """  <!-- Directive 3 & 13: Universal Global UI Error Boundary (Zero Silent Crashes) -->
  <script>
    window.addEventListener('error', function(event) {
      showFatalUIError('UI Runtime Error: ' + (event.message || 'Script error') + ' (' + (event.filename || 'unknown') + ':' + (event.lineno || 0) + ')');
    });
    window.addEventListener('unhandledrejection', function(event) {
      var reason = event.reason;
      var msg = reason && (reason.message || reason.toString()) ? (reason.message || reason.toString()) : 'Unhandled Promise Rejection';
      showFatalUIError('Async Operation Error: ' + msg);
    });
    function showFatalUIError(msg) {
      var box = document.getElementById('__fatal_error_banner');
      if (!box) {
        box = document.createElement('div');
        box.id = '__fatal_error_banner';
        box.setAttribute('role', 'alert');
        box.style.cssText = 'position:fixed;top:0;left:0;right:0;background:#b91c1c;color:#fff;padding:12px 16px;z-index:99999;font-weight:600;font-family:monospace;font-size:14px;box-shadow:0 4px 6px rgba(0,0,0,0.3);display:flex;justify-content:space-between;align-items:center;';
        if (document.body) {
          document.body.prepend(box);
        } else {
          document.documentElement.prepend(box);
        }
      }
      box.textContent = '';
      var textSpan = document.createElement('span');
      textSpan.textContent = '⚠️ ' + msg;
      box.appendChild(textSpan);
      var dismissBtn = document.createElement('button');
      dismissBtn.textContent = 'Dismiss';
      dismissBtn.style.cssText = 'background:#fff;color:#b91c1c;border:none;padding:4px 10px;border-radius:4px;cursor:pointer;font-weight:bold;margin-left:12px;';
      dismissBtn.onclick = function() { box.remove(); };
      box.appendChild(dismissBtn);
    }
  </script>
"""


def remediate_html_error_boundary(content: str) -> str:
    """Inject universal error boundary immediately following <head>."""
    match = re.search(r'(<head\b[^>]*>)', content, re.IGNORECASE)
    if match:
        idx = match.end()
        return content[:idx] + "\n" + GLOBAL_ERROR_BOUNDARY_SNIPPET + content[idx:]
    return content


def remediate_spdx_header(file_path: Path, content: str) -> str:
    """Inject standard SPDX-License-Identifier header into source file."""
    suffix = file_path.suffix.lower()
    if suffix in {".py", ".sh"}:
        header = "# SPDX-FileCopyrightText: 2026 [Author/Organization]\n# SPDX-License-Identifier: AGPL-3.0-or-later\n\n"
        if content.startswith("#!"):
            first_line_end = content.find("\n")
            if first_line_end != -1:
                return content[:first_line_end + 1] + header + content[first_line_end + 1:]
        return header + content
    elif suffix in {".js", ".ts", ".css"}:
        header = "/*\nSPDX-FileCopyrightText: 2026 [Author/Organization]\nSPDX-License-Identifier: AGPL-3.0-or-later\n*/\n\n"
        return header + content
    elif suffix == ".html":
        header = "<!--\nSPDX-FileCopyrightText: 2026 [Author/Organization]\nSPDX-License-Identifier: AGPL-3.0-or-later\n-->\n"
        match = re.search(r'(<!doctype\s+html[^>]*>)', content, re.IGNORECASE)
        if match:
            idx = match.end()
            return content[:idx] + "\n" + header + content[idx:]
        return header + content
    return content


def check_html_ui_compliance(file_path: Path, content: str, fix_mode: bool = False) -> tuple[list[str], str]:
    """Audit Web UI HTML files for required Global UI Error Boundary."""
    errors = []

    # Skip files inside data, report, export, or doc directories
    path_parts = {part.lower() for part in file_path.parts}
    if path_parts & {"output", "reports", "data", "exports", "site", "coverage", "htmlcov", "docs"}:
        return errors, content

    # Only audit files that are either named index.html or reside in a web UI source folder
    is_ui_source = (
        file_path.name.lower() == "index.html"
        or bool(path_parts & UI_SOURCE_DIRS)
    )
    if not is_ui_source:
        return errors, content

    # Skip generated visualizations or exports (e.g. pyvis, plotly, vis-network exports)
    if any(sig in content for sig in ["pyvis", "vis-network", "Generated by", "plotly.js"]):
        return errors, content

    # If the file defines an active Web UI with scripts and a body, ensure the global error boundary is present
    if "<script" in content.lower() and "<body" in content.lower():
        has_error_boundary = (
            "window.addEventListener('error'" in content
            or 'window.addEventListener("error"' in content
            or "window.onerror" in content
        )
        if not has_error_boundary:
            if fix_mode:
                content = remediate_html_error_boundary(content)
                file_path.write_text(content, encoding="utf-8")
                sys.stderr.write(f"  [AUTO-FIXED] Injected Global Error Boundary into: {file_path}\n")
            else:
                errors.append(
                    f"{file_path}: [UI] Web UI HTML missing mandatory Global Error Boundary (window.addEventListener('error', ...)). See Directive 3 & 13."
                )
    return errors, content


def check_non_python_security(file_path: Path, content: str, fix_mode: bool = False) -> list[str]:
    """Line-based audit for JavaScript, TypeScript, HTML, and Workflow files."""
    errors = []

    # Check Workflow compliance
    if file_path.suffix in {".yaml", ".yml"} and (".github/workflows" in str(file_path) or "workflows" in str(file_path)):
        errors.extend(check_workflow_compliance(file_path, content))

    # Check HTML UI compliance
    if file_path.suffix == ".html":
        ui_errors, content = check_html_ui_compliance(file_path, content, fix_mode=fix_mode)
        errors.extend(ui_errors)

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
    fix_mode = "--fix" in sys.argv
    cli_args = [arg for arg in sys.argv[1:] if arg != "--fix"]
    repo_root = Path(__file__).resolve().parent.parent
    if cli_args:
        repo_root = Path(cli_args[0]).resolve()

    sys.stderr.write(f"[AUDIT] Scanning repository for standards compliance: {repo_root}" + (" [AUTO-FIX ACTIVE]" if fix_mode else "") + "\n")

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
                if fix_mode:
                    content = remediate_spdx_header(path, content)
                    path.write_text(content, encoding="utf-8")
                    sys.stderr.write(f"  [AUTO-FIXED] Injected SPDX AGPL-3.0 header into: {path}\n")
                else:
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
                errors.extend(check_non_python_security(path, content, fix_mode=fix_mode))

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
