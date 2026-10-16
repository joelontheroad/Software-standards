# Master Software Standards Specification (12-Category Standards Kit)

**Version:** 1.0.0  
**Effective Date:** 2026-10-15  
**License Baseline:** GNU Affero General Public License v3.0 (`AGPL-3.0-or-later`)  
**Scope:** Standalone utilities, developer tools, CLI applications, and local browser-based utilities (running on `localhost`).

---

## Table of Contents
1. [Scope & Philosophy](#1-scope--philosophy)
2. [Category 1: Privacy by Design & Data Minimization](#category-1-privacy-by-design--data-minimization)
3. [Category 2: Software Lifecycle Management (SLM) & Licensing](#category-2-software-lifecycle-management-slm--licensing)
4. [Category 3: UI & Human Interface Guidelines (CLI & Web UI)](#category-3-ui--human-interface-guidelines-cli--web-ui)
5. [Category 4: Configuration & Preset Architecture](#category-4-configuration--preset-architecture)
6. [Category 5: Secure Programming & Cybersecurity Hardening](#category-5-secure-programming--cybersecurity-hardening)
7. [Category 6: Supply Chain Security & Packaging](#category-6-supply-chain-security--packaging)
8. [Category 7: Testing & Quality Assurance](#category-7-testing--quality-assurance)
9. [Category 8: Observability, Logging & Error Handling](#category-8-observability-logging--error-handling)
10. [Category 9: Portability & Cross-Platform Compatibility](#category-9-portability--cross-platform-compatibility)
11. [Category 10: Process Lifecycle & Performance](#category-10-process-lifecycle--performance)
12. [Category 11: Interoperability & Unix Composability](#category-11-interoperability--unix-composability)
13. [Category 12: Documentation & Developer Experience](#category-12-documentation--developer-experience)
14. [Appendix: RFC-2119 Conformance Terminology](#appendix-rfc-2119-conformance-terminology)

---

## 1. Scope & Philosophy

This specification establishes non-negotiable architectural and engineering standards for software created across this organization. 

### Core Axioms
- **Right-Sized Compliance**: Retain rigorous technical controls from NIST SP 800-218 (SSDF), OpenSSF, SLSA, and MITRE CWE Top 25 while eliminating enterprise SaaS, cloud infrastructure, and multi-tenant overhead.
- **Local Sovereignty**: All state, presets, and cache files reside strictly on the user’s local machine. Zero remote tracking, beaconing, or unvetted external network traffic.
- **Defense-in-Depth for Localhost**: Protect local web utilities against DNS rebinding, cross-origin browser abuse, and local multi-user eavesdropping via ephemeral tokens, W3C CSP headers, and POSIX least-privilege permissions.
- **Agent-First Executability**: Standards are structured with unambiguous RFC-2119 imperatives (`MUST`, `MUST NOT`, `SHOULD`) so downstream AI coding agents can ingest and enforce them without ambiguity.

---

## Category 1: Privacy by Design & Data Minimization

### 1.1 Zero Telemetry by Default
- The application **MUST NOT** initiate outbound network requests for telemetry, analytics, tracking, or crash diagnostics unless the user has given explicit, proactive opt-in consent.
- Update-check notifications **SHOULD NOT** query remote servers automatically on startup. If an update check is supported, it **MUST** require explicit invocation (e.g., `tool update-check`) or an explicit configuration setting (`check_updates: true`).

### 1.2 Local-Only State Residency
- All presets, cache entries, and temporary files **MUST** reside exclusively on the user's local filesystem in standard XDG paths (see [Category 4](#category-4-configuration--preset-architecture)).
- The application **MUST NOT** transmit user configuration or presets to any remote endpoint.

### 1.3 Path & Secret Sanitization in Logs
- When writing debug logs or crash traces to disk or stderr, the application **MUST** sanitize local paths by scrubbing the user's home directory username (e.g., transforming `/home/alice/project` into `~<USER>/project` or `[HOME]/project`).
- The application **MUST NOT** write environment variables, auth tokens, or API keys into log files or console traces.

### 1.4 State Ephemerality & Deterministic Purge
- Every application **MUST** provide a CLI flag or command to view and purge its stored local state:
  ```bash
  # View where data is stored
  mytool config paths
  # Reset all configuration and presets to factory default
  mytool config reset --force
  ```

---

## Category 2: Software Lifecycle Management (SLM) & Licensing

### 2.1 License Selection & Notices
- Every repository **MUST** be licensed under the **GNU Affero General Public License v3.0 or later** (`AGPL-3.0-or-later`).
- The repository root **MUST** contain an unmodified copy of the GNU AGPLv3 text named `LICENSE`.

### 2.2 SPDX Machine-Readable Headers (REUSE Specification)
- Every source code file **MUST** begin with standardized SPDX copyright and license identifiers in comment syntax appropriate to the language:
  ```python
  # SPDX-FileCopyrightText: 2026 [Author/Organization]
  # SPDX-License-Identifier: AGPL-3.0-or-later
  ```
  ```javascript
  // SPDX-FileCopyrightText: 2026 [Author/Organization]
  // SPDX-License-Identifier: AGPL-3.0-or-later
  ```

### 2.3 Single Source of Truth for Versioning (SemVer 2.0.0)
- The project **MUST** follow Semantic Versioning (`MAJOR.MINOR.PATCH`).
- Version numbers **MUST NOT** be hardcoded across individual source file headers.
- The version string **MUST** be declared in exactly one primary manifest:
  - Python: `__version__ = "1.0.0"` in `src/<package>/__init__.py` and/or `pyproject.toml`.
  - Node: `"version": "1.0.0"` in `package.json`.
- The CLI **MUST** expose `--version` (or `-v`), returning solely the tool name and version string:
  ```text
  mytool 1.0.0 (GNU AGPLv3+)
  ```

### 2.4 AGPL-3.0 Section 13 Network Interaction Compliance
- AGPL-3.0 Section 13 mandates that anyone interacting with the software through a network (including a local browser interacting with a local web server) **MUST** be offered an opportunity to receive the corresponding source code.
- **Web UI**: The web interface header or footer **MUST** display a persistent, visible link:
  ```html
  <a href="https://github.com/username/mytool" target="_blank" rel="noopener noreferrer">Source Code (GNU AGPLv3)</a>
  ```
- **CLI**: The `--version` command **MUST** include a link to the source repository.

### 2.5 Changelog & Git Commits
- Commit messages **MUST** adhere to the **Conventional Commits 1.0.0** format:
  `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, `build:`, `ci:`, `chore:`.
- Every repository **MUST** maintain a `CHANGELOG.md` adhering to [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).

---

## Category 3: UI & Human Interface Guidelines (CLI & Web UI)

### 3.1 Command-Line Interface (POSIX & GNU Guidelines)
- **Standard Option Naming**:
  - `-h`, `--help`: Display usage summary and exit with code `0`.
  - `-v`, `--version`: Display version information and exit with code `0`.
  - `-q`, `--quiet`: Suppress non-essential informational and progress output.
  - `--verbose`: Enable detailed operational logging.
  - `--config <path>`: Specify a custom configuration or preset file path.
  - `--json`: Output structured data in machine-readable JSON.
- **Subcommand Hierarchy**: Subcommands **MUST** use lowercase kebab-case (e.g., `mytool preset list`, `mytool preset export`).

### 3.2 Terminal Output & Color Discipline
- **Stream Discipline**:
  - `stdout`: Reserved exclusively for primary operational output (data, formatted reports, `--json`). Must remain clean and pipeable.
  - `stderr`: Reserved for progress bars, spinners, diagnostic messages, log lines, and errors.
- **TTY Detection & Color Disablement**:
  - ANSI colors and terminal styling **MUST ONLY** be emitted if `stdout.isatty()` (or equivalent) returns true.
  - The application **MUST** respect the [`NO_COLOR`](https://no-color.org) environment variable. If `NO_COLOR` is present (regardless of value), all color and ANSI styling **MUST** be suppressed.

### 3.3 Local Web UI Guidelines
- **Zero-Build, Self-Contained Architecture**:
  - Web interfaces **MUST** be written in modern Vanilla HTML5, CSS3, and JavaScript, served directly by the backend.
  - **Zero External CDNs**: All scripts, stylesheets, and fonts **MUST** be served locally from the backend. The application **MUST NOT** include external `<link>` or `<script>` tags targeting CDNs (Google Fonts, unpkg, cdnjs), ensuring 100% offline functionality.
- **Accessibility (WCAG 2.1 Level AA)**:
  - Contrast ratio between text and background **MUST** be at least `4.5:1` for normal text and `3:1` for large text.
  - All interactive elements **MUST** support full keyboard navigation (Tab order, focus rings, `Enter`/`Space` activation).
  - Form controls **MUST** have associated `<label>` tags with matching `for`/`id` attributes.
  - Modal dialogs **MUST** trap focus and close upon pressing the `Escape` key.
- **Preset State Visibility**:
  - The UI **MUST** clearly indicate the currently active preset and show an asterisk or "Unsaved Changes" indicator when dirty.
  - Destructive actions (resetting presets, deleting items) **MUST** require explicit confirmation.

---

## Category 4: Configuration & Preset Architecture

### 4.1 XDG Base Directory Conformance
Applications **MUST NOT** scatter arbitrary dotfiles in the user's root home folder (`~/.mytool`). They **MUST** adhere to the XDG Base Directory Specification across operating systems:

| Purpose | Linux / macOS Default | Windows Equivalent |
|---|---|---|
| **Config & Presets** | `~/.config/<app-name>/` | `%APPDATA%\<app-name>\` |
| **Data & State** | `~/.local/share/<app-name>/` | `%LOCALAPPDATA%\<app-name>\Data\` |
| **Cache & Temp** | `~/.cache/<app-name>/` | `%LOCALAPPDATA%\<app-name>\Cache\` |

### 4.2 Configuration File Format
- Presets and user configuration files **MUST** use **YAML** (`.yaml`) as the standard format.
- Generated configuration files **MUST** contain inline comments explaining default parameters and valid value ranges.

### 4.3 5-Tier Precedence Hierarchy
Configuration parameters **MUST** resolve deterministically in the following order (highest priority wins):
1. **CLI Arguments / GUI Overrides** (e.g. `--port 8080`)
2. **Environment Variables** (e.g. `MYTOOL_PORT=8080`)
3. **Workspace Config** (`./.mytool.yaml` in the current working directory)
4. **User Global Config / Presets** (`~/.config/mytool/config.yaml` or `presets/default.yaml`)
5. **Built-in Application Defaults** (defined in code)

### 4.4 Strict Schema Validation & Error Reporting
- Configuration and presets **MUST** be validated against a formal schema on load:
  - Python: Pydantic v2 model (`BaseModel`)
  - Node: Zod schema (`z.object({...})`)
- If a YAML file contains syntax errors or invalid fields, the application **MUST** fail fast and output a human-readable error with line number and expected type, rather than silently defaulting or crashing.

---

## Category 5: Secure Programming & Cybersecurity Hardening

### 5.1 Localhost Binding & Network Isolation
- When running an embedded or local web server, the server **MUST** bind strictly to `127.0.0.1` (IPv4) or `::1` (IPv6).
- The server **MUST NOT** bind to `0.0.0.0` (all interfaces) by default. Binding to external interfaces **MUST** require an explicit CLI flag (e.g., `--host 0.0.0.0`).

### 5.2 Ephemeral Startup Launch Token Authentication
To prevent malicious local browser tabs or cross-origin scripts from issuing unauthorized commands to `http://localhost:<port>`, the server **MUST** enforce launch token authentication:
1. On startup, the CLI generates a cryptographically secure random token (32-byte hex).
2. The CLI prints the authenticated URL to stderr: `http://127.0.0.1:8080/?token=4a7f8e...` and optionally opens the browser.
3. The web server sets a local `SameSite=Strict; HttpOnly` session cookie on first request with a valid token.
4. All subsequent API mutations (POST, PUT, DELETE) **MUST** validate this token or session cookie.

### 5.3 W3C Content Security Policy & Security Headers
Every HTTP response from the local web server **MUST** include the following protective headers:
```http
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none';
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer
```

### 5.4 MITRE CWE Top 25 Protections
- **CWE-502 (Insecure Deserialization)**:
  - In Python, `yaml.load()` is **STRICTLY PROHIBITED**. Applications **MUST** use `yaml.safe_load()`.
  - In Node, use safe schema parsers.
- **CWE-22 (Path Traversal)**:
  - User-provided file paths or preset names **MUST** be canonicalized using `os.path.realpath` / `fs.realpathSync`.
  - The application **MUST** verify that the resolved path resides within the designated base directory:
    ```python
    canonical = os.path.realpath(target_path)
    if not canonical.startswith(allowed_base_dir):
        raise PermissionError(f"Access denied: {target_path} escapes allowed directory")
    ```
- **CWE-78 (OS Command Injection)**:
  - Invoking external shell commands with raw string interpolation (`shell=True` in Python, `exec()` in Node) is **STRICTLY FORBIDDEN**.
  - All process invocations **MUST** pass discrete argument arrays:
    ```python
    subprocess.run(["git", "status", "--porcelain"], check=True)
    ```

### 5.5 POSIX Least-Privilege Filesystem Permissions
When creating configuration directories and preset files:
- Directory permissions **MUST** be set to mode `0700` (`rwx------`) on POSIX systems.
- File permissions **MUST** be set to mode `0600` (`rw-------`) on POSIX systems.
- Safe temporary files **MUST** be created using standard library utilities (`tempfile.NamedTemporaryFile` in Python, `node:fs.mkdtemp` in Node). Never use hardcoded predictable paths in `/tmp`.

### 5.6 Cryptographic & Entropy Standards (NIST SP 800-131A)
- Security tokens, secret keys, and nonces **MUST** use cryptographically secure pseudo-random number generators (CSPRNG):
  - Python: `secrets.token_hex(32)`
  - Node: `node:crypto.randomBytes(32).toString('hex')`
- General pseudo-random generators (`random.random()` or `Math.random()`) **MUST NOT** be used for any security-sensitive operations.
- Cryptographic hashes **MUST** use SHA-256 or stronger. MD5 and SHA-1 are **STRICTLY PROHIBITED**.

### 5.7 OWASP Top 10 for LLM Applications (When AI is Integrated)
- **Prompt Injection (LLM01)**: System prompts and instructions **MUST** be structurally segregated from untrusted user files or inputs.
- **Sensitive Information Disclosure (LLM02)**: API keys (OpenAI, Anthropic, Gemini) **MUST NOT** be persisted into presets, written to disk logs, or displayed in the UI. They **MUST** be read from environment variables or secure memory.
- **Excessive Agency (LLM06)**: If an AI feature proposes file edits or command execution, the tool **MUST** require explicit user confirmation before applying destructive changes.

---

## Category 6: Supply Chain Security & Packaging

### 6.1 OpenSSF Scorecard Controls
- All third-party GitHub Actions in `.github/workflows/` **MUST** be pinned to full 40-character commit SHAs, annotated with the version tag:
  ```yaml
  uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
  ```
- Repositories **MUST** enforce automated vulnerability auditing on dependencies via `pip-audit` (Python) or `npm audit` (Node) in CI.
- Automated secret scanning (e.g., `gitleaks`) **MUST** run on all pull requests and pushes.

### 6.2 SLSA Build Provenance & Checksums (Levels 1 & 2)
- All official distribution artifacts (wheels, tarballs) **MUST** be built automatically in GitHub Actions runners (never manually from local laptops).
- Every release **MUST** generate and publish a `checksums.txt` file containing SHA-256 hashes of all released assets.
- Releases **SHOULD** attach SLSA provenance generated via `slsa-framework/slsa-github-generator`.

### 6.3 Software Bill of Materials (SBOM - NIST SP 800-218)
- Every release workflow **MUST** generate and attach a standard CycloneDX or SPDX JSON Software Bill of Materials (`sbom.json`).

### 6.4 Packaging & Distribution Standards
- **Python**: Projects **MUST** use `pyproject.toml` (standard build backend such as `hatchling` or `flit-core`) declaring CLI console scripts, enabling execution via `pipx run <tool>`.
- **Node**: Projects **MUST** use modern ES Modules (`"type": "module"`) with a declared `"bin"` entry point, enabling execution via `npx <tool>`.

---

## Category 7: Testing & Quality Assurance

### 7.1 CLI Subprocess & Integration Tests
- In addition to internal unit tests, the test suite **MUST** include end-to-end CLI tests that invoke the entry point as a subprocess.
- CLI tests **MUST** assert:
  - Correct exit codes (`0` for success, non-zero for errors).
  - Clean separation between `stdout` (data/results) and `stderr` (logs/status).
  - Validation of `--help`, `--version`, and `--json` outputs.

### 7.2 Filesystem & Environment Isolation
- Tests **MUST NOT** write to or modify the developer's real `~/.config` or user directory.
- All file tests **MUST** execute inside isolated temporary directories (e.g., pytest's `tmp_path` fixture or `node:os.tmpdir()`), with environment variables like `XDG_CONFIG_HOME` redirected to the temporary path.

### 7.3 Deterministic Testing
- Unit tests **MUST NOT** make live external network requests. All network interactions **MUST** be mocked or stubbed.

---

## Category 8: Observability, Logging & Error Handling

### 8.1 Standard Exit Codes
Applications **MUST** exit with consistent, deterministic status codes:
- `0`: Success.
- `1`: General operational failure (e.g. file missing, invalid preset content).
- `2`: Command line usage / syntax error (e.g. invalid flag or argument).
- `130`: Terminated by user (`SIGINT` / `Ctrl+C`).

### 8.2 Log Levels & Flag Mapping
- **Default**: Informational messages, standard output, clean errors.
- **`-q` / `--quiet`**: Suppress all output except critical fatal errors and primary data.
- **`--verbose` / `--debug`**: Output timestamps, debug log statements, and full diagnostic context to `stderr`.

### 8.3 Safe Error Output (No Leaked Stack Traces)
- By default in production execution, unhandled operational errors **MUST** present a concise, actionable one-line message on `stderr`:
  `Error: Preset file 'default.yaml' contains invalid syntax on line 4.`
- Full stack traces **MUST ONLY** be displayed when the `--debug` or `--verbose` flag is explicitly provided.

---

## Category 9: Portability & Cross-Platform Compatibility

### 9.1 Universal UTF-8 Encoding
- All file read and write operations **MUST** explicitly specify `encoding="utf-8"`:
  ```python
  with open(path, "r", encoding="utf-8") as f:
      content = f.read()
  ```
- Applications **MUST NOT** rely on the ambient system locale encoding (e.g. Windows ANSI code pages).

### 9.2 Universal UTC Timestamps (ISO 8601)
- All stored, logged, or emitted timestamps **MUST** follow ISO 8601 UTC format:
  `YYYY-MM-DDTHH:MM:SSZ`.

### 9.3 Platform-Agnostic File Paths
- Hardcoded slash separators (`/` or `\`) in code strings are **STRICTLY PROHIBITED**.
- Paths **MUST** be constructed using `pathlib.Path` in Python or `node:path` in Node.

### 9.4 Git Line Ending Normalization
- Every repository **MUST** contain a `.gitattributes` file enforcing consistent LF line endings across all platforms:
  ```gitattributes
  * text=auto eol=lf
  *.py text diff=python
  *.js text
  *.json text
  *.yaml text
  *.md text
  ```

---

## Category 10: Process Lifecycle & Performance

### 10.1 Sub-Second Startup Latency
- Fast path commands (`--help`, `--version`, CLI flag validation) **MUST** execute in under **200 milliseconds**.
- Heavy dependencies (e.g. web frameworks, large schema validators, GUI libraries) **MUST** be lazily imported inside the specific subcommand function where they are required.

### 10.2 Streaming & Memory Discipline
- Commands operating on files of arbitrary size **MUST** stream data in chunks rather than reading entire files into RAM at once.

### 10.3 Graceful Signal Handling
- The application **MUST** install signal handlers for `SIGINT` (`Ctrl+C`) and `SIGTERM`.
- When interrupted, the application **MUST**:
  1. Immediately cease background workers.
  2. Flush and close any open write file handles.
  3. Clean up any temporary files or lockfiles.
  4. Exit cleanly with status code `130` without dumping an unhandled `KeyboardInterrupt` traceback.

---

## Category 11: Interoperability & Unix Composability

### 11.1 Standard Input Piping (`-`)
- Whenever a command accepts a file input path argument, passing `-` **MUST** cause the application to read from `sys.stdin` (e.g., `cat data.txt | mytool -`).

### 11.2 Machine-Readable Structured Output
- Commands that produce tabular or multi-field data **MUST** provide a `--json` or `--ndjson` (newline-delimited JSON) flag.
- When `--json` is enabled:
  - Primary JSON data **MUST** be printed strictly to `stdout`.
  - All logs, spinners, or progress messages **MUST** be redirected to `stderr` or suppressed.
  - The JSON output **MUST** be valid, parseable JSON suitable for piping directly into `jq` or an AI agent tool.

---

## Category 12: Documentation & Developer Experience

### 12.1 Standard README.md Architecture
Every repository **MUST** maintain a `README.md` structured with the following standard sections:
1. **Title & One-Line Pitch**: High-level statement of what the utility accomplishes.
2. **Badges**: License (AGPLv3), CI build status, supported runtime versions.
3. **30-Second Quickstart**: Exactly 3 commands showing how to install, run, and execute a basic task.
4. **CLI Options Reference**: Clear table detailing all subcommands and flags.
5. **Configuration & Presets**: Annotated YAML sample showing default configuration options and paths.
6. **AGPL-3.0 License Notice**: Explicit statement of open source terms.

### 12.2 Coordinated Vulnerability Disclosure (`SECURITY.md`)
- Every repository **MUST** include a `SECURITY.md` file specifying how security researchers can disclose vulnerabilities privately (via GitHub Private Vulnerability Reporting), with a commitment to acknowledge reports within 72 hours.

### 12.3 In-Code Documentation & Commenting Standards

Code comments and docstrings bridge the gap between mechanical execution and human comprehension. High-quality in-code documentation is essential for maintainability, security audits, and reliable AI-assisted pair programming.

#### 12.3.1 Philosophy: Explaining Intent ("Why, Not What")
- Code describes *what* is executed and *how*; comments **MUST** explain *why* (architectural intent, non-obvious business logic, performance trade-offs, security invariants, or OS-specific quirks).
- Comments **MUST NOT** merely restate or paraphrase the code. Redundant comments that narrate obvious syntax (e.g., `total += 1  # Add 1 to total`) add noise and **MUST** be avoided.
- Expressive variable naming, small single-responsibility functions, and explicit static type annotations are the primary tools for self-documenting code. Comments **MUST NOT** be used as a patch for unreadable code—refactor the code first.

#### 12.3.2 Module & File-Level Docstrings
- Every source file **MUST** begin with the mandatory SPDX license header ([Category 2.2](#22-spdx-machine-readable-headers-reuse-specification)), followed immediately by a module-level docstring or top-level block comment.
- The module docstring **MUST** succinctly summarize the file's primary architectural responsibility, scope, and any major invariants:
  ```python
  # SPDX-FileCopyrightText: 2026 [Author/Organization]
  # SPDX-License-Identifier: AGPL-3.0-or-later

  """Configuration schema and XDG preset management for the application."""
  ```

#### 12.3.3 Public Contract Documentation (Google Style & JSDoc)
- All public modules, public classes, public functions/methods, and CLI command handlers **MUST** have structured contract documentation.
- **Python**: **MUST** adhere to the **Google Python Style Guide** docstring format ([PEP 257](https://peps.python.org/pep-0257/) compliant).
- **Node / JavaScript / TypeScript**: **MUST** adhere to standard **JSDoc 3** / **TSDoc** block comments (`/** ... */`).
- **POSIX Shell**: Functions **MUST** be preceded by a comment describing purpose, arguments (`$1`, `$2`), environment variables consumed, and exit status.

#### 12.3.4 Lean Typing Synergy (Zero Type Redundancy)
- When static type hints (Python `typing`, TypeScript, or Pydantic/Zod schemas) are present in the signature, docstrings **MUST NOT** duplicate the type identifier.
- Focus parameter documentation strictly on semantic meaning, valid ranges, units of measurement, or constraints:
  ```python
  # CORRECT: Lean Google Style (Types in signature, semantic description in docstring)
  def sanitize_log_path(path: str, max_depth: int = 5) -> str:
      """Scrub local username and home directory from log strings.

      Args:
          path: The raw filesystem path string to sanitize.
          max_depth: Maximum directory traversal depth to scrub.

      Returns:
          Sanitized path string with the user home directory replaced by '~<USER>'.
      """
  ```
  ```javascript
  // CORRECT: Lean JSDoc (TypeScript or Zod handles types, JSDoc describes semantics)
  /**
   * Resolve and canonicalize preset file path within the allowed presets directory.
   *
   * @param {string} presetName - Kebab-case identifier of the preset.
   * @returns {string} Absolute, canonicalized path to the preset YAML file.
   * @throws {Error} If path traversal outside presets directory is detected.
   */
  ```

#### 12.3.5 Side Effects, Exceptions & Security Invariants
- Functions that perform I/O, mutate state, acquire locks, or raise explicit runtime errors **MUST** document these behaviors using `Raises:` (Python) or `@throws` (JSDoc).
- Security-critical logic (e.g. constant-time string comparison, path canonicalization, permission bitmasking) **MUST** include an explanatory inline comment citing the invariant:
  ```python
  # SECURITY: Use constant-time comparison to prevent timing side-channel attacks on launch tokens
  if not secrets.compare_digest(candidate_token, expected_token):
      raise PermissionError("Invalid token")
  ```

#### 12.3.6 Standardized Annotation Tags
- Actionable tracking comments **MUST** follow standardized uppercase tags:
  - `TODO(username or #issue): <actionable task>`: Planned work with explicit owner or issue reference.
  - `FIXME: <description>`: Known fragility, temporary workaround, or bug requiring imminent resolution.
  - `NOTE: <description>`: Essential architectural context or non-obvious prerequisite for future maintainers.
  - `SECURITY: <rationale>`: Explicit declaration of security invariant or defense-in-depth measure.
- **No Dead Code**: Commented-out blocks of dead code are **STRICTLY PROHIBITED** in committed files. Version control history preserves past implementations.

#### 12.3.7 Linter & Static Analysis Exemption Discipline
- Whenever suppressing a linter, type-checker, or security scanner warning (e.g., `# noqa`, `# type: ignore`, `/* eslint-disable-next-line */`, `# shellcheck disable=SC...`), the suppression comment **MUST** include an inline justification explaining why the exception is safe:
  ```python
  # noqa: S101 - Assertions are guaranteed safe in unit test fixtures
  assert result.exit_code == 0
  ```
  ```bash
  # shellcheck disable=SC2086 - Word splitting is intentional for passing discrete CLI arguments
  exec "$CLI_BIN" $EXTRA_FLAGS "$@"
  ```

#### 12.3.8 AI Agent Comment Hygiene & Preservation
- AI coding agents **MUST NOT** strip, truncate, or overwrite existing docstrings, explanatory comments, or license notices during refactoring or code generation.
- AI coding agents **MUST NOT** generate conversational narrative comments (e.g., `# Now we initialize the variable`, `# Next step: loop through items`).
- When modifying function signatures or return types, AI agents **MUST** immediately synchronize the associated docstring parameter documentation.

---

## Appendix: RFC-2119 Conformance Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).
