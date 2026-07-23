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
export BATMAN_STATE="$TMP/state" BATMAN_CONF="$TMP/conf.json"
echo '{"minutes":60,"tokens":200000}' > "$BATMAN_CONF"
TP="$TMP/projects/proj-a/s.jsonl"
IN=$(jq -n --arg tp "$TP" '{session_id:"t1", cwd:"/home/u/proj-a", transcript_path:$tp}')

ERR=$(bash hooks/batman.sh check <<<"$IN" 2>&1 >/dev/null)
[ -z "$ERR" ] && ok "no stderr noise on first run" || no "stderr: $ERR"
rm -f "$TMP/state/t1.state"

OUT=$(bash hooks/batman.sh check <<<"$IN" | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "BATMAN:"     "check warns on a long session"
has "$OUT" "250k"        "context size reported"

OUT2=$(bash hooks/batman.sh check <<<"$IN")
[ -z "$OUT2" ] && ok "warns once, not every prompt" || no "warned twice"

# empty project with no WHY.md -> new-project nudge
mkdir -p "$TMP/fresh"
OUT=$(jq -n --arg c "$TMP/fresh" '{session_id:"t2",cwd:$c,transcript_path:""}' \
  | bash hooks/batman.sh session-start | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "batman-new" "empty project nudges the new-project ritual"

# a lived-in dir with no git (e.g. $HOME) is NOT a new project
mkdir -p "$TMP/lived-in"
touch "$TMP/lived-in"/f{1,2,3,4}
OUT=$(jq -n --arg c "$TMP/lived-in" '{session_id:"t4",cwd:$c,transcript_path:""}' \
  | bash hooks/batman.sh session-start | jq -r '.hookSpecificOutput.additionalContext')
case "$OUT" in *batman-new*) no "non-empty dir without git nudged the new-project ritual";;
  *) ok "non-empty dir without git is not a new project";; esac

printf '# Why test\nProblem: checking WHY.md is read.\n' > "$TMP/fresh/WHY.md"
OUT=$(jq -n --arg c "$TMP/fresh" '{session_id:"t3",cwd:$c,transcript_path:""}' \
  | bash hooks/batman.sh session-start | jq -r '.hookSpecificOutput.additionalContext')
has "$OUT" "north star" "WHY.md becomes the north star"

# jq missing / bad input must never break a session
echo 'not json' | bash hooks/batman.sh check >/dev/null 2>&1 && ok "garbage input exits clean" || no "garbage input broke the hook"

[ $FAIL -eq 0 ] && echo "all good" || exit 1
