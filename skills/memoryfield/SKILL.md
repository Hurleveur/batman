---
name: memoryfield
description: Semantic search over Claude Code's memory notes (~/.claude/projects/*/memory/*.md), instead of hand-maintained MEMORY.md indexes. Use when asked to find a past memory/note by meaning rather than by project or filename — "did we hit this before", "what do we know about X across projects" — or to build/rebuild the search index.
---

# memoryfield

Implements [memoryfields](https://calpaterson.com/memoryfields.html) for the memory
notes under `~/.claude/projects/*/memory/`: the notes stay plain Markdown, and
finding one becomes semantic search instead of reading every `MEMORY.md`.

The Markdown is the only truth. The SQLite index is a disposable cache built from
it — never the other way around, and never edited by hand.

## Rebuild the index

```bash
memoryfield-index ~/.claude/projects
```

Walks every `<project>/memory/*.md` (skipping each project's own `MEMORY.md`,
which is a hand-maintained pointer file, not a note), embeds each note's
frontmatter `description:` plus its body, and writes path, project, name,
description, mtime and embedding into one file at
`$XDG_CACHE_HOME/memoryfield/index.sqlite3` (`~/.cache/memoryfield` by default).

Never `~/.claude` — that tree is Syncthing-synced, and a live SQLite file there
can be swapped out from under a running process mid-write. Always a full rebuild:
run it again any time the notes have moved on, there's no incremental mode to
fall out of sync with the files.

Needs an embedding model reachable at `$OLLAMA_URL` (default
`http://127.0.0.1:11434`), model `nomic-embed-text`.

## Search

```bash
memoryfield-search "<query>" [top-n]
```

Embeds the query the same way, ranks the index by cosine similarity, prints one
line per hit — `<score> <path>`, best first, top 10 by default.

Bare names, no path: the plugin's `bin/` is on `PATH`. Don't spell
`${CLAUDE_PLUGIN_ROOT}/bin/memoryfield-search` — that variable is empty in the
Bash tool's environment.

If the index is missing or stale, run `memoryfield-index` first — search doesn't
build it for you.
