#!/bin/bash
# Installer for the Biomass Conversion Index Monitoring System.
#
# This is the only installer. It replaces install-oneliner.sh, install-smart.sh,
# install-interactive.sh, install-interactive-v2.sh, install-interactive-lang.sh,
# install-i18n.sh, install-one-command.sh and install-lib.sh, which were near-identical
# copies that each carried their own inline copy of the plugin scripts. The scripts now
# live in templates/ only, so a bug gets fixed once instead of eight times.
#
#   bash install.sh                 # ask where to install, defaulting to what fits
#   bash install.sh --user --yes    # no questions
#   bash install.sh --with-amnesia  # also install /digital-amnesia
#
# Set BIOMASS_REPO_URL to install from a fork, a branch, or a local checkout
# (file:///path/to/repo).

set -e

REPO_URL="${BIOMASS_REPO_URL:-https://raw.githubusercontent.com/fireinbelly/biomass-conversion-index-monitoring-system/main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo '')"

INSTALL_TYPE=""
ASSUME_YES=false
WITH_AMNESIA=false

usage() {
    cat <<'USAGE'
Biomass Conversion Index Monitoring System - installer

Usage: bash install.sh [options]

  --project        Install to ./.claude (this project only)
  --user           Install to ~/.claude (every project)
  --yes, -y        Don't ask; use the detected default
  --with-amnesia   Also install the optional /digital-amnesia command
  --help, -h       Show this

With no options the installer asks, defaulting to project-level when the current
directory looks like a project and user-level otherwise.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) INSTALL_TYPE="project" ;;
        --user)    INSTALL_TYPE="user" ;;
        --yes|-y)  ASSUME_YES=true ;;
        --with-amnesia) WITH_AMNESIA=true ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

# `curl ... | bash` hands the script itself to bash on stdin, so there is no terminal to
# read answers from and a `read` would either hit EOF or swallow the script's own text.
# Fall back to the detected defaults instead. Use `bash <(curl ...)` to get the prompts,
# or pass flags explicitly: `curl ... | bash -s -- --user --yes`.
if [[ ! -t 0 ]]; then
    ASSUME_YES=true
fi

echo "🌱 Biomass Conversion Index Monitoring System"
echo "============================================="
echo ""

# --- where does it go -------------------------------------------------------

if [[ -z "$INSTALL_TYPE" ]]; then
    if [[ -f "package.json" || -f "pyproject.toml" || -f "Cargo.toml" || -f "go.mod" || -d ".git" ]]; then
        DEFAULT_TYPE="project"
        echo "📁 This looks like a project directory."
    else
        DEFAULT_TYPE="user"
        echo "ℹ️  No project detected here."
    fi

    if $ASSUME_YES; then
        INSTALL_TYPE="$DEFAULT_TYPE"
    else
        echo ""
        echo "  1) Project-level  - ./.claude, tracks only this project, shareable via git"
        echo "  2) User-level     - ~/.claude, tracks every project you work on"
        echo ""
        read -p "Choice [default: $DEFAULT_TYPE]: " choice
        case "$choice" in
            1|project) INSTALL_TYPE="project" ;;
            2|user)    INSTALL_TYPE="user" ;;
            "")        INSTALL_TYPE="$DEFAULT_TYPE" ;;
            *) echo "❌ Didn't understand '$choice'." >&2; exit 1 ;;
        esac
    fi
fi

if [[ "$INSTALL_TYPE" == "project" ]]; then
    PLUGIN_DIR="$(pwd)/.claude"
else
    PLUGIN_DIR="$HOME/.claude"
fi
DATA_DIR="$PLUGIN_DIR/prompt-data"
TRACKER_PATH="$PLUGIN_DIR/prompt-tracker.py"

echo ""
echo "📂 Plugin:  $PLUGIN_DIR"
echo "💾 Data:    $DATA_DIR"
echo ""

if ! $ASSUME_YES; then
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
        echo "❌ Cancelled."
        exit 0
    fi
fi

# --- fetching ---------------------------------------------------------------

