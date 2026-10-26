#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 [Author/Organization]
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

# ==============================================================================
# Open Source Software Standards Kit - Repository Standards Synchronizer
#
# Safely updates an existing repository with the latest governance standards:
# - AGENTS.md (Root AI Agent Directive)
# - .agents/rules/enforce-standards.md (IDE Agent Rules)
# - SECURITY.md (Vulnerability Disclosure Policy)
# - .gitattributes (Universal LF Line Endings)
# ==============================================================================

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

STANDARDS_REPO_URL="https://github.com/joelontheroad/Software-standards.git"
RAW_BASE_URL="https://raw.githubusercontent.com/joelontheroad/Software-standards/main"

TARGET_DIR="."
FORCE=false
CHECK_ONLY=false

#######################################
# Print command-line usage summary and options reference.
# Outputs:
#   Writes help documentation to stdout.
#######################################
show_help() {
    cat << 'EOF'
Usage: sync-standards.sh [options] [target-directory]

Safely synchronize the latest software standards, AI agent directives,
and security policies into an existing project.

Options:
  -d, --dest <path>     Target repository directory (default: current directory '.')
  -f, --force           Bypass uncommitted git changes warning
  -c, --check-only      Run compliance audit only without modifying any files
  -h, --help            Show this help message and exit

Examples:
  # Remote sync via GitHub CLI (recommended for private repository):
  gh api -H "Accept: application/vnd.github.v3.raw" repos/joelontheroad/Software-standards/contents/scripts/sync-standards.sh | bash -s -- --force .

  # Remote sync via SSH temporary clone:
  git clone --depth 1 git@github.com:joelontheroad/Software-standards.git /tmp/standards && /tmp/standards/scripts/sync-standards.sh --force . && rm -rf /tmp/standards

  # From the standards kit repo targeting another folder:
  ./scripts/sync-standards.sh /path/to/my-tool

  # Audit compliance without modifying files:
  ./scripts/sync-standards.sh --check-only
EOF
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dest)
            TARGET_DIR="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -c|--check-only)
            CHECK_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Error: Unknown argument '$1'" >&2
            show_help >&2
            exit 2
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "================================================================="
echo " Synchronizing Standards into: $TARGET_DIR"
echo "================================================================="

# Verify target directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist." >&2
    exit 1
fi

# Check git status if git is initialized
if [[ -d "$TARGET_DIR/.git" ]]; then
    if [[ "$FORCE" = false ]] && [[ -n "$(git -C "$TARGET_DIR" status --porcelain 2>/dev/null || true)" ]]; then
        echo "[WARNING] Target directory has uncommitted git changes." >&2
        echo "          Commit or stash your changes before syncing, or pass --force." >&2
        if [[ "$CHECK_ONLY" = false ]]; then
            read -r -p "Continue anyway? [y/N] " response || response="n"
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo "Aborted." >&2
                exit 1
            fi
        fi
    fi
fi

# Setup source: local files or remote raw download
TMP_SOURCE_DIR=""
cleanup() {
    if [[ -n "$TMP_SOURCE_DIR" ]] && [[ -d "$TMP_SOURCE_DIR" ]]; then
        rm -rf "$TMP_SOURCE_DIR"
    fi
}
trap cleanup EXIT

LOCAL_SOURCE=""
if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/../AGENTS.md" ]] && [[ -f "$SCRIPT_DIR/../STANDARDS.md" ]]; then
    LOCAL_SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [[ -z "$LOCAL_SOURCE" ]]; then
    echo "→ Standards repository not found locally. Fetching standards..."
    TMP_SOURCE_DIR="$(mktemp -d)"
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        gh repo clone joelontheroad/Software-standards "$TMP_SOURCE_DIR" -- --depth 1 --quiet
    elif [[ -n "${STANDARDS_TOKEN:-}" ]]; then
        git clone --depth 1 "https://x-access-token:${STANDARDS_TOKEN}@github.com/joelontheroad/Software-standards.git" "$TMP_SOURCE_DIR" --quiet
    elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
        git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/joelontheroad/Software-standards.git" "$TMP_SOURCE_DIR" --quiet
    else
        git clone --depth 1 "$STANDARDS_REPO_URL" "$TMP_SOURCE_DIR" --quiet || {
            echo "Error: Failed to clone private standards repository from $STANDARDS_REPO_URL." >&2
            echo "Tip: Ensure you are logged in with 'gh auth login' or have SSH keys configured." >&2
            exit 1
        }
    fi
    LOCAL_SOURCE="$TMP_SOURCE_DIR"
fi

fetch_or_copy() {
    local rel_path="$1"
    local dest_path="$2"

    mkdir -p "$(dirname "$dest_path")"
    cp "$LOCAL_SOURCE/$rel_path" "$dest_path"
}

if [[ "$CHECK_ONLY" = true ]]; then
    echo "→ Running standards compliance check..."
    if [[ -f "$LOCAL_SOURCE/scripts/check-compliance.py" ]]; then
        python3 "$LOCAL_SOURCE/scripts/check-compliance.py" "$TARGET_DIR" || true
    fi
    exit 0
fi

# 1. Update AGENTS.md
echo "→ Updating AGENTS.md..."
fetch_or_copy "AGENTS.md" "$TARGET_DIR/AGENTS.md"

# 2. Update .agents/rules/enforce-standards.md
echo "→ Updating .agents/rules/enforce-standards.md..."
fetch_or_copy ".agents/rules/enforce-standards.md" "$TARGET_DIR/.agents/rules/enforce-standards.md"

