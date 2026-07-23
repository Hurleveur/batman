---
name: batman-new
description: The ritual before a new project or a significant new feature — check whether it already exists, capture why it should exist, and write WHY.md. Use when starting a new repo, an empty directory, a fresh feature branch, or the SessionStart hook reports an uninitialized project. Also whenever the user proposes building something before it exists, in any phrasing — "new project", "let's build X", "should I build X", "can you make me a X", "is there a plugin/tool/script/library for X", "existing or new", "write a X that", "I need something that does X", "/batman-new". A question about whether X is possible is a build request; run the search half (step 1) even when the WHY.md half is overkill.
---

# Batman — new project

Three questions. Five minutes. Costs less than the weekend you'd lose.

Step 1 stands alone. Scratch work, a throwaway script, a directory that will never
be a project — run the search, skip 2 and 3. Never skip the search: it is the half
that saves the weekend.

## 1. Does it exist already?

Search before writing a line:
- `gh search repos "<idea>" --sort stars` and `gh search code`
- web search for the obvious name and the obvious phrasing
- the user's own repos (`ls` their GitHub dir, `gh repo list`)
- installed dependencies and skills — it may already be on the machine

Report the closest three matches in one line each, then a verdict:

```
USE IT     — <repo> does this. Install it and go.
FORK IT    — <repo> is 80% of it. Fork, change <thing>.
BUILD IT   — closest is <repo>, which doesn't do <thing>. That gap is real.
```

If the verdict is USE IT and the user builds anyway, that's their call — note it
in WHY.md and never raise it again.

## 2. Why does it exist, and write it down

Use the **batman-why** skill: it asks the two questions and writes `WHY.md`. Carry
the search result in with you — the closest match found above is the
`Already exists:` line, and it's the line that stops this getting rebuilt again in
six months.

That file is what Batman checks drift against for the life of the project. Keep it
current: when the answer changes, run batman-why again — a stale WHY.md is worse
than none.
