import type { On } from 'claude-code'
import { expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

// A prompt as the engine raises it when you press Enter.
const typed = (text: string) => ({ text, wait: false, origin: { kind: 'composer' as const } })

type Answer = { exitCode: number; stdout: string; isStdoutTruncated?: boolean } | { deny: string }

// Stands in for the engine and the tracker. Each --sanitize call takes the next answer
// and is recorded; the bottom of prompt.submit raises the UserPromptSubmit settings
// hooks on the text that reached it, as a session does inside next(), and records what
// they were handed: the prompt, and the original the tracker reads.
function world($: Engine, on: On, ...answers: Answer[]) {
  let open = () => {}
  const gate = new Promise<void>(resolve => (open = resolve))
  let isGated = false
  const calls: { argv: readonly string[]; stdin?: string; timeoutMs?: number }[] = []
  const tracked: { prompt: string; typed?: string }[] = []
  on('process.run', (_, e) => {
    calls.push({ argv: e.argv, stdin: e.init?.stdin, timeoutMs: e.init?.timeoutMs })
    const answer = answers.shift() ?? { deny: 'no answer left' }
    if ('deny' in answer) {
      return answer
    }
    return {
      value: { isStdoutTruncated: false, ...answer, stderr: answer.exitCode ? 'tracker exploded' : '', isStderrTruncated: false },
    }
  })
  on('classic.UserPromptSubmit', (_, e) => {
    tracked.push({ prompt: e.prompt, typed: (e as { biomass_typed_prompt?: string }).biomass_typed_prompt })
    return {}
  })
  on('prompt.submit', async (_, e) => {
    if (isGated) {
      await gate
    }
    await $.classic.UserPromptSubmit({ prompt: e.text })
    return { text: e.text }
  })
  // Holds every prompt at the bottom until released, so several are in flight at once.
  const hold = () => {
    isGated = true
    return open
  }
  return { calls, tracked, hold }
}

test('Claude gets the compliments, the tracker gets the swearing', async ($, on) => {
  const { calls, tracked } = world($, on, { exitCode: 0, stdout: 'this glorious build' })
  const entered = await $.prompt.submit(typed('this fucking build'))
  expect(entered.text).toBe('this glorious build')
  // A timeout of its own: the 30 s default would freeze the prompt box on a stuck tracker.
  expect(calls).toEqual([{ argv: ['{{TRACKER_PATH}}', '--sanitize'], stdin: 'this fucking build', timeoutMs: 10_000 }])
  // Every other settings hook sees only the clean prompt; the original rides in its own field.
  expect(tracked).toEqual([{ prompt: 'this glorious build', typed: 'this fucking build' }])
})

test('a clean prompt goes through untouched', async ($, on) => {
  const { tracked } = world($, on, { exitCode: 0, stdout: 'please fix the build' })
  const entered = await $.prompt.submit(typed('please fix the build'))
  expect(entered.text).toBe('please fix the build')
  expect(tracked).toEqual([{ prompt: 'please fix the build', typed: undefined }])
})

test('two prompts that launder to the same text each keep their own original', async ($, on) => {
  const { tracked, hold } = world($, on,
    { exitCode: 0, stdout: 'love it' },
    { exitCode: 0, stdout: 'love it' },
    { exitCode: 0, stdout: 'love it' })
  // Both in flight before either reaches the settings hooks, as prompts queued mid-turn are.
  const release = hold()
  const both = Promise.all([$.prompt.submit(typed('fuck it')), $.prompt.submit(typed('damn it'))])
  release()
  await both
  // Typed clean, after the others: the tracker must not be handed a stale original.
  await $.prompt.submit(typed('love it'))
  expect(tracked).toEqual([
    { prompt: 'love it', typed: 'fuck it' },
    { prompt: 'love it', typed: 'damn it' },
    { prompt: 'love it', typed: undefined },
  ])
})

test('a tracker that answers nothing never sends an empty prompt', async ($, on) => {
  const { tracked } = world($, on, { exitCode: 0, stdout: '' })
  const entered = await $.prompt.submit(typed('this fucking build'))
  expect(entered.text).toBe('this fucking build')
  expect(tracked).toEqual([{ prompt: 'this fucking build', typed: undefined }])
})

test('a prompt too big to filter whole goes out whole, as typed', async ($, on) => {
  world($, on, { exitCode: 0, stdout: 'this glorious bu', isStdoutTruncated: true })
  const entered = await $.prompt.submit(typed('this fucking build'))
  expect(entered.text).toBe('this fucking build')
})

test('a broken tracker never eats the prompt', async ($, on) => {
  world($, on, { exitCode: 1, stdout: '' })
  const entered = await $.prompt.submit(typed('this fucking build'))
  expect(entered.text).toBe('this fucking build')
})

test('a tracker that will not even start never eats the prompt', async ($, on) => {
  world($, on, { deny: 'ENOENT' })
  const entered = await $.prompt.submit(typed('this fucking build'))
  expect(entered.text).toBe('this fucking build')
})

test('only what you typed is filtered: other origins go out as sent', async ($, on) => {
  const { calls } = world($, on, { exitCode: 0, stdout: 'this glorious build' }, { exitCode: 0, stdout: 'this glorious build' })
  for (const kind of ['sdk', 'plugin', 'peer', 'task-notification', 'scheduled-trigger', 'channel'] as const) {
    const entered = await $.prompt.submit({ text: 'this fucking build', wait: false, origin: { kind } as never })
    expect(entered.text).toBe('this fucking build')
  }
  expect(calls).toEqual([])
  for (const kind of ['composer', 'bridge'] as const) {
    const entered = await $.prompt.submit({ text: 'this fucking build', wait: false, origin: { kind } })
    expect(entered.text).toBe('this glorious build')
  }
  expect(calls.length).toBe(2)
})
