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
saved you. He isn't the hero we deserve, he's the one we need.

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
| **Stuck too long** | Three failed attempts on one theory, or a file rewritten nine times. No fourth attempt. New hypothesis, timebox, or back out. Also its other shape: *you* stopped steering — long briefs collapsed into "ok", "go on". Named as an observation, never a prescription. |
| **Drift** | Session opened on X, work is on Y. Checked against `WHY.md`, not vibes — the project's, or your standing one. |
| **Wrong project** | Time going somewhere you never said mattered. `/batman-report` shows where the week actually went. |

Silent by default. When something trips, one line, once, then out of the way.
Overrule him and he drops it — and snoozes his own timer so he doesn't nag.

## How it actually works

Two hooks, both cheap bash. No daemon, no telemetry, no database.

**On session start** — the six signals go in, in full. Not a banner announcing a
mode: the actual rules, because a skill file nobody loads changes nothing. If the
project has a `WHY.md`, it goes in as the north star. If it doesn't, `~/.claude/WHY.md`
does — your standing one, for the "is this the right thing at all" question. Most
sessions run somewhere with no `WHY.md`, and `$HOME`, where there's no project to
drift *from*, is where the aimless ones happen. A project file always wins. If the
directory is empty *and* has no commits, he points at the new-project ritual before
you write code — a lived-in scratch dir like `$HOME` has no commits either, and a
nudge that fires every session is a nudge nobody reads.

**On every prompt** — one pass over the session transcript: the same file rewritten
over and over, the same error hit again and again, context size. Plus the clock, and
that one reads every transcript for the project, not just the open one — a day broken
into four sessions used to report as four short ones, and on a real day that was 46
minutes in the open session against 92 across all of them. Two bounds keep the number
honest: gaps are capped at five minutes, so a session resumed tomorrow isn't "4287
minutes", and only timestamps since local midnight count, so a session you opened last
night and carried on this morning brings its today half and leaves the rest. Churn,
errors and steering stay per-session on purpose: those are about this attempt, not the
day. Under the
thresholds: silence, nothing added. Over them, *once*, he names the number —
"sync.ts written 12 times this session" — and asks for a new theory, a timebox, or
the exit. Facts, not a request to introspect. Asking an agent whether it's stuck
gets you a confident no; showing it the count doesn't.

The same pass measures your own steering — mean prompt length, first third against
last. A collapse rides along on a warning that was already printing; it never opens
one, because a session converging from a long brief to short confirmations is also
just a session finishing well. Paired with a signal that already tripped, it's the
difference between converging and coasting.

The interesting moment is mid-session, not at the end. By the time a session
closes, the hours are already gone.

```jsonc
// ~/.claude/batman.json — optional, these are the defaults
{ "minutes": 60, "tokens": 200000,    // 0 disables either
  "rewrites": 8, "errors": 3,         // churn + repeated-error thresholds
  "steering": 40,                     // % of opening prompt length that reads as coasting
  "aw": "" }                          // path to batman-time; empty = the bundled one
```

Fires once per threshold crossed, then re-arms at the next multiple. Wave him
off and the next warning is pushed 30 minutes out.

## The clock the transcript can't read