# $1 is repo-relative (templates/curse-stats.py, i18n.py, locales/en.json), so files
# outside templates/ can be installed too. $3 replaces the {{...}} placeholders.
install_file() {
    local src_path="$1" dest_file="$2" use_placeholders="${3:-false}"
    local local_src="$src_path"
    [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$src_path" ]] && local_src="$SCRIPT_DIR/$src_path"

    mkdir -p "$(dirname "$dest_file")"

    if [[ -f "$local_src" ]]; then
        cp "$local_src" "$dest_file"
        echo "   ✅ $src_path"
    elif command -v curl &> /dev/null; then
        # --fail matters: without it curl writes GitHub's "404: Not Found" body into the
        # destination and still exits 0, so a missing file installs as a broken script
        # while the installer reports success.
        if curl -sSL --fail "$REPO_URL/$src_path" -o "$dest_file"; then
            echo "   ✅ $src_path"
        else
            rm -f "$dest_file"
            echo "   ❌ could not fetch $src_path" >&2
            return 1
        fi
    else
        echo "   ❌ need curl to fetch $src_path" >&2
        return 1
    fi

    if [[ "$use_placeholders" == "true" ]]; then
        sed -e "s|{{DATA_DIR}}|$DATA_DIR|g" \
            -e "s|{{PLUGIN_DIR}}|$PLUGIN_DIR|g" \
            -e "s|{{TRACKER_PATH}}|$TRACKER_PATH|g" \
            "$dest_file" > "$dest_file.tmp" && mv "$dest_file.tmp" "$dest_file"
    fi
}

# Merge our hook into settings.json instead of overwriting the file. Claude Code keeps
# ALL hooks, permissions, env and MCP config in there, so writing a fresh settings.json
# silently deletes whatever else the user had configured.
merge_hook_settings() {
    local settings_file="$1" hook_command="$2"
    mkdir -p "$(dirname "$settings_file")"
    python3 - "$settings_file" "$hook_command" <<'MERGE_SETTINGS_EOF'
import json, os, sys

path, command = sys.argv[1], sys.argv[2]

settings = {}
if os.path.exists(path):
    with open(path, encoding='utf-8') as handle:
        existing = handle.read().strip()
    if existing:
        try:
            settings = json.loads(existing)
        except json.JSONDecodeError as exc:
            sys.exit("   %s is not valid JSON (%s). Nothing was changed - fix it and re-run." % (path, exc))

groups = settings.setdefault('hooks', {}).setdefault('UserPromptSubmit', [])
if any(hook.get('command') == command for group in groups for hook in group.get('hooks', [])):
    print('   Hook already present, settings.json left alone.')
else:
    groups.append({'hooks': [{'type': 'command', 'command': command, 'timeout': 5}]})
    with open(path, 'w', encoding='utf-8') as handle:
        json.dump(settings, handle, indent=2)
        handle.write('\n')
    print('   Hook merged into settings.json (existing config preserved).')
MERGE_SETTINGS_EOF
}

# --- install ----------------------------------------------------------------

command -v python3 &> /dev/null || { echo "❌ python3 is required." >&2; exit 1; }

echo "📥 Installing..."
mkdir -p "$DATA_DIR"

install_file "templates/prompt-tracker.py" "$PLUGIN_DIR/prompt-tracker.py"
install_file "templates/curse-stats.py"    "$PLUGIN_DIR/curse-stats.py"

# Both scripts do `from i18n import ...` and i18n.py loads locales/ relative to itself,
# so the runtime has to sit next to them. Language comes from LANG at runtime.
install_file "i18n.py"          "$PLUGIN_DIR/i18n.py"
install_file "locales/en.json"  "$PLUGIN_DIR/locales/en.json"

install_file "templates/commands/biomass-conversion-index.md" \
             "$PLUGIN_DIR/commands/biomass-conversion-index.md" true
install_file "templates/commands/harmony-breaches.md" \
             "$PLUGIN_DIR/commands/harmony-breaches.md" true

if $WITH_AMNESIA; then
    install_file "templates/digital-amnesia.py" "$PLUGIN_DIR/digital-amnesia.py"
    install_file "templates/digital-amnesia.md" "$PLUGIN_DIR/commands/digital-amnesia.md" true
fi

chmod +x "$PLUGIN_DIR"/*.py

merge_hook_settings "$PLUGIN_DIR/settings.json" "BIOMASS_DATA_DIR=\"$DATA_DIR\" $TRACKER_PATH"

echo ""
echo "✅ Done."
echo ""
echo "🚀 Commands:"
echo "   /biomass-conversion-index [daily|weekly|monthly|hourly] [--last N]"
echo "   /harmony-breaches"
if $WITH_AMNESIA; then echo "   /digital-amnesia [--force]"; fi
echo ""
if [[ "$INSTALL_TYPE" == "project" ]]; then
    echo "📝 Project-level: only tracks work in this directory."
else
    echo "👤 User-level: tracks every project."
fi
echo "🔒 Data stays in $DATA_DIR. Nothing is uploaded anywhere."
echo ""
echo "Restart Claude Code (or start a new session) to activate the hook."
