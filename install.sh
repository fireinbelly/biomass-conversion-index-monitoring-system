#!/bin/bash
set -e

echo "🌱 Installing Biomass Conversion Index Monitoring System..."

# Get current directory
PLUGIN_DIR="$(pwd)/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create .claude directory if it doesn't exist
mkdir -p "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/commands"

# Copy plugin files
echo "📁 Copying plugin files..."

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
    # Create data directory if it doesn't exist
    data_dir = os.path.expanduser("~/.claude/prompt-data")
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
    data_dir = os.path.expanduser("~/.claude/prompt-data")
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
    """Calculate curse word statistics."""
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
cat > "$PLUGIN_DIR/commands/curse-stats.md" << 'EOF'
---
description: "Show curse word statistics from your prompts"
tools: ["Bash"]
---

# Curse Word Statistics

Show statistics about curse words in your prompts. Usage examples:

- `/curse-stats` - Daily statistics
- `/curse-stats weekly` - Weekly statistics  
- `/curse-stats monthly` - Monthly statistics
- `/curse-stats --last 7` - Last 7 days
- `/curse-stats --start 2024-01-01 --end 2024-01-31` - Custom date range

```bash
python3 .claude/curse-stats.py $ARGUMENTS
```
EOF

cat > "$PLUGIN_DIR/commands/fucks-given.md" << 'EOF'
---
description: "Quick check of how many fucks you've given today"
tools: ["Bash"]
---

# Fucks Given Today

A quick summary of your curse word usage today:

```bash
python3 .claude/curse-stats.py daily --last 1 | grep -E "(Total|fuck)" || echo "No fucks given today! 🎉"
```
EOF

# Make scripts executable
chmod +x "$PLUGIN_DIR/prompt-tracker.py"
chmod +x "$PLUGIN_DIR/curse-stats.py"

# Create or update settings.json
SETTINGS_FILE="$PLUGIN_DIR/settings.json"
TRACKER_PATH="$(pwd)/.claude/prompt-tracker.py"

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
            "command": "$TRACKER_PATH"
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
echo "📊 Data will be stored in: ~/.claude/prompt-data/"
echo ""
echo "🚀 Available commands:"
echo "  /biomass-conversion-index          - View statistics"
echo "  /biomass-conversion-index weekly   - Weekly breakdown"
echo "  /biomass-conversion-index monthly  - Monthly breakdown"
echo "  /harmony-breaches          - Quick daily summary"
echo ""
echo "🌿 Start using Claude Code and your prompts will be tracked automatically!"
echo "   Use /biomass-conversion-index to see your conversion index statistics."
echo ""