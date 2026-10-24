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
| **1. Privacy by Design** | [`STANDARDS.md#category-1`](STANDARDS.md#category-1-privacy-by-design--data-minimization) | Zero telemetry; Freedesktop XDG local data residency (`basedir-spec`); username scrubbing; permanent data erasure (Desktop Trash strictly prohibited for state resets); zero unsolicited autostart |
| **2. SLM, Compatibility & Licensing** | [`STANDARDS.md#category-2`](STANDARDS.md#category-2-software-lifecycle-management-slm-compatibility--licensing) | GNU AGPL-3.0; SPDX file headers; SemVer 2.0; AGPLv3 §13 source notice in UI & CLI; strict preservation of user-facing functionality (CLI commands/flags, presets, UI) with freedom to refactor internals |
| **3. UI Guidelines** | [`STANDARDS.md#category-3`](STANDARDS.md#category-3-ui--human-interface-guidelines-cli--web-ui) | POSIX/GNU flags (`--no-browser`); stdout/stderr separation; `NO_COLOR`; clickable CLI URLs (OSC 8); auto-browser launch; WCAG 2.1 AA accessible web UI; zero CDNs; safe `.desktop` launchers without shell wrappers; zero silent clipboard writes |
| **4. Configuration** | [`STANDARDS.md#category-4`](STANDARDS.md#category-4-configuration--preset-architecture) | Freedesktop XDG Base Directories (`basedir-spec` v0.8); YAML presets with comments; Pydantic/Zod schemas; 5-tier precedence |
| **5. Secure Programming** | [`STANDARDS.md#category-5`](STANDARDS.md#category-5-secure-programming--cybersecurity-hardening) | 127.0.0.1 bind only; ephemeral launch token auth; W3C CSP headers; safe YAML; path canonicalization & safe RFC 8089 File URIs; Shared MIME-info database with `nosniff` |
| **6. Supply Chain** | [`STANDARDS.md#category-6`](STANDARDS.md#category-6-supply-chain-security--packaging) | OpenSSF Scorecard (pinned action SHAs, secret scan, audit); SLSA 1-2 provenance; SBOM; SHA-256 |
| **7. Testing & QA** | [`STANDARDS.md#category-7`](STANDARDS.md#category-7-testing--quality-assurance) | Subprocess CLI exit-code & stream tests; isolated temporary directory fixtures (`tmp_path`) |
| **8. Observability** | [`STANDARDS.md#category-8`](STANDARDS.md#category-8-observability-logging--error-handling) | Standard exit codes (0/1/2/130); clean single-line error messages without stack traces |
| **9. Portability** | [`STANDARDS.md#category-9`](STANDARDS.md#category-9-portability--cross-platform-compatibility) | Universal UTF-8 encoding on all file/stream I/O; ISO 8601 UTC timestamps; `pathlib.Path` / `node:path`; Git LF |
| **10. Performance** | [`STANDARDS.md#category-10`](STANDARDS.md#category-10-process-lifecycle--performance) | Sub-200ms CLI startup; lazy imports for web servers; streaming I/O; graceful `SIGINT` handling |
| **11. Composability** | [`STANDARDS.md#category-11`](STANDARDS.md#category-11-interoperability--unix-composability) | Stdin piping support (`-`); machine-readable `--json` output flag; File Manager D-Bus (`org.freedesktop.FileManager1`) with headless pre-flight |
| **12. Documentation** | [`STANDARDS.md#category-12`](STANDARDS.md#category-12-documentation--developer-experience) | 6-part standard `README.md`; `SECURITY.md` policy; Google Style / JSDoc docstrings; "why, not what" comment discipline |

---

## How to Use This Kit

### 1. Scaffolding a New Project (`new-project.sh`)

Use the automated scaffolding script to initialize a new, 100% standards-compliant Python utility in seconds.

#### A. Scaffolding into an Existing Directory / GitHub Repo (Recommended)
If you already created and cloned a repository on GitHub (or are sitting inside an existing directory):

```bash
git clone git@github.com:joelontheroad/Software-standards.git /tmp/standards
/tmp/standards/scripts/new-project.sh \
  --name <project-name> \
  --desc "<Short description of your utility>" \
  --dest . \
  --force \
  --install
rm -rf /tmp/standards
```
*(The `--dest .` flag targets the current directory; `--force` allows scaffolding into an existing repository even if it already contains files such as an initial README or .gitignore).*

#### B. Scaffolding into a New Subdirectory
To create a brand-new folder from anywhere on your system:

```bash
git clone git@github.com:joelontheroad/Software-standards.git /tmp/standards
/tmp/standards/scripts/new-project.sh \
  --name <project-name> \
  --desc "<Short description of your utility>" \
  --install
rm -rf /tmp/standards
```

#### C. Remote One-Liner (curl + `$STANDARDS_TOKEN`)
On any remote VM or server without cloning:

```bash
curl -sSL -H "Authorization: Bearer $STANDARDS_TOKEN" -H "Accept: application/vnd.github.v3.raw" \
  https://api.github.com/repos/joelontheroad/Software-standards/contents/scripts/new-project.sh | bash -s -- \
  --name <project-name> \
  --desc "<Short description of your utility>" \
  --dest . \
  --force \
  --install
```

#### D. Local Development (From inside this repository)
```bash
./scripts/new-project.sh -n <project-name> --desc "<Short description>" --install
```

---

### `new-project.sh` CLI Flags Reference

| Flag | Description | Default |
|---|---|---|
| `-n, --name <name>` | Project and CLI command name (kebab-case; auto-inferred from folder if running with `--dest .`) | *Required or auto-inferred* |
| `-d, --dest <path>` | Destination directory path | `./<project-name>` |
| `--desc <text>` | Short utility description (optional) | `"A standard-compliant open-source utility"` |
| `--author <name>` | Author or organization name | `"joelontheroad"` |
| `--email <email>` | Author email address | `"author@example.com"` |
| `-f, --force` | Overwrite or scaffold into directory even if it contains files | `false` |
| `--install` | Automatically create virtualenv and install in editable mode | `false` |
| `-h, --help` | Display usage information and exit | — |

---

### What `new-project.sh` Does Automatically

1. **Governance & Legal Files**: Copies official GNU AGPL-3.0 [`LICENSE`](LICENSE), [`SECURITY.md`](templates/common/SECURITY.md), [`CONTRIBUTING.md`](templates/common/CONTRIBUTING.md), [`.gitattributes`](templates/common/.gitattributes), and [`.gitignore`](templates/common/.gitignore).
2. **Python Scaffold**: Copies starter codebase (`pyproject.toml`, `src/app/`, `tests/test_cli.py`).
3. **AI Agent Directives**: Injects [`AGENTS.md`](AGENTS.md) and [`.agents/rules/enforce-standards.md`](.agents/rules/enforce-standards.md) (automatically ignored by `.gitignore` so public GitHub commits stay clean).
4. **Configuration Customization**: Replaces all placeholders (`mytool`, author, description) across all source code, config, and HTML files.
5. **Git Initialization**: Reinitializes or configures the Git repository (`main` branch).
6. **Environment Setup**: If `--install` is passed, creates `.venv` and runs `pip install -e ".[dev,web]"`.
7. **Instant Audit**: Executes [`scripts/check-compliance.py`](scripts/check-compliance.py) to guarantee **`[PASS]`** out of the box.
8. **Generates AI Prompt**: Displays the ready-to-use prompt and saves it directly to `.agents/kickoff.md` inside the new project.

> [!TIP]
> **Architectural Guidance**: See the [Scaffolding and AI Prompt Q&A Guide](docs/scaffolding-and-ai-prompt-qa.md) for detailed analysis of the structural necessity of Project Name during scaffolding versus the mission-critical semantic role of Project Description in AI prompting.

---

### AI Coding Agent Kickoff Prompt

Once your project is scaffolded, open the project directory in your AI assistant (e.g., Antigravity, Claude Code, Cursor) and paste the prompt saved in `.agents/kickoff.md`:

```markdown
/plan We are developing '<PROJECT_NAME>' in this repository.

This project is governed by our 12 Open Source Software Standards defined in AGENTS.md and .agents/rules/enforce-standards.md. You MUST adhere to all 12 standards without exception:
- Zero telemetry and local data residency (presets saved in $XDG_CONFIG_HOME/<PROJECT_NAME>/ as YAML).
- GNU AGPL-3.0-or-later license (with SPDX headers on all files and Section 13 notice in UI/CLI).
- Local web server bound strictly to 127.0.0.1 with ephemeral token authentication and W3C CSP headers.
- CLI stream separation (stdout for machine data/JSON, stderr for logs/status) and NO_COLOR support.
- Subprocess CLI tests verifying exit codes and stream separation.

PURPOSE & REQUIREMENTS:
- Name: <PROJECT_NAME>
- Description: <SHORT DESCRIPTION OF WHAT THE UTILITY DOES>
- Core Features:
  1. <Describe Feature 1>
  2. <Describe Feature 2>

TASK:
1. Review the scaffolded codebase in src/app/ and tests/.
2. Implement the core features following stream separation, XDG preset management, and input sanitization.
3. Add subprocess test cases in tests/ to verify CLI exit codes and stream separation.
4. Run 'check-standards' and 'pytest' to verify complete compliance.

Please present an implementation plan before writing any code.
```


---

### 2. Updating Existing Programs & Synchronizing Standards (`sync-standards.sh`)

When standards, AI agent directives, or security guidelines evolve—such as when incorporating new Freedesktop.org specifications or privacy/security controls—you can easily upgrade any existing program that uses these standards.

> [!NOTE]
> Because `Software-standards` is a private repository, unauthenticated `curl raw.githubusercontent.com...` requests return `404 Not Found`. Use one of the authenticated methods below.

#### Step 1: Synchronize Governance & Directives into the Existing Project
Choose one of the following methods from inside your existing project's directory:

##### A. Remote Update via GitHub CLI `gh` (Recommended for Private Repo)
```bash
gh api -H "Accept: application/vnd.github.v3.raw" \
  repos/joelontheroad/Software-standards/contents/scripts/sync-standards.sh | bash -s -- --force .
```

##### B. Remote Update via Ephemeral SSH Clone (No Token or CLI Required)
```bash
git clone --depth 1 git@github.com:joelontheroad/Software-standards.git /tmp/standards \
  && /tmp/standards/scripts/sync-standards.sh --force . \
  && rm -rf /tmp/standards
```

##### C. Remote Update via `curl` (Using Personal Access Token)
```bash
export GITHUB_TOKEN="ghp_yourTokenHere"  # or STANDARDS_TOKEN

curl -sSL -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3.raw" \
  https://api.github.com/repos/joelontheroad/Software-standards/contents/scripts/sync-standards.sh | bash -s -- --force .
```

##### D. Local Update (Using local clone on the same machine)
```bash
"/mnt/joelg-docs/Personal/Software Projects/Software-standards/scripts/sync-standards.sh" --force .
```
*(Passing `--force` allows synchronizing even if the target folder contains uncommitted working tree changes).*

#### What `sync-standards.sh` Updates Automatically:
1. **Refreshes Governance & Agent Rules**: Updates `AGENTS.md` and `.agents/rules/enforce-standards.md` with the latest directives (strict preservation of user-facing functionality with internal refactoring freedom, Freedesktop XDG base directory v0.8, Trash ban on state resets, autostart restrictions, safe `.desktop` execution, clipboard safety, safe File URIs, and Shared MIME-info).
2. **Synchronizes Core Legal & Security Files**: Adds missing `LICENSE` (GNU AGPLv3), `SECURITY.md`, and `.gitattributes` if not already present.
3. **Inspects Linter Configs**: Checks `pyproject.toml` for Google Style docstring rules (`pydocstyle` / `D`).
4. **Runs Compliance Audit**: Scans the project with `check-compliance.py`.

---

#### Step 2: Audit & Refactor Code for Updated Standards Compliance
Once the governance files are refreshed, verify that the application code adheres to the updated standards using the checklist below:

| Dimension | Verification Action | Standards Reference |
|---|---|---|
| **Preservation of User-Facing Functionality** | Verify that no user-facing CLI commands, subcommands, flags, configuration preset keys, or Web UI controls were deleted, renamed, or broken during refactorings. Confirm that internal refactorings preserve external contracts and all existing tests pass without regression. | [Category 2.6](STANDARDS.md#26-preservation-of-user-facing-interaction-surface--backward-compatibility) |
| **Deterministic State Purge** | Verify that `--reset-config` or `config reset` permanently unlinks/shreds files and **does NOT** move them to Desktop Trash (`trash-spec`), which leaks path metadata and timestamps in `.trashinfo` files. | [Category 1.4](STANDARDS.md#14-state-ephemerality--deterministic-purge) |
| **No Unsolicited Autostart** | Verify the application does not install background entries in `$XDG_CONFIG_HOME/autostart` or attempt removable media triggers. | [Category 1.6](STANDARDS.md#16-prohibition-on-unsolicited-persistence--autostart) |
| **Clipboard Safety** | Verify clipboard writes require an explicit user gesture (`--copy` flag or UI button) and **never** silently write or copy ephemeral launch tokens, passwords, or secrets. | [Category 3.7](STANDARDS.md#37-clipboard-safety--interaction-guidelines-freedesktop-consensus) |
| **Safe Desktop Launchers** | Verify any generated `.desktop` files point directly to the binary (`Exec=mytool launch --no-browser --`) without shell wrappers (`Exec=sh -c` is prohibited), and quote arguments (`"%u"`). | [Category 3.6](STANDARDS.md#36-freedesktop-desktop-entry-conformance-desktop) |
| **Safe File URIs** | Verify any handling of `file://` URIs rejects remote hostnames (must be empty or localhost) and resolves paths strictly within designated directory jails using `os.path.realpath`. | [Category 5.4](STANDARDS.md#54-mitre-cwe-top-25-protections) |
| **MIME Type Integrity** | Ensure local web servers determine asset MIME types using standard system MIME databases (`shared-mime-info`) and serve assets with explicit `Content-Type` headers paired with `X-Content-Type-Options: nosniff`. | [Category 5.8](STANDARDS.md#58-freedesktop-shared-mime-info-conformance--content-type-integrity) |
| **File Manager D-Bus** | If providing a "Reveal in Folder" option (`--reveal`), verify headless detection and <=1000ms timeout protection. | [Category 11.3](STANDARDS.md#113-desktop-file-manager-integration-freedesktop-orgfreedesktopfilemanager1) |

---

#### Step 3: Automated Upgrade via AI Coding Agent
To automate the refactoring process, open your existing project in your AI coding assistant (Antigravity, Claude Code, Cursor) and paste the following prompt:

```markdown
/plan Upgrade this project to comply with the latest 12 Open Source Software Standards defined in AGENTS.md and STANDARDS.md.

Specifically audit and refactor the codebase for the updated standards:
1. Privacy & State Purge: Verify that state reset commands (--reset-config / config reset) permanently delete files (unlink). Ensure they do NOT move files to the Desktop Trash Can.
2. User-Facing Contract Preservation: Verify that no existing user-facing functionality, CLI commands, subcommands, flags, YAML preset keys, or Web UI controls are deleted, renamed, or disabled. Refactorings must be strictly behavior-preserving.
3. Autostart: Ensure no background autostart entries are registered by default.
4. Clipboard Safety: Ensure clipboard operations require an explicit user gesture (--copy or UI button click) and NEVER copy ephemeral launch tokens or secrets.
5. Desktop Launchers: If .desktop files are generated, ensure Exec= points directly to the binary without shell wrappers (sh -c is prohibited) and quotes parameters ("%u").
6. File URIs & Path Traversal: Ensure file:// URI parsing rejects remote authorities, decodes safely, and verifies paths reside within allowed directory jails using os.path.realpath.
7. Asset Serving: Ensure HTTP asset responses emit verified Content-Type headers from standard MIME databases alongside X-Content-Type-Options: nosniff.
8. Interoperability: If a "Reveal in Folder" feature exists, ensure it checks for headless environments and uses a <=1000ms timeout guard.

Run the test suite and compliance check when finished:
pytest
check-standards
```

---

### 3. Manual Scaffolding Alternative
If you prefer copying files manually:
```bash
# 1. Copy the starter scaffold
cp -r templates/python my-new-python-tool
cp -r templates/common/* my-new-python-tool/
cp templates/common/.* my-new-python-tool/ 2>/dev/null || true
cp AGENTS.md my-new-python-tool/
mkdir -p my-new-python-tool/.agents/rules
cp .agents/rules/enforce-standards.md my-new-python-tool/.agents/rules/

# 2. Enter and install in development mode
cd my-new-python-tool
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev,web]"

# 3. Test CLI and run test suite
mytool --help
pytest
```


### 4. Scaffolding a New Node Utility
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

### 5. Auditing a Project for Standards Compliance
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
│   ├── check-compliance.py         # Automated compliance audit script
│   └── new-project.sh              # Single-command project scaffolding tool
├── templates/
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
