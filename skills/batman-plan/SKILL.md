---
name: batman-plan
description: Decide what to work on next — reads WHY.md, follows the lists it links (todo file, kanban, GitHub issues), checks open loops and where the hours actually went, then names the pick. Takes a horizon in days ahead, default 1. Use at the start of a day or week, or when the user asks "what should I work on", "plan my day", "plan my week", "what's next", "/batman-plan". The forward-looking half of /batman-report. Reads only, writes nothing.
---

# Batman — plan

The morning question, not the evening one. `/batman-report` says where the week
went; this says where the day should go. Only run it when asked.

## 0. How far ahead

`/batman-plan [days]` — days ahead, **default 1**, today. `/batman-plan 7` plans
the week. Anything the user says in words counts as the argument: "the week" is
7, "the sprint" is whatever they say it is.

The horizon changes both ends:

- **1 day** — one pick, the first concrete step, the loops that block it. Things
  further out than tomorrow are noise; leave them out.
- **2–7 days** — the shape, not a schedule. Which projects get which days, what
  has to land before the rest can start, what is going to be dropped. Say the
  dropped part out loud; a week plan that fits everything is a week plan that
  was never true.
- **More than a week** — you're planning against `WHY.md`'s priority order, not
  against a todo list. Anything that far out only holds at the project level.

Look back as far as you look ahead, never less than 3 days — that number is the
lookback used in step 2. Planning a week off yesterday's hours is guessing.

## 1. Find the north star

Same precedence as the session hook: `WHY.md` in the working directory wins;
otherwise `$BATMAN_WHY`, otherwise `~/.claude/WHY.md`.

Read it **whole**, not the first twenty lines. The priority order, the "not the
work" list and the drift tells sit below the fold, and they are the half that
does the work here.

No `WHY.md` anywhere: say so, offer `/batman-why`, stop. Never invent a priority
order — a made-up one is worse than none, because it gets followed.

**`WHY.md` outranks everything below.** If it names its own sources, its own
order to check them, or how the user wants this to run, follow that instead of
the defaults. The defaults are for a `WHY.md` that says nothing about planning.

## 2. Gather — parallel, cheap, silent on failure

- **The lists `WHY.md` links.** Read them. Honour what it says each list *means*
  — a todo file of errands and a project kanban are not the same claim on the
  day, and treating them as one produces noise.
- **GitHub.** `gh issue list --assignee @me` and `gh pr list --author @me`, in
  the repos `WHY.md` names, else the current one. Skip without comment if `gh`
  is missing or unauthenticated.
- **Open loops.** `git status --short` and unpushed commits in the current repo
  and any repo path `WHY.md` names. A half-finished branch is a stronger claim
  on the morning than anything new.
- **Where the hours went.** `batman-report <lookback>` — the horizon from step 0,
  minimum 3. Bare name, no path: the plugin's `bin/` is on PATH. Do not spell it
  `${CLAUDE_PLUGIN_ROOT}/scripts/report.sh`; that variable is empty in the Bash
  tool's environment.
- **`batman-time --all`** only if `WHY.md` asks for it. ActivityWatch is
  per-machine and optional.
- **A week or more, either direction** (not a single day): add `batman-time` for
  desk hours transcripts miss, `/check-in` for hypercampus, and flag a stale
  kanban as wanting `/aggregate` first. A single day skips all three — the
  lists, open loops, `batman-report 3` are enough.

## 3. Say it — length follows the situation

**Clear morning** — the lists, the open loops and `WHY.md`'s order all point the
same way: keep it short. The pick, the first concrete step, one question. Don't
inflate an obvious answer into a briefing.

**Murky morning** — threads competing, or where the hours went disagrees with
what `WHY.md` says matters: dig. Name the competing threads and what each costs,
what the order says, which open loop blocks which, what has gone cold. Then one
question. The user picks.

Both shapes hold at any horizon: a clear week is still short, a murky day still
gets dug into. The horizon sets what's in scope, not how much you say.

Recommending is allowed here, and only here — the command was invoked to get an
opinion. Everywhere else Batman observes and does not prescribe.

## 4. Writes nothing

Read-only, like `/batman-report`. No file, no state, no dashboard. The one
exception is a `WHY.md` that explicitly authorizes a write (e.g. "add the pick
to my list") — and even then, only after the user agrees to the pick.
