# Architectural Q&A: Project Name & Description in Scaffolding & AI Prompts

> **Context**: Evaluation of the roles, necessities, and interactions of **Project Name** and **Project Description** across the two primary phases of new project initialization:
> 1. **Scaffolding Phase** (Executed via [`scripts/new-project.sh`](../scripts/new-project.sh) and repository starter templates)
> 2. **AI Agent Kickoff Phase** (Executed via Antigravity or AI coding agents using the kick-off prompt)

---

## Executive Summary & Decision Matrix

| Dimension | Project Name | Project Description |
|---|---|---|
| **Scaffolding Phase** (`new-project.sh`) | **STRICTLY REQUIRED**<br>*(or auto-derived & sanitized from directory)* | **OPTIONAL**<br>*(sensible fallback default, but recommended)* |
| **AI Prompt Phase** (Kickoff Prompt) | **HIGH VALUE / RECOMMENDED**<br>*(technically discoverable from files, but grounds agent identity)* | **MISSION CRITICAL / ESSENTIAL**<br>*(primary semantic anchor for agent domain reasoning & boundaries)* |

### Key Takeaway
- **In Scaffolding**: **Project Name** is structurally essential to generate valid code, configuration files, and package manifests. **Description** can safely fall back to a generic default (`"A standard-compliant open-source utility"`) because code compiles and runs without it.
- **In AI Prompts**: The relationship **inverts**. The AI agent can inspect the local filesystem to discover the project name, but **without a rich Project Description**, the agent cannot deduce the tool's domain, purpose, problem scope, or architectural constraints.

---

```mermaid
graph TD
    subgraph Phase 1: Scaffolding (new-project.sh)
        PN1[Project Name] -->|Mandatory Substitution| C1[pyproject.toml / package.json]
        PN1 -->|Mandatory Substitution| C2[XDG Config Directory: ~/.config/name/]
        PN1 -->|Mandatory Substitution| C3[CLI Entry Point & prog name]
        PN1 -->|Mandatory Substitution| C4[Server Cookie & Title]
        PD1[Project Description] -->|Optional Fallback| C5[README.md & CLI --help summary]
    end

    subgraph Phase 2: AI Agent Kickoff (Antigravity Prompt)
        PN2[Project Name] -->|Anchors Context| A1[CLI Command Syntax & Test Cases]
        PD2[Project Description] -->|Crucial Semantic Grounding| A2[Domain Logic & Architecture]
        PD2 -->|Prevents Scope Creep| A3[Subcommand & Argument Design]
        PD2 -->|Directive 12 Compliance| A4[Structured Module Docstrings]
    end
```

---

## Section 1: Scaffolding Phase Deep Dive (`new-project.sh`)

### Q1.1: Why is Project Name strictly necessary during scaffolding? What breaks if it is omitted?
**Answer**: Project Name is not merely a label; it serves as a **functional system identifier** across 9 interdependent code and configuration touchpoints. If omitted or left as a generic placeholder (e.g. `mytool`):

1. **Python / Node Packaging Manifests**:
   - In [`templates/python/pyproject.toml`](../templates/python/pyproject.toml): `name = "<project-name>"` and `[project.scripts] <project-name> = "app.cli:main"`.
   - In [`templates/node/package.json`](../templates/node/package.json): `"name": "<project-name>"` and `"bin": { "<project-name>": "./src/index.js" }`.
   - *Failure Mode*: Installing multiple scaffolded utilities in the same environment or via `pipx` / `npm` causes global command collisions.
2. **XDG Base Directory Names (Directive 4)**:
   - Config directory: `$XDG_CONFIG_HOME/<project-name>/` (Linux/macOS: `~/.config/<project-name>/`).
   - Cache directory: `$XDG_CACHE_HOME/<project-name>/`.
   - Data directory: `$XDG_DATA_HOME/<project-name>/`.
   - *Failure Mode*: Different utilities will overwrite each other's YAML presets in `~/.config/mytool/`.
3. **Environment Variable Configuration Overrides (Directive 4)**:
   - Standard 5-tier precedence expects `<PROJECT_NAME>_CONFIG` or `<PROJECT_NAME>_PARAM`.
