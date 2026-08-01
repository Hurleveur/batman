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
mk() { # mk <dir> <cwd> <start_epoch>
  local d="$TMP/projects/$1"; mkdir -p "$d"; local f="$d/s.jsonl" t=$3
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
mk proj-a /home/u/proj-a "$(date -d '1 day ago' +%s)"

OUT=$(bash scripts/report.sh 7 "$TMP/projects")
has "$OUT" "proj-a"            "report finds the project"
has "$OUT" "0h38m"             "active time counted (19 gaps x 120s, capped)"
has "$OUT" "hot.ts rewritten"  "churn signal fires"
has "$OUT" "same error"        "repeated-error signal fires"

OUT=$(bash scripts/report.sh 7 "$TMP/nope" 2>&1); [ $? -ne 0 ] || true
has "$OUT" "no transcripts"    "missing dir handled"

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
d="$TMP/projects/proj-b"; mkdir -p "$d"; f="$d/s.jsonl"; t=$(date -d '1 day ago' +%s)
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