# 3. Synchronize LICENSE if missing
if [[ ! -f "$TARGET_DIR/LICENSE" ]]; then
    echo "→ Creating missing LICENSE (GNU AGPLv3)..."
    fetch_or_copy "templates/common/LICENSE" "$TARGET_DIR/LICENSE"
fi

# 4. Synchronize SECURITY.md if missing
if [[ ! -f "$TARGET_DIR/SECURITY.md" ]]; then
    echo "→ Creating missing SECURITY.md..."
    fetch_or_copy "templates/common/SECURITY.md" "$TARGET_DIR/SECURITY.md"
fi

# 5. Synchronize .gitattributes if missing
if [[ ! -f "$TARGET_DIR/.gitattributes" ]]; then
    echo "→ Creating missing .gitattributes..."
    fetch_or_copy "templates/common/.gitattributes" "$TARGET_DIR/.gitattributes"
fi

# 6. Synchronize GitHub Actions CI & Release Workflows
if [[ -d "$TARGET_DIR/.github/workflows" ]]; then
    echo "→ Updating .github/workflows/ci.yml..."
    fetch_or_copy "templates/common/.github/workflows/ci.yml" "$TARGET_DIR/.github/workflows/ci.yml"
    echo "→ Updating .github/workflows/release.yml..."
    fetch_or_copy "templates/common/.github/workflows/release.yml" "$TARGET_DIR/.github/workflows/release.yml"
fi

# 7. Check Python pyproject.toml for ruff pydocstyle configuration
if [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
    echo "→ Inspecting Python pyproject.toml..."
    if ! grep -q 'convention = "google"' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
        echo ""
        echo "  [NOTE] Recommended addition for pyproject.toml:"
        echo "  --------------------------------------------------"
        echo "  [tool.ruff.lint]"
        echo "  select = [\"E\", \"F\", \"W\", \"I\", \"B\", \"S\", \"D\"]"
        echo "  ignore = [\"D104\", \"D105\", \"D107\", \"D205\", \"D212\"]"
        echo ""
        echo "  [tool.ruff.lint.pydocstyle]"
        echo "  convention = \"google\""
        echo "  --------------------------------------------------"
        echo ""
    fi
fi

# 7. Run compliance check
echo "→ Running compliance audit on updated repository..."
if [[ -n "$LOCAL_SOURCE" ]] && [[ -f "$LOCAL_SOURCE/scripts/check-compliance.py" ]]; then
    python3 "$LOCAL_SOURCE/scripts/check-compliance.py" "$TARGET_DIR" || true
fi

echo ""
echo "================================================================="
echo " [SUCCESS] Standards successfully synchronized into: $TARGET_DIR"
echo "================================================================="
echo ""
echo "Next step: Run this prompt in Antigravity or your AI Coding Agent"
echo "to bring all existing code into compliance with updated standards:"
echo ""
cat << 'EOF'
-----------------------------------------------------------------
/plan Upgrade this project to comply with the latest 12 Open Source Software Standards defined in AGENTS.md and STANDARDS.md:

1. Directive 1 (Privacy & State Purge):
   - Verify state reset commands (--reset-config / config reset) permanently delete files (unlink).
   - Ensure they do NOT move state files to the Desktop Trash Can.
   - Verify no background autostart entries are registered by default.
2. Directive 2 (Functional Preservation & Lifecycle):
   - Verify strict preservation of existing user-facing functionality (CLI subcommands, flags, preset keys, UI controls).
   - Internal implementations and helper routines may be refactored freely provided all external behaviors and tests pass without regression.
3. Directive 3 (UI Guidelines & Desktop):
   - In server startup, format launch URLs as OSC 8 clickable links with TTY / NO_COLOR fallback.
   - Automatically open the user's default browser on launch unless --no-browser is passed or running headless.
   - Ensure clipboard writes require an explicit user gesture (--copy or UI button) and NEVER copy tokens or secrets.
   - If .desktop launchers exist, ensure Exec= invokes the binary directly without shell wrappers (sh -c is prohibited).
4. Directive 5 (Secure Programming):
   - Ensure file:// URI parsing rejects remote authorities, decodes safely, and verifies paths reside within allowed directory jails using os.path.realpath.
   - Ensure HTTP asset responses emit verified Content-Type headers from standard MIME databases alongside X-Content-Type-Options: nosniff.
5. Directive 11 (Composability):
   - If a "Reveal in Folder" feature exists, ensure it checks for headless environments and uses a <=1000ms timeout guard.
6. Directive 12 (Documentation):
   - Ensure each module begins with an architectural summary docstring after the SPDX header.
   - Upgrade public functions and classes to Google Style docstrings (or JSDoc).
   - Add '# SECURITY:' rationale comments on security invariants.
7. Directive 13 (Verification Discipline & Zero Silent Failures):
   - In Web UI, ensure top-level global error boundary (window.onerror & unhandledrejection) is present to prevent silent "nothing happened" crashes.
   - Ensure all disabled buttons provide a visible explanation or tooltip explaining what is missing.
   - Ensure all asynchronous tasks/polling use strictly unique task IDs (never colliding with stale state).
   - Run static linter (no-undef) across all JavaScript/Python code and NEVER claim a bug is fixed without behavioral proof.
8. Run test suite and compliance audit to confirm zero regressions:
   pytest
   check-standards
-----------------------------------------------------------------
EOF
echo ""
