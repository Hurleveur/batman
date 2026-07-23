---
name: batman-why
description: Write or refresh a project's WHY.md — the north star Batman measures drift against. Drafts it from the README, git log, and what the user already said, then asks them to correct it rather than starting from a blank page. Use for a project that already exists and has no WHY.md, or when the stated reason has changed and the file is stale, or when the user says "/batman-why", "write a WHY", "what's the why here", "why does this project exist", "update WHY.md". For a project that does not exist yet, use batman-new instead — it does the does-this-already-exist search first, then lands here.
---

# Batman — why

The file exists so drift has something to be measured against. No search, no
verdict — that's batman-new. Twenty lines, and never a blank page.

## 1. Draft it before asking anything

Correcting a wrong guess takes a user ten seconds; answering "so why does this
exist?" cold takes ten minutes and usually gets a restatement of *what* it is.
So draft first, from whatever is already lying around:

- what the user said in this conversation — their words beat your paraphrase
- `README.md`, the repo description, package manifest description
- `git log --oneline -20`, open issues, TODOs
- for a brand-new project: the request that started it, and batman-new's verdict

Fill every line you can, mark the rest `<?>`. Never invent a `Problem:` — if
nothing in the repo says why it exists, that line stays `<?>` and is exactly what
you ask about.

## 2. Show it and ask two things

Put the draft in chat, then:

> That the why? Anything to add or cut?

Then, at most two questions, and only for the `<?>` lines — the ones that
change the file:

- Who hits this problem? You, a team, strangers?
- What happens if it dies today?
- What does done look like — the smallest version that's already useful?

Two rounds, max. **Deeper interrogation belongs to grill-me** — hand off if the
plan is fuzzy or the user wants a real beating. Batman is the door, not the
interrogation room.

## 3. Write it

`WHY.md` at the project root. Over 20 lines means it's a design doc, not a north
star — cut it:

```markdown
# Why <project>

**Problem:** <one sentence, in the user's words>
**For:** <who>
**Done looks like:** <smallest useful version>
**Already exists:** <closest thing found, and why it isn't enough>
**Explicitly not doing:** <the tempting thing that isn't the point>

Started <YYYY-MM-DD>.
```

No `WHY.md` yet? Write it as soon as the user says the draft is close enough —
it's eight lines, editing it later is free. One already there? That's a rewrite of
someone's stated reason: show the changed lines and get a yes before touching it.
Edit in place, keep the original `Started` date. North star, not a changelog —
replace the wrong lines, don't append to them.

If the user won't answer, don't invent one. Write the draft as it stands, `<?>`
and all. Half a north star still beats none, and a visible `<?>` is a question
that gets answered the next time someone opens the file.
