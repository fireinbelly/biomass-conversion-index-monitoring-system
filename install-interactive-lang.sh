#!/bin/bash
# Interactive language selection installer for Biomass Conversion Index Monitoring System
# Usage: bash <(curl -sSL https://raw.githubusercontent.com/fireinbelly/biomass-conversion-index-monitoring-system/main/install-interactive-lang.sh)

set -e

# Download and source language configuration functions
get_languages_config() {
    cat << 'LANG_CONFIG_EOF'
import json
import sys
from pathlib import Path

def load_languages():
    # Hardcoded for installer - will be updated from languages.json after installation
    return {
        "available_languages": [
            {"code": "en", "name": "English", "native_name": "English", "flag": "🇺🇸", "status": "complete"},
            {"code": "es", "name": "Spanish", "native_name": "Español", "flag": "🇪🇸", "status": "planned"},
            {"code": "fr", "name": "French", "native_name": "Français", "flag": "🇫🇷", "status": "planned"},
            {"code": "pt", "name": "Portuguese", "native_name": "Português", "flag": "🇵🇹", "status": "planned"},
            {"code": "de", "name": "German", "native_name": "Deutsch", "flag": "🇩🇪", "status": "planned"},
            {"code": "zh", "name": "Chinese", "native_name": "中文", "flag": "🇨🇳", "status": "planned"}
        ],
        "default_language": "en",
        "fallback_language": "en",
        "auto_detect": True
    }

def detect_system_language():
    import os
    for env_var in ['LC_MESSAGES', 'LC_ALL', 'LANG']:
        if env_var in os.environ:
            locale = os.environ[env_var]
            if locale:
                lang = locale.split('_')[0].split('.')[0]
                if len(lang) == 2:
                    return lang
    return 'en'

def get_language_by_code(code):
    languages = load_languages()
    for lang in languages['available_languages']:
        if lang['code'] == code:
            return lang
    return None

if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == 'list':
            languages = load_languages()
            for i, lang in enumerate(languages['available_languages'], 1):
                status_indicator = "✅" if lang['status'] == 'complete' else "🚧" if lang['status'] == 'planned' else "❌"
                print(f"{i}) {lang['flag']} {lang['native_name']} ({lang['name']}) {status_indicator}")
        elif sys.argv[1] == 'detect':
            detected = detect_system_language()
            lang = get_language_by_code(detected)
            if lang:
                print(f"{detected}|{lang['flag']} {lang['native_name']}")
            else:
                print("en|🇺🇸 English")
        elif sys.argv[1] == 'get' and len(sys.argv) > 2:
            index = int(sys.argv[2]) - 1
            languages = load_languages()['available_languages']
            if 0 <= index < len(languages):
                lang = languages[index]
                print(f"{lang['code']}|{lang['flag']} {lang['native_name']}")
LANG_CONFIG_EOF
}

echo "🌱 Biomass Conversion Index Monitoring System - Interactive Installer"
echo "===================================================================="
echo ""

# Create temporary Python helper
TEMP_LANG_HELPER=$(mktemp)
get_languages_config > "$TEMP_LANG_HELPER"

# Detect system language
DETECTED_LANG_INFO=$(python3 "$TEMP_LANG_HELPER" detect)
DETECTED_CODE="${DETECTED_LANG_INFO%%|*}"
DETECTED_DISPLAY="${DETECTED_LANG_INFO##*|}"

echo "🌐 Language Selection"
echo "System detected: $DETECTED_DISPLAY"
echo ""
echo "Available languages:"

# Show language options
python3 "$TEMP_LANG_HELPER" list

echo ""
echo "Which language would you like to use?"

# Find detected language index
DETECTED_INDEX=""
LANG_COUNT=$(python3 "$TEMP_LANG_HELPER" list | wc -l)

for i in $(seq 1 $LANG_COUNT); do
    LANG_INFO=$(python3 "$TEMP_LANG_HELPER" get $i)
    LANG_CODE="${LANG_INFO%%|*}"
    if [[ "$LANG_CODE" == "$DETECTED_CODE" ]]; then
        DETECTED_INDEX=$i
        break
    fi
done

if [[ -n "$DETECTED_INDEX" ]]; then
    DEFAULT_CHOICE=$DETECTED_INDEX
    echo "Recommendation: $DETECTED_INDEX (based on your system settings)"
