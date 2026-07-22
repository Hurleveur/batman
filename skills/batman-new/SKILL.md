---
name: batman-new
description: The ritual before a new project or a significant new feature — check whether it already exists, capture why it should exist, and write WHY.md. Use when starting a new repo, an empty directory, a fresh feature branch, or when the user says "new project", "let's build X", "/batman-why", or the SessionStart hook reports an uninitialized project.
---

# Batman — new project

Three questions. Five minutes. Costs less than the weekend you'd lose.

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

## 2. Why does it exist?

Ask the user, plainly. Don't accept the first answer if it's a restatement of the
idea ("a plugin that tracks time" is *what*, not *why*).

- Who hits this problem? You, a team, strangers?
- What happens if it never gets built?
- What does done look like — the smallest version that's already useful?

Two rounds of this, max. **Deeper interrogation belongs to grill-me** — if the
plan is fuzzy or the user wants a real beating, hand off to that skill and let it
work. Batman is the door, not the interrogation room.

## 3. Write it down

Create `WHY.md` at the project root. Short — if it's over 20 lines it's a design
doc, not a north star:

```markdown
# Why <project>

**Problem:** <one sentence, in the user's words>
**For:** <who>
**Done looks like:** <smallest useful version>
**Already exists:** <closest thing found, and why it isn't enough>
**Explicitly not doing:** <the tempting thing that isn't the point>

Started <YYYY-MM-DD>.
```

That file is what Batman checks drift against for the life of the project. Keep
it current: when the answer changes, edit it — a stale WHY.md is worse than none.

If the user won't answer, don't invent one. Write `WHY.md` with the problem line
only and move on. Half a north star still beats none.
