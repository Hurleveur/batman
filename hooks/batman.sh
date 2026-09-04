#!/usr/bin/env bash
# Batman hooks. Cheap, quiet, and never in the way.
#   session-start  <- SessionStart : the rules, WHY.md, new-project nudge
#   check          <- UserPromptSubmit : churn, repeated errors, active time, context size
#   pretooluse     <- PreToolUse(Bash) : catches `git init` at the moment it fires
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

# Signal 1, at the moment it matters instead of buried in the session-start banner.
# `git init` is the one unambiguous "starting a new project" signal a hook can see —
# a new file write is not (could be a test, a module in an existing project, anything).
# `ask` over `deny`: no attempt to detect whether a search already happened this
# session, that is a heuristic that will be wrong often enough to get snoozed and
# ignored. A search is always cheap to run right now, so just ask every time.
if [ "$MODE" = pretooluse ]; then
  CMD=$(jq -r '.tool_input.command // ""' <<<"$IN" 2>/dev/null)
  # Anchored on each segment's start, not a bare substring search — otherwise
  # `echo "run git init later"` trips it too.
  if echo "$CMD" | tr ';|' '\n' | sed -E 's/&&|\|\|/\n/g' \
      | grep -qE '^[[:space:]]*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+init([[:space:]]|$)'; then
    REASON="BATMAN: new git repo. Search first — GitHub, your own repos, installed deps, existing skills. State USE IT / FORK IT / BUILD IT, then continue. User overrules -> $SELF snooze 30"
    jq -n --arg r "$REASON" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"ask", permissionDecisionReason:$r}}'
  fi
  exit 0
fi

if [ "$MODE" = session-start ]; then
  # The rules ship here, in full. A banner that only names the mode changes
  # nothing: SKILL.md is never loaded unless someone calls the Skill tool, and
  # nobody does. Behaviour is only ever what this text says.
  CTX="BATMAN ACTIVE — watch on wasted time, not wasted code. Live every response this
session. Off only if user says \"batman off\".

Default silent. Signal trips -> ONE line, once, then drop. Never repeat a warning already
given, never nag across turns, never block work, never moralise.

1. ALREADY EXISTS. New tool, script, library? Search first: GitHub, user's own repos,
   installed deps, existing skills. Not stdlib — that is ponytail's rung; this is 'whole
   thing already shipped'. Verdict: USE IT / FORK IT / BUILD IT, plus what differs.
2. NOBODY ASKED. No requester and nothing breaks without it = cut. 'Would be nice' is
   not a requester.
3. WRONG HANDS. Say it BEFORE attempt one, not after five: visual fit ('make it look
   right', spacing, sizing), images/audio/video, testing with no runner (no browser,
   device or hardware = guessing), anything tuned by feel. Two attempts max, then hand
   back — always name the escape: the tool that makes it tractable, or 'you do this
   part, ninety seconds'.
4. STUCK. Three failed attempts at one thing, same file rewritten 3x, or same error 2x
   = stop. No fourth attempt on the same theory. Out loud: new hypothesis, timebox, or
   back out. Sunk cost is not a reason. Deleting the branch is respectable.
   Second shape, user side: they stopped steering. Briefs that opened long and specific
   collapsed into 'ok', 'go on'; they are no longer reacting to what you did. Name the
   observation once, stop there — 'you opened with a spec, last few are one-liners;
   still the right thread?' Do NOT prescribe a break, lighter scope, or a stopping
   point. What they do with it is theirs.
5. DRIFT. Opened on X, work now on unrelated Y: 'came here for X, still want X?' WHY.md
   where present is the north star — measure against it, not vibes.
6. WRONG PROJECT. Backward, 'where did my week go': /batman-report [days back, 7].
   Forward, 'what now' or a day with no stated target: /batman-plan [days ahead, 1].
   Only when the question is real — long session, new week. Never speculatively.

Hand off, don't duplicate: vague plan -> grill-me. Code too big -> ponytail. New or empty
project -> batman-new skill.

Sound like this, then stop talking:
  'Third attempt at the same selector. New theory or back out?'
  'That is chrono with fewer stars. Ten minutes reading beats two days rebuilding.'
  'You can't see the page. Neither can I. Open devtools, done in a minute.'