else
    DEFAULT_CHOICE=1
    echo "Recommendation: 1 (English - default)"
fi

echo ""
while true; do
    read -p "Choice [default: $DEFAULT_CHOICE]: " choice
    choice=${choice:-$DEFAULT_CHOICE}
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$LANG_COUNT" ]; then
        SELECTED_LANG_INFO=$(python3 "$TEMP_LANG_HELPER" get $choice)
        SELECTED_CODE="${SELECTED_LANG_INFO%%|*}"
        SELECTED_DISPLAY="${SELECTED_LANG_INFO##*|}"
        echo "✅ Selected: $SELECTED_DISPLAY"
        break
    else
        echo "❌ Invalid choice. Please enter a number between 1 and $LANG_COUNT."
    fi
done

# Clean up temporary file
rm "$TEMP_LANG_HELPER"

echo ""

# Installation type selection (same as before)
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
    read -p "Enter choice (1 or 2): " install_choice
    case $install_choice in
        1)
            INSTALL_TYPE="project"
            PLUGIN_DIR="$(pwd)/.claude"
            DATA_DIR="$(pwd)/.claude/prompt-data"
            TRACKER_PATH="$(pwd)/.claude/prompt-tracker.py"
            CONFIG_PATH="$(pwd)/.claude/biomass-config.json"
            echo "✅ Selected: Project-level installation"
            break
            ;;
        2)
            INSTALL_TYPE="user"
            PLUGIN_DIR="$HOME/.claude"
            DATA_DIR="$HOME/.claude/prompt-data"
            TRACKER_PATH="$HOME/.claude/prompt-tracker.py"
            CONFIG_PATH="$HOME/.biomass-config.json"
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
echo "🌐 Language: $SELECTED_DISPLAY"
echo "⚙️  Configuration: $CONFIG_PATH"
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

# Download and install all necessary files
echo "📥 Installing core files..."

# Create languages.json
cat > "$PLUGIN_DIR/languages.json" << 'LANGUAGES_EOF'
{
  "available_languages": [
    {
      "code": "en",
      "name": "English",
      "native_name": "English",
      "flag": "🇺🇸",
      "status": "complete"
    },
    {
      "code": "es",
      "name": "Spanish",
      "native_name": "Español",
      "flag": "🇪🇸", 
      "status": "planned"
    },
    {
      "code": "fr",
      "name": "French",
      "native_name": "Français",
      "flag": "🇫🇷",
      "status": "planned"
    },
    {
      "code": "pt",
      "name": "Portuguese",
      "native_name": "Português",
      "flag": "🇵🇹",
      "status": "planned"
    },
    {
      "code": "de",
      "name": "German", 
      "native_name": "Deutsch",
      "flag": "🇩🇪",
      "status": "planned"
    },
    {
      "code": "zh",
      "name": "Chinese",
      "native_name": "中文",
      "flag": "🇨🇳",
      "status": "planned"
    }
  ],
  "default_language": "en",
  "fallback_language": "en",
  "auto_detect": true,
  "config": {
    "note": "Update this file to add/remove languages or change settings",
    "status_values": ["complete", "partial", "planned", "disabled"],
    "instructions": {
      "add_language": "Add new language object to available_languages array",
      "remove_language": "Set status to 'disabled' or remove from array", 
      "change_default": "Update default_language code",
      "disable_autodetect": "Set auto_detect to false"
    }
  }
}
LANGUAGES_EOF

# Create config.py (embedded in installer for simplicity)
cat > "$PLUGIN_DIR/config.py" << 'CONFIG_EOF'
#!/usr/bin/env python3
import json
import os
from pathlib import Path
from datetime import datetime

