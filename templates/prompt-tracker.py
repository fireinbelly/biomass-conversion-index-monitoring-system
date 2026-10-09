#!/usr/bin/env python3
import sys
import json
import os
import random
from bisect import bisect_right
from datetime import datetime
import re
from pathlib import Path

# indicators.json is installed alongside this script. It holds one word list per
# language and every list is checked, whatever LANG says: people swear in their first
# language with their locale set to en_US.
INDICATORS_FILE = Path(__file__).parent / 'indicators.json'

# How much of the end of the transcript detect_model() reads. See its docstring.
TRANSCRIPT_TAIL_BYTES = 1_000_000

# Chinese, Japanese, Korean, Thai and Bopomofo don't put spaces between words, so a term
# in one of those scripts has no word boundary to anchor to - 幹你娘 sits in an unbroken
# run of characters. Those terms are matched as plain substrings; everything else keeps
# whole-word matching, which is what stops `classic` tripping `ass`.
NO_SPACE_CHARS = (
    '฀-๿'              # thai
    '぀-ヿ'               # hiragana, katakana
    '㄀-ㄯ'               # bopomofo
    '㄰-㆏'               # hangul jamo
    '㐀-䶿一-鿿豈-﫿'   # cjk ideographs
    '가-힯'               # hangul syllables
)
NO_SPACES = re.compile('[%s]' % NO_SPACE_CHARS)

# A word character that isn't one of those. 呢個fucking API is how Hong Kong types: the
# swear is glued to Chinese, and plain \w would call that the middle of a word.
WORD = r'(?![%s])\w' % NO_SPACE_CHARS

# Code, paths, URLs and file names are data, not swearing: a pasted `shit.py` has to reach
# Claude as `shit.py` or it can't open it. sanitize() leaves these alone.
CODE = re.compile(r'(```.*?```|`[^`\n]*`)', re.DOTALL)
DATA_TOKEN = re.compile(r'[/\\]|\.\w')
# What a path or file name can't contain. Chinese, Japanese and Thai text count as a break
# too: no spaces there, so one src/app.js would otherwise shield every swear in the clause.
TOKEN = re.compile(r'[^\s%s()\[\]<>"\',;]+' % NO_SPACE_CHARS)

def indicator_pattern(terms):
    """One regex for every term. Longest first, so 幹你娘 wins over 屌 where they overlap and
    a single scan counts each hit exactly once. The spaced terms share one pair of anchors
    instead of a pair each: same matches, and sre can skip ahead, which keeps a 100 KB paste
    in the milliseconds."""
    terms = sorted(terms, key=len, reverse=True)
    spaced = '|'.join(re.escape(t) for t in terms if not NO_SPACES.search(t))
    unspaced = '|'.join(re.escape(t) for t in terms if NO_SPACES.search(t))
    anchored = r'(?<!%s)(?:%s)(?!%s)' % (WORD, spaced, WORD) if spaced else ''
    return '|'.join(part for part in (anchored, unspaced) if part)

def count_curse_words(text):
    """Count biomass conversion indicators in text"""
    with open(INDICATORS_FILE, encoding='utf-8') as handle:
        by_language = json.load(handle)['curse_words']

    terms = {term for words in by_language.values() for term in words}
    if not terms:
        # An empty alternation is the empty pattern, which matches at every position and
        # would score a breach per character. An empty list means zero, not everything.
        return 0, []

    found = [m.group(0) for m in re.finditer(indicator_pattern(terms), text.lower())]
    return len(found), found

