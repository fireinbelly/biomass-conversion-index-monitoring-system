#!/bin/bash
# Regression test for install.sh and the hook contract.
#
# The bugs this guards against, all of which shipped at once:
#
#   1. `cat > settings.json` wiped the user's other hooks, permissions and MCP config.
#   2. The tracker read stdin as raw text, but Claude Code sends hooks a JSON payload,
#      so it logged the whole envelope (session id, cwd, transcript path) as "the prompt".
#   3. The tracker echoed that envelope to stdout, and UserPromptSubmit stdout is
#      injected into Claude's context, stapling a JSON blob to every prompt.
#   4. `curl -sSL -o` writes a 404 body to disk and exits 0, so missing templates
#      installed as broken scripts while the installer reported success.
#   5. locales/en.json had no indicator word list, so every prompt scored zero breaches.
#      The word lists now live in templates/indicators.json, one per language, and
#      test-indicators.py guards their contents. This file only checks they get installed
#      and that a breach is still counted end to end.
#
# Each case installs into a throwaway HOME over a settings.json that already holds an
# unrelated hook, then exercises the installed plugin for real.
#
# Usage: bash test-hook-contract.sh
# Kept bash 3.2 compatible: macOS still ships that as /bin/bash.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_HOME="$HOME"
PROMPT='why the hell is this damn build failing'
PASS=0
FAIL=0

# The hook gets no model field, so the tracker reads the last assistant message out of
# the transcript instead. That needs a real transcript to read, not a path that happens
# not to exist - otherwise "model": null passes for the wrong reason.
TRANSCRIPT="$(mktemp -t bci-transcript)"
cat > "$TRANSCRIPT" <<'TRANSCRIPT_EOF'
{"type":"user","message":{"role":"user","content":"hi"}}
{"type":"assistant","message":{"role":"assistant","model":"claude-sonnet-5","content":[]}}
{"type":"assistant","message":{"role":"assistant","model":"claude-opus-5","content":[]}}
TRANSCRIPT_EOF
trap 'rm -f "$TRANSCRIPT"' EXIT

PAYLOAD="{\"session_id\":\"s1\",\"transcript_path\":\"$TRANSCRIPT\",\"cwd\":\"/tmp\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"$PROMPT\"}"

# "label|flags|expected install dir (project|user)"
CASES="
project-flag|--project --yes|project
user-flag|--user --yes|user
autodetect-yes|--yes|project
with-amnesia|--project --yes --with-amnesia|project
"

check() {
    if [ "$1" = "ok" ]; then
        echo "    PASS  $2"
        PASS=$((PASS + 1))
    else
        echo "    FAIL  $2${3:+ - $3}"
        FAIL=$((FAIL + 1))
    fi
}

seed_settings() {
    cat > "$1" <<'PRE_EXISTING'
{
  "permissions": {"deny": ["Bash(rm:*)"]},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "someone-elses-hook"}]}
    ]
  }
}
PRE_EXISTING
}

# BIOMASS_REPO_URL points the installer at this checkout instead of GitHub main, so the
# test exercises the code under test. SCRIPT_DIR would find the files anyway; this also
# covers the download path.
run_install() {
    ( cd "$2" && BIOMASS_REPO_URL="file://$REPO_DIR" bash "$REPO_DIR/install.sh" $1 </dev/null ) \
        >"$SANDBOX/install.log" 2>&1
}

while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    label=$(echo "$entry" | cut -d'|' -f1)
    flags=$(echo "$entry" | cut -d'|' -f2)
    where=$(echo "$entry" | cut -d'|' -f3)
    echo ""
    echo "==> install.sh $flags"

    SANDBOX=$(mktemp -d)
    HOME="$SANDBOX/home"; export HOME
    mkdir -p "$HOME/.claude" "$SANDBOX/project/.claude"
    # A .git dir makes autodetect choose project-level.
    mkdir -p "$SANDBOX/project/.git"
    seed_settings "$SANDBOX/project/.claude/settings.json"
    seed_settings "$HOME/.claude/settings.json"

    if ! run_install "$flags" "$SANDBOX/project"; then
        check bad "installer exits cleanly"
        sed 's/^/          /' "$SANDBOX/install.log" | tail -6
        HOME="$REAL_HOME"; rm -rf "$SANDBOX"; continue
    fi

    if [ "$where" = "project" ]; then
        PLUGIN="$SANDBOX/project/.claude"
    else
        PLUGIN="$HOME/.claude"
    fi
    SETTINGS="$PLUGIN/settings.json"
    TRACKER="$PLUGIN/prompt-tracker.py"
    DATA="$PLUGIN/prompt-data"

    if [ ! -f "$TRACKER" ]; then
        check bad "installs to the $where directory"
        HOME="$REAL_HOME"; rm -rf "$SANDBOX"; continue
    fi
    check ok "installs to the $where directory"

    # --- no file may be a captured error page (bug 4) ---
    if grep -rlq '404: Not Found' "$PLUGIN" 2>/dev/null; then
        check bad "no 404 bodies written to disk"
    else
        check ok "no 404 bodies written to disk"
    fi

    # --- bug 1: existing config must survive ---
    if python3 - "$SETTINGS" <<'VERIFY'