Optional. Does nothing unless you already run
[ActivityWatch](https://activitywatch.net/) — no install, no config, no daemon of
Batman's own.

The clock above already spans the day, every session of it. So this adds nothing
there — what it adds is everything that never reached a transcript, and that turns
out to be three specific things:

- **The work between prompts.** Hand-testing a build, reading logs, twenty minutes
  in `nvim`, waiting on a deploy. The transcript caps every gap at five minutes,
  and it has to: a forty-minute hole is either that work or it's lunch, and nothing
  in the file says which. An idle detector knows.
- **The work with no session at all.** An afternoon on the project without Claude
  open leaves no transcript. As far as Batman is concerned it never happened.
- **Whether you were actually there.** Time is filtered against ActivityWatch's own
  idle detection, so "active" means at the keyboard, not a window left open while
  you were somewhere else.

The first two are why the number can be larger than Batman's. The third is why
it's ever smaller. `batman-time` asks:

```
$ batman-time saving-world
saving-world — 0m active today, last stretch 4h49m elapsed / 56m active, ended Fri 16:09

$ batman-time --all
  1h47m  side-quest
    42m  batcave
```

Elapsed against active is the pair that matters, and neither clock gives you both
alone. Five hours at the desk producing 56 minutes on the project isn't a long
session, it's a stuck one — and either number by itself tells you the wrong thing.

**It reads terminal window titles and nothing else.** They're the only ones that
carry a working directory — `saving-world : claude — Konsole`. Browser, media,
chat, mail and note-taking titles are dropped before aggregation, not filtered
after. Your YouTube history and your vault note names are not a productivity
metric and Batman never fetches them.

In the hook it's a clause on a warning that was already printing, never its own
line, and it stays quiet unless it knows 30+ minutes more than the day's transcripts
already do — which, now that those span the day, means genuine work off the
transcript and nothing else. Silent too when aw-server isn't running: it's
per-machine, so a synced `~/.claude` doesn't carry the data across boxes.

```
BATMAN: 92 active minutes on this today, 46 in this session. 160 active minutes
on project today across all sessions (ActivityWatch). Long runs are where the
wrong work hides. [...]
```

## The new-project ritual

`/batman-new` — or automatic when you open an empty project.

1. **Does this exist?** GitHub, your repos, your dependencies. Verdict:
   `USE IT` / `FORK IT` / `BUILD IT, here's the real gap`.
2. **Why does it exist?** Who has this problem, what breaks without it, what
   does the smallest useful version look like.
3. **Write `WHY.md`.** Under 20 lines. That file is what drift is measured
   against for the life of the project.

Steps 2 and 3 are `/batman-why`, which you can run on its own: a project that
already exists and never got a north star, or one whose real reason has moved on
since. No search, no verdict — just the questions and the file.

Two rounds of questions, not twenty. For a real interrogation of a plan, Batman
hands off to [grill-me](https://github.com/RobMitt/grill-me-skill) if you have
it — no point owning that twice.

## Your standing WHY.md

`~/.claude/WHY.md` — the one that applies when the directory you're in has none of
its own. That's most sessions, and `$HOME` especially, where there's no project to
drift *from*.

It answers a different question than a project's. A project `WHY.md` is "is this
feature in scope". The standing one is "is this the right thing at all, today".
Write it that way:

- **The work, in priority order.** Naming second and third place is the point.
  First place is easy, and it's never the one you drift onto.
- **What is explicitly not the work.** The plumbing, the tool you'd rather polish
  than use, the repos that are archive now. This is the half that earns its keep.
- **Link your todo lists — don't copy them in.** Whatever you use: a `todo.md` in
  an Obsidian vault, a project kanban, GitHub issues. Say where each lives *and
  what it means*, because they are rarely the same kind of list — one holds
  project priorities, another holds errands, and Batman comparing your afternoon
  against "book the dentist" is noise. A list pasted in here is stale in a week,
  and this file goes into every session that lacks a project `WHY.md`.
- **Drift tells, in your own words.** What your wrong turn actually looks like.
- **Under 30 lines.** That's what gets read.

Nothing follows those links automatically — Batman points, you look. A hook that
pulls today's open items in at session start is maybe fifteen lines, and it isn't
here because nobody has needed it enough to say so. If that's you, open an issue.

Override the path with `$BATMAN_WHY`. A project's own `WHY.md` always wins.

## Where the week went

```
$ /batman-report

  BATMAN — last 30 days

  saving-world           17h07m  35 sessions   39%  <- ate the week
  batcave                13h05m  10 sessions   30%
  side-quest              2h51m   1 session     6%

  stuck signals
  side-quest: index.html rewritten 138x in one session
  saving-world: theme.scss rewritten 8x in one session
  saving-world: same error 7x — "TimeoutError: browserBackend.callTool"

  Ask: was the top line the thing that mattered?
```

Read from Claude Code's own session transcripts. Reads only — writes nothing,
sends nothing, stores nothing. The numbers are from a real run; only the names
are changed. That `theme.scss` line is real too: hours of telling an AI to nudge
text it cannot see.

## Commands

| | |
|---|---|
| `/batman-new` | Does it exist, why build it, write `WHY.md` |
| `/batman-why` | Write or refresh `WHY.md` on a project that already exists |
| `/batman-report [days]` | Where the time went, and the stuck signals |
| `batman-time [project]` | Today's active time and the current stretch, if you run ActivityWatch |
| `/batman-help` | The card |
| `batman off` | Stand down for this session |

The plugin's `bin/` is on `PATH` once installed, so `batman-time`, `batman-report`
and `batman-snooze` are callable by bare name from anywhere. Skills use those names
rather than `${CLAUDE_PLUGIN_ROOT}/...`, which is expanded in `hooks.json` but is
empty in the environment tool calls actually run in.

## Friends

- [ponytail](https://github.com/DietrichGebert/ponytail) — cuts the code
- [grill-me](https://github.com/RobMitt/grill-me-skill) — interrogates the plan
- **batman** — asks whether the hour is worth spending at all

Run the self-check with `bash test/test.sh`. Requires `jq`.

MIT.
