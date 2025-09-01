#!/usr/bin/env python3
import sys
import json
import os
import glob
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from pathlib import Path

# Add the parent directory to sys.path to import i18n
sys.path.insert(0, str(Path(__file__).parent.parent))
from i18n import _, _list

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
            # Use localized error message
            print(_('errors.reading_file', file=file_path, error=str(e)))
    
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
    """Print formatted statistics using localized strings."""
    # Localize period name
    period_localized = _(f'periods.{period.lower()}', period=period.title())
    
    # Print header
    print(f"\n⚡ {_('stats.title', period=period_localized)}")
    print("=" * 50)
    
    # Print summary stats
    print(_('stats.total_prompts', count=stats['total_prompts']))
    print(_('stats.total_breaches', count=stats['total_curses']))
    print(_('stats.average_deviation', value=f"{stats['average_curses_per_prompt']:.2f}"))
    
    if stats['stats_by_period']:
        print(f"\n{_('stats.breakdown_title', period=period_localized)}")
        print("-" * 30)
        
        # Sort periods chronologically
        sorted_periods = sorted(stats['stats_by_period'].items())
        
        for period_key, period_stats in sorted_periods:
            print(f"\n{period_key}:")
            print(f"  {_('stats.prompts_count', count=period_stats['prompts'])}")
            print(f"  {_('stats.breach_count', count=period_stats['curses'])}")
            if period_stats['curse_words']:
                types_list = ', '.join([f'{word}({count})' for word, count in period_stats['curse_words'].most_common(3)])
                print(f"  {_('stats.predominant_types', types=types_list)}")

def main():
    """Main entry point"""
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
        start_str = start_date or _('errors.no_data_dir')  # Using as fallback text
        end_str = end_date or 'now'
        print(f"\n{_('stats.date_range', start=start_str, end=end_str)}")

if __name__ == "__main__":
    main()