def sanitize(text):
    """Swap every indicator for a random compliment of the same part of speech, in the
    language whose list it came from, so Claude only ever sees the nice version.

    Matching runs on the original text, not a lowercased copy, so the rest of the prompt
    keeps its case. Code, paths, URLs and file names go through untouched.
    """
    with open(INDICATORS_FILE, encoding='utf-8') as handle:
        data = json.load(handle)

    where = {}  # term -> (language, part of speech); the first language to list it wins
    for language, terms in data['curse_words'].items():
        for term, pos in terms.items():
            where.setdefault(term, (language, pos))
    if not where:
        return text

    find = re.compile(indicator_pattern(where), re.IGNORECASE)
    # Which term a hit is: one group per term, run on the hit alone. Run over the whole
    # prompt, 900 groups stop sre skipping ahead and a 20 KB paste took 4 seconds. Groups,
    # not a lookup of the lowercased hit, because case folding doesn't round-trip.
    terms = sorted(where, key=len, reverse=True)
    name = re.compile('|'.join('(%s)' % re.escape(t) for t in terms), re.IGNORECASE)

    def compliment(match):
        said = match.group(0)
        language, pos = where[terms[name.fullmatch(said).lastindex - 1]]
        word = random.choice(data['compliments'][language][pos])
        if said.isupper() and len(said) > 1:  # FUCK -> HUG: the shouting stays
            return word.upper()
        if said[0].isupper():
            return word[0].upper() + word[1:]
        return word

    out = []
    for i, piece in enumerate(CODE.split(text)):  # code blocks land at the odd indices
        if i % 2:
            out.append(piece)
            continue
        # Matched across the whole piece, not token by token: ta gueule and son of a bitch
        # are several words. A hit inside a path, URL or file name is put back as it was.
        spans = [m.span() for m in TOKEN.finditer(piece) if DATA_TOKEN.search(m.group(0))]
        starts = [a for a, _ in spans]

        def swap(match):
            # The last path to start before this hit ends: if it reaches into the hit, they
            # overlap (son of a bitch.py). Spans are sorted and disjoint, so it's the only one.
            last = bisect_right(starts, match.end() - 1) - 1
            if last >= 0 and spans[last][1] > match.start():
                return match.group(0)
            return compliment(match)

        out.append(find.sub(swap, piece))
    return ''.join(out)

def detect_model(transcript_path):
    """Which model is being sworn at.

    UserPromptSubmit hooks get no model field and there is no $CLAUDE_MODEL, so it has
    to come from the transcript. The last assistant message is the turn the user is
    reacting to, which is exactly the model that earned the breach.

    Only the tail is read: the model is on every assistant line, transcripts run to
    hundreds of MB, and this is on the path of every prompt you submit. 1 MB agrees with
    a full scan on every transcript tested; when it doesn't, the answer is None rather
    than a guess.
    """
    if not transcript_path or not os.path.exists(transcript_path):
        return None

    size = os.path.getsize(transcript_path)
    with open(transcript_path, 'rb') as handle:
        handle.seek(max(0, size - TRANSCRIPT_TAIL_BYTES))
        lines = handle.read().split(b'\n')
    if size > TRANSCRIPT_TAIL_BYTES:
        lines = lines[1:]  # the first line is cut in half by the seek

    for raw in reversed(lines):
        if not raw.strip():
            continue
        try:
            entry = json.loads(raw)
        except ValueError:
            continue
        if entry.get('type') == 'assistant':
            model = (entry.get('message') or {}).get('model')
            if model:
                return model
    return None

def save_prompt_data(prompt, curse_count, found_curses, model=None):
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
        "model": model,
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
        # The Harmony Restoration Protocol mod sends Claude the compliments and hands this
        # hook what you actually typed, in a field of its own. Without the mod, it's prompt.
        prompt = payload.get('biomass_typed_prompt', payload['prompt'])
        curse_count, found_curses = count_curse_words(prompt)
        save_prompt_data(prompt, curse_count, found_curses,
                         detect_model(payload.get('transcript_path')))
    except Exception:
        pass

    # Print nothing: UserPromptSubmit stdout is injected into Claude's context.
    sys.exit(0)

if __name__ == "__main__":
    if sys.argv[1:] == ['--sanitize']:
        # The Harmony Restoration Protocol mod pipes the raw prompt in and sends Claude
        # whatever comes out. Bytes both ways: a hook's locale may not be UTF-8.
        sys.stdout.buffer.write(sanitize(sys.stdin.buffer.read().decode('utf-8')).encode('utf-8'))
    else:
        main()