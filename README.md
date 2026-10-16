# Open Source Software Standards Kit

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Standards: 12-Category](https://img.shields.io/badge/Standards-12--Category-emerald.svg)](STANDARDS.md)
[![Agent: Compliant](https://img.shields.io/badge/AI_Agent-Compliant-violet.svg)](AGENTS.md)

An authoritative, lightweight, machine-actionable software standards kit and project scaffolding template for standalone open-source utilities (CLI and local web servers on `localhost`).

All projects governed by this standards kit:
- Have **no user accounts** and collect **zero telemetry**.
- Store **zero PII**, persisting user preferences strictly as local YAML presets in standard XDG directories.
- Are distributed under the **GNU Affero General Public License v3.0 or later** (`AGPL-3.0-or-later`).
- Feature multi-layered cybersecurity defense (OpenSSF Scorecard, SLSA, NIST SSDF, MITRE CWE Top 25, POSIX least-privilege permissions, and W3C Content Security Policies).

---

## The 12 Standards Categories

| Category | Specification Document | Primary Enforcements |
|---|---|---|
| **1. Privacy by Design** | [`STANDARDS.md#category-1`](STANDARDS.md#category-1-privacy-by-design--data-minimization) | Zero telemetry; 100% local data residency; username log scrubbing; `--reset-config` |
| **2. SLM & Licensing** | [`STANDARDS.md#category-2`](STANDARDS.md#category-2-software-lifecycle-management-slm--licensing) | GNU AGPL-3.0; SPDX file headers; SemVer 2.0; AGPLv3 §13 source notice in UI & CLI |
| **3. UI Guidelines** | [`STANDARDS.md#category-3`](STANDARDS.md#category-3-ui--human-interface-guidelines-cli--web-ui) | POSIX/GNU flags; stdout/stderr separation; `NO_COLOR`; WCAG 2.1 AA accessible web UI; zero CDNs |
| **4. Configuration** | [`STANDARDS.md#category-4`](STANDARDS.md#category-4-configuration--preset-architecture) | XDG Base Directories; YAML presets with comments; Pydantic/Zod schemas; 5-tier precedence |
| **5. Secure Programming** | [`STANDARDS.md#category-5`](STANDARDS.md#category-5-secure-programming--cybersecurity-hardening) | 127.0.0.1 bind only; ephemeral launch token auth; W3C CSP headers; safe YAML; path canonicalization |
| **6. Supply Chain** | [`STANDARDS.md#category-6`](STANDARDS.md#category-6-supply-chain-security--packaging) | OpenSSF Scorecard (pinned action SHAs, secret scan, audit); SLSA 1-2 provenance; SBOM; SHA-256 |
| **7. Testing & QA** | [`STANDARDS.md#category-7`](STANDARDS.md#category-7-testing--quality-assurance) | Subprocess CLI exit-code & stream tests; isolated temporary directory fixtures (`tmp_path`) |
| **8. Observability** | [`STANDARDS.md#category-8`](STANDARDS.md#category-8-observability-logging--error-handling) | Standard exit codes (0/1/2/130); clean single-line error messages without stack traces |
| **9. Portability** | [`STANDARDS.md#category-9`](STANDARDS.md#category-9-portability--cross-platform-compatibility) | Explicit `encoding="utf-8"`; ISO 8601 UTC timestamps; `pathlib.Path` / `node:path`; Git LF |
| **10. Performance** | [`STANDARDS.md#category-10`](STANDARDS.md#category-10-process-lifecycle--performance) | Sub-200ms CLI startup; lazy imports for web servers; streaming I/O; graceful `SIGINT` handling |
| **11. Composability** | [`STANDARDS.md#category-11`](STANDARDS.md#category-11-interoperability--unix-composability) | Stdin piping support (`-`); machine-readable `--json` output flag |
| **12. Documentation** | [`STANDARDS.md#category-12`](STANDARDS.md#category-12-documentation--developer-experience) | 6-part standard `README.md`; `SECURITY.md` private vulnerability disclosure policy |

---

## How to Use This Kit

### 1. Ingesting by Downstream AI Agents
When initializing a new software project with an AI coding assistant (such as Antigravity, Claude Code, Cursor, or Copilot):
- Copy [`AGENTS.md`](AGENTS.md) and [`.agents/rules/enforce-standards.md`](.agents/rules/enforce-standards.md) into the new repository root.
- The AI agent will automatically detect and enforce all 12 standards when creating or modifying code.

### 2. Scaffolding a New Python Utility
To start a new Python utility adhering to all standards:
```bash
# 1. Copy the starter scaffold
cp -r templates/python my-new-python-tool
cp -r templates/common/* my-new-python-tool/
cp templates/common/.* my-new-python-tool/ 2>/dev/null || true

# 2. Enter and install in development mode
cd my-new-python-tool
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev,web]"

# 3. Test CLI and run test suite
mytool --help
pytest
```

### 3. Scaffolding a New Node Utility
To start a new Node utility adhering to all standards:
```bash
# 1. Copy the starter scaffold
cp -r templates/node my-new-node-tool
cp -r templates/common/* my-new-node-tool/
cp templates/common/.* my-new-node-tool/ 2>/dev/null || true

# 2. Enter and install dependencies
cd my-new-node-tool
npm install

# 3. Test CLI and run test suite
node src/index.js --help
npm test
```

### 4. Auditing a Project for Standards Compliance
Run the compliance scanner directly from any project directory:

```bash
check-standards
```
*(This streams the latest compliance scanner directly from your private GitHub repository using `$STANDARDS_TOKEN`).*

The scanner audits:
- Presence of SPDX AGPL-3.0 headers across all code files.
- Absence of hardcoded version numbers in code file headers.
- Presence of GNU AGPLv3 `LICENSE` and AGPL §13 source link in Web UI.
- Absence of banned anti-patterns (`yaml.load()`, `shell=True`, default `0.0.0.0` bindings).
- Universal UTF-8 encoding declarations on file operations.

---

## Environment Setup (`check-standards`)

To configure the `check-standards` command on your laptop or remote VM:

### 1. Add Token & Alias to `~/.bashrc`
Run the following in your terminal (replace `YOUR_GITHUB_PAT_TOKEN` with your actual token):

```bash
# Set your private standards token
echo 'export STANDARDS_TOKEN="YOUR_GITHUB_PAT_TOKEN"' >> ~/.bashrc

# Set the check-standards command shortcut
echo 'alias check-standards='\''curl -sSL -H "Authorization: Bearer $STANDARDS_TOKEN" -H "Accept: application/vnd.github.v3.raw" https://api.github.com/repos/joelontheroad/Software-standards/contents/scripts/check-compliance.py | python3 - .'\' >> ~/.bashrc

# Reload shell configuration
source ~/.bashrc
```

### 2. Verify
```bash
check-standards
```

---

## Multi-Machine & Remote VM Architecture (Desktop + HP Server VM)

When developing across multiple environments (such as a local workstation and an isolated VM on an HP server), follow this architectural model:

### 1. Separation of Concerns: Public vs. Internal Artifacts
End users and public Git repositories **do not** need your internal AI agent rules or prompt files:
- **Public Artifacts (Committed to Git)**: Application source code, unit tests (`tests/`), `LICENSE` (AGPLv3), `README.md`, and `SECURITY.md`.
- **Internal Governance (Kept Local or `.gitignore`'d)**: `AGENTS.md`, `.agents/rules/`, and prompt notes.

### 2. Keeping AI Rules Out of Public Git Repositories
To prevent internal AI directives from polluting your public repositories, add them to `.gitignore` in your target projects:
```gitignore
# Internal AI Agent Directives & Local Rules
.agents/
AGENTS.md
```
- **On your desktop & on your VM**: Copy `AGENTS.md` and `.agents/rules/enforce-standards.md` directly into the project folder so local AI agents enforce the rules.
- **On GitHub**: Git completely ignores these files. Your public repository remains pristine and professional.

### 3. Enforcing Compliance Across Environments (3-Layer Gate)
Even with agent files `.gitignore`'d, compliance is guaranteed across all machines:

1. **Layer 1: Authoring (Local / VM)**:
   - **Option A**: Copy `AGENTS.md` into the project root and `enforce-standards.md` into `.agents/rules/` (both ignored by git).
   - **Option B (Global IDE Rule)**: In Antigravity, place the rule in your Global Customization Root (`~/.gemini/config/rules/enforce-standards.md`). Every project opened in the IDE automatically adheres to the 12 standards without needing any local files in the project.
2. **Layer 2: Local Pre-Commit Audit**:
   - Run the compliance check from any project directory:
     ```bash
     check-standards
     ```
3. **Layer 3: Centralized GitHub Actions CI Gate (Private Repo + Token)**:
   - Configure the project's `.github/workflows/ci.yml` to checkout the private standards repo securely:
     ```yaml
     - name: Checkout Private Standards Repository
      uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
      with:
        repository: joelontheroad/Software-standards
        token: ${{ secrets.STANDARDS_TOKEN }}
        path: .standards

    - name: Run Standards Compliance Check
      run: python3 .standards/scripts/check-compliance.py .
     ```
   - **Advantage**: Individual projects never need a copy of the audit script committed, the standards repo remains 100% private, and whenever you update a standard rule centrally, **all your repositories immediately inherit the new check on their next CI run**.

---

## Migrating Existing Projects to These Standards

When bringing an existing project into compliance (either on your laptop or on a remote VM), use one of the following prompts with your AI coding assistant:

### Option A: The "Audit-First" Interactive Prompt *(Recommended for complex projects)*
> Analyzes the codebase, identifies non-compliant patterns, and presents an implementation plan before touching code.

```markdown
/plan We are migrating this repository to comply with our organization's 12 Open Source Software Standards.

Please perform a compliance audit of this codebase and prepare a migration plan:

1. RUN AUDIT:
   Execute the compliance scanner:
   check-standards

2. GAP ANALYSIS:
   Inspect the code and report on:
   - Licensing & SPDX: Are all source files prefixed with SPDX AGPL-3.0 headers? Does root have the AGPLv3 LICENSE? Is versioning declared in a single source of truth?
   - Privacy & Config: Are user configs/presets stored in standard XDG paths as YAML? Is there zero telemetry and a `--reset-config` option?
   - Cybersecurity: If a web server exists, does it bind strictly to 127.0.0.1 with ephemeral token authentication and W3C CSP headers? Are there any unsafe `yaml.load()`, `shell=True`, or path traversal vectors?
   - CLI & UI: Does the CLI separate stdout (data/json) from stderr (logs/status)? Does it honor NO_COLOR? Does the Web UI/CLI include the AGPL-3.0 Section 13 source link?
   - Tests: Are there subprocess CLI tests verifying exit codes and stream separation?

3. PRESENT PLAN:
   Present an implementation plan detailing the exact files to be updated or added. Do not modify any code until I approve the plan.
```

---

### Option B: The Direct "Migrate & Verify" Prompt *(Best for lightweight utilities)*
> Autonomously refactors code for compliance and iterates until the compliance scanner passes.

```markdown
We need to update this existing project to strictly comply with our 12 Open Source Software Standards.

Please update this codebase following this execution order:

1. COPY DIRECTIVES:
   - Copy `AGENTS.md` into the root directory and `enforce-standards.md` into `.agents/rules/` (ensure `.gitignore` ignores both).
   - Ensure the root `LICENSE` is the official GNU AGPLv3.

2. CODEBASE UPDATES:
   - Headers: Add `SPDX-FileCopyrightText` and `SPDX-License-Identifier: AGPL-3.0-or-later` to the top of every code file.
   - Versioning: Ensure the version number is maintained in a single place (`pyproject.toml` or `package.json`), never duplicated in file headers.
   - Privacy & Config: Ensure presets/configs use XDG base directories (`~/.config/<app>`), YAML format with schema validation (Pydantic/Zod), and add a `--reset-config` command.
   - Security: Replace any `yaml.load()` with `yaml.safe_load()`. Canonicalize all paths with `realpath`. If a web server exists, ensure it defaults strictly to `127.0.0.1` with ephemeral token authentication and W3C CSP headers.
   - AGPL §13 Notice: Ensure Web UI footer and CLI `--version` output prominently link to the source repository.
   - CLI Disciplines: Ensure stdout is reserved for data/JSON, stderr for logs/status, and support `-` for stdin.
   - Encodings: Ensure all file read/write calls explicitly specify `encoding="utf-8"`.

3. VERIFY:
   - Run the compliance check and fix any errors until it outputs [PASS]:
     check-standards
   - Run the project test suite.
```



---

## Repository Structure

```
Software-standards/
├── STANDARDS.md                     # Complete 12-category master reference manual
├── AGENTS.md                        # Machine-ingestible instruction directive for AI coding agents
├── LICENSE                          # GNU Affero General Public License v3.0
├── README.md                        # Standards kit overview and usage guide
├── .agents/
│   └── rules/
│       └── enforce-standards.md     # Antigravity/Agent workspace rule
├── scripts/
│   └── check-compliance.py         # Automated compliance audit script
└── templates/
    ├── common/                      # Shared legal, security & CI templates
    │   ├── LICENSE                  # GNU AGPL-3.0 text
    │   ├── SECURITY.md              # NIST SSDF compliant vulnerability policy
    │   ├── CONTRIBUTING.md          # Developer contribution guide & commit rules
    │   ├── .gitignore               # Comprehensive ignores (Python, Node, secrets)
    │   ├── .gitattributes           # Universal LF line endings
    │   └── .github/
    │       └── workflows/
    │           ├── ci.yml           # OpenSSF-compliant CI (lint, audit, test)
    │           └── release.yml      # Automated release with SLSA provenance & SBOM
    ├── python/                      # Python CLI + FastAPI starter scaffold
    │   ├── pyproject.toml           # Hatchling packaging with pipx console script
    │   ├── src/app/
    │   │   ├── __init__.py          # Single source of version truth
    │   │   ├── cli.py               # POSIX CLI with lazy loading & stream separation
    │   │   ├── config.py            # XDG YAML preset manager (POSIX mode 0700/0600)
    │   │   ├── server.py            # FastAPI server (127.0.0.1, CSP, ephemeral token)
    │   │   └── web/index.html       # Zero-build accessible HTML/CSS UI with AGPL link
    │   └── tests/
    │       └── test_cli.py          # Subprocess exit-code & security test suite
    └── node/                        # Node CLI + Hono starter scaffold
        ├── package.json             # Modern ESM packaging with npx bin definition
        ├── src/
        │   ├── index.js             # POSIX CLI with lazy loading & signal handling
        │   ├── config.js            # XDG YAML preset manager with Zod validation
        │   ├── server.js            # Hono server (127.0.0.1, CSP, ephemeral token)
        │   └── web/index.html       # Zero-build accessible HTML/CSS UI with AGPL link
        └── tests/
            └── cli.test.js          # Node test suite verifying exit codes and paths
```

---

## License

This standards kit and all templates are licensed under the **GNU Affero General Public License v3.0 or later** ([`LICENSE`](LICENSE)).