4. **CLI Help & Error Attribution (Directive 3 & 8)**:
   - `argparse.ArgumentParser(prog="<project-name>")` controls usage strings and error messages.
5. **Local Web Server Isolation (Directive 5)**:
   - Web server titles and HTTP cookies: `f"{project_name}_session"`.
   - *Failure Mode*: Session cookies on `127.0.0.1` conflict across local services.
6. **Subprocess Test Suite (Directive 7)**:
   - Tests execute `subprocess.run(["<project-name>", "--help"])`. The binary name must match the package manifest.
7. **Legal & Licensing Notices (Directive 2)**:
   - Web UI footer and CLI `--version` mandate: `<a href="https://github.com/joelontheroad/<project-name>">Source Code (GNU AGPLv3)</a>`.
8. **Documentation & Badges (Directive 12)**:
   - Quickstart commands in `README.md` (`pip install -e .` followed by `<project-name> --help`).

### Q1.2: Can the scaffolding script infer Project Name automatically instead of requiring `--name`?
**Answer**: **Yes, with careful validation.** 
When scaffolding into an existing repository or current directory (`--dest .`), the script can inspect `basename "$PWD"`.
However, directory names frequently contain uppercase letters or underscores (e.g., `Speaker-Analyzer` or `data_vault`), whereas packaging standards require strict normalization:
- **Python (PEP 508)**: Lowercase alphanumeric with hyphens (`speaker-analyzer`).
- **Node (npm)**: Lowercase URL-friendly kebab-case (`speaker-analyzer`).

**Implementation in `new-project.sh`**:
When `-n/--name` is omitted and the target directory is an existing directory:
1. Extract directory base name.
2. Normalize to lowercase and replace underscores with hyphens.
3. Validate format `^[a-z0-9-]+$`.
4. Use as the project name automatically.

### Q1.3: Is the Project Description necessary during scaffolding? What happens if it is omitted?
**Answer**: **It is technically optional, but beneficial.**
If the user omits `--desc`, the scaffolding script safely supplies a standard fallback:
```bash
DESCRIPTION="A standard-compliant open-source utility"
```
- **What works if omitted**: Everything compiles, installs, tests pass, and compliance audits pass.
- **What is compromised**:
  1. `pyproject.toml` contains a generic description.
  2. CLI `--help` outputs `speaker-analyzer: A standard-compliant open-source utility.`
  3. `README.md` features placeholder text instead of an informative elevator pitch.
- **Verdict for Scaffolding**: Keep `--desc` optional with the fallback default. Do not block the developer if they just want to scaffold quickly.

---

## Section 2: AI Prompt Phase Deep Dive (Kickoff Prompt & Agent Directives)

### Q2.1: In the AI Kickoff Prompt, do we need the Project Name if the project is already scaffolded?
**Answer**: **Recommended and high-value, though technically redundant with filesystem inspection.**

- **Why it could be omitted**: The AI agent operates directly inside the project root and can view `pyproject.toml` or `package.json` to find `name = "..."`.
- **Why keeping it in the prompt is superior engineering**:
  1. **Zero-Turn Context Anchoring**: Eliminates an initial exploratory turn where the agent has to read files just to find out what tool it is working on.
  2. **Prevents Command Drift**: Prevents the agent from writing documentation or test cases referencing generic invocations like `python -m app.cli` or `mytool` instead of the installed CLI binary.
  3. **Repository vs Package Disambiguation**: In repositories where the GitHub repo name differs slightly from the CLI command (e.g. repo is `AudioProcessor` but command is `audioproc`), stating `Name: audioproc` in the prompt ensures the agent implements the exact CLI binary intended.
  4. **Cost**: Stating `- Name: <project_name>` takes fewer than 5 tokens. The cost-to-benefit ratio heavily favors keeping it.

### Q2.2: In the AI Kickoff Prompt, why is Project Description indispensable? What happens if it is omitted?
**Answer**: **The Project Description is the single most critical semantic anchor in the entire prompt.**

Without a clear description:
1. **The Semantic Void**: A project name like `acu-gtune` or `speaker-analyzer` is ambiguous:
   - Does `speaker-analyzer` analyze audio waveforms from a microphone?
   - Does it perform speaker diarization on audio recordings?
   - Does it scrape and analyze transcripts of speakers in public city council hearings?
   - Does it calibrate acoustic speaker hardware over Bluetooth?
