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
  # From inside an existing project:
  curl -fsSL https://raw.githubusercontent.com/joelontheroad/Software-standards/main/scripts/sync-standards.sh | bash

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

fetch_or_copy() {
    local rel_path="$1"
    local dest_path="$2"

    mkdir -p "$(dirname "$dest_path")"

    if [[ -n "$LOCAL_SOURCE" ]]; then
        cp "$LOCAL_SOURCE/$rel_path" "$dest_path"
    else
        curl -fsSL "$RAW_BASE_URL/$rel_path" -o "$dest_path"
    fi
}

if [[ "$CHECK_ONLY" = true ]]; then
    echo "→ Running standards compliance check..."
    if [[ -n "$LOCAL_SOURCE" ]] && [[ -f "$LOCAL_SOURCE/scripts/check-compliance.py" ]]; then
        python3 "$LOCAL_SOURCE/scripts/check-compliance.py" "$TARGET_DIR" || true
    else
        TMP_AUDIT_SCRIPT="$(mktemp)"
        curl -fsSL "$RAW_BASE_URL/scripts/check-compliance.py" -o "$TMP_AUDIT_SCRIPT"
        python3 "$TMP_AUDIT_SCRIPT" "$TARGET_DIR" || true
        rm -f "$TMP_AUDIT_SCRIPT"
    fi
    exit 0
fi

# 1. Update AGENTS.md
echo "→ Updating AGENTS.md..."
fetch_or_copy "AGENTS.md" "$TARGET_DIR/AGENTS.md"

# 2. Update .agents/rules/enforce-standards.md
echo "→ Updating .agents/rules/enforce-standards.md..."
fetch_or_copy ".agents/rules/enforce-standards.md" "$TARGET_DIR/.agents/rules/enforce-standards.md"

# 3. Synchronize SECURITY.md if missing
if [[ ! -f "$TARGET_DIR/SECURITY.md" ]]; then
    echo "→ Creating missing SECURITY.md..."
    fetch_or_copy "templates/common/SECURITY.md" "$TARGET_DIR/SECURITY.md"
fi

# 4. Synchronize .gitattributes if missing
if [[ ! -f "$TARGET_DIR/.gitattributes" ]]; then
    echo "→ Creating missing .gitattributes..."
    fetch_or_copy "templates/common/.gitattributes" "$TARGET_DIR/.gitattributes"
fi

# 5. Check Python pyproject.toml for ruff pydocstyle configuration
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

# 6. Run compliance check
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
echo "to bring all existing code into compliance with Directive 12:"
echo ""
cat << 'EOF'
-----------------------------------------------------------------
/plan Review all source files in this repository against our updated
AGENTS.md Directive 12 (In-Code Documentation & Commenting Standards).

1. Ensure each module begins with an architectural summary docstring
   immediately following the SPDX header.
2. Upgrade public functions and classes to Google Style docstrings (or JSDoc)
   using lean typing without duplicate type annotations.
3. Add '# SECURITY:' rationale comments on timing comparisons, path
   canonicalization, and permission settings.
4. Clean up any redundant code narrations or dead code.
5. In pyproject.toml, ensure ruff includes "D" in lint.select and
   pydocstyle.convention = "google".
6. Run tests to confirm zero regressions.
-----------------------------------------------------------------
EOF
echo ""
