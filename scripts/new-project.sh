#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 [Author/Organization]
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

# ==============================================================================
# Open Source Software Standards Kit - Project Scaffolding Tool
#
# Generates a new standards-compliant Python utility pre-configured with:
# - GNU AGPL-3.0-or-later licensing & SPDX headers
# - XDG base directories with YAML preset management
# - POSIX stream separation (stdout/stderr) & NO_COLOR support
# - Ephemeral-token authenticated localhost web server & accessible Web UI
# - OpenSSF / SLSA security CI workflows
# - Subprocess test suite isolating XDG temporary directories
# - AI Agent Directives (AGENTS.md & .agents/rules/enforce-standards.md)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STANDARDS_REPO_URL="https://github.com/joelontheroad/Software-standards.git"

# Default configuration values
PROJECT_NAME=""
DEST_DIR=""
DESCRIPTION="A standard-compliant open-source utility"
AUTHOR="joelontheroad"
EMAIL="author@example.com"
DO_INSTALL=false
FORCE=false

#######################################
# Print command-line usage summary and options reference.
# Outputs:
#   Writes help documentation to stdout.
#######################################
show_help() {
    cat << 'EOF'
Usage: new-project.sh [options]

Options:
  -n, --name <name>       Project and CLI command name (kebab-case, e.g. log-scrubber)
                          (Defaults to directory name when running with --dest .)
  -d, --dest <path>       Destination directory (default: ./<project-name>)
      --desc <text>       Short description of the utility (optional)
      --author <name>     Author or organization name (default: joelontheroad)
      --email <email>     Author email address (default: author@example.com)
  -f, --force             Overwrite or scaffold into directory even if it contains files
      --install           Automatically create virtualenv and install in editable mode
  -h, --help              Show this help message and exit

Examples:
  ./scripts/new-project.sh -n log-scrubber --desc "Local log file privacy scrubbing utility"
  ./scripts/new-project.sh -n data-vault --install
  ./scripts/new-project.sh -d . --force --install
EOF
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -d|--dest)
            DEST_DIR="$2"
            shift 2
            ;;
        --desc)
            DESCRIPTION="$2"
            shift 2
            ;;
        --author)
            AUTHOR="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --install)
            DO_INSTALL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            show_help >&2
            exit 2
            ;;
    esac
done

