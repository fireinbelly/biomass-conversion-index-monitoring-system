#!/usr/bin/env python3
import sys
import json
import os
from datetime import datetime
import re
from pathlib import Path

# Add the parent directory to sys.path to import i18n
sys.path.insert(0, str(Path(__file__).parent.parent))
from i18n import _, _list

def count_curse_words(text):
    """Count biomass conversion indicators in text"""
    # Get indicators from localization
    curse_words = _list('indicators.curse_words')
    
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