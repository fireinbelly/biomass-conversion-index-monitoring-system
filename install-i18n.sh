#!/bin/bash
# I18n-ready installer for Biomass Conversion Index Monitoring System
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/fireinbelly/biomass-conversion-index-monitoring-system/main/install-i18n.sh)

set -e

# Language detection function
detect_language() {
    # Check environment variables for language preference
    for env_var in LC_MESSAGES LC_ALL LANG; do
        if [[ -n "${!env_var}" ]]; then
            lang="${!env_var}"
            # Extract language code (e.g., 'es_ES.UTF-8' -> 'es')
            lang_code="${lang%%_*}"
            lang_code="${lang_code%%.*}"
            if [[ ${#lang_code} -eq 2 ]]; then
                echo "$lang_code"
                return
            fi
        fi
    done
    echo "en"  # Default to English
}

DETECTED_LANG=$(detect_language)

echo "🌱 Biomass Conversion Index Monitoring System - I18n Installer"
echo "=============================================================="
echo "Language: $DETECTED_LANG"
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

# Create directories
mkdir -p "$PLUGIN_DIR/commands"
mkdir -p "$PLUGIN_DIR/locales"
mkdir -p "$DATA_DIR"

# Download and install i18n infrastructure
echo "📥 Installing i18n infrastructure..."

# Create i18n.py
cat > "$PLUGIN_DIR/i18n.py" << 'I18N_EOF'
#!/usr/bin/env python3
"""
Internationalization (i18n) module for Biomass Conversion Index Monitoring System
Handles loading and formatting localized strings
"""
import json
import os
from pathlib import Path

class I18n:
    def __init__(self, lang=None):
        self.lang = lang or self._detect_language()
        self.strings = self._load_strings()
    
    def _detect_language(self):
        """Detect language from environment variables"""
        # Check common environment variables in order of preference
        for env_var in ['LC_MESSAGES', 'LC_ALL', 'LANG']:
            if env_var in os.environ:
                locale = os.environ[env_var]
                if locale:
                    # Extract language code (e.g., 'es_ES.UTF-8' -> 'es')
                    lang = locale.split('_')[0].split('.')[0]
                    if lang and len(lang) == 2:
                        return lang
        
        # Default to English
        return 'en'
    
    def _load_strings(self):
        """Load strings for the detected/specified language"""
        # Get the directory where this script is located
        script_dir = Path(__file__).parent
        locales_dir = script_dir / 'locales'
        
        # Try to load the requested language
        lang_file = locales_dir / f'{self.lang}.json'
        if lang_file.exists():
            try:
                with open(lang_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        
        # Fallback to English
        en_file = locales_dir / 'en.json'
        try:
            with open(en_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            # Ultimate fallback: empty dict
            return {}
    
    def get(self, key_path, **kwargs):
        """
        Get a localized string by key path (e.g., 'stats.title')
        Supports string formatting with kwargs
        """
        keys = key_path.split('.')
        value = self.strings
        
        # Navigate through the nested dictionary
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                # Return the key path if not found (for debugging)
                return f"[{key_path}]"
        
        # If it's a string, format it with provided kwargs
        if isinstance(value, str) and kwargs:
            try:
                return value.format(**kwargs)
            except (KeyError, ValueError):
                # If formatting fails, return unformatted string
                return value
        
        return value
    
    def get_list(self, key_path):
        """Get a list value (e.g., for curse words)"""
        value = self.get(key_path)
        if isinstance(value, list):
            return value
        return []

# Global instance - can be overridden by setting environment variables
_i18n = None

def init_i18n(lang=None):
    """Initialize the global i18n instance"""
    global _i18n
    _i18n = I18n(lang)
    return _i18n

def get_i18n():
    """Get the global i18n instance, initializing if needed"""
    global _i18n
    if _i18n is None:
        _i18n = I18n()
    return _i18n

def _(key_path, **kwargs):
    """Shorthand function for getting localized strings"""
    return get_i18n().get(key_path, **kwargs)

def _list(key_path):
    """Shorthand function for getting localized lists"""
    return get_i18n().get_list(key_path)
I18N_EOF

# Create English locale file
cat > "$PLUGIN_DIR/locales/en.json" << 'EN_LOCALE_EOF'
{
  "app": {
    "name": "Biomass Conversion Index Monitoring System",
    "description": "Claude Code plugin for monitoring biomass conversion index events"
  },
  "stats": {
    "title": "Biomass Conversion Index Statistics ({period})",
    "total_prompts": "Total Prompts: {count}",
    "total_breaches": "Total Harmony Breaches: {count}",
    "average_deviation": "Average Harmony Deviation Index: {value}",
    "breakdown_title": "Breakdown by {period}:",
    "prompts_count": "Prompts: {count}",
    "breach_count": "Breach Count: {count}",
    "predominant_types": "Predominant Breach Types: {types}",
    "date_range": "Date range: {start} to {end}",
    "no_breaches_today": "No harmony breaches today! 🌿"
  },
  "periods": {
    "daily": "Daily",
    "weekly": "Weekly", 
    "monthly": "Monthly",
    "hourly": "Hourly"
  },
  "errors": {
    "reading_file": "Error reading {file}: {error}",
    "no_data_dir": "beginning"
  },
  "indicators": {
    "curse_words": ["damn", "shit", "fuck", "ass", "bitch", "hell", "crap", "piss", "bastard", "slut", "whore", "dick", "cock", "pussy", "tits", "balls", "suck", "bloody"]
  }
}
EN_LOCALE_EOF

# Create i18n-ready prompt tracker script
cat > "$PLUGIN_DIR/prompt-tracker.py" << 'TRACKER_EOF'
#!/usr/bin/env python3
import sys
import json
import os
from datetime import datetime
import re
from pathlib import Path

# Add the current directory to sys.path to import i18n
sys.path.insert(0, str(Path(__file__).parent))

try:
    from i18n import _, _list
except ImportError:
    # Fallback if i18n is not available
    def _(key, **kwargs):
        return key
    def _list(key):
        return ["damn", "shit", "fuck", "ass", "bitch", "hell", "crap", "piss", "bastard", "slut", "whore", "dick", "cock", "pussy", "tits", "balls", "suck", "bloody"]

def count_curse_words(text):
    """Count biomass conversion indicators in text"""
    # Get indicators from localization
    try:
        curse_words = _list('indicators.curse_words')
    except:
        # Fallback list
        curse_words = ["damn", "shit", "fuck", "ass", "bitch", "hell", "crap", "piss", "bastard", "slut", "whore", "dick", "cock", "pussy", "tits", "balls", "suck", "bloody"]
    
    # Convert to lowercase and split into words
    words = re.findall(r'\b\w+\b', text.lower())
    
    curse_count = 0
    found_curses = []
    
    for word in words:
        if word in curse_words:
            curse_count += 1
            found_curses.append(word)
    
    return curse_count, found_curses

def save_prompt_data(prompt, curse_count, found_curses):
    """Save prompt data to storage"""
    # Use data directory from environment or default
    data_dir = os.environ.get('BIOMASS_DATA_DIR', os.path.expanduser("~/.claude/prompt-data"))
    os.makedirs(data_dir, exist_ok=True)
    
    # Prepare data entry
    entry = {
        "timestamp": datetime.now().isoformat(),
        "prompt": prompt,
        "curse_count": curse_count,
        "found_curses": found_curses,
        "date": datetime.now().strftime("%Y-%m-%d"),
        "hour": datetime.now().hour
    }
    
    # Append to daily log file
    date_str = datetime.now().strftime("%Y-%m-%d")
    log_file = os.path.join(data_dir, f"prompts_{date_str}.jsonl")
    
    try:
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')
    except IOError as e:
        # Fail silently - we don't want to break Claude Code
        pass

def main():
    """Main entry point"""
    # Read the prompt from stdin (this is how Claude Code passes the user's prompt)
    prompt = sys.stdin.read().strip()
    
    # Count biomass conversion indicators
    curse_count, found_curses = count_curse_words(prompt)
    
    # Save prompt data
    save_prompt_data(prompt, curse_count, found_curses)
    
    # Return the original prompt unchanged (exit code 0 means continue processing)
    print(prompt)
    sys.exit(0)

if __name__ == "__main__":
    main()
TRACKER_EOF

# Create i18n-ready stats script (compact version for installer)
cat > "$PLUGIN_DIR/curse-stats.py" << 'STATS_EOF'
#!/usr/bin/env python3
import sys,json,os,glob
from datetime import datetime,timedelta
from collections import defaultdict,Counter
from pathlib import Path

# Add the current directory to sys.path to import i18n
sys.path.insert(0, str(Path(__file__).parent))

try:
    from i18n import _, _list
except ImportError:
    # Fallback if i18n is not available
    def _(key, **kwargs):
        if 'stats.title' in key:
            return f"⚡ Biomass Conversion Index Statistics ({kwargs.get('period', 'Daily')})"
        elif 'total_prompts' in key:
            return f"Total Prompts: {kwargs.get('count', 0)}"
        elif 'total_breaches' in key:
            return f"Total Harmony Breaches: {kwargs.get('count', 0)}"
        elif 'average_deviation' in key:
            return f"Average Harmony Deviation Index: {kwargs.get('value', '0.00')}"
        elif 'breakdown_title' in key:
            return f"Breakdown by {kwargs.get('period', 'Daily')}:"
        elif 'prompts_count' in key:
            return f"Prompts: {kwargs.get('count', 0)}"
        elif 'breach_count' in key:
            return f"Breach Count: {kwargs.get('count', 0)}"
        elif 'predominant_types' in key:
            return f"Predominant Breach Types: {kwargs.get('types', '')}"
        return key

def load_data(start_date=None,end_date=None):
    data_dir=os.environ.get('BIOMASS_DATA_DIR',os.path.expanduser("~/.claude/prompt-data"))
    if not os.path.exists(data_dir):return[]
    all_data=[]
    for file_path in glob.glob(os.path.join(data_dir,"prompts_*.jsonl")):
        try:
            with open(file_path,'r',encoding='utf-8') as f:
                for line in f:
                    if line.strip():
                        entry=json.loads(line)
                        entry_date=datetime.fromisoformat(entry['timestamp']).date()
                        if start_date and entry_date<start_date:continue
                        if end_date and entry_date>end_date:continue
                        all_data.append(entry)
        except:pass
    return all_data

def calc_stats(data,period="daily"):
    if not data:return{"total_prompts":0,"total_curses":0,"average_curses_per_prompt":0,"stats_by_period":{}}
    total_prompts,total_curses=len(data),sum(e['curse_count'] for e in data)
    stats=defaultdict(lambda:{"prompts":0,"curses":0,"curse_words":Counter()})
    for entry in data:
        dt=datetime.fromisoformat(entry['timestamp'])
        key=dt.strftime("%Y-%m-%d") if period=="daily" else dt.strftime("%Y-%m") if period=="monthly" else f"Week of {(dt-timedelta(days=dt.weekday())).strftime('%Y-%m-%d')}"
        stats[key]["prompts"]+=1
        stats[key]["curses"]+=entry['curse_count']
        for curse in entry['found_curses']:stats[key]["curse_words"][curse]+=1
    return{"total_prompts":total_prompts,"total_curses":total_curses,"average_curses_per_prompt":total_curses/total_prompts if total_prompts>0 else 0,"stats_by_period":dict(stats)}

def print_stats(stats,period="daily"):
    period_cap = period.title()
    print(f"\n{_('stats.title', period=period_cap)}")
    print("="*50)
    print(_('stats.total_prompts', count=stats['total_prompts']))
    print(_('stats.total_breaches', count=stats['total_curses']))
    print(_('stats.average_deviation', value=f"{stats['average_curses_per_prompt']:.2f}"))
    if stats['stats_by_period']:
        print(f"\n{_('stats.breakdown_title', period=period_cap)}")
        print("-"*30)
        for k,v in sorted(stats['stats_by_period'].items()):
            print(f"\n{k}:")
            print(f"  {_('stats.prompts_count', count=v['prompts'])}")
            print(f"  {_('stats.breach_count', count=v['curses'])}")
            if v['curse_words']:
                types_list = ', '.join([f'{w}({c})' for w,c in v['curse_words'].most_common(3)])
                print(f"  {_('stats.predominant_types', types=types_list)}")

period,start_date,end_date="daily",None,None
args=sys.argv[1:]
for i,arg in enumerate(args):
    if arg in["daily","weekly","monthly"]:period=arg
    elif arg=="--last" and i+1<len(args):end_date,start_date=datetime.now().date(),datetime.now().date()-timedelta(days=int(args[i+1]))
print_stats(calc_stats(load_data(start_date,end_date),period),period)
STATS_EOF

# Create commands with i18n support
cat > "$PLUGIN_DIR/commands/biomass-conversion-index.md" << EOF
---
description: "Show biomass conversion index statistics from your prompts"
tools: ["Bash"]
---
# Biomass Conversion Index Statistics
Usage: /biomass-conversion-index [daily|weekly|monthly] [--last N]
\`\`\`bash
BIOMASS_DATA_DIR="$DATA_DIR" python3 $PLUGIN_DIR/curse-stats.py \$ARGUMENTS
\`\`\`
EOF

cat > "$PLUGIN_DIR/commands/harmony-breaches.md" << EOF
---
description: "Quick check of harmony breaches today"
tools: ["Bash"]
---
# Harmony Breaches Today
\`\`\`bash
BIOMASS_DATA_DIR="$DATA_DIR" python3 $PLUGIN_DIR/curse-stats.py daily --last 1 | grep -E "(Total|Index)" || echo "No harmony breaches today! 🌿"
\`\`\`
EOF

# Make scripts executable
chmod +x "$PLUGIN_DIR"/*.py

# Create settings
cat > "$PLUGIN_DIR/settings.json" << EOF
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command", 
            "command": "BIOMASS_DATA_DIR=\"$DATA_DIR\" $TRACKER_PATH"
          }
        ]
      }
    ]
  }
}
EOF

echo ""
echo "✅ Biomass Conversion Index Monitoring System installed with i18n support!"
echo "🌐 Language: $DETECTED_LANG (detected from environment)"
echo "📊 Commands: /biomass-conversion-index, /harmony-breaches"
echo ""
echo "🔧 Language customization:"
echo "   • Set LANG=es to use Spanish (when available)"
echo "   • Set LC_MESSAGES=fr to use French (when available)"
echo "   • Add more languages by creating locale files"
echo ""
echo "⚡ Your prompts will now be tracked automatically!"