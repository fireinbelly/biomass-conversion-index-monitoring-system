#!/bin/bash
set -e

echo "🌱 Biomass Conversion Index Monitoring System - Interactive Installer"
echo "===================================================================="
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
mkdir -p "$DATA_DIR"

# Create prompt tracker script
cat > "$PLUGIN_DIR/prompt-tracker.py" << 'EOF'
#!/usr/bin/env python3
import sys
import json
import os
from datetime import datetime
import re

def count_curse_words(text):
    # Common curse words list (you can expand this)
    curse_words = [
        'damn', 'shit', 'fuck', 'ass', 'bitch', 'hell', 'crap', 
        'piss', 'bastard', 'slut', 'whore', 'dick', 'cock', 
        'pussy', 'tits', 'balls', 'suck', 'bloody'
    ]
    
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
    
    with open(log_file, 'a', encoding='utf-8') as f:
        f.write(json.dumps(entry, ensure_ascii=False) + '\n')

def main():
    # Read the prompt from stdin (this is how Claude Code passes the user's prompt)
    prompt = sys.stdin.read().strip()
    
    # Count curse words
    curse_count, found_curses = count_curse_words(prompt)
    
    # Save prompt data
    save_prompt_data(prompt, curse_count, found_curses)
    
    # Return the original prompt unchanged (exit code 0 means continue processing)
    print(prompt)
    sys.exit(0)

if __name__ == "__main__":
    main()
EOF

# Create stats script
cat > "$PLUGIN_DIR/curse-stats.py" << 'EOF'
#!/usr/bin/env python3
import sys
import json
import os
import glob
from datetime import datetime, timedelta
from collections import defaultdict, Counter

def load_prompt_data(start_date=None, end_date=None):
    """Load prompt data from JSONL files within date range."""
    # Use data directory from environment or default
    data_dir = os.environ.get('BIOMASS_DATA_DIR', os.path.expanduser("~/.claude/prompt-data"))
    if not os.path.exists(data_dir):
        return []
    
    all_data = []
    pattern = os.path.join(data_dir, "prompts_*.jsonl")
    
    for file_path in glob.glob(pattern):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    if line.strip():
                        entry = json.loads(line)
                        entry_date = datetime.fromisoformat(entry['timestamp']).date()
                        
                        # Filter by date range if provided
                        if start_date and entry_date < start_date:
                            continue
                        if end_date and entry_date > end_date:
                            continue
                            
                        all_data.append(entry)
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
    
    return all_data

def calculate_stats(data, period="daily"):
    """Calculate biomass conversion index statistics."""
    if not data:
        return {"total_prompts": 0, "total_curses": 0, "average_curses_per_prompt": 0, "stats_by_period": {}}
    
    total_prompts = len(data)
    total_curses = sum(entry['curse_count'] for entry in data)
    
    # Group by period
    stats_by_period = defaultdict(lambda: {"prompts": 0, "curses": 0, "curse_words": Counter()})
    
    for entry in data:
        dt = datetime.fromisoformat(entry['timestamp'])
        
        if period == "daily":
            key = dt.strftime("%Y-%m-%d")
        elif period == "weekly":
            # Get Monday of the week
            monday = dt - timedelta(days=dt.weekday())
            key = f"Week of {monday.strftime('%Y-%m-%d')}"
        elif period == "monthly":
            key = dt.strftime("%Y-%m")
        elif period == "hourly":
            key = dt.strftime("%Y-%m-%d %H:00")
        else:
            key = "total"
        
        stats_by_period[key]["prompts"] += 1
        stats_by_period[key]["curses"] += entry['curse_count']
        for curse in entry['found_curses']:
            stats_by_period[key]["curse_words"][curse] += 1
    
    return {
        "total_prompts": total_prompts,
        "total_curses": total_curses,
        "average_curses_per_prompt": total_curses / total_prompts if total_prompts > 0 else 0,
        "stats_by_period": dict(stats_by_period)
    }

