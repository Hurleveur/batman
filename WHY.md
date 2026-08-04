# Why batman

**Problem:** The expensive mistakes aren't bad code — they're hours spent on the
wrong project, a feature nobody asked for, a bug attacked five times with the
same failed theory, or a job an AI was never going to do well (nudging text it
can't see). Nothing in the tooling notices.

**For:** Me first, then anyone who has lost a weekend the same way.

**Done looks like:** An always-on skill that stays silent, plus two cheap hooks
that ask one rude question when a session runs long — a report that shows where
the week actually went, and, facing the other way, a plan that reads WHY.md and
the lists it links to answer what the day should hold.

**Already exists:** [scope-guard](https://github.com/atoolz/scope-guard) catches
the *agent* editing files outside the prompt. ponytail cuts code size. grill-me
interrogates a plan. None of them ask whether the hour is worth spending.

**Explicitly not doing:** Blocking tool calls, a persistent time-tracking
database, a dashboard, or re-implementing grill-me's interrogation.

**Open direction (2026-08-04):** the report only ever reads Claude Code
transcripts plus ActivityWatch's terminal-window bucket — both blind to
anything that happened off the keyboard. Alexandre asked for the report to
dig further: situate a session against what he actually did, including time
spent watching videos, not just active-minute totals. ActivityWatch already
has a browser watcher and a web-history bucket; reading those is not a new
persistent database, just a wider read of one that already exists — but it
is a direct reversal of `batman-time`'s current, deliberate terminal-only
scoping ("Adding a GUI editor here also starts exposing its window titles"),
chosen for privacy. Whoever picks this up has to resolve that tension first
— which titles/domains are fair game, whether video app names get logged at
all — not just wire up the extra bucket.

Started 2026-07-22.
