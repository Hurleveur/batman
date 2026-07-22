---
name: batman-report
description: Show where time actually went across projects, from Claude Code session transcripts — hours per project, sessions, and stuck signals (files rewritten many times, the same error hit repeatedly, long grinds with little steering). Use when the user asks "where did my week go", "am I working on the right thing", "/batman-report", or during a retro. Reads only, writes nothing.
---

# Batman — report

Run it:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/report.sh 7    # days, default 7
```

Then read it back in **three lines, maximum**:

1. Where the time went, and whether the top project is the one that mattered.
   If `WHY.md` exists in the top project, check the work against it.
2. The loudest stuck signal, if any — a file rewritten nine times or the same
   error four times means an approach that never worked and never got dropped.
3. One question, not a lecture. "Was that the week you wanted?" beats a plan.

Don't run it unprompted, don't run it twice in a session, don't turn the numbers
into a dashboard. It reads transcripts only — no tracking, no state, nothing
written anywhere.
