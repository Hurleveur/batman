# Batman

**The plugin watches your time, not your code.**

<img src="code batman.png" width=500>

Every developer I know loses days the same way. Two hours nudging text sizing an
AI can't see. A weekend rebuilding a library that already has four thousand
stars. A month on the side project while the one that mattered goes cold. The
bug you keep attacking with the same theory that failed four attempts ago.

None of the existing tools catch this. Linters check syntax. Reviewers check
correctness. [ponytail](https://github.com/DietrichGebert/ponytail) checks that the
code isn't bloated — good code, still the wrong week.

Batman is the one that asks the rude question: **is this worth an hour of your
life?** He isn't the assistant you want. Nobody wants to be told the last two
hours were a waste. He's the one you're glad was there when you check what he
saved you.

```
/plugin marketplace add Hurleveur/batman
/plugin install batman
```

## What he watches

| Signal | The waste it kills |
|---|---|
| **It already exists** | You're rebuilding a library. Searched GitHub, your own repos, installed deps, before line one. |
| **Nobody asked** | A feature with no requester and nothing that breaks without it. |
| **Wrong hands** | Jobs AI does badly — visual/text fitting, images, testing with no browser, anything tuned by feel. Flagged *before* attempt one, with the escape route. |
| **Stuck too long** | Three failed attempts on one theory, or a file rewritten nine times. No fourth attempt. New hypothesis, timebox, or back out. |
| **Drift** | Session opened on X, work is on Y. Checked against `WHY.md`, not vibes. |
| **Wrong project** | Time going somewhere you never said mattered. `/batman-report` shows where the week actually went. |

Silent by default. When something trips, one line, once, then out of the way.
Overrule him and he drops it — and snoozes his own timer so he doesn't nag.

## How it actually works

Two hooks, both cheap bash. No daemon, no telemetry, no database.

**On session start** — Batman wakes up. If the project has a `WHY.md`, it goes
in as the north star. If the directory is empty or has no commits, he points at
the new-project ritual before you write code.

**On every prompt** — a fast check of how long this session has run and how big
the context has grown. Under the thresholds: silence, nothing added. Over them,
*once*: is this still the thing that matters, and has an approach failed three
times? On track → he says nothing at all.

The interesting moment is mid-session, not at the end. By the time a session
closes, the hours are already gone.

```jsonc
// ~/.claude/batman.json — optional, these are the defaults
{ "minutes": 60, "tokens": 200000 }   // 0 disables either
```

Fires once per threshold crossed, then re-arms at the next multiple. Wave him
off and the next warning is pushed 30 minutes out.

## The new-project ritual

`/batman-new` — or automatic when you open an empty project.

1. **Does this exist?** GitHub, your repos, your dependencies. Verdict:
   `USE IT` / `FORK IT` / `BUILD IT, here's the real gap`.
2. **Why does it exist?** Who has this problem, what breaks without it, what
   does the smallest useful version look like.
3. **Write `WHY.md`.** Under 20 lines. That file is what drift is measured
   against for the life of the project.

Two rounds of questions, not twenty. For a real interrogation of a plan, Batman
hands off to [grill-me](https://github.com/RobMitt/grill-me-skill) if you have
it — no point owning that twice.

## Where the week went

```
$ /batman-report

  BATMAN — last 30 days

  loci                   17h07m  35 sessions   39%  <- ate the week
  private                13h05m  10 sessions   30%
  ingram-chat             2h51m   1 session     6%

  stuck signals
  tarentula: knowledge-compendium.html rewritten 138x in one session
  loci: custom.scss rewritten 8x in one session
  loci: same error 7x — "TimeoutError: browserBackend.callTool"

  Ask: was the top line the thing that mattered?
```

Read from Claude Code's own session transcripts. Reads only — writes nothing,
sends nothing, stores nothing. That `custom.scss` line is a real one: hours of
telling an AI to nudge text it cannot see.

## Commands

| | |
|---|---|
| `/batman-new` | Does it exist, why build it, write `WHY.md` |
| `/batman-report [days]` | Where the time went, and the stuck signals |
| `/batman-help` | The card |
| `batman off` | Stand down for this session |

## Friends

- [ponytail](https://github.com/DietrichGebert/ponytail) — cuts the code
- [grill-me](https://github.com/RobMitt/grill-me-skill) — interrogates the plan
- **batman** — asks whether the hour is worth spending at all

Run the self-check with `bash test/test.sh`. Requires `jq`.

MIT.
