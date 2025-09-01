#!/bin/bash
# Shared installation functions for Biomass Conversion Index Monitoring System

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

# Function to download or copy template files
install_template() {
    local src_file=$1
    local dest_file=$2
    local use_placeholders=${3:-false}
    
    REPO_URL="https://raw.githubusercontent.com/fireinbelly/biomass-conversion-index-monitoring-system/main"
    
    if [[ -f "templates/$src_file" ]]; then
        # Local development - copy from templates
        if $use_placeholders; then
            # Replace placeholders in template
            sed -e "s|{{DATA_DIR}}|$DATA_DIR|g" \
                -e "s|{{PLUGIN_DIR}}|$PLUGIN_DIR|g" \
                -e "s|{{TRACKER_PATH}}|$TRACKER_PATH|g" \
                "templates/$src_file" > "$dest_file"
        else
            cp "templates/$src_file" "$dest_file"
        fi
        echo "   ✅ Copied $src_file"
    elif command -v curl &> /dev/null; then
        # Download from GitHub
        if curl -sSL "$REPO_URL/templates/$src_file" -o "$dest_file" 2>/dev/null; then
            if $use_placeholders; then
                # Replace placeholders after download
                sed -i.bak -e "s|{{DATA_DIR}}|$DATA_DIR|g" \
                           -e "s|{{PLUGIN_DIR}}|$PLUGIN_DIR|g" \
                           -e "s|{{TRACKER_PATH}}|$TRACKER_PATH|g" \
                           "$dest_file" && rm -f "$dest_file.bak"
            fi
            echo "   ✅ Downloaded $src_file"
        else
            echo "   ❌ Failed to download $src_file"
            return 1
        fi
    else
        echo "   ❌ Cannot download $src_file (no curl available)"
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
    
    # Install core files
    install_template ".claude/prompt-tracker.py" "$PLUGIN_DIR/prompt-tracker.py" false
    install_template ".claude/curse-stats.py" "$PLUGIN_DIR/curse-stats.py" false
    install_template ".claude/commands/biomass-conversion-index.md" "$PLUGIN_DIR/commands/biomass-conversion-index.md" true
    install_template ".claude/commands/harmony-breaches.md" "$PLUGIN_DIR/commands/harmony-breaches.md" true
    install_template ".claude/settings.json.template" "$PLUGIN_DIR/settings.json" true
    
    # Make executable
    chmod +x "$PLUGIN_DIR"/*.py
}