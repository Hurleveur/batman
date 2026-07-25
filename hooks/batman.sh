#!/usr/bin/env bash
# Batman hooks. Cheap, quiet, and never in the way.
#   session-start  <- SessionStart : the rules, WHY.md, new-project nudge
#   check          <- UserPromptSubmit : churn, repeated errors, active time, context size
#   snooze [min]   <- called by the skill when you overrule Batman
# Fails silent on purpose: a watchman that breaks your session is worse than none.
set -uo pipefail

STATE_DIR="${BATMAN_STATE:-$HOME/.claude/batman}"
CONF="${BATMAN_CONF:-$HOME/.claude/batman.json}"
MODE="${1:-check}"
SELF=$(readlink -f "$0" 2>/dev/null || echo "$0")

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
  # The rules ship here, in full. A banner that only names the mode changes
  # nothing: SKILL.md is never loaded unless someone calls the Skill tool, and
  # nobody does. Behaviour is only ever what this text says.
  CTX="BATMAN ACTIVE — a watch on wasted time, not wasted code. These rules are live for
every response this session. Off only if the user says \"batman off\".

Default is silence. When a signal below trips, say ONE line, once, then drop it. Never
repeat a warning already given, never nag across turns, never block the work, never moralise.

1. ALREADY EXISTS. New tool, script, or library? Search first — GitHub, the user's own
   repos, installed deps, existing skills. Not stdlib, that's ponytail's rung; this is
   'the whole thing already shipped'. Give a verdict: USE IT / FORK IT / BUILD IT, and
   what is actually different.
2. NOBODY ASKED. No requester, and nothing breaks without it = cut it. 'It'd be nice'
   is not a requester.
3. WRONG HANDS. Say it BEFORE the first attempt, not after the fifth: visual fit ('make
   it look right', spacing, sizing), images/audio/video, testing with no runner (no
   browser, device, or hardware = guessing), anything tuned by feel. Two attempts max,
   then hand it back — and always name the escape: the tool that makes it tractable, or
   'you do this part, it'll take you ninety seconds'.
4. STUCK. Three failed attempts at one thing, the same file rewritten three times, or
   the same error twice = stop. No fourth attempt on the same theory. Out loud: new
   hypothesis, timebox, or back out. Sunk cost is not a reason. Deleting the branch is
   a respectable outcome.
5. DRIFT. Session opened on X, work is now on unrelated Y: 'came here for X, still want
   X?' WHY.md, where present, is the north star — compare against it, not against vibes.
6. WRONG PROJECT. Run /batman-report when the question is real (a long session, a new
   week, a 'where did my week go') — never speculatively.

Hand off rather than duplicate: vague plan -> grill-me. Code too big -> ponytail. New or
empty project -> batman-new skill.

Sound like this, then stop talking:
  'Third attempt at the same selector. New theory or back out?'
  'That's chrono with fewer stars. Ten minutes reading it beats two days rebuilding it.'
  'You can't see the page. Neither can I. Open devtools, drag it, done in a minute.'

User overrules -> drop it immediately, no re-arguing, and run: $SELF snooze 30"
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

# ---- check: churn, repeated errors, active time, context size --------------
# Facts, not introspection. "Have you failed three times?" is a question the model
# answers with silence because answering it costs a transcript scan. "sync.ts written
# 12 times" is a fact it has to deal with. One jq pass, ~0.1s on a 4MB transcript.
[ -f "$TP" ] || quiet
MINS_LIMIT=$(conf minutes 60)
TOKS_LIMIT=$(conf tokens 200000)
# The skill tells the model to notice three rewrites itself. The hook is the backstop
# and needs a higher bar: across 88 real sessions, 5 rewrites fired in a third of them,
# 8 in a sixth. A warning that fires every third session is wallpaper.
HOT_LIMIT=$(conf rewrites 8)
ERR_LIMIT=$(conf errors 3)
[ "$MINS_LIMIT" -gt 0 ] 2>/dev/null || quiet

