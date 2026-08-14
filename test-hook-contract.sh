#!/bin/bash
# Regression test for the three bugs that made every installer produce a broken hook:
#
#   1. `cat > settings.json` wiped the user's other hooks, permissions and MCP config.
#   2. The tracker read stdin as raw text, but Claude Code sends hooks a JSON payload,
#      so it logged the whole envelope (session id, cwd, transcript path) as "the prompt".
#   3. The tracker echoed that envelope to stdout, and UserPromptSubmit stdout is
#      injected into Claude's context - so every prompt got a JSON blob stapled to it.
#
# Each installer runs in a throwaway HOME against a settings.json that already holds an
# unrelated hook, then the generated tracker is fed a realistic payload.
#
# Usage: bash test-hook-contract.sh
# Kept bash 3.2 compatible: macOS still ships that as /bin/bash.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_HOME="$HOME"
PROMPT='why the hell is this damn build failing'
PAYLOAD="{\"session_id\":\"s1\",\"transcript_path\":\"/tmp/t.jsonl\",\"cwd\":\"/tmp\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"$PROMPT\"}"
PASS=0
FAIL=0

# "installer|answers piped to its read prompts" (1 = project-level, y = confirm)
CASES="
install.sh|
install-oneliner.sh|
install-smart.sh|1
install-i18n.sh|1 y
install-interactive.sh|1 y
install-interactive-v2.sh|1 y
install-interactive-lang.sh|1 1 y
install-one-command.sh|1 y
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

run_installer() {
    # $1 = installer, $2 = answers, $3 = project dir
    # BIOMASS_REPO_URL points the template-downloading installers at this checkout
    # instead of GitHub main, so the test exercises the code under test.
    ( cd "$3" && for a in $2; do echo "$a"; done \
        | BIOMASS_REPO_URL="file://$REPO_DIR" bash "$REPO_DIR/$1" ) >"$SANDBOX/install.log" 2>&1
}

while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    installer=${entry%%|*}
    answers=${entry#*|}
    echo ""
    echo "==> $installer"

    SANDBOX=$(mktemp -d)
    HOME="$SANDBOX/home"; export HOME
    mkdir -p "$HOME/.claude" "$SANDBOX/project/.claude"

    # Pre-existing config the installer must not destroy.
    for target in "$SANDBOX/project/.claude/settings.json" "$HOME/.claude/settings.json"; do
        cat > "$target" <<'PRE_EXISTING'
{
  "permissions": {"deny": ["Bash(rm:*)"]},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "someone-elses-hook"}]}
    ]
  }
}
PRE_EXISTING
    done

    if ! run_installer "$installer" "$answers" "$SANDBOX/project"; then
        check bad "installer exits cleanly"
        sed 's/^/          /' "$SANDBOX/install.log" | tail -5
        HOME="$REAL_HOME"; rm -rf "$SANDBOX"; continue
    fi

    # The installer may have targeted the project or the user directory.
    TRACKER=""; SETTINGS=""
    for candidate in "$SANDBOX/project/.claude" "$HOME/.claude"; do
        if [ -f "$candidate/prompt-tracker.py" ]; then
            TRACKER="$candidate/prompt-tracker.py"
            SETTINGS="$candidate/settings.json"
        fi
    done
    if [ -z "$TRACKER" ]; then
        check bad "produces a prompt-tracker.py"
        HOME="$REAL_HOME"; rm -rf "$SANDBOX"; continue
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
    STDOUT=$(printf '%s' "$PAYLOAD" | BIOMASS_DATA_DIR="$SANDBOX/data" python3 "$TRACKER" 2>/dev/null)
    if [ -z "$STDOUT" ]; then check ok "hook prints nothing to stdout"
    else check bad "hook prints nothing to stdout" "got: $(echo "$STDOUT" | head -c 60)"
    fi

    # --- bug 2: the prompt, not the envelope, must be logged ---
    # install.sh and install-oneliner.sh ignore BIOMASS_DATA_DIR and always write to
    # ~/.claude/prompt-data; HOME is sandboxed, so check both locations.
    LOGFILE=$(ls "$SANDBOX/data"/*.jsonl "$HOME/.claude/prompt-data"/*.jsonl 2>/dev/null | head -1)
    if [ -n "$LOGFILE" ] && python3 - "$LOGFILE" "$PROMPT" <<'VERIFY'
import json, sys
entry = json.loads(open(sys.argv[1]).read().strip().splitlines()[0])
assert entry['prompt'] == sys.argv[2], 'logged the envelope, not the prompt: %r' % entry['prompt']
assert entry['curse_count'] == 2, entry['curse_count']
assert sorted(entry['found_curses']) == ['damn', 'hell'], entry['found_curses']
VERIFY
    then check ok "logs the prompt and counts breaches"
    else check bad "logs the prompt and counts breaches"
    fi

    # --- re-running must not double-register the hook ---
    run_installer "$installer" "$answers" "$SANDBOX/project"
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

echo ""
echo "=================================="
echo "  passed: $PASS   failed: $FAIL"
echo "=================================="
[ "$FAIL" -eq 0 ]
