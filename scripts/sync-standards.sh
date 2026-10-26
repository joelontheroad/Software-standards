#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 [Author/Organization]
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

# ==============================================================================
# Open Source Software Standards Kit - Universal Standards Synchronizer
#
# Safely updates an existing repository with the latest governance standards:
# - AGENTS.md (Root AI Agent Directive)
# - .agents/rules/enforce-standards.md (IDE Agent Rules)
# - SECURITY.md (Vulnerability Disclosure Policy)
# - .gitattributes (Universal LF Line Endings)
# - .github/workflows/ci.yml (Branch-agnostic, stack-detecting CI)
# - .github/workflows/release.yml (Supply chain release attestation)
# - .gitignore (Ensures private agent rules & virtualenvs are ignored)
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
AUTO_MODE=false
SYNC_ALL=false
DO_STAGE=true

# Auto-enable non-interactive mode if running in a pipe or headless environment
if [ ! -t 0 ]; then
    AUTO_MODE=true
fi

#######################################
# Print command-line usage summary and options reference.
# Outputs:
#   Writes help documentation to stdout.
#######################################
show_help() {
    cat << 'EOF'
Usage: sync-standards.sh [options] [target-directory]

Safely synchronize the latest software standards, AI agent directives,
and security policies into existing projects without manual intervention.

Options:
  -d, --dest <path>     Target repository directory (default: current directory '.')
  --all                 Batch discover and synchronize all sibling project repositories
  --auto                Run non-interactively without user prompts (default in pipes)
  -f, --force           Bypass uncommitted git changes warning
  -s, --stage           Automatically stage synchronized governance files in git (default: true)
  --no-stage            Do not automatically stage synchronized files in git
  -c, --check-only      Run compliance audit only without modifying any files
  -h, --help            Show this help message and exit

Examples:
  # Batch update all sibling projects in one zero-intervention command:
  ./scripts/sync-standards.sh --all --auto

  # Synchronize current directory:
  ./scripts/sync-standards.sh --auto .

  # Remote sync via GitHub CLI (recommended for private repository):
  gh api -H "Accept: application/vnd.github.v3.raw" repos/joelontheroad/Software-standards/contents/scripts/sync-standards.sh | bash -s -- --auto .

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
        --all|--batch)
            SYNC_ALL=true
            shift
            ;;
        --auto)
            AUTO_MODE=true
            FORCE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -s|--stage)
            DO_STAGE=true
            shift
            ;;
        --no-stage)
            DO_STAGE=false
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

# Setup source: local files or remote clone
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
            echo "Error: Failed to clone standards repository from $STANDARDS_REPO_URL." >&2
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

