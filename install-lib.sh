#!/bin/bash
# Shared installation functions for Biomass Conversion Index Monitoring System

# Merge our hook into settings.json instead of overwriting the file.
# Claude Code keeps ALL hooks, permissions, env and MCP config in this one file,
# so writing a fresh settings.json silently deletes whatever else was there.
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

# Function to try installing with different methods
install_profanity() {
    local method=$1
    local command=$2
    echo "   Trying $method..."
    if eval "$command" 2>/dev/null; then
        echo "   ✅ Installed with $method"
        PROFANITY_INSTALLED=true
        return 0
    else
        echo "   ❌ Failed with $method"
        return 1
    fi
}

# Install better_profanity using available package managers
install_better_profanity() {
    echo "📦 Installing better_profanity package..."
    PROFANITY_INSTALLED=false

    # Try different installation methods
    if ! $PROFANITY_INSTALLED && command -v conda &> /dev/null; then
        install_profanity "conda" "conda install -c conda-forge better-profanity -y --quiet"
    fi

    if ! $PROFANITY_INSTALLED && [[ -n "$VIRTUAL_ENV" ]] && command -v pip &> /dev/null; then
        install_profanity "pip (virtual env)" "pip install better-profanity --quiet"
    fi

    if ! $PROFANITY_INSTALLED && command -v pip3 &> /dev/null; then
        install_profanity "pip3 --user" "pip3 install better-profanity --user --quiet"
    fi

    if ! $PROFANITY_INSTALLED && command -v pip &> /dev/null; then
        install_profanity "pip --user" "pip install better-profanity --user --quiet"
    fi

    if ! $PROFANITY_INSTALLED && command -v pipx &> /dev/null; then
        install_profanity "pipx" "pipx install better-profanity --quiet"
    fi

    # Try with --break-system-packages as last resort
    if ! $PROFANITY_INSTALLED && command -v pip3 &> /dev/null; then
        install_profanity "pip3 --break-system-packages" "pip3 install better-profanity --break-system-packages --quiet"
    fi

    if ! $PROFANITY_INSTALLED && command -v pip &> /dev/null; then
        install_profanity "pip --break-system-packages" "pip install better-profanity --break-system-packages --quiet"
    fi

    if ! $PROFANITY_INSTALLED; then
        echo "⚠️  Could not install better-profanity with any method."
        echo "   The system will use fallback profanity detection."
        echo "   For better detection, manually install: pip install better-profanity"
    fi
}

# Function to download or copy a repo file
# $1 is repo-relative (e.g. templates/curse-stats.py, i18n.py, locales/en.json) so
# files outside templates/ can be installed too.
install_template() {
    local src_path=$1
    local dest_file=$2
    local use_placeholders=${3:-false}

    # Overridable so forks, branches and the test suite can install from elsewhere.
    REPO_URL="${BIOMASS_REPO_URL:-https://raw.githubusercontent.com/fireinbelly/biomass-conversion-index-monitoring-system/main}"

    mkdir -p "$(dirname "$dest_file")"

    if [[ -f "$src_path" ]]; then
        # Local development - copy from the checkout
        if $use_placeholders; then
            # Replace placeholders in template
            sed -e "s|{{DATA_DIR}}|$DATA_DIR|g" \
                -e "s|{{PLUGIN_DIR}}|$PLUGIN_DIR|g" \
                -e "s|{{TRACKER_PATH}}|$TRACKER_PATH|g" \
                "$src_path" > "$dest_file"
        else
            cp "$src_path" "$dest_file"
        fi
        echo "   ✅ Copied $src_path"
    elif command -v curl &> /dev/null; then
        # --fail matters: without it curl writes GitHub's "404: Not Found" body into
        # the destination and still exits 0, so a missing file installs as a broken
        # script and the installer reports success.
        if curl -sSL --fail "$REPO_URL/$src_path" -o "$dest_file"; then
            if $use_placeholders; then
                # Replace placeholders after download
                sed -i.bak -e "s|{{DATA_DIR}}|$DATA_DIR|g" \
                           -e "s|{{PLUGIN_DIR}}|$PLUGIN_DIR|g" \
                           -e "s|{{TRACKER_PATH}}|$TRACKER_PATH|g" \
                           "$dest_file" && rm -f "$dest_file.bak"
            fi
            echo "   ✅ Downloaded $src_path"
        else
            echo "   ❌ Failed to download $src_path"
            rm -f "$dest_file"
            return 1
        fi
    else
        echo "   ❌ Cannot download $src_path (no curl available)"
        return 1
    fi
    return 0
}

# Install all core plugin files
install_plugin_files() {
    echo "📥 Installing plugin files..."
    
    # Create directories
    mkdir -p "$PLUGIN_DIR/commands"
    mkdir -p "$DATA_DIR"
    
    # Install core files. Any failure aborts: a half-installed plugin that reports
    # success is how the missing templates went unnoticed.
    install_template "templates/prompt-tracker.py" "$PLUGIN_DIR/prompt-tracker.py" false || return 1
    install_template "templates/curse-stats.py" "$PLUGIN_DIR/curse-stats.py" false || return 1

    # Both scripts do `from i18n import ...` and i18n.py loads locales/ from its own
    # directory, so the runtime has to sit next to them.
    install_template "i18n.py" "$PLUGIN_DIR/i18n.py" false || return 1
    install_template "locales/en.json" "$PLUGIN_DIR/locales/en.json" false || return 1

    install_template "templates/commands/biomass-conversion-index.md" "$PLUGIN_DIR/commands/biomass-conversion-index.md" true || return 1
    install_template "templates/commands/harmony-breaches.md" "$PLUGIN_DIR/commands/harmony-breaches.md" true || return 1

    merge_hook_settings "$PLUGIN_DIR/settings.json" "BIOMASS_DATA_DIR=\"$DATA_DIR\" $TRACKER_PATH" || return 1

    # Make executable
    chmod +x "$PLUGIN_DIR"/*.py
}