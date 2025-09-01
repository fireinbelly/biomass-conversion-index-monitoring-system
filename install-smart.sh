#!/bin/bash
# Smart installer - detects context and suggests best option
set -e

echo "🌱 Biomass Conversion Index Monitoring System - Smart Installer"
echo "==============================================================="

# Auto-detect best installation type
if [[ -f "package.json" ]] || [[ -f "pyproject.toml" ]] || [[ -f "Cargo.toml" ]] || [[ -d ".git" ]]; then
    echo "📁 Project detected - recommending project-level installation"
    DEFAULT=1
    RECOMMENDATION="project-level (recommended for this project)"
else
    echo "👤 No project detected - recommending user-level installation"  
    DEFAULT=2
    RECOMMENDATION="user-level (recommended for general use)"
fi

echo ""
echo "Install as:"
echo "1) Project-level (.claude/ in current directory)"
echo "2) User-level (~/.claude/ in home directory)"
echo ""
echo "Recommendation: $RECOMMENDATION"
echo ""

read -p "Choice [default: $DEFAULT]: " choice
choice=${choice:-$DEFAULT}

case $choice in
    1)
        INSTALL_TYPE="project"
        PLUGIN_DIR="$(pwd)/.claude"
        DATA_DIR="$(pwd)/.claude/prompt-data"
        ;;
    2)
        INSTALL_TYPE="user"
        PLUGIN_DIR="$HOME/.claude"
        DATA_DIR="$HOME/.claude/prompt-data"
        ;;
    *)
        echo "❌ Invalid choice. Using default: $DEFAULT"
        if [[ $DEFAULT == 1 ]]; then
            INSTALL_TYPE="project"
            PLUGIN_DIR="$(pwd)/.claude"
            DATA_DIR="$(pwd)/.claude/prompt-data"
        else
            INSTALL_TYPE="user"
            PLUGIN_DIR="$HOME/.claude"
            DATA_DIR="$HOME/.claude/prompt-data"
        fi
        ;;
esac

echo "✅ Installing to: $PLUGIN_DIR"

# Run the actual installation (reuse logic from interactive script)
mkdir -p "$PLUGIN_DIR/commands"
mkdir -p "$DATA_DIR"

# Create optimized scripts (same as interactive but without user prompts)
cat > "$PLUGIN_DIR/prompt-tracker.py" << 'EOF'
#!/usr/bin/env python3
import sys,json,os,re
from datetime import datetime
def count_curse_words(text):
    words=re.findall(r'\b\w+\b',text.lower())
    curses=['damn','shit','fuck','ass','bitch','hell','crap','piss','bastard','slut','whore','dick','cock','pussy','tits','balls','suck','bloody']
    found=[w for w in words if w in curses]
    return len(found),found
def save_prompt_data(prompt,curse_count,found_curses):
    data_dir=os.environ.get('BIOMASS_DATA_DIR',os.path.expanduser("~/.claude/prompt-data"))
    os.makedirs(data_dir,exist_ok=True)
    entry={"timestamp":datetime.now().isoformat(),"prompt":prompt,"curse_count":curse_count,"found_curses":found_curses,"date":datetime.now().strftime("%Y-%m-%d"),"hour":datetime.now().hour}
    with open(os.path.join(data_dir,f"prompts_{datetime.now().strftime('%Y-%m-%d')}.jsonl"),'a',encoding='utf-8') as f:f.write(json.dumps(entry,ensure_ascii=False)+'\n')
prompt=sys.stdin.read().strip()
curse_count,found_curses=count_curse_words(prompt)
save_prompt_data(prompt,curse_count,found_curses)
print(prompt)
EOF

cat > "$PLUGIN_DIR/curse-stats.py" << 'EOF'
#!/usr/bin/env python3
import sys,json,os,glob
from datetime import datetime,timedelta
from collections import defaultdict,Counter
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
    print(f"\n⚡ Biomass Conversion Index Statistics ({period.title()})\n"+"="*50)
    print(f"Total Prompts: {stats['total_prompts']}\nTotal Harmony Breaches: {stats['total_curses']}\nAverage Harmony Deviation Index: {stats['average_curses_per_prompt']:.2f}")
    if stats['stats_by_period']:
        print(f"\nBreakdown by {period.title()}:\n"+"-"*30)
        for k,v in sorted(stats['stats_by_period'].items()):
            print(f"\n{k}:\n  Prompts: {v['prompts']}\n  Breach Count: {v['curses']}")
            if v['curse_words']:print(f"  Predominant Breach Types: {', '.join([f'{w}({c})' for w,c in v['curse_words'].most_common(3)])}")
period,start_date,end_date="daily",None,None
args=sys.argv[1:]
for i,arg in enumerate(args):
    if arg in["daily","weekly","monthly"]:period=arg
    elif arg=="--last" and i+1<len(args):end_date,start_date=datetime.now().date(),datetime.now().date()-timedelta(days=int(args[i+1]))
print_stats(calc_stats(load_data(start_date,end_date),period),period)
EOF

# Create commands
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
            "command": "BIOMASS_DATA_DIR=\"$DATA_DIR\" $PLUGIN_DIR/prompt-tracker.py"
          }
        ]
      }
    ]
  }
}
EOF

echo "✅ Biomass Conversion Index Monitoring System installed!"
echo "📊 Commands: /biomass-conversion-index, /harmony-breaches"
echo "⚡ Your prompts will now be tracked automatically!"