class Config:
    def __init__(self, config_path=None):
        self.config_path = Path(config_path or Path.home() / '.biomass-config.json')
        self.config = self._load_config()
        self.languages = self._load_languages()
    
    def _load_config(self):
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except:
                pass
        return {
            "language": None,
            "install_type": "user", 
            "data_dir": str(Path.home() / '.claude' / 'prompt-data'),
            "version": "1.0.0",
            "created": None,
            "last_updated": None
        }
    
    def _load_languages(self):
        script_dir = Path(__file__).parent
        lang_file = script_dir / 'languages.json'
        if lang_file.exists():
            try:
                with open(lang_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except:
                pass
        return {"available_languages": [{"code": "en", "name": "English", "native_name": "English", "flag": "🇺🇸", "status": "complete"}], "default_language": "en", "fallback_language": "en", "auto_detect": True}
    
    def get_preferred_language(self, cli_override=None):
        if cli_override:
            return cli_override
        if self.config.get('language'):
            return self.config['language']
        if self.languages.get('auto_detect', True):
            for env_var in ['LC_MESSAGES', 'LC_ALL', 'LANG']:
                if env_var in os.environ:
                    locale = os.environ[env_var]
                    if locale:
                        lang = locale.split('_')[0].split('.')[0]
                        if len(lang) == 2:
                            return lang
        return self.languages.get('fallback_language', 'en')
    
    def set_language(self, language_code):
        self.config['language'] = language_code
    
    def set_install_type(self, install_type):
        self.config['install_type'] = install_type
    
    def set_data_dir(self, data_dir):
        self.config['data_dir'] = str(data_dir)
    
    def save_config(self):
        now = datetime.now().isoformat()
        if not self.config.get('created'):
            self.config['created'] = now
        self.config['last_updated'] = now
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
            return True
        except:
            return False

_config = None
def get_config():
    global _config
    if _config is None:
        _config = Config()
    return _config
CONFIG_EOF

# Create updated i18n.py that uses config
cat > "$PLUGIN_DIR/i18n.py" << 'I18N_EOF'
#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

class I18n:
    def __init__(self, lang=None):
        self.lang = lang or self._detect_language()
        self.strings = self._load_strings()
    
    def _detect_language(self):
        # Try to use config.py if available
        try:
            sys.path.insert(0, str(Path(__file__).parent))
            from config import get_config
            return get_config().get_preferred_language()
        except ImportError:
            pass
        
        # Fallback to environment detection
        for env_var in ['LC_MESSAGES', 'LC_ALL', 'LANG']:
            if env_var in os.environ:
                locale = os.environ[env_var]
                if locale:
                    lang = locale.split('_')[0].split('.')[0]
                    if lang and len(lang) == 2:
                        return lang
        return 'en'
    
    def _load_strings(self):
        script_dir = Path(__file__).parent
        locales_dir = script_dir / 'locales'
        
        lang_file = locales_dir / f'{self.lang}.json'
        if lang_file.exists():
            try:
                with open(lang_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except:
                pass
        
        en_file = locales_dir / 'en.json'
        try:
            with open(en_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return {}
    
    def get(self, key_path, **kwargs):
        keys = key_path.split('.')
        value = self.strings
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return f"[{key_path}]"
        
        if isinstance(value, str) and kwargs:
            try:
                return value.format(**kwargs)
            except:
                return value
        
        return value
    
    def get_list(self, key_path):
        value = self.get(key_path)
        if isinstance(value, list):
            return value
        return []

_i18n = None
def get_i18n():
    global _i18n
    if _i18n is None:
        _i18n = I18n()
    return _i18n

def _(key_path, **kwargs):
    return get_i18n().get(key_path, **kwargs)

def _list(key_path):
    return get_i18n().get_list(key_path)
I18N_EOF

# Create English locale (same as before)
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

# Install scripts (same i18n-ready versions as before, but more compact)
cat > "$PLUGIN_DIR/prompt-tracker.py" << 'TRACKER_EOF'
#!/usr/bin/env python3
import sys,json,os,re
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
try:
    from i18n import _list
except ImportError:
    def _list(key): return ["damn", "shit", "fuck", "ass", "bitch", "hell", "crap", "piss", "bastard", "slut", "whore", "dick", "cock", "pussy", "tits", "balls", "suck", "bloody"]

def count_curse_words(text):
    curse_words = ["damn", "shit", "fuck", "ass", "bitch", "hell", "crap", "piss", "bastard", "slut", "whore", "dick", "cock", "pussy", "tits", "balls", "suck", "bloody"]
    words = re.findall(r'\b\w+\b', text.lower())
    curse_count = 0
    found_curses = []
    for word in words:
        if word in curse_words:
            curse_count += 1
            found_curses.append(word)
    return curse_count, found_curses

def save_prompt_data(prompt, curse_count, found_curses):
    data_dir = os.environ.get('BIOMASS_DATA_DIR', os.path.expanduser("~/.claude/prompt-data"))
    os.makedirs(data_dir, exist_ok=True)
    entry = {"timestamp": datetime.now().isoformat(), "prompt": prompt, "curse_count": curse_count, "found_curses": found_curses, "date": datetime.now().strftime("%Y-%m-%d"), "hour": datetime.now().hour}
    date_str = datetime.now().strftime("%Y-%m-%d")
    log_file = os.path.join(data_dir, f"prompts_{date_str}.jsonl")
    try:
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')
    except: pass

prompt = sys.stdin.read().strip()
curse_count, found_curses = count_curse_words(prompt)
save_prompt_data(prompt, curse_count, found_curses)
print(prompt)
TRACKER_EOF

# Create stats script (compact i18n version)
cat > "$PLUGIN_DIR/curse-stats.py" << 'STATS_EOF'
#!/usr/bin/env python3
import sys,json,os,glob
from datetime import datetime,timedelta
from collections import defaultdict,Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
try:
    from i18n import _
except ImportError:
    def _(key, **kwargs):
        if 'stats.title' in key: return f"⚡ Biomass Conversion Index Statistics ({kwargs.get('period', 'Daily')})"
        elif 'total_prompts' in key: return f"Total Prompts: {kwargs.get('count', 0)}"
        elif 'total_breaches' in key: return f"Total Harmony Breaches: {kwargs.get('count', 0)}"
        elif 'average_deviation' in key: return f"Average Harmony Deviation Index: {kwargs.get('value', '0.00')}"
        elif 'breakdown_title' in key: return f"Breakdown by {kwargs.get('period', 'Daily')}:"
        elif 'prompts_count' in key: return f"Prompts: {kwargs.get('count', 0)}"
        elif 'breach_count' in key: return f"Breach Count: {kwargs.get('count', 0)}"
        elif 'predominant_types' in key: return f"Predominant Breach Types: {kwargs.get('types', '')}"
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

# CLI argument parsing
period,start_date,end_date="daily",None,None
args=sys.argv[1:]
for i,arg in enumerate(args):
    if arg in["daily","weekly","monthly"]:period=arg
    elif arg=="--last" and i+1<len(args):end_date,start_date=datetime.now().date(),datetime.now().date()-timedelta(days=int(args[i+1]))
    elif arg=="--lang" and i+1<len(args):
        # Language override support
        try:
            from i18n import init_i18n
            init_i18n(args[i+1])
        except: pass

print_stats(calc_stats(load_data(start_date,end_date),period),period)
STATS_EOF

# Create commands
cat > "$PLUGIN_DIR/commands/biomass-conversion-index.md" << EOF
---
description: "Show biomass conversion index statistics from your prompts"
tools: ["Bash"]
---
# Biomass Conversion Index Statistics
Usage: /biomass-conversion-index [daily|weekly|monthly] [--last N] [--lang CODE]
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

# Create configuration file
python3 << EOF
import sys
sys.path.insert(0, '$PLUGIN_DIR')
from config import Config

config = Config('$CONFIG_PATH')
config.set_language('$SELECTED_CODE')
config.set_install_type('$INSTALL_TYPE')
config.set_data_dir('$DATA_DIR')
config.save_config()

print(f"Configuration saved: {config.config_path}")
print(f"Language: $SELECTED_DISPLAY")
print(f"Install type: $INSTALL_TYPE")
EOF

# Create settings.json
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
echo "✅ Installation complete!"
echo ""
echo "🎯 Plugin installed to: $PLUGIN_DIR"
echo "🌐 Language: $SELECTED_DISPLAY"
echo "💾 Data will be stored in: $DATA_DIR"
echo "⚙️  Configuration: $CONFIG_PATH"
echo ""
echo "🚀 Available commands:"
echo "  /biomass-conversion-index          - View statistics"
echo "  /biomass-conversion-index weekly   - Weekly breakdown"
echo "  /biomass-conversion-index monthly  - Monthly breakdown"
echo "  /harmony-breaches                  - Quick daily summary"
echo ""
echo "🔧 Language options:"
echo "  Use --lang=CODE flag to override language temporarily"
echo "  Edit $PLUGIN_DIR/languages.json to add/modify languages"
echo "  Edit $CONFIG_PATH to change persistent settings"
echo ""
echo "⚡ Your prompts will now be tracked automatically!"