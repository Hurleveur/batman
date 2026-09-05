"""Shared plumbing for memoryfield-index and memoryfield-search.

Implements https://calpaterson.com/memoryfields.html for Claude Code's own memory
notes: the Markdown on disk stays the only truth, and this module is what turns it
into an embedding a query can be ranked against.
"""
import json
import os
import urllib.request


def embed(text):
    """Embed `text` via the Ollama-compatible API at $OLLAMA_URL (default localhost)."""
    url = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/") + "/api/embed"
    req = urllib.request.Request(
        url,
        data=json.dumps({"model": "nomic-embed-text", "input": text}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)["embeddings"][0]


def parse_frontmatter(text):
    """Return (name, description, body) from a note's leading `---` frontmatter block.

    Only top-level (unindented) keys are read — `metadata:` nests `type` and friends
    under it, and those aren't part of what gets embedded or reported here.
    """
    if not text.startswith("---\n"):
        return None, None, text
    end = text.find("\n---", 4)
    if end == -1:
        return None, None, text
    head = text[4:end]
    body = text[end + 4:].lstrip("\n")
    name = description = None
    for line in head.splitlines():
        if line[:1] in (" ", "\t"):
            continue
        if line.startswith("name:"):
            name = line.split(":", 1)[1].strip()
        elif line.startswith("description:"):
            description = line.split(":", 1)[1].strip()
    return name, description, body


def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = sum(x * x for x in a) ** 0.5
    nb = sum(x * x for x in b) ** 0.5
    return dot / (na * nb) if na and nb else 0.0


def index_path():
    """Where the cache lives — never under ~/.claude, which Syncthing can rewrite
    out from under a running process mid-write, silently orphaning the write."""
    cache_home = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
    return os.path.join(cache_home, "memoryfield", "index.sqlite3")