2. **Directive 12 Compliance (Docstrings & Architecture)**:
   - AGENTS.md Directive 12 states: *"Every source file MUST have a module docstring immediately following the SPDX header summarizing architectural purpose."*
   - Without a domain description, the agent generates vacuous comments like `# Implements speaker analyzer functionality`.
3. **Guardrail Against Scope Creep & Hallucinated Dependencies**:
   - If the agent only receives bullet points like `1. Parse inputs; 2. Generate report`, but lacks the high-level description, it may pull in heavy third-party dependencies (e.g., PyTorch, librosa, pandas) when the utility only needed standard-library JSON parsing and regex.
4. **CLI Subcommand & Argument Hierarchy**:
   - An effective CLI design mirrors the mental model of the domain. The description communicates who uses the tool and why.

**Verdict for AI Prompt**: **MANDATORY.** If the user fails to provide a description in the AI prompt, the agent must be instructed to ask for clarification before generating code.

### Q2.3: Does the AI prompt need to repeat the 12 Standards if `AGENTS.md` is in the repository?
**Answer**: **No! In fact, repeating them is an anti-pattern.**

When `scripts/new-project.sh` scaffolds a project, it automatically places:
- [`AGENTS.md`](../AGENTS.md) in the project root.
- [`.agents/rules/enforce-standards.md`](../.agents/rules/enforce-standards.md) in the project customization directory.

**Disadvantages of a "Fat Prompt" (Repeating all 12 standards in the prompt)**:
1. Consumes 800+ tokens of prompt context on every invocation.
2. Increases risk of instruction drift or contradictions if the user edits `AGENTS.md` but pastes an older prompt.
3. Distracts the agent's attention away from the project's unique business logic.

**The "Lean & Focused" Prompt Pattern**:
The AI prompt delegates standards enforcement entirely to `AGENTS.md`, and focuses 100% of its payload on **project identity, domain purpose, and specific functional requirements**.

---

## Section 3: Recommended Scaffolding & Prompt Designs

### 3.1 The Ideal Kickoff Prompt Template

Here is the recommended lean, high-fidelity AI prompt format generated at the conclusion of `new-project.sh`:

```markdown
/plan We are developing '<PROJECT_NAME>' in this repository.

This project is governed by our 12 Open Source Software Standards defined in AGENTS.md.

PROJECT SPECIFICATION:
- Name: <PROJECT_NAME>
- Description: <SHORT DESCRIPTION OF WHAT THE UTILITY DOES AND WHY>
- Target CLI Command: <PROJECT_NAME>
- Planned Core Features:
  1. <Feature 1: e.g., Ingest raw transcript HTML/text from local files or stdin>
  2. <Feature 2: e.g., Parse speaker metadata and store presets in ~/.config/<PROJECT_NAME>/>
  3. <Feature 3: e.g., Output summary metrics to stdout (JSON) or launch localhost Web UI>

TASK FOR AI AGENT:
1. Review the scaffolded architecture in src/app/ and tests/.
2. Present an architectural implementation plan detailing module structures, CLI subcommands, and preset schemas.
3. Implement the planned features adhering strictly to stream separation (stdout for data, stderr for logs), XDG preset management, and AGPLv3 licensing.
4. Add subprocess test cases in tests/ to verify CLI exit codes and stream separation.
5. Run 'check-standards' (or python scripts/check-compliance.py) and test suite to verify 100% compliance.
```

---

## Section 4: Practical Recommendations

1. **Auto-Derive Name in `new-project.sh`**:
   - If `--name` is omitted and `--dest .` is specified, `new-project.sh` automatically infers and normalizes the project name from the current directory.
2. **Auto-Generate `.agents/kickoff.md`**:
   - `new-project.sh` writes the populated prompt directly to `.agents/kickoff.md` inside the scaffolded repository so it is immediately accessible.
3. **Documented in `README.md`**:
   - The developer workflow clearly distinguishes between the structural requirement of the name during scaffolding and the semantic requirement of the description in AI prompting.