sync_single_project() {
    local target="$1"
    target="$(cd "$target" && pwd)"

    echo "================================================================="
    echo " Synchronizing Standards into: $target"
    echo "================================================================="

    if [[ ! -d "$target" ]]; then
        echo "Error: Directory '$target' does not exist." >&2
        return 1
    fi

    # Check git status if git is initialized
    local is_git_repo=false
    if [[ -d "$target/.git" ]]; then
        is_git_repo=true
        if [[ "$AUTO_MODE" = false ]] && [[ "$FORCE" = false ]] && [[ -n "$(git -C "$target" status --porcelain 2>/dev/null || true)" ]]; then
            echo "[WARNING] Target directory has uncommitted git changes." >&2
            echo "          Commit or stash your changes before syncing, or pass --auto / --force." >&2
            if [[ "$CHECK_ONLY" = false ]]; then
                if [ -t 0 ]; then
                    read -r -p "Continue anyway? [y/N] " response || response="n"
                    if [[ ! "$response" =~ ^[Yy]$ ]]; then
                        echo "Aborted." >&2
                        return 1
                    fi
                else
                    echo "→ Non-interactive environment detected: proceeding with safe sync."
                fi
            fi
        fi
    fi

    if [[ "$CHECK_ONLY" = true ]]; then
        echo "→ Running standards compliance check..."
        if [[ -f "$LOCAL_SOURCE/scripts/check-compliance.py" ]]; then
            python3 "$LOCAL_SOURCE/scripts/check-compliance.py" "$target" || true
        fi
        return 0
    fi

    # 1. Update AGENTS.md
    echo "→ Updating AGENTS.md..."
    fetch_or_copy "AGENTS.md" "$target/AGENTS.md"

    # 2. Update .agents/rules/enforce-standards.md
    echo "→ Updating .agents/rules/enforce-standards.md..."
    fetch_or_copy ".agents/rules/enforce-standards.md" "$target/.agents/rules/enforce-standards.md"

    # 3. Synchronize LICENSE if missing
    if [[ ! -f "$target/LICENSE" ]]; then
        echo "→ Creating missing LICENSE (GNU AGPLv3)..."
        fetch_or_copy "templates/common/LICENSE" "$target/LICENSE"
    fi

    # 4. Synchronize SECURITY.md if missing
    if [[ ! -f "$target/SECURITY.md" ]]; then
        echo "→ Creating missing SECURITY.md..."
        fetch_or_copy "templates/common/SECURITY.md" "$target/SECURITY.md"
    fi

    # 5. Synchronize .gitattributes if missing
    if [[ ! -f "$target/.gitattributes" ]]; then
        echo "→ Creating missing .gitattributes..."
        fetch_or_copy "templates/common/.gitattributes" "$target/.gitattributes"
    fi

    # 6. Synchronize GitHub Actions CI & Release Workflows
    echo "→ Synchronizing .github/workflows/ci.yml..."
    fetch_or_copy "templates/common/.github/workflows/ci.yml" "$target/.github/workflows/ci.yml"
    echo "→ Synchronizing .github/workflows/release.yml..."
    fetch_or_copy "templates/common/.github/workflows/release.yml" "$target/.github/workflows/release.yml"

    # 7. Safe .gitignore merging (ensures private rules, standards, and venvs are ignored)
    local gitignore_file="$target/.gitignore"
    if [[ -f "$gitignore_file" ]]; then
        local to_append=""
        if ! grep -q "\.agents/rules" "$gitignore_file" 2>/dev/null; then
            to_append+=$'\n.agents/rules/'
        fi
        if ! grep -q "\.standards" "$gitignore_file" 2>/dev/null; then
            to_append+=$'\n.standards/'
        fi
        if ! grep -q "\.venv" "$gitignore_file" 2>/dev/null; then
            to_append+=$'\n.venv/'
        fi
        if [[ -n "$to_append" ]]; then
            echo "→ Safely updating .gitignore with private standards and venv entries..."
            printf "%s\n" "$to_append" >> "$gitignore_file"
        fi
    fi

    # 8. Check Python pyproject.toml for ruff pydocstyle configuration
    if [[ -f "$target/pyproject.toml" ]]; then
        echo "→ Inspecting Python pyproject.toml..."
        if ! grep -q 'convention = "google"' "$target/pyproject.toml" 2>/dev/null; then
            echo "  [NOTE] Recommended addition for pyproject.toml: [tool.ruff.lint.pydocstyle] convention = \"google\""
        fi
    fi

    # 9. Run compliance check and auto-remediate deterministic violations
    echo "→ Running compliance audit with auto-remediation (--fix)..."
    local audit_status=0
    if [[ -n "$LOCAL_SOURCE" ]] && [[ -f "$LOCAL_SOURCE/scripts/check-compliance.py" ]]; then
        python3 "$LOCAL_SOURCE/scripts/check-compliance.py" "$target" --fix || audit_status=$?
    fi

    # 10. Automated Git Staging (Eliminates 'fatal: ambiguous argument' on diffs and stages auto-fixes)
    if [[ "$is_git_repo" = true ]] && [[ "$DO_STAGE" = true ]]; then
        echo "→ Staging standardized governance, workflow, and remediated files in git..."
        git -C "$target" add -f .github/workflows/ci.yml .github/workflows/release.yml AGENTS.md .agents/ SECURITY.md .gitattributes 2>/dev/null || true
        if [[ -f "$target/.gitignore" ]]; then
            git -C "$target" add .gitignore 2>/dev/null || true
        fi
        if [[ -f "$target/LICENSE" ]]; then
            git -C "$target" add LICENSE 2>/dev/null || true
        fi
        git -C "$target" add -u "*.html" 2>/dev/null || true
    fi

    if [[ "$audit_status" -eq 0 ]]; then
        echo " [SUCCESS] $target: Standards successfully synchronized and PASSING audit."
    else
        echo " [NOTICE] $target: Standards synchronized. See audit warnings above."
    fi
    return "$audit_status"
}

# Main Execution Routing: Batch Mode (--all) vs Single Target Mode
if [[ "$SYNC_ALL" = true ]]; then
    echo "================================================================="
    echo " Batch Synchronizing All Sibling Projects (Zero-Intervention)"
    echo "================================================================="

    PARENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
    echo "→ Discovering project repositories in: $PARENT_DIR"

    DISCOVERED=()
    for dir in "$PARENT_DIR"/*/; do
        dir="${dir%/}"
        base_name="$(basename "$dir")"
        # Skip standards repository itself, tmp, and archive folders
        if [[ "$base_name" == "Software-standards" ]] || [[ "$base_name" == "tmp" ]] || [[ "$base_name" == "Old Projects"* ]] || [[ "$base_name" == "utils" ]]; then
            continue
        fi
        # Check if project contains git or recognized project descriptors
        if [[ -d "$dir/.git" ]] || [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/package.json" ]] || [[ -f "$dir/AGENTS.md" ]]; then
            DISCOVERED+=("$dir")
        fi
    done

    echo "→ Discovered ${#DISCOVERED[@]} project(s) to synchronize."
    TOTAL_SUCCESS=0
    TOTAL_NOTICES=0

    for proj_dir in "${DISCOVERED[@]}"; do
        echo ""
        if sync_single_project "$proj_dir"; then
            TOTAL_SUCCESS=$((TOTAL_SUCCESS + 1))
        else
            TOTAL_NOTICES=$((TOTAL_NOTICES + 1))
        fi
    done

    echo ""
    echo "================================================================="
    echo " Batch Synchronization Summary: ${TOTAL_SUCCESS} passed, ${TOTAL_NOTICES} with notices."
    echo "================================================================="
    exit 0
else
    sync_single_project "$TARGET_DIR"
    exit $?
fi
