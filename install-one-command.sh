#!/bin/bash
# One-command installer for Biomass Conversion Index Monitoring System
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/fireinbelly/biomass-conversion-index-monitoring-system/main/install-one-command.sh)

set -e

echo "🌱 Biomass Conversion Index Monitoring System - One Command Install"
echo "=================================================================="
echo ""

# Check if we're in a git repo or project directory
if [[ -f "package.json" ]] || [[ -f "pyproject.toml" ]] || [[ -f "Cargo.toml" ]] || [[ -d ".git" ]]; then
    PROJECT_DETECTED=true
    echo "📁 Project detected in current directory"
else
    PROJECT_DETECTED=false
    echo "ℹ️  No specific project detected in current directory"
fi

echo ""
echo "Choose installation type:"
echo "1) Project-level (installs to current directory's .claude/)"
echo "2) User-level (installs to ~/.claude/)"
echo ""

while true; do
    read -p "Enter choice (1 or 2): " choice
    case $choice in
        1)
            INSTALL_TYPE="project"
            PLUGIN_DIR="$(pwd)/.claude"
            DATA_DIR="$(pwd)/.claude/prompt-data"
            TRACKER_PATH="$(pwd)/.claude/prompt-tracker.py"
            echo "✅ Selected: Project-level installation"
            break
            ;;
        2)
            INSTALL_TYPE="user"
            PLUGIN_DIR="$HOME/.claude"
            DATA_DIR="$HOME/.claude/prompt-data"
            TRACKER_PATH="$HOME/.claude/prompt-tracker.py"
            echo "✅ Selected: User-level installation"
            break
            ;;
        *)
            echo "❌ Invalid choice. Please enter 1 or 2."
            ;;
    esac
done

echo ""
echo "📂 Plugin files will be installed to: $PLUGIN_DIR"
echo "💾 Data will be stored in: $DATA_DIR"
echo ""

# Confirm installation
read -p "Proceed with installation? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Installation cancelled"
    exit 0
fi

echo ""
echo "🚀 Installing..."

# Load shared installation functions
if [[ -f "install-lib.sh" ]]; then
    source install-lib.sh
elif command -v curl &> /dev/null; then
    # Download install-lib.sh if not available locally
    TEMP_LIB=$(mktemp)
    if curl -sSL "https://raw.githubusercontent.com/fireinbelly/biomass-conversion-index-monitoring-system/main/install-lib.sh" -o "$TEMP_LIB" 2>/dev/null; then
        source "$TEMP_LIB"
        rm -f "$TEMP_LIB"
    else
        echo "❌ Could not load installation library. Please check your internet connection."
        exit 1
    fi
else
    echo "❌ Cannot load installation library (no curl available). Please ensure install-lib.sh is in the current directory."
    exit 1
fi

# Install better_profanity
install_better_profanity

# Install plugin files
install_plugin_files

echo ""
echo "✅ Installation complete!"
echo ""
echo "🎯 Plugin installed to: $PLUGIN_DIR"
echo "💾 Data will be stored in: $DATA_DIR"
echo ""
echo "🚀 Available commands:"
echo "  /biomass-conversion-index          - View statistics"
echo "  /biomass-conversion-index weekly   - Weekly breakdown"
echo "  /biomass-conversion-index monthly  - Monthly breakdown"
echo "  /harmony-breaches                  - Quick daily summary"
echo ""

if [[ "$INSTALL_TYPE" == "project" ]]; then
    echo "📝 Project-level installation notes:"
    echo "   • Plugin is specific to this project directory"
    echo "   • Data is stored locally in this project"
    echo "   • Use git to share plugin with team members"
elif [[ "$INSTALL_TYPE" == "user" ]]; then
    echo "👤 User-level installation notes:"
    echo "   • Plugin works across all your projects"
    echo "   • Data is centralized in your home directory"  
    echo "   • Commands available in any Claude Code session"
fi

echo ""
echo "⚡ Start using Claude Code and your prompts will be tracked automatically!"
echo "   Use /biomass-conversion-index to see your conversion index statistics."
echo ""