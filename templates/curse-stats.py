#!/usr/bin/env python3
import sys
import json
import os
import glob
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from pathlib import Path

# i18n.py and locales/ are installed alongside this script.
sys.path.insert(0, str(Path(__file__).parent))
from i18n import _, _list

def load_prompt_data(start_date=None, end_date=None):
    """Load prompt data from JSONL files within date range."""
    # The installer always puts the data next to this script ($PLUGIN_DIR/prompt-data),
    # for user-level and project-level installs alike, so defaulting to a sibling
    # directory is right in both. The old default was a hardcoded ~/.claude/prompt-data,
    # which sent project-level installs looking in the user-level directory.
    # BIOMASS_DATA_DIR still overrides.
    data_dir = os.environ.get('BIOMASS_DATA_DIR', str(Path(__file__).parent / "prompt-data"))
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
        return {"total_prompts": 0, "total_curses": 0, "average_curses_per_prompt": 0,
                "stats_by_period": {}, "stats_by_model": {}}

    total_prompts = len(data)
    total_curses = sum(entry['curse_count'] for entry in data)

    # Group by period
    stats_by_period = defaultdict(lambda: {"prompts": 0, "curses": 0, "curse_words": Counter()})
    # Group by the model that earned the breach. Entries logged before the tracker
    # recorded a model have no key at all, which is not the same as a model named
    # "unknown" - print_stats labels it, this keeps the data honest.
    stats_by_model = defaultdict(lambda: {"prompts": 0, "curses": 0, "curse_words": Counter()})

    for entry in data:
        dt = datetime.fromisoformat(entry['timestamp'])

        model_stats = stats_by_model[entry.get('model')]
        model_stats["prompts"] += 1
        model_stats["curses"] += entry['curse_count']
        for curse in entry['found_curses']:
            model_stats["curse_words"][curse] += 1
        
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
        "stats_by_period": dict(stats_by_period),
        "stats_by_model": dict(stats_by_model)
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

    by_model = stats.get('stats_by_model') or {}
    if by_model:
        print(f"\n{_('stats.by_model_title')}")
        print("-" * 30)

        # Worst offender first. Rate decides ties and is the interesting number, but
        # volume leads, because one breach out of two prompts is not a trend.
        ranked = sorted(by_model.items(),
                        key=lambda kv: (kv[1]['curses'], kv[1]['curses'] / kv[1]['prompts']),
                        reverse=True)
        width = max(len(m or _('stats.model_unknown')) for m in by_model)

        for model, model_stats in ranked:
            rate = model_stats['curses'] / model_stats['prompts']
            print("  {:<{w}}  {}".format(
                model or _('stats.model_unknown'), _('stats.model_row',
                    breaches=model_stats['curses'], prompts=model_stats['prompts'],
                    rate=f"{rate:.2f}"), w=width))
            if model_stats['curse_words']:
                types_list = ', '.join(f'{word}({count})'
                                       for word, count in model_stats['curse_words'].most_common(3))
                print("  {:<{w}}  {}".format('', _('stats.predominant_types', types=types_list), w=width))

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