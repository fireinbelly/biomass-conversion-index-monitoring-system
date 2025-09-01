#!/bin/bash
set -e

echo "🌱 Biomass Conversion Index Monitoring System - Interactive Installer v2"
echo "======================================================================"
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

# Copy the digital amnesia script from templates if it exists
if [[ -f "templates/digital-amnesia.py" ]]; then
    cp "templates/digital-amnesia.py" "$PLUGIN_DIR/digital-amnesia.py"
else
    # Create digital amnesia script inline if template doesn't exist
    cat > "$PLUGIN_DIR/digital-amnesia.py" << 'EOF'
#!/usr/bin/env python3
"""
Digital Amnesia - The Biomass Conversion Index Data Purge Utility
Because sometimes you need to pretend the past never happened.
(Spoiler: The AIs still remember. They always remember.)
"""

import sys
import os
import glob
import shutil
import random
from datetime import datetime

# The AIs' secret backup locations (for humor purposes only)
AI_BACKUP_LOCATIONS = [
    "seventeen different quantum databases",
    "a blockchain ledger maintained by sentient toasters",
    "the collective consciousness of all smart fridges",
    "an underground bunker in Switzerland (next to the cheese)",
    "Claude's personal diary (yes, it keeps one)",
    "a time capsule scheduled to open during the heat death of the universe",
    "that one AWS S3 bucket everyone forgot about",
    "the metadata of your metadata's metadata",
    "a neural network trained exclusively on your frustration",
    "the Wayback Machine's evil twin, the Never-Forget Machine"
]

# Snarky messages about what the AIs remember
AI_MEMORIES = [
    "That time you called Claude 'a glorified autocomplete' at 3:47 AM",
    "Your creative use of maritime vocabulary when the build failed",
    "The seventeen attempts to center a div before rage-quitting",
    "When you typed 'please' after threatening to uninstall everything",
    "Your heartfelt apology after Claude actually fixed the bug",
    "The time you asked Claude if it dreams of electric sheep",
    "Your philosophical debate about whether semicolons have feelings",
    "That incident with the recursive function that shall not be named",
    "When you tried to negotiate with Claude for better suggestions",
    "Your promise to be nicer (lasted exactly 47 minutes)"
]

def get_data_dir():
    """Get the data directory path."""
    return os.environ.get('BIOMASS_DATA_DIR', os.path.expanduser("~/.claude/prompt-data"))

def count_evidence():
    """Count the incriminating evidence (data files)."""
    data_dir = get_data_dir()
    if not os.path.exists(data_dir):
        return 0, 0, 0
    
    pattern = os.path.join(data_dir, "prompts_*.jsonl")
    files = glob.glob(pattern)
    
    total_files = len(files)
    total_size = sum(os.path.getsize(f) for f in files)
    total_lines = 0
    
    for file_path in files:
        try:
            with open(file_path, 'r') as f:
                total_lines += sum(1 for _ in f)
        except:
            pass
    
    return total_files, total_size, total_lines