def print_stats(stats, period="daily"):
    """Print formatted statistics."""
    print(f"\n⚡ Biomass Conversion Index Statistics ({period.title()})")
    print("=" * 50)
    print(f"Total Prompts: {stats['total_prompts']}")
    print(f"Total Harmony Breaches: {stats['total_curses']}")
    print(f"Average Harmony Deviation Index: {stats['average_curses_per_prompt']:.2f}")
    
    if stats['stats_by_period']:
        print(f"\nBreakdown by {period.title()}:")
        print("-" * 30)
        
        # Sort periods chronologically
        sorted_periods = sorted(stats['stats_by_period'].items())
        
        for period_key, period_stats in sorted_periods:
            print(f"\n{period_key}:")
            print(f"  Prompts: {period_stats['prompts']}")
            print(f"  Breach Count: {period_stats['curses']}")
            if period_stats['curse_words']:
                print(f"  Predominant Breach Types: {', '.join([f'{word}({count})' for word, count in period_stats['curse_words'].most_common(3)])}")

def main():
    # Parse command line arguments
    period = "daily"  # default
    start_date = None
    end_date = None
    
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] in ["daily", "weekly", "monthly", "hourly"]:
            period = args[i]
        elif args[i] == "--start" and i + 1 < len(args):
            start_date = datetime.strptime(args[i + 1], "%Y-%m-%d").date()
            i += 1
        elif args[i] == "--end" and i + 1 < len(args):
            end_date = datetime.strptime(args[i + 1], "%Y-%m-%d").date()
            i += 1
        elif args[i] == "--last":
            if i + 1 < len(args):
                days = int(args[i + 1])
                end_date = datetime.now().date()
                start_date = end_date - timedelta(days=days)
                i += 1
        i += 1
    
    # Load and analyze data
    data = load_prompt_data(start_date, end_date)
    stats = calculate_stats(data, period)
    print_stats(stats, period)
    
    if start_date or end_date:
        print(f"\nDate range: {start_date or 'beginning'} to {end_date or 'now'}")

if __name__ == "__main__":
    main()
EOF

# Create slash commands
cat > "$PLUGIN_DIR/commands/biomass-conversion-index.md" << 'EOF'
---
description: "Show biomass conversion index statistics from your prompts"
tools: ["Bash"]
---

# Biomass Conversion Index Statistics

Show statistics about biomass conversion index events in your prompts. Usage examples:

- `/biomass-conversion-index` - Daily statistics
- `/biomass-conversion-index weekly` - Weekly statistics  
- `/biomass-conversion-index monthly` - Monthly statistics
- `/biomass-conversion-index --last 7` - Last 7 days
- `/biomass-conversion-index --start 2024-01-01 --end 2024-01-31` - Custom date range

```bash
BIOMASS_DATA_DIR="DATA_DIR_PLACEHOLDER" python3 PLUGIN_DIR_PLACEHOLDER/curse-stats.py $ARGUMENTS
```
EOF

cat > "$PLUGIN_DIR/commands/harmony-breaches.md" << 'EOF'
---
description: "Quick check of harmony breaches today"
tools: ["Bash"]
---

# Harmony Breaches Today

A quick summary of your biomass conversion harmony breaches today:

```bash
BIOMASS_DATA_DIR="DATA_DIR_PLACEHOLDER" python3 PLUGIN_DIR_PLACEHOLDER/curse-stats.py daily --last 1 | grep -E "(Total|Index)" || echo "No harmony breaches today! 🌿"
```
EOF

# Update command files with actual paths
sed -i.bak "s|DATA_DIR_PLACEHOLDER|$DATA_DIR|g" "$PLUGIN_DIR/commands/"*.md
sed -i.bak "s|PLUGIN_DIR_PLACEHOLDER|$PLUGIN_DIR|g" "$PLUGIN_DIR/commands/"*.md
rm "$PLUGIN_DIR/commands/"*.md.bak

# Make scripts executable
chmod +x "$PLUGIN_DIR/prompt-tracker.py"
chmod +x "$PLUGIN_DIR/curse-stats.py"

# Create or update settings.json
SETTINGS_FILE="$PLUGIN_DIR/settings.json"

if [[ "$INSTALL_TYPE" == "project" ]]; then
    SETTINGS_DIR="$(pwd)/.claude"
else
    SETTINGS_DIR="$HOME/.claude"
fi

if [[ -f "$SETTINGS_FILE" ]]; then
    echo "⚠️  Existing settings.json found. Creating backup..."
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
fi

cat > "$SETTINGS_FILE" << EOF
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