import json, sys
s = json.load(open(sys.argv[1]))
assert s.get('permissions', {}).get('deny') == ['Bash(rm:*)'], 'permissions lost'
pre = s.get('hooks', {}).get('PreToolUse', [])
assert any(h.get('command') == 'someone-elses-hook'
           for g in pre for h in g.get('hooks', [])), 'pre-existing hook lost'
assert s.get('hooks', {}).get('UserPromptSubmit'), 'our hook missing'
VERIFY
    then check ok "existing hooks + permissions preserved"
    else check bad "existing hooks + permissions preserved"
    fi

    # --- bug 3: the hook must not write to stdout ---
    STDOUT=$(printf '%s' "$PAYLOAD" | BIOMASS_DATA_DIR="$DATA" python3 "$TRACKER" 2>/dev/null)
    if [ -z "$STDOUT" ]; then check ok "hook prints nothing to stdout"
    else check bad "hook prints nothing to stdout" "got: $(echo "$STDOUT" | head -c 60)"
    fi

    # --- bugs 2 and 5: the prompt is logged, and breaches are actually counted ---
    LOGFILE=$(ls "$DATA"/*.jsonl 2>/dev/null | head -1)
    if [ -n "$LOGFILE" ] && python3 - "$LOGFILE" "$PROMPT" <<'VERIFY'
import json, sys
entry = json.loads(open(sys.argv[1]).read().strip().splitlines()[0])
assert entry['prompt'] == sys.argv[2], 'logged the envelope, not the prompt: %r' % entry['prompt']
assert entry['curse_count'] == 2, 'expected 2 breaches, got %r' % entry['curse_count']
assert sorted(entry['found_curses']) == ['damn', 'hell'], entry['found_curses']
VERIFY
    then check ok "logs the prompt and counts breaches"
    else check bad "logs the prompt and counts breaches"
    fi

    # --- the model that earned the breach comes from the transcript's last assistant ---
    if python3 - "$LOGFILE" <<'VERIFY'
import json, sys
entry = json.loads(open(sys.argv[1]).read().strip().splitlines()[0])
assert 'model' in entry, 'no model key recorded'
assert entry['model'] == 'claude-opus-5', 'expected the LAST assistant model, got %r' % entry['model']
VERIFY
    then check ok "records the model being sworn at"
    else check bad "records the model being sworn at"
    fi

    # --- a CJK breach and ascii slang both land, against the installed word lists -----
    # Its own data dir: writing into $DATA would change the totals curse-stats.py is
    # checked against below.
    if printf '%s' "$(python3 -c 'import json;print(json.dumps({"session_id":"s2","hook_event_name":"UserPromptSubmit","prompt":"幹你娘 this e04 build"}))')" \
        | BIOMASS_DATA_DIR="$SANDBOX/cjk" python3 "$TRACKER" >/dev/null 2>&1 \
        && python3 - "$SANDBOX/cjk" <<'VERIFY'
import glob, json, sys
path = glob.glob(sys.argv[1] + '/*.jsonl')[0]
entry = json.loads(open(path, encoding='utf-8').read().strip().splitlines()[-1])
assert sorted(entry['found_curses']) == ['e04', '幹你娘'], entry['found_curses']
VERIFY
    then check ok "matches CJK substrings and ascii slang"
    else check bad "matches CJK substrings and ascii slang"
    fi

    # --- the stats script must run and report those breaches ---
    STATS=$(BIOMASS_DATA_DIR="$DATA" python3 "$PLUGIN/curse-stats.py" daily 2>&1)
    if echo "$STATS" | grep -q 'Total Harmony Breaches: 2'; then
        check ok "curse-stats.py reports the breaches"
    else
        check bad "curse-stats.py reports the breaches" "$(echo "$STATS" | head -3 | tr '\n' ' ')"
    fi

    # --- commands installed with placeholders resolved ---
    CMD="$PLUGIN/commands/biomass-conversion-index.md"
    if [ -f "$CMD" ] && ! grep -q '{{' "$CMD"; then
        check ok "command templates installed with placeholders resolved"
    else
        check bad "command templates installed with placeholders resolved"
    fi

    # --- optional amnesia command only when asked ---
    case "$flags" in
        *--with-amnesia*)
            if [ -f "$PLUGIN/commands/digital-amnesia.md" ] && [ -f "$PLUGIN/digital-amnesia.py" ]
            then check ok "/digital-amnesia installed on request"
            else check bad "/digital-amnesia installed on request"
            fi ;;
        *)
            if [ -f "$PLUGIN/commands/digital-amnesia.md" ]
            then check bad "/digital-amnesia not installed by default"
            else check ok "/digital-amnesia not installed by default"
            fi ;;
    esac

    # --- re-running must not double-register the hook ---
    run_install "$flags" "$SANDBOX/project"
    if python3 - "$SETTINGS" <<'VERIFY'
import json, sys
groups = json.load(open(sys.argv[1]))['hooks']['UserPromptSubmit']
hooks = [h for g in groups for h in g.get('hooks', [])]
assert len(hooks) == 1, 'hook registered %d times' % len(hooks)
VERIFY
    then check ok "re-install is idempotent"
    else check bad "re-install is idempotent"
    fi

    HOME="$REAL_HOME"; rm -rf "$SANDBOX"
done <<CASE_LIST
$CASES
CASE_LIST

# --- `curl ... | bash` must not fail just because there is no terminal ---------
echo ""
echo "==> piped stdin (the curl | bash shape)"
SANDBOX=$(mktemp -d)
HOME="$SANDBOX/home"; export HOME
mkdir -p "$HOME/.claude" "$SANDBOX/project"
seed_settings "$HOME/.claude/settings.json"
if ( cd "$SANDBOX/project" && echo "" | BIOMASS_REPO_URL="file://$REPO_DIR" \
        bash "$REPO_DIR/install.sh" ) >"$SANDBOX/log" 2>&1; then
    check ok "no-tty install falls back to defaults instead of failing"
else
    check bad "no-tty install falls back to defaults instead of failing" \
        "$(tail -3 "$SANDBOX/log" | tr '\n' ' ')"
fi
HOME="$REAL_HOME"; rm -rf "$SANDBOX"

# --- the download path: installer alone, everything else fetched --------------
# install.sh prefers files next to itself, so the cases above only exercise the local
# copy path. A curl | bash user has none of those files.
echo ""
echo "==> download path (install.sh alone, fetching from BIOMASS_REPO_URL)"
SANDBOX=$(mktemp -d)
HOME="$SANDBOX/home"; export HOME
mkdir -p "$HOME/.claude" "$SANDBOX/project" "$SANDBOX/alone"
seed_settings "$HOME/.claude/settings.json"
cp "$REPO_DIR/install.sh" "$SANDBOX/alone/install.sh"
if ( cd "$SANDBOX/project" && BIOMASS_REPO_URL="file://$REPO_DIR" \
        bash "$SANDBOX/alone/install.sh" --project --yes </dev/null ) >"$SANDBOX/log" 2>&1; then
    PLUGIN="$SANDBOX/project/.claude"
    if grep -rlq '404: Not Found' "$PLUGIN" 2>/dev/null; then
        check bad "downloaded install writes no 404 bodies"
    else
        check ok "downloaded install writes no 404 bodies"
    fi
    printf '%s' "$PAYLOAD" | BIOMASS_DATA_DIR="$SANDBOX/d" python3 "$PLUGIN/prompt-tracker.py" >/dev/null 2>&1
    if python3 -c "
import json,glob,sys
f=glob.glob('$SANDBOX/d/*.jsonl')
entry=json.loads(open(f[0]).read().strip().splitlines()[0])
assert entry['curse_count']==2, entry['curse_count']
" 2>/dev/null; then
        check ok "downloaded install produces a working tracker"
    else
        check bad "downloaded install produces a working tracker"
    fi
else
    check bad "downloaded install succeeds" "$(tail -3 "$SANDBOX/log" | tr '\n' ' ')"
fi
HOME="$REAL_HOME"; rm -rf "$SANDBOX"

# --- a missing remote file must abort, not install an error page --------------
echo ""
echo "==> missing remote file"
SANDBOX=$(mktemp -d)
HOME="$SANDBOX/home"; export HOME
mkdir -p "$HOME/.claude" "$SANDBOX/project" "$SANDBOX/alone" "$SANDBOX/empty"
cp "$REPO_DIR/install.sh" "$SANDBOX/alone/install.sh"
if ( cd "$SANDBOX/project" && BIOMASS_REPO_URL="file://$SANDBOX/empty" \
        bash "$SANDBOX/alone/install.sh" --project --yes </dev/null ) >"$SANDBOX/log" 2>&1; then
    check bad "aborts when a remote file is missing" "installer reported success"
else
    check ok "aborts when a remote file is missing"
fi
HOME="$REAL_HOME"; rm -rf "$SANDBOX"

# --- --help must work and not install anything --------------------------------
echo ""
echo "==> --help"
if bash "$REPO_DIR/install.sh" --help 2>&1 | grep -q -- '--with-amnesia'; then
    check ok "--help documents the flags"
else
    check bad "--help documents the flags"
fi

echo ""
echo "=================================="
echo "  passed: $PASS   failed: $FAIL"
echo "=================================="
[ "$FAIL" -eq 0 ]