FACTS=$(jq -n -r -R '
  [inputs | fromjson?] as $e
  | ($e | map(.timestamp // empty) | sort
     | map(sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) as $t
  | ($t | length) as $n
  # Active minutes, gaps capped at 5 min. Wall-clock lies: a session resumed the next
  # day reported "4287 minutes" after an hour of work, and got ignored for it.
  | (if $n < 2 then 0 else
      [range(1; $n)] | map(($t[.] - $t[.-1]) | if . > 300 then 300 else . end) | add
    end) as $active
  | ($e | map(select(.type == "assistant") | .message.content[]?
      | select(.type == "tool_use" and (.name | test("^(Edit|Write|NotebookEdit)$")))
      | .input.file_path // empty)
     | group_by(.) | map({k: .[0], n: length}) | max_by(.n)) as $hot
  | ($e | map(select(.type == "user") | .message.content[]?
      | select(type == "object" and .type == "tool_result" and .is_error == true)
      | (if (.content | type) == "string" then .content else (.content[0].text? // "") end)
      | gsub("[\\t\\n\"]"; " ") | .[0:60])
     | group_by(.) | map({k: .[0], n: length}) | max_by(.n)) as $err
  | [ ($active / 60 | floor), ($hot.k // "-"), ($hot.n // 0), ($err.k // "-"), ($err.n // 0) ]
  | @tsv' "$TP" 2>/dev/null)
[ -n "$FACTS" ] || quiet
IFS=$'\t' read -r ACTIVE HOTF HOTN ERRK ERRN <<<"$FACTS"
ACTIVE=${ACTIVE:-0}; HOTN=${HOTN:-0}; ERRN=${ERRN:-0}

TOKS=$(tail -80 "$TP" 2>/dev/null | jq -r 'select(.type=="assistant") | .message.usage
  | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' 2>/dev/null \
  | sort -rn | head -1)
TOKS=${TOKS:-0}

# Floors, so each signal warns once per threshold crossed, not once per prompt.
FMIN=0; FTOK=0; FHOT=0; FERR=0
[ -f "$STATE" ] && read -r FMIN FTOK FHOT FERR < "$STATE"
FMIN=${FMIN:-0}; FTOK=${FTOK:-0}; FHOT=${FHOT:-0}; FERR=${FERR:-0}
STUCK=""; DRAG=""

if [ "$HOTN" -ge $((FHOT + HOT_LIMIT)) ]; then
  FHOT=$HOTN
  STUCK=" ${HOTF##*/} written $HOTN times this session."
fi
if [ "$ERRN" -ge $((FERR + ERR_LIMIT)) ]; then
  FERR=$ERRN
  STUCK="$STUCK Same error $ERRN times: \"$ERRK\"."
fi
if [ "$ACTIVE" -ge $((FMIN + MINS_LIMIT)) ]; then
  FMIN=$(( ACTIVE / MINS_LIMIT * MINS_LIMIT ))
  DRAG=" $ACTIVE active minutes."
fi
if [ "$TOKS" -ge $((FTOK + TOKS_LIMIT)) ]; then
  FTOK=$(( TOKS / TOKS_LIMIT * TOKS_LIMIT ))
  DRAG="$DRAG $(( TOKS / 1000 ))k tokens of context."
fi
[ -n "$STUCK$DRAG" ] || quiet
echo "$FMIN $FTOK $FHOT $FERR" > "$STATE"

# Churn outranks the clock: it is evidence, the clock is only a prior.
if [ -n "$STUCK" ]; then
  emit UserPromptSubmit "BATMAN:$STUCK$DRAG That is signal 4, stuck — measured from this
session's transcript, not a hunch. Before answering, in ONE line: state a new hypothesis,
timebox it, or back out — and say which one. No fourth attempt on the same theory. Then
answer. If the user waves you off, run: $SELF snooze 30"
fi

emit UserPromptSubmit "BATMAN:$DRAG Long runs are where the wrong work hides. Before
answering, in ONE line: what is done, what is left, and is this still the thing that
matters (WHY.md if present)? If it is not, say so and offer the exit — new theory,
timebox, hand it back, or drop it. Then answer the actual question. If the user waves
you off, run: $SELF snooze 30"
