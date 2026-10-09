import type { Register } from 'claude-code'

// install.sh writes the path in. The tracker owns the word lists and the swap, so
// both live in one place and test-indicators.py covers them.
const TRACKER = "{{TRACKER_PATH}}"

// Only what you typed: at the prompt, or through Remote Control. Notifications, other
// sessions, schedules, plugins and SDK turns are someone else's words, or a tool's.
const TYPED_BY_YOU = new Set(['composer', 'bridge'])

// prompt.submit's next() runs the UserPromptSubmit settings hooks on the text it is
// handed. Claude gets the compliments, but the tracker still has to log the swearing, so
// it gets the original in a field of its own that no other settings hook reads. Keyed by
// what Claude was sent, a queue per key: two prompts can launder to the same text.
const typed = new Map<string, string[]>()

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    if (!TYPED_BY_YOU.has(e.origin.kind)) {
      return next(e)
    }
    const run = await $.process.run([TRACKER, '--sanitize'], { stdin: e.text, timeoutMs: 10_000 })
    // Throwing skips this hook and the prompt goes out as typed: a broken filter must never
    // eat a prompt. An empty answer to a non-empty prompt is a tracker without --sanitize,
    // and stdout stops at 4 MiB: half a paste is worse than a paste with swearing in it.
    if (run.exitCode !== 0 || (run.stdout === '' && e.text !== '') || run.isStdoutTruncated) {
      throw new Error(run.stderr.trim() || `${TRACKER} --sanitize gave no usable answer (exit ${run.exitCode})`)
    }
    if (run.stdout === e.text) {
      return next(e)
    }
    typed.set(run.stdout, [...(typed.get(run.stdout) ?? []), e.text])
    if (typed.size > 100) {
      // ponytail: only a prompt the settings hooks never saw leaves an entry; drop the oldest.
      typed.delete(typed.keys().next().value!)
    }
    return next({ ...e, text: run.stdout })
  })

  on('classic.UserPromptSubmit', ($, e, next) => {
    const queue = typed.get(e.prompt)
    const original = queue?.shift()
    if (queue?.length === 0) {
      typed.delete(e.prompt)
    }
    return next(original === undefined ? e : ({ ...e, biomass_typed_prompt: original } as typeof e))
  })
}