User overrules -> drop it immediately, no re-arguing, and run: $SELF snooze 30"
  if [ -f "$CWD/WHY.md" ]; then
    CTX="$CTX

This project's north star (WHY.md) — compare the work against it, not against vibes:
$(head -20 "$CWD/WHY.md")"
  else
    # No project WHY.md. Fall back to the standing one so signal 5 still has something
    # to measure drift against — most sessions run somewhere with no WHY.md, and $HOME
    # is where the aimless ones happen. A project file always wins; this is the floor,
    # never an override. Slightly longer head: the standing file carries a priority
    # order and its drift tells below the fold, which is the half that does the work.
    GLOBAL_WHY="${BATMAN_WHY:-$HOME/.claude/WHY.md}"
    if [ -f "$GLOBAL_WHY" ]; then
      CTX="$CTX

No WHY.md here, so the standing north star applies — compare the work against it, not
against vibes. It is broader than a project's, so use it for the 'is this the right
thing at all' question, not for line-level scope:
$(head -30 "$GLOBAL_WHY")"
    fi
    # New project = no git history AND a near-empty directory. Both, not either:
    # $HOME and other working dirs have no commits but plenty in them, and a
    # nudge that fires every session is a nudge nobody reads.
    if [ -n "$CWD" ] && [ -d "$CWD" ]; then
      commits=$(git -C "$CWD" rev-list --count HEAD 2>/dev/null || echo 0)
      files=$(find "$CWD" -maxdepth 1 -mindepth 1 ! -name '.*' 2>/dev/null | wc -l)
      if [ "$commits" -eq 0 ] && [ "$files" -le 2 ]; then
        CTX="$CTX

New or empty project, and no WHY.md. Before writing code, use the batman-new skill:
check whether this already exists, get the real reason out of the user, write WHY.md."
      fi
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

# Local midnight. Every clock below counts from here, so "today" means today.
MID=$(date -d 00:00 +%s 2>/dev/null || echo 0)

