#!/usr/bin/env python3
import sys
import json
import os
from datetime import datetime
import re
from pathlib import Path

# indicators.json is installed alongside this script. It holds one word list per
# language and every list is checked, whatever LANG says: people swear in their first
# language with their locale set to en_US.
INDICATORS_FILE = Path(__file__).parent / 'indicators.json'

# Chinese, Japanese, Korean, Thai and Bopomofo don't put spaces between words, so a term
# in one of those scripts has no word boundary to anchor to - 幹你娘 sits in an unbroken
# run of characters. Those terms are matched as plain substrings; everything else keeps
# whole-word matching, which is what stops `classic` tripping `ass`.
NO_SPACES = re.compile(
    '[฀-๿'              # thai
    '぀-ヿ'               # hiragana, katakana
    '㄀-ㄯ'               # bopomofo
    '㄰-㆏'               # hangul jamo
    '㐀-䶿一-鿿豈-﫿'   # cjk ideographs
    '가-힯]'              # hangul syllables
)

def count_curse_words(text):
    """Count biomass conversion indicators in text"""
    with open(INDICATORS_FILE, encoding='utf-8') as handle:
        by_language = json.load(handle)['curse_words']

    # One regex over every language. Longest terms first, so 幹你娘 wins over 屌 where
    # they overlap and a single scan counts each hit exactly once.
    terms = {term for words in by_language.values() for term in words}
    parts = [re.escape(t) if NO_SPACES.search(t) else r'(?<!\w)%s(?!\w)' % re.escape(t)
             for t in sorted(terms, key=len, reverse=True)]
    if not parts:
        # An empty alternation is the empty pattern, which matches at every position and
        # would score a breach per character. An empty list means zero, not everything.
        return 0, []

    found = [m.group(0) for m in re.finditer('|'.join(parts), text.lower())]
    return len(found), found

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
    # Claude Code hands hooks a JSON payload on stdin, not the bare prompt text.
    # Tracking must never block prompt submission, so failures stay silent.
    try:
        payload = json.loads(sys.stdin.read())
        prompt = payload['prompt']
        curse_count, found_curses = count_curse_words(prompt)
        save_prompt_data(prompt, curse_count, found_curses)
    except Exception:
        pass

    # Print nothing: UserPromptSubmit stdout is injected into Claude's context.
    sys.exit(0)

if __name__ == "__main__":
    main()