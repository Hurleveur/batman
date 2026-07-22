#!/usr/bin/env bash
# Batman — where did the time actually go?
# Reads Claude Code session transcripts. Reads only; writes nothing.
# Usage: report.sh [days] [projects_dir]
set -euo pipefail

DAYS="${1:-7}"
ROOT="${2:-$HOME/.claude/projects}"

command -v jq >/dev/null || { echo "batman: needs jq (apt install jq)" >&2; exit 1; }
[ -d "$ROOT" ] || { echo "batman: no transcripts at $ROOT" >&2; exit 1; }

# Per session: project<TAB>active_seconds<TAB>prompts<TAB>hottest_file<TAB>times<TAB>repeated_error<TAB>times<TAB>date
scan() {
  jq -n -r -R '
    [inputs | fromjson? ] as $e
    | ($e | map(.timestamp // empty) | sort
       | map(sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) as $t
    | ($t | length) as $n
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
        | gsub("[\\t\\n]"; " ") | .[0:60])
       | group_by(.) | map({k: .[0], n: length}) | max_by(.n)) as $err
    | [ ($e | map(.cwd // empty) | last // "?"),
        ($active | floor),
        ($e | map(select(.type == "user" and (.message.content | type) == "string")) | length),
        ($hot.k // "-"), ($hot.n // 0),
        ($err.k // "-"), ($err.n // 0),
        ($t | first // 0 | strftime("%Y-%m-%d")) ]
    | @tsv' "$1" 2>/dev/null || true
}

DATA=$(find "$ROOT" -name '*.jsonl' -mtime "-$DAYS" -size +1k 2>/dev/null \
  | while read -r f; do scan "$f"; done)

[ -n "$DATA" ] || { echo "batman: nothing in the last $DAYS days."; exit 0; }

printf '\n  BATMAN — last %s days\n\n' "$DAYS"

echo "$DATA" | awk -F'\t' '
  { n = split($1, p, "/"); proj = p[n] ? p[n] : $1
    secs[proj] += $2; sess[proj]++; total += $2 }
  END {
    for (k in secs) printf "%d\t%s\t%d\n", secs[k], k, sess[k]
    printf "TOTAL\t%d\n", total
  }' | sort -rn | awk -F'\t' -v OFS='' '
  /^TOTAL/ { total = $2; next }
  { proj[++i] = $2; s[i] = $1; n[i] = $3 }
  END {
    for (j = 1; j <= i; j++) {
      pct = total ? int(s[j] * 100 / total) : 0
      printf "  %-22s %2dh%02dm  %2d session%s  %3d%%%s\n", proj[j], s[j]/3600, (s[j]%3600)/60, \
             n[j], (n[j] == 1 ? " " : "s"), pct, (j == 1 && pct >= 50 ? "  <- ate the week" : "")
    }
  }'

# Loudest signals only — a wall of warnings is the same as no warning.
ALL=$(echo "$DATA" | awk -F'\t' '
  { n = split($1, p, "/"); proj = p[n] ? p[n] : $1 }
  $5 >= 5 { m = split($4, q, "/"); printf "%d\t  %s: %s rewritten %dx in one session (%s)\n", $5, proj, q[m], $5, $8 }
  $7 >= 3 { printf "%d\t  %s: same error %dx — \"%s\" (%s)\n", $7, proj, $7, $6, $8 }
  $2 >= 7200 && $3 <= 3 { printf "%d\t  %s: %dh session, %d prompt(s) — long grind, little steering (%s)\n", 5, proj, $2/3600, $3, $8 }' \
  | sort -rn)

if [ -n "$ALL" ]; then
  N=$(wc -l <<<"$ALL")
  printf '\n  stuck signals\n%s\n' "$(head -5 <<<"$ALL" | cut -f2-)"
  [ "$N" -gt 5 ] && printf '  ... and %d more. Same story.\n' "$((N - 5))"
fi

printf '\n  Ask: was the top line the thing that mattered?\n\n'