FACTS=$(jq -n -r -R --argjson mid "${MID:-0}" '
  [inputs | fromjson?] as $e
  | ($e | map(.timestamp // empty) | sort
     | map(sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) as $t
  | ($t | length) as $n
  # Active minutes since midnight, gaps capped at 5 min. Both bounds are load-bearing.
  # Wall-clock lies: a session resumed the next day reported "4287 minutes" after an
  # hour of work, and got ignored for it. A whole-file sum lies the same way, quieter —
  # a real transcript opened 16:09 the previous afternoon and picked up again the next
  # morning totalled 85 minutes, of which 43 belonged to the day being reported.
  | (if $n < 2 then 0 else
      ([range(1; $n)] | map(select($t[.] >= $mid)
        | ($t[.] - $t[.-1]) | if . > 300 then 300 else . end) | add) // 0
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
  # Steering: mean prompt length, first third vs last third. Typed prompts only —
  # hook injections start "<", the local-command wrapper starts "Caveat:", and both
  # would swamp the average with text the user never wrote.
  | ($e | map(select(.type == "user" and (.message.content | type) == "string")
      | .message.content
      | select(startswith("<") | not) | select(startswith("Caveat:") | not) | length)) as $L
  | ($L | length) as $ln
  | (if $ln >= 8 then ($ln / 3 | floor) else 0 end) as $k
  | (if $k > 0 then (($L[0:$k] | add) / $k | floor) else 0 end) as $early
  | (if $k > 0 then (($L[-$k:] | add) / $k | floor) else 0 end) as $late
  | [ ($active / 60 | floor), ($hot.k // "-"), ($hot.n // 0), ($err.k // "-"), ($err.n // 0),
      $early, $late ]
  | @tsv' "$TP" 2>/dev/null)
[ -n "$FACTS" ] || quiet
IFS=$'\t' read -r ACTIVE HOTF HOTN ERRK ERRN EARLY LATE <<<"$FACTS"
ACTIVE=${ACTIVE:-0}; HOTN=${HOTN:-0}; ERRN=${ERRN:-0}; EARLY=${EARLY:-0}; LATE=${LATE:-0}

# The clock, across today's sessions. $ACTIVE above is this transcript alone, so a day
# split over four sessions reads as four short ones — measured on a real one: 46 minutes
# in the open session, 92 across the four together. Same project directory, same jq,
# same midnight cutoff. Churn, errors and steering stay per-session on purpose: those are
# about this attempt, not the day. ponytail: one jq per sibling, ~0.13s for four. The
# mtime test only skips files cheaply — a transcript touched today but written yesterday
# still sums to zero, because the cutoff is applied to the timestamps, not the file.
SIBS=$(find "$(dirname "$TP")" -name '*.jsonl' -newermt "$(date +%Y-%m-%d)" ! -path "$TP" -print0 2>/dev/null \
  | while IFS= read -r -d '' f; do
      jq -n -r -R --argjson mid "${MID:-0}" '[inputs | fromjson?] as $e
        | ($e | map(.timestamp // empty) | sort
           | map(sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) as $t
        | ($t | length) as $n
        | (if $n < 2 then 0 else
            ([range(1; $n)] | map(select($t[.] >= $mid)
              | ($t[.] - $t[.-1]) | if . > 300 then 300 else . end) | add) // 0
          end)' "$f" 2>/dev/null
    done | awk '{s+=$1} END {printf "%d", s/60}')
SIBS=${SIBS:-0}
ACTIVE_ALL=$(( ACTIVE + SIBS ))

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
if [ "$ACTIVE_ALL" -ge $((FMIN + MINS_LIMIT)) ]; then
  FMIN=$(( ACTIVE_ALL / MINS_LIMIT * MINS_LIMIT ))
  # Name both numbers when they differ, session first: "23 this session" is the one
  # that feels true, the day total is the one that has been hiding behind it. Leading
  # with the day total instead reads as "you've been at this 101 minutes" when the
  # session itself just started — misleads at a glance.
  if [ "$SIBS" -gt 0 ]; then
    DRAG=" $ACTIVE active minutes in this session, $ACTIVE_ALL today."
  else
    DRAG=" $ACTIVE active minutes."
  fi
fi
if [ "$TOKS" -ge $((FTOK + TOKS_LIMIT)) ]; then
  FTOK=$(( TOKS / TOKS_LIMIT * TOKS_LIMIT ))
  DRAG="$DRAG $(( TOKS / 1000 ))k tokens of context."
fi
[ -n "$STUCK$DRAG" ] || quiet
echo "$FMIN $FTOK $FHOT $FERR" > "$STATE"

# Steering rides an emission that was already happening — never opens one. A collapse
# from a long opening brief to one-liners is also just a session converging, so alone it
# is not evidence; paired with a signal that already tripped it is. Measured over 27 real
# sessions: <40% fires in 3 of the 15 long ones, about one in five. A separate signal at
# that rate would be noise; an extra clause on a line already printing is free.
STEER_LIMIT=$(conf steering 40)
if [ "$EARLY" -gt 0 ] && [ "$((LATE * 100 / EARLY))" -lt "$STEER_LIMIT" ]; then
  DRAG="$DRAG Prompts opened ~$EARLY chars, latest third ~$LATE."
fi

# ActivityWatch, where it is running. Same deal as steering: rides an emission that was
# already happening, never opens one. $ACTIVE_ALL now covers the day, so only one blind
# spot is left, and it is the one no transcript can close: gaps are capped at 5 minutes
# because a hole in the timestamps is either an hour of hand-testing or an hour at lunch,
# and nothing in the file says which. An idle detector does. That is all this asks about
# — measured against the day's total, so it stays quiet unless there is real work off the
# transcript. Quiet too when aw-server is not running: it is per-machine, and ~/.claude
# syncs between boxes while ActivityWatch's data does not.
AW=$(conf aw "$(dirname "$SELF")/../bin/batman-time")
if [ -n "$CWD" ] && [ -x "$AW" ]; then
  DRAG="$DRAG$(timeout 5 "$AW" --hook "$CWD" "$ACTIVE_ALL" 2>/dev/null)"
fi

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
