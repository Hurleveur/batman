#!/usr/bin/env bash
# Batman hooks. Cheap, quiet, and never in the way.
#   session-start  <- SessionStart : mode banner, WHY.md, new-project nudge
#   check          <- UserPromptSubmit : has this run too long / too big
#   snooze [min]   <- called by the skill when you overrule Batman
# Fails silent on purpose: a watchman that breaks your session is worse than none.
set -uo pipefail

STATE_DIR="${BATMAN_STATE:-$HOME/.claude/batman}"
CONF="${BATMAN_CONF:-$HOME/.claude/batman.json}"
MODE="${1:-check}"

emit() { # emit <hookEventName> <context>
  jq -n --arg e "$1" --arg c "$2" \
    '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}' 2>/dev/null
  exit 0
}
quiet() { exit 0; }

command -v jq >/dev/null || quiet
mkdir -p "$STATE_DIR" 2>/dev/null

conf() { # conf <key> <default>
  local v; v=$(jq -r --arg k "$1" '.[$k] // empty' "$CONF" 2>/dev/null)
  [ -n "$v" ] && echo "$v" || echo "$2"
}

# snooze doesn't read stdin
if [ "$MODE" = snooze ]; then
  for f in "$STATE_DIR"/*.state; do
    [ -f "$f" ] || continue
    read -r fmin ftok < "$f" 2>/dev/null || continue
    echo "$((fmin + ${2:-30})) $ftok" > "$f"
  done
  exit 0
fi

IN=$(cat)
CWD=$(jq -r '.cwd // ""' <<<"$IN" 2>/dev/null)
SID=$(jq -r '.session_id // "x"' <<<"$IN" 2>/dev/null)
TP=$(jq -r '.transcript_path // ""' <<<"$IN" 2>/dev/null)
STATE="$STATE_DIR/$SID.state"

if [ "$MODE" = session-start ]; then
  CTX="BATMAN ACTIVE — watching for wasted time, not wasted code. Silent unless something trips."
  if [ -f "$CWD/WHY.md" ]; then
    CTX="$CTX

This project's north star (WHY.md) — compare the work against it, not against vibes:
$(head -20 "$CWD/WHY.md")"
  elif [ -n "$CWD" ] && [ -d "$CWD" ]; then
    # New project = no git history AND a near-empty directory. Both, not either:
    # $HOME and other working dirs have no commits but plenty in them, and a
    # nudge that fires every session is a nudge nobody reads.
    commits=$(git -C "$CWD" rev-list --count HEAD 2>/dev/null || echo 0)
    files=$(find "$CWD" -maxdepth 1 -mindepth 1 ! -name '.*' 2>/dev/null | wc -l)
    if [ "$commits" -eq 0 ] && [ "$files" -le 2 ]; then
      CTX="$CTX

New or empty project, and no WHY.md. Before writing code, use the batman-new skill:
check whether this already exists, get the real reason out of the user, write WHY.md."
    fi
  fi
  emit SessionStart "$CTX"
fi

# ---- check: elapsed time + context size -----------------------------------
[ -f "$TP" ] || quiet
MINS_LIMIT=$(conf minutes 60)
TOKS_LIMIT=$(conf tokens 200000)
[ "$MINS_LIMIT" -gt 0 ] 2>/dev/null || quiet

FIRST=$(head -300 "$TP" 2>/dev/null | jq -r 'select(.timestamp) | .timestamp' 2>/dev/null | head -1)
[ -n "$FIRST" ] || quiet
START=$(date -d "$FIRST" +%s 2>/dev/null) || quiet
ELAPSED=$(( ( $(date +%s) - START ) / 60 ))

TOKS=$(tail -80 "$TP" 2>/dev/null | jq -r 'select(.type=="assistant") | .message.usage
  | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' 2>/dev/null \
  | sort -rn | head -1)
TOKS=${TOKS:-0}

FMIN=0; FTOK=0
[ -f "$STATE" ] && read -r FMIN FTOK < "$STATE"
FMIN=${FMIN:-0}; FTOK=${FTOK:-0}
WARN=""

if [ "$ELAPSED" -ge $((FMIN + MINS_LIMIT)) ]; then
  FMIN=$(( ELAPSED / MINS_LIMIT * MINS_LIMIT ))
  WARN="${ELAPSED} minutes in this session."
fi
if [ "$TOKS" -ge $((FTOK + TOKS_LIMIT)) ]; then
  FTOK=$(( TOKS / TOKS_LIMIT * TOKS_LIMIT ))
  WARN="$WARN $(( TOKS / 1000 ))k tokens of context."
fi
[ -n "$WARN" ] || quiet
echo "$FMIN $FTOK" > "$STATE"

emit UserPromptSubmit "BATMAN:$WARN Long runs are where the wrong work hides. In ONE line, before
answering: is this still the thing that matters (check WHY.md if present), and has any
approach now failed three times? If yes, say so and offer the exit — new theory, timebox,
hand it to the user, or back out. If the work is on track, say nothing about this at all.
If the user waves you off, run: \${CLAUDE_PLUGIN_ROOT}/hooks/batman.sh snooze 30"