# If project name was not explicitly provided, attempt auto-inference if targeting current or existing directory
if [[ -z "$PROJECT_NAME" ]]; then
    TARGET_LOOKUP_DIR="${DEST_DIR:-.}"
    if [[ -d "$TARGET_LOOKUP_DIR" ]]; then
        CANDIDATE_NAME=$(basename "$(cd "$TARGET_LOOKUP_DIR" && pwd)" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
        # Prevent accidentally inferring from the standards repo root or generic folder names
        if [[ "$CANDIDATE_NAME" =~ ^[a-z0-9-]+$ ]] && [[ "$CANDIDATE_NAME" != "software-standards" ]] && [[ "$CANDIDATE_NAME" != "scripts" ]] && [[ "$CANDIDATE_NAME" != "tmp" ]] && [[ "$CANDIDATE_NAME" != "." ]]; then
            PROJECT_NAME="$CANDIDATE_NAME"
            echo "→ Inferred project name '$PROJECT_NAME' from target directory ($(basename "$(cd "$TARGET_LOOKUP_DIR" && pwd)"))"
        fi
    fi
fi

# Validate required arguments
if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: --name <project-name> is required (or run with -d . inside a named project directory)." >&2
    show_help >&2
    exit 2
fi

# Automatically normalize project name to lowercase (Python packaging standard)
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')

# Sanitize project name (lowercase letters, digits, and hyphens)
if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "Error: Project name '$PROJECT_NAME' must consist of letters, digits, and hyphens." >&2
    exit 2
fi

# Set default destination directory if not explicitly provided
if [[ -z "$DEST_DIR" ]]; then
    DEST_DIR="./$PROJECT_NAME"
fi

if [[ "$DESCRIPTION" == "A standard-compliant open-source utility" ]]; then
    echo "→ Using default description: \"$DESCRIPTION\""
    echo "  (Tip: Pass --desc \"<summary>\" to customize during scaffolding, or refine it in the AI kickoff prompt)."
fi

# Prevent overwriting existing directory containing files unless --force is used
if [[ -d "$DEST_DIR" ]] && [[ "$FORCE" = false ]]; then
    NON_GIT_FILES=$(find "$DEST_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' 2>/dev/null || true)
    if [[ -n "$NON_GIT_FILES" ]]; then
        echo "Error: Target directory '$DEST_DIR' contains existing files:" >&2
        find "$DEST_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec basename {} \; 2>/dev/null | head -n 10 | sed 's/^/  - /' >&2
        echo "" >&2
        echo "Tip: Re-run with --force (or -f) to scaffold into this directory anyway." >&2
        exit 1
    fi
fi



echo "================================================================="
echo " Scaffolding Standards-Compliant Project: $PROJECT_NAME"
echo "================================================================="

# Determine source location: Local checkout vs. Remote clone
TMP_SOURCE_DIR=""
#######################################
# Clean up temporary cloned repository on script termination or error.
#######################################
cleanup() {
    if [[ -n "$TMP_SOURCE_DIR" ]] && [[ -d "$TMP_SOURCE_DIR" ]]; then
        rm -rf "$TMP_SOURCE_DIR"
    fi
}
trap cleanup EXIT

if [[ -d "$SCRIPT_DIR/../templates/python" ]] && [[ -d "$SCRIPT_DIR/../templates/common" ]]; then
    SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    echo "→ Using local standards repository at: $SOURCE_DIR"
else
    echo "→ Standards repository not found locally. Cloning from GitHub..."
    TMP_SOURCE_DIR="$(mktemp -d)"
    if [[ -n "${STANDARDS_TOKEN:-}" ]]; then
        git clone --depth 1 "https://x-access-token:${STANDARDS_TOKEN}@github.com/joelontheroad/Software-standards.git" "$TMP_SOURCE_DIR" --quiet
    else
        git clone --depth 1 "$STANDARDS_REPO_URL" "$TMP_SOURCE_DIR" --quiet || {
            echo "Error: Failed to clone standards repository from $STANDARDS_REPO_URL." >&2
            echo "Tip: Set the STANDARDS_TOKEN environment variable for private repository access." >&2
            exit 1
        }
    fi
    SOURCE_DIR="$TMP_SOURCE_DIR"
fi

# 1. Create target directory
mkdir -p "$DEST_DIR"
DEST_DIR="$(cd "$DEST_DIR" && pwd)"
echo "→ Destination directory: $DEST_DIR"

# 2. Copy common governance and CI files
echo "→ Copying common governance & security files..."
cp "$SOURCE_DIR/templates/common/LICENSE" "$DEST_DIR/"
cp "$SOURCE_DIR/templates/common/SECURITY.md" "$DEST_DIR/"
cp "$SOURCE_DIR/templates/common/CONTRIBUTING.md" "$DEST_DIR/"
cp "$SOURCE_DIR/templates/common/.gitignore" "$DEST_DIR/"
cp "$SOURCE_DIR/templates/common/.gitattributes" "$DEST_DIR/"
mkdir -p "$DEST_DIR/.github/workflows"
cp "$SOURCE_DIR/templates/common/.github/workflows/ci.yml" "$DEST_DIR/.github/workflows/"
cp "$SOURCE_DIR/templates/common/.github/workflows/release.yml" "$DEST_DIR/.github/workflows/"

# 3. Copy Python template files
echo "→ Copying Python starter scaffold..."
cp "$SOURCE_DIR/templates/python/pyproject.toml" "$DEST_DIR/"
cp -r "$SOURCE_DIR/templates/python/src" "$DEST_DIR/"
cp -r "$SOURCE_DIR/templates/python/tests" "$DEST_DIR/"

# 4. Copy AI agent directives (automatically ignored by git in .gitignore)
echo "→ Injecting AI coding agent directives (AGENTS.md & rules)..."
cp "$SOURCE_DIR/AGENTS.md" "$DEST_DIR/"
mkdir -p "$DEST_DIR/.agents/rules"
cp "$SOURCE_DIR/.agents/rules/enforce-standards.md" "$DEST_DIR/.agents/rules/"

# 5. Substitute placeholders safely using Python (ensures cross-platform UTF-8 consistency)
echo "→ Customizing project configuration & metadata..."
python3 - << PYEOF
import os
from pathlib import Path

dest = Path("$DEST_DIR")
project_name = "$PROJECT_NAME"
description = "$DESCRIPTION"
author = "$AUTHOR"
email = "$EMAIL"

# 1. pyproject.toml
pyproject = dest / "pyproject.toml"
if pyproject.exists():
    text = pyproject.read_text(encoding="utf-8")
    text = text.replace('name = "mytool"', f'name = "{project_name}"')
    text = text.replace('description = "A standard-compliant open-source utility"', f'description = "{description}"')
    text = text.replace('name = "Author Name", email = "author@example.com"', f'name = "{author}", email = "{email}"')
    text = text.replace('mytool = "app.cli:main"', f'{project_name} = "app.cli:main"')
    pyproject.write_text(text, encoding="utf-8")

# 2. src/app/__init__.py
init_file = dest / "src" / "app" / "__init__.py"
if init_file.exists():
    text = init_file.read_text(encoding="utf-8")
    text = text.replace("https://github.com/username/mytool", f"https://github.com/{author}/{project_name}")
    init_file.write_text(text, encoding="utf-8")

# 3. src/app/config.py
config_file = dest / "src" / "app" / "config.py"
if config_file.exists():
    text = config_file.read_text(encoding="utf-8")
    text = text.replace('APP_NAME = "mytool"', f'APP_NAME = "{project_name}"')
    config_file.write_text(text, encoding="utf-8")

# 4. src/app/cli.py
cli_file = dest / "src" / "app" / "cli.py"
if cli_file.exists():
    text = cli_file.read_text(encoding="utf-8")
    text = text.replace('prog="mytool"', f'prog="{project_name}"')
    text = text.replace('description="mytool: A standard-compliant open-source utility."', f'description="{project_name}: {description}"')
    text = text.replace("[mytool]", f"[{project_name}]")
    cli_file.write_text(text, encoding="utf-8")

# 5. src/app/server.py
server_file = dest / "src" / "app" / "server.py"
if server_file.exists():
    text = server_file.read_text(encoding="utf-8")
    text = text.replace('title="mytool Local Server"', f'title="{project_name} Local Server"')
    text = text.replace('description="Localhost-bound web server for mytool"', f'description="Localhost-bound web server for {project_name}"')
    text = text.replace('"mytool_session"', f'"{project_name}_session"')
    text = text.replace("[mytool]", f"[{project_name}]")
    server_file.write_text(text, encoding="utf-8")

# 6. src/app/web/index.html
html_file = dest / "src" / "app" / "web" / "index.html"
if html_file.exists():
    text = html_file.read_text(encoding="utf-8")
    text = text.replace("mytool", project_name)
    text = text.replace("https://github.com/username/mytool", f"https://github.com/{author}/{project_name}")
    html_file.write_text(text, encoding="utf-8")
PYEOF

# 6. Generate Category-12 Compliant README.md
echo "→ Generating initial README.md..."
cat << EOF > "$DEST_DIR/README.md"
# $PROJECT_NAME

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Standards: 13-Category](https://img.shields.io/badge/Standards-Compliant-emerald.svg)](https://github.com/joelontheroad/Software-standards)

$DESCRIPTION

This project strictly adheres to the 13 Open Source Software Standards:
- **Zero Telemetry & Local Data**: Presets saved locally in \`\$XDG_CONFIG_HOME/$PROJECT_NAME/\`.
- **GNU AGPL-3.0-or-later**: Free and open source with full user rights.
- **Strict Localhost Security**: Web servers default strictly to \`127.0.0.1\` with ephemeral token authentication.

---

## 3-Step Quickstart

\`\`\`bash
# 1. Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 2. Install in development mode
pip install -e ".[dev,web]"

# 3. Run the CLI
$PROJECT_NAME --help
\`\`\`

---

## CLI Flags Reference

| Flag | Description |
|---|---|
| \`-h, --help\` | Display usage and subcommand information |
| \`-v, --version\` | Display version, AGPLv3 license, and source link |
| \`-q, --quiet\` | Suppress non-essential diagnostic output |
| \`--verbose\` | Enable detailed diagnostic messages on stderr |
| \`--json\` | Output parseable machine data to stdout |
| \`preset show\` | Display active configuration preset |
| \`serve\` | Start authenticated local web server on 127.0.0.1 |

---

## Configuration & Presets

Configuration and presets reside in standard XDG directories:
- **Linux/macOS**: \`~/.config/$PROJECT_NAME/config.yaml\`
- **Windows**: \`%APPDATA%\\$PROJECT_NAME\\config.yaml\`

---

## Security Policy

See [\`SECURITY.md\`](SECURITY.md) for vulnerability disclosure and reporting guidelines.

---

## License

Licensed under the **GNU Affero General Public License v3.0 or later** (see [\`LICENSE\`](LICENSE)).
Source repository: [https://github.com/$AUTHOR/$PROJECT_NAME](https://github.com/$AUTHOR/$PROJECT_NAME)
EOF

# 7. Initialize Git Repository
echo "→ Initializing git repository..."
git -C "$DEST_DIR" init -b main --quiet

# 8. Optional Environment Setup
if [[ "$DO_INSTALL" = true ]]; then
    echo "→ Setting up virtualenv and installing dependencies..."
    python3 -m venv "$DEST_DIR/.venv"
    "$DEST_DIR/.venv/bin/pip" install --quiet --upgrade pip
    "$DEST_DIR/.venv/bin/pip" install --quiet -e "$DEST_DIR[dev,web]"
    echo "→ Virtual environment created at $DEST_DIR/.venv"
fi

# 9. Verify Standards Compliance Out-of-the-Box
echo "→ Validating standards compliance..."
python3 "$SOURCE_DIR/scripts/check-compliance.py" "$DEST_DIR"

echo ""
echo "================================================================="
echo " [SUCCESS] Project $PROJECT_NAME successfully created!"
echo "================================================================="
echo "Location: $DEST_DIR"
echo ""
echo "Next Steps:"
echo "  cd \"$DEST_DIR\""
if [[ "$DO_INSTALL" = false ]]; then
    echo "  python3 -m venv .venv"
    echo "  source .venv/bin/activate"
    echo "  pip install -e \".[dev,web]\""
else
    echo "  source .venv/bin/activate"
fi
echo "  $PROJECT_NAME --help"
echo "  pytest"
echo ""
# 10. Generate .agents/kickoff.md with ready-to-use prompt
mkdir -p "$DEST_DIR/.agents"
cat << EOF > "$DEST_DIR/.agents/kickoff.md"
# AI Agent Kickoff Prompt for $PROJECT_NAME

Copy and paste this prompt into Antigravity or your AI coding assistant to begin implementation:

\`\`\`markdown
/plan We are developing '$PROJECT_NAME' in this repository.

This project is governed by our 13 Open Source Software Standards defined in AGENTS.md.

PURPOSE & REQUIREMENTS:
- Name: $PROJECT_NAME
- Description: $DESCRIPTION
- Planned Features:
  1. <Describe Feature 1>
  2. <Describe Feature 2>

TASK:
1. Review the scaffolded codebase in src/app/ and tests/.
2. Implement the planned features adhering strictly to stream separation (stdout for data, stderr for logs), XDG preset management, and AGPLv3 licensing.
3. Add subprocess test cases in tests/ to verify CLI exit codes and stream separation.
4. Run 'check-standards' and 'pytest' to verify complete compliance.

Please present an implementation plan before writing code.
\`\`\`
EOF

echo "-----------------------------------------------------------------"
echo "AI Agent Kickoff Prompt (saved to: $DEST_DIR/.agents/kickoff.md):"
echo "-----------------------------------------------------------------"
cat << EOF
/plan We are developing '$PROJECT_NAME' in this repository.

This project is governed by our 13 Open Source Software Standards defined in AGENTS.md.

PURPOSE & REQUIREMENTS:
- Name: $PROJECT_NAME
- Description: $DESCRIPTION
- Planned Features:
  1. <Describe Feature 1>
  2. <Describe Feature 2>

TASK:
1. Review the scaffolded codebase in src/app/ and tests/.
2. Implement the planned features adhering strictly to stream separation (stdout for data, stderr for logs), XDG preset management, and AGPLv3 licensing.
3. Add subprocess test cases in tests/ to verify CLI exit codes and stream separation.
4. Run 'check-standards' and 'pytest' to verify complete compliance.

Please present an implementation plan before writing code.
EOF
echo "-----------------------------------------------------------------"
