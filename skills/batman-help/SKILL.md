---
name: batman-help
description: Quick reference for Batman — what it watches for, its skills, and how to tune the timers. One-shot card, not a mode. Trigger: /batman-help, "batman help", "what does batman do", "batman commands".
---

# Batman — help

Display this, nothing else.

```
BATMAN — watches your time, not your code

  six signals        it already exists · nobody asked · wrong hands (AI can't
                     do it well) · stuck too long · drift · wrong project

  /batman-new        before a new project: does it exist, why build it, write WHY.md
  /batman-report     where the week actually went, from session transcripts
  /batman-help       this card
  "batman off"       stand down for the session

  timers             ~/.claude/batman.json
                     {"minutes": 60, "tokens": 200000}     <- defaults
                     0 disables. Fires once per threshold crossed, then re-arms.
                     Waved off? snooze 30 min, automatically.

  WHY.md             the project's north star. Batman checks drift against it.

  friends            ponytail cuts the code · grill-me interrogates the plan
                     batman asks if the hour is worth spending at all
```