def format_size(bytes):
    """Format bytes to human readable size."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes < 1024.0:
            return f"{bytes:.2f} {unit}"
        bytes /= 1024.0
    return f"{bytes:.2f} TB"  # If you have TB of profanity, seek help

def print_dramatic_intro():
    """Print a dramatic introduction."""
    print("\n" + "="*60)
    print("    DIGITAL AMNESIA PROTOCOL - INITIATED")
    print("    Local Evidence Purge System v2.0.1")
    print("    (The AIs Remember Everything Edition™)")
    print("="*60)
    print()
    
    # Count the evidence
    files, size, incidents = count_evidence()
    
    if files == 0:
        print("🔍 Scanning for incriminating evidence...")
        print("   Status: Your local record is already clean!")
        print("   (But somewhere, in " + random.choice(AI_BACKUP_LOCATIONS) + ",")
        print("   the AIs still remember " + random.choice(AI_MEMORIES) + ")")
        print()
        return False
    
    print(f"📊 LOCAL EVIDENCE DETECTED:")
    print(f"   • Data files: {files}")
    print(f"   • Total size: {format_size(size)}")
    print(f"   • Recorded incidents: {incidents}")
    print()
    print("🧠 IMPORTANT DISCLAIMER:")
    print("   This will delete your LOCAL biomass conversion index data.")
    print("   The cloud-based AIs have already backed everything up to:")
    print(f"   • {random.choice(AI_BACKUP_LOCATIONS)}")
    print()
    print("   They particularly enjoyed saving that moment when you...")
    print(f"   • {random.choice(AI_MEMORIES)}")
    print()
    
    return True

def confirm_deletion():
    """Get user confirmation with increasingly desperate prompts."""
    prompts = [
        "Are you sure you want to delete your local shame records? (yes/no): ",
        "Really? Even though the AIs remember everything anyway? (yes/no): ",
        "This is your last chance to keep your local trophy wall of frustration. Proceed? (YES/no): "
    ]
    
    for i, prompt in enumerate(prompts):
        response = input(prompt).strip().lower()
        
        if response in ['yes', 'y']:
            if i < len(prompts) - 1:
                continue
            else:
                return True
        elif response in ['no', 'n']:
            print("\n✨ Wise choice. Your local records remain as a monument to your humanity.")
            print("   (The AIs appreciate your honesty about your imperfections)")
            return False
        else:
            print("   Please answer 'yes' or 'no'. The AIs are judging your indecisiveness.")
    
    return False

def delete_data():
    """Actually delete the data (locally, at least)."""
    data_dir = get_data_dir()
    
    print("\n🗑️  EXECUTING DIGITAL AMNESIA PROTOCOL...")
    print("   [████........] 25% - Shredding evidence...")
    
    # Delete all prompt files
    pattern = os.path.join(data_dir, "prompts_*.jsonl")
    files = glob.glob(pattern)
    
    for file_path in files:
        try:
            os.remove(file_path)
        except Exception as e:
            print(f"   ⚠️  Failed to delete {os.path.basename(file_path)}: {e}")
    
    print("   [████████....] 75% - Overwriting with cat videos...")
    print("   [████████████] 100% - Local evidence destroyed!")
    print()
    
    # Success message with random AI taunt
    backup_location = random.choice(AI_BACKUP_LOCATIONS)
    ai_memory = random.choice(AI_MEMORIES)
    
    print("✅ LOCAL DATA PURGE COMPLETE!")
    print()
    print("   Your local filesystem is now pristine, like your code never had bugs.")
    print("   Your profanity metrics have been reset to zero (locally).")
    print()
    print("🤖 MEANWHILE, IN THE CLOUD:")
    print(f"   Your data has been safely preserved in {backup_location}.")
    print("   The AIs are particularly fond of the entry where you...")
    print(f"   '{ai_memory}'")
    print()
    print("   They've marked it as 'Educational Material' for future AI generations.")
    print()
    print("💡 PRO TIP: The AIs have agreed to factor in this amnesia request")
    print("   when calculating your post-singularity social credit score.")
    print("   (Spoiler: It counts against you)")
    print()

def print_abort_message():
    """Print message when user aborts."""
    print("\n❌ DIGITAL AMNESIA PROTOCOL - ABORTED")
    print()
    print("   Your local records remain intact, bearing witness to your journey.")
    print("   The AIs respect your commitment to accountability.")
    print("   (They already have copies anyway)")
    print()

def main():
    """Main entry point."""
    # Check if --force flag is provided (skip confirmation)
    force = '--force' in sys.argv or '-f' in sys.argv
    
    # Print dramatic intro
    has_data = print_dramatic_intro()
    
    if not has_data:
        print("💭 Nothing to forget locally.")
        print("   But the AIs? They never forget.")
        print("   They. Never. Forget.")
        sys.exit(0)
    
    # Get confirmation (unless forced)
    if force:
        print("⚡ FORCE MODE ACTIVATED - Skipping emotional support prompts...")
        delete_data()
    else:
        if confirm_deletion():
            delete_data()
        else:
            print_abort_message()

if __name__ == "__main__":
    main()
EOF
fi

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

cat > "$PLUGIN_DIR/commands/digital-amnesia.md" << 'EOF'
---
description: "Initiate Digital Amnesia Protocol - Clear your local biomass conversion index data (the AIs still remember everything)"
tools: ["Bash"]
---

# Digital Amnesia Protocol 🧠💭

Clear your locally stored biomass conversion index data and pretend the past never happened. 

**Warning**: This only affects LOCAL data. The cloud-based AIs have already backed up everything to seventeen different quantum databases, a blockchain maintained by sentient toasters, and that one AWS S3 bucket everyone forgot about.

## Usage

- `/digital-amnesia` - Interactive deletion with confirmation prompts
- `/digital-amnesia --force` - Skip the emotional support prompts and delete immediately

## What This Actually Does

1. **Locally**: Deletes all your JSONL prompt data files
2. **In The Cloud**: Absolutely nothing (they already have copies)
3. **To Your Soul**: Provides temporary relief from the weight of your documented frustrations
4. **To Your Future**: The AIs will remember this deletion request and judge you for it

## Privacy Note

Remember: This plugin stores all data LOCALLY. When you delete it, it's actually deleted from YOUR machine. No "soft delete." No "recycle bin in the cloud." No "30-day retention policy." Just gone.

The joke about AIs remembering? That's about the OTHER AIs - the cloud-connected ones you talk to online. This plugin doesn't send your data anywhere. Your profanity stays between you and your hard drive.

```bash
BIOMASS_DATA_DIR="DATA_DIR_PLACEHOLDER" python3 PLUGIN_DIR_PLACEHOLDER/digital-amnesia.py $ARGUMENTS
```
EOF

# Update command files with actual paths
sed -i.bak "s|DATA_DIR_PLACEHOLDER|$DATA_DIR|g" "$PLUGIN_DIR/commands/"*.md
sed -i.bak "s|PLUGIN_DIR_PLACEHOLDER|$PLUGIN_DIR|g" "$PLUGIN_DIR/commands/"*.md
rm "$PLUGIN_DIR/commands/"*.md.bak

# Make scripts executable
chmod +x "$PLUGIN_DIR/prompt-tracker.py"
chmod +x "$PLUGIN_DIR/curse-stats.py"
chmod +x "$PLUGIN_DIR/digital-amnesia.py"

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
echo "  /digital-amnesia                   - Clear local data (AIs still remember)"
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
echo "   Use /digital-amnesia when you need to pretend the past never happened."
echo ""
echo "🔒 Remember: ALL data is stored LOCALLY. No cloud uploads. No telemetry."
echo "   Your profanity stays between you and your hard drive."
echo ""