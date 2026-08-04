#!/usr/bin/env bash
# Batman self-check. No framework. Run: bash test/test.sh
set -uo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
# EXIT traps are inherited by $(...) subshells — only the top-level shell cleans up.
trap '[ "$$" = "$BASHPID" ] && rm -rf "$TMP"' EXIT
FAIL=0
ok() { echo "  ok   $1"; }
no() { echo "  FAIL $1"; FAIL=1; }
has() { grep -q -- "$2" <<<"$1" && ok "$3" || { no "$3"; echo "--- got ---"; echo "$1"; }; }

# --- fixture: one session, 40 min, a file rewritten 6x, same error 3x --------
mk() { # mk <dir> <cwd> <start_epoch> [basename]
  local d="$TMP/projects/$1"; mkdir -p "$d"; local f="$d/${4:-s}.jsonl" t=$3
  : > "$f"
  for i in $(seq 0 19); do
    ts=$(date -u -d "@$((t + i * 120))" +%Y-%m-%dT%H:%M:%S.000Z)
    printf '{"type":"user","cwd":"%s","timestamp":"%s","message":{"role":"user","content":"do the thing"}}\n' "$2" "$ts" >> "$f"
    printf '{"type":"assistant","cwd":"%s","timestamp":"%s","message":{"role":"assistant","usage":{"input_tokens":5,"cache_read_input_tokens":250000,"cache_creation_input_tokens":100},"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/p/hot.ts"}}]}}\n' "$2" "$ts" >> "$f"
    printf '{"type":"user","cwd":"%s","timestamp":"%s","message":{"role":"user","content":[{"type":"tool_result","is_error":true,"content":"TypeError: cannot read x"}]}}\n' "$2" "$ts" >> "$f"
  done
  # pad past the 1k size filter
  printf '{"type":"ai-title","aiTitle":"%s"}\n' "$(head -c 900 /dev/zero | tr '\0' 'x')" >> "$f"
}
# Today, deliberately: the hook's clock counts from midnight, so a fixture dated
# yesterday would make every clock assertion below pass by reading zero.
mk proj-a /home/u/proj-a "$(date +%s)"

OUT=$(bash scripts/report.sh 7 "$TMP/projects")
has "$OUT" "proj-a"            "report finds the project"
has "$OUT" "0h38m"             "active time counted (19 gaps x 120s, capped)"
has "$OUT" "hot.ts rewritten"  "churn signal fires"
has "$OUT" "same error"        "repeated-error signal fires"

OUT=$(bash scripts/report.sh 7 "$TMP/nope" 2>&1); [ $? -ne 0 ] || true
has "$OUT" "no transcripts"    "missing dir handled"

# A readable root whose subdirs aren't: find exits non-zero, and set -e used to kill
# the report with no output at all. Also the singular, now that /batman-report 1 is
# the documented evening run.
mkdir -p "$TMP/locked/inner"; : > "$TMP/locked/inner/x.jsonl"; chmod 000 "$TMP/locked/inner"
OUT=$(bash scripts/report.sh 1 "$TMP/locked" 2>&1); RC=$?
chmod 755 "$TMP/locked/inner"
has "$OUT" "nothing in the last 1 day." "unreadable subdir still reports, in the singular"
[ "$RC" -eq 0 ] && ok "empty result exits 0" || no "empty result exited $RC"

# --- hooks ------------------------------------------------------------------
# Points at nothing by default, so the standing-WHY fallback stays out of every other
# test — otherwise these would read the real ~/.claude/WHY.md and pass or fail on it.
export BATMAN_STATE="$TMP/state" BATMAN_CONF="$TMP/conf.json" BATMAN_WHY="$TMP/none.md"
echo '{"minutes":60,"tokens":200000}' > "$BATMAN_CONF"
TP="$TMP/projects/proj-a/s.jsonl"
IN=$(jq -n --arg tp "$TP" '{session_id:"t1", cwd:"/home/u/proj-a", transcript_path:$tp}')

ERR=$(bash hooks/batman.sh check <<<"$IN" 2>&1 >/dev/null)
[ -z "$ERR" ] && ok "no stderr noise on first run" || no "stderr: $ERR"
rm -f "$TMP/state/t1.state"

OUT=$(bash hooks/batman.sh check <<<"$IN" | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "BATMAN:"                  "check warns on a long session"
has "$OUT" "250k"                     "context size reported"
has "$OUT" "hot.ts written 20 times"  "the churn fact is named, not asked about"
has "$OUT" "Same error 20 times"      "the repeated error is quoted back"

case "$OUT" in *"Prompts opened"*) no "steering fired on uniform prompts";;
  *) ok "steady prompt length is not a steering collapse";; esac

OUT2=$(bash hooks/batman.sh check <<<"$IN")
[ -z "$OUT2" ] && ok "warns once, not every prompt" || no "warned twice"

# --- steering: long opening briefs, one-liners by the end -------------------
d="$TMP/projects/proj-b"; mkdir -p "$d"; f="$d/s.jsonl"; t=$(date +%s)
for i in $(seq 0 8); do
  ts=$(date -u -d "@$((t + i * 120))" +%Y-%m-%dT%H:%M:%S.000Z)
  # first third long, rest one-liners; the injections must be ignored, not averaged in
  if [ "$i" -lt 3 ]; then p=$(head -c 400 /dev/zero | tr '\0' 'q'); else p=ok; fi
  printf '{"type":"user","cwd":"/p","timestamp":"%s","message":{"role":"user","content":"%s"}}\n' "$ts" "$p" >> "$f"
  printf '{"type":"user","cwd":"/p","timestamp":"%s","message":{"role":"user","content":"<system-reminder>%s</system-reminder>"}}\n' "$ts" "$p" >> "$f"
done
printf '{"type":"ai-title","aiTitle":"%s"}\n' "$(head -c 900 /dev/zero | tr '\0' 'x')" >> "$f"
echo '{"minutes":1,"tokens":200000}' > "$BATMAN_CONF"
OUT=$(jq -n --arg tp "$f" '{session_id:"t5",cwd:"/p",transcript_path:$tp}' \
  | bash hooks/batman.sh check | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "Prompts opened ~400 chars, latest third ~2" "steering collapse is measured and named"
echo '{"minutes":60,"tokens":200000}' > "$BATMAN_CONF"

# --- the clock spans today's sessions ---------------------------------------
# Two transcripts, same project, 38 active minutes each. Per-session the limit is never
# crossed and Batman says nothing; across the day it is 76 and he should.
mk proj-x /home/u/proj-x "$(date +%s)" a
mk proj-x /home/u/proj-x "$(date +%s)" b
TPX="$TMP/projects/proj-x/a.jsonl"
OUT=$(jq -n --arg tp "$TPX" '{session_id:"t-x1", cwd:"/home/u/proj-x", transcript_path:$tp}' \
  | bash hooks/batman.sh check | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "76 active minutes on this today, 38 in this session" \
  "the clock counts today's other sessions, not just this one"

# One transcript alone keeps the original wording — nothing to disambiguate.
OUT=$(jq -n --arg tp "$TP" '{session_id:"t-x2", cwd:"/home/u/proj-a", transcript_path:$tp}' \
  | bash hooks/batman.sh check | jq -r '.hookSpecificOutput.additionalContext')
grep -q "in this session" <<<"$OUT" && no "a lone session is not dressed up as a day" \
  || ok "a lone session is not dressed up as a day"

# --- yesterday's minutes are not today's ------------------------------------
# The file filter is mtime, which says "touched today". The sum is timestamps, which
# say "worked today". Reading the first as the second charged a real morning with the
# 42 minutes of the previous afternoon, because the session had merely been resumed.
# `old` is written now, so it passes the mtime filter exactly as a resumed session does.
mk proj-y /home/u/proj-y "$(date -d '1 day ago' +%s)" old
mk proj-y /home/u/proj-y "$(date +%s)" new
echo '{"minutes":1,"tokens":200000}' > "$BATMAN_CONF"
OUT=$(jq -n --arg tp "$TMP/projects/proj-y/new.jsonl" \
    '{session_id:"t-y1", cwd:"/home/u/proj-y", transcript_path:$tp}' \
  | bash hooks/batman.sh check | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "38 active minutes" "a transcript touched today but written yesterday counts zero"
case "$OUT" in *"76 active"*) no "yesterday's session is not summed into today";;
  *) ok "yesterday's session is not summed into today";; esac

# The same file as the open session: its own yesterday minutes drop out too.
OUT=$(jq -n --arg tp "$TMP/projects/proj-y/old.jsonl" \
    '{session_id:"t-y2", cwd:"/home/u/proj-y", transcript_path:$tp}' \
  | bash hooks/batman.sh check | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "0 in this session" "an overnight session contributes only its today half"
echo '{"minutes":60,"tokens":200000}' > "$BATMAN_CONF"

# --- bare-name entry points -------------------------------------------------
# ${CLAUDE_PLUGIN_ROOT} is empty outside hooks.json, so skills call these by name.
OUT=$(bin/batman-report 7 "$TMP/projects" 2>&1)
has "$OUT" "proj-a"  "batman-report runs without CLAUDE_PLUGIN_ROOT"
echo "60 0 0 0" > "$TMP/state/t-snooze.state"
bin/batman-snooze 45 >/dev/null 2>&1
read -r SNZ _ < "$TMP/state/t-snooze.state"
[ "$SNZ" = 105 ] && ok "batman-snooze pushes the floor out" \
  || no "batman-snooze pushes the floor out (got $SNZ, want 105)"

# --- ActivityWatch clause ---------------------------------------------------
# Stubbed, because the real one needs aw-server and this suite must run anywhere.
# What is under test is the wiring: that it rides the warning instead of opening a
# line of its own, and that a missing script changes nothing.
printf '#!/bin/sh\necho " 130 active minutes on proj-a today across all sessions (ActivityWatch)."\n' > "$TMP/aw.sh"
chmod +x "$TMP/aw.sh"
echo "{\"minutes\":60,\"tokens\":200000,\"aw\":\"$TMP/aw.sh\"}" > "$BATMAN_CONF"
OUT=$(jq -n --arg tp "$TP" '{session_id:"t-aw1", cwd:"/home/u/proj-a", transcript_path:$tp}' \
  | bash hooks/batman.sh check | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "130 active minutes on proj-a" "activitywatch clause rides the warning"
has "$OUT" "signal 4, stuck"              "it appends to the stuck line, never replaces it"
[ "$(jq -n --arg tp "$TP" '{session_id:"t-aw1b", cwd:"/home/u/proj-a", transcript_path:$tp}' \
    | bash hooks/batman.sh check | jq -r '.hookSpecificOutput.additionalContext' \
    | grep -c "ActivityWatch")" = 1 ] \
  && ok "clause appears once, not once per signal" || no "clause appears once, not once per signal"

echo '{"minutes":60,"tokens":200000,"aw":"/nope/not-here"}' > "$BATMAN_CONF"
OUT=$(jq -n --arg tp "$TP" '{session_id:"t-aw2", cwd:"/home/u/proj-a", transcript_path:$tp}' \
  | bash hooks/batman.sh check | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "tokens of context"  "missing activitywatch script leaves the warning intact"
grep -q "ActivityWatch" <<<"$OUT" && no "silent when the script is absent" || ok "silent when the script is absent"

if command -v python3 >/dev/null; then
  OUT=$(bin/batman-time --selftest 2>&1)
  has "$OUT" "selftest ok" "batman-time interval math self-checks"
else
  ok "batman-time selftest skipped (no python3)"
fi
echo '{"minutes":60,"tokens":200000}' > "$BATMAN_CONF"

# empty project with no WHY.md -> new-project nudge
mkdir -p "$TMP/fresh"
OUT=$(jq -n --arg c "$TMP/fresh" '{session_id:"t2",cwd:$c,transcript_path:""}' \
  | bash hooks/batman.sh session-start | jq -r '.hookSpecificOutput.additionalContext')
# grep the nudge's own words: the always-on rules mention batman-new too
has "$OUT" "Before writing code" "empty project nudges the new-project ritual"
has "$OUT" "1. ALREADY EXISTS"   "the rules ship with the session, not just a banner"

# a lived-in dir with no git (e.g. $HOME) is NOT a new project
mkdir -p "$TMP/lived-in"
touch "$TMP/lived-in"/f{1,2,3,4}
OUT=$(jq -n --arg c "$TMP/lived-in" '{session_id:"t4",cwd:$c,transcript_path:""}' \
  | bash hooks/batman.sh session-start | jq -r '.hookSpecificOutput.additionalContext')
case "$OUT" in *"Before writing code"*) no "non-empty dir without git nudged the new-project ritual";;
  *) ok "non-empty dir without git is not a new project";; esac

# --- standing WHY.md: the floor when the project has none -------------------
printf '# Why standing\nProblem: the plumbing is not the work.\n' > "$TMP/standing.md"
OUT=$(BATMAN_WHY="$TMP/standing.md" jq -n --arg c "$TMP/lived-in" \
  '{session_id:"t6",cwd:$c,transcript_path:""}' \
  | BATMAN_WHY="$TMP/standing.md" bash hooks/batman.sh session-start \
  | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "the plumbing is not the work" "standing WHY.md applies where a project has none"

OUT=$(jq -n --arg c "$TMP/lived-in" '{session_id:"t7",cwd:$c,transcript_path:""}' \
  | bash hooks/batman.sh session-start | jq -r '.hookSpecificOutput.additionalContext')
# "north star" alone would match signal 5 in the always-on rules; match the block.
case "$OUT" in *"the standing north star applies"*|*"This project's north star"*)
    no "claimed a north star with no WHY.md anywhere";;
  *) ok "no WHY.md anywhere is silent, not invented";; esac

printf '# Why test\nProblem: checking WHY.md is read.\n' > "$TMP/fresh/WHY.md"
OUT=$(jq -n --arg c "$TMP/fresh" '{session_id:"t3",cwd:$c,transcript_path:""}' \
  | BATMAN_WHY="$TMP/standing.md" bash hooks/batman.sh session-start \
  | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "north star" "WHY.md becomes the north star"
case "$OUT" in *"the plumbing is not the work"*) no "standing WHY overrode the project's";;
  *) ok "a project WHY.md wins over the standing one";; esac

# jq missing / bad input must never break a session
echo 'not json' | bash hooks/batman.sh check >/dev/null 2>&1 && ok "garbage input exits clean" || no "garbage input broke the hook"

[ $FAIL -eq 0 ] && echo "all good" || exit 1
