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
    # sort_by, not max_by: a session can churn two files (a script and its
    # template, say), and max_by silently drops every file but the loudest one.
    | ($e | map(select(.type == "assistant") | .message.content[]?
        | select(.type == "tool_use" and (.name | test("^(Edit|Write|NotebookEdit)$")))
        | .input.file_path // empty)
       | group_by(.) | map({k: .[0], n: length}) | sort_by(-.n)) as $hots
    | ($hots[0]) as $hot | ($hots[1]) as $hot2
    | ($e | map(select(.type == "user") | .message.content[]?
        | select(type == "object" and .type == "tool_result" and .is_error == true)
        | (if (.content | type) == "string" then .content else (.content[0].text? // "") end)
        | gsub("[\\t\\n]"; " ") | .[0:60])
       | group_by(.) | map({k: .[0], n: length}) | max_by(.n)) as $err
    | [ ($e | map(.cwd // empty) | last // "?"),
        ($active | floor),
        ($e | map(select(.type == "user" and (.message.content | type) == "string")) | length),
        ($hot.k // "-"), ($hot.n // 0),
        ($hot2.k // "-"), ($hot2.n // 0),
        ($err.k // "-"), ($err.n // 0),
        ($t | first // 0 | strftime("%Y-%m-%d")) ]
    | @tsv' "$1" 2>/dev/null || true
}

# `|| true`: find exits non-zero on an unreadable subdir, and with set -e + pipefail
# that killed the whole report silently — exit 1, not one line of output.
DATA=$(find "$ROOT" -name '*.jsonl' -mtime "-$DAYS" -size +1k 2>/dev/null \
  | while read -r f; do scan "$f"; done || true)

[ -n "$DATA" ] || { echo "batman: nothing in the last $DAYS day$([ "$DAYS" = 1 ] || echo 's')."; exit 0; }

printf '\n  BATMAN — last %s day%s\n\n' "$DAYS" "$([ "$DAYS" = 1 ] && echo '' || echo 's')"

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

# Loudest signals, not just the loudest one — a wall of warnings is the same as no
# warning, but a five-line cap on a week that had four separate multi-hour grinds
# hides three of them behind "...and N more." Columns shifted by the second hot file:
# cwd active prompts hot1_k hot1_n hot2_k hot2_n err_k err_n date.
ALL=$(echo "$DATA" | awk -F'\t' '
  { n = split($1, p, "/"); proj = p[n] ? p[n] : $1 }
  $5 >= 5 { m = split($4, q, "/"); printf "%d\t  %s: %s rewritten %dx in one session (%s)\n", $5, proj, q[m], $5, $10 }
  $7 >= 5 { m = split($6, q, "/"); printf "%d\t  %s: %s rewritten %dx in one session (%s)\n", $7, proj, q[m], $7, $10 }
  $9 >= 3 { printf "%d\t  %s: same error %dx — \"%s\" (%s)\n", $9, proj, $9, $8, $10 }
  $2 >= 7200 && $3 <= 3 { printf "%d\t  %s: %dh session, %d prompt(s) — long grind, little steering (%s)\n", 5, proj, $2/3600, $3, $10 }' \
  | sort -rn)

# Capped per project, not flat: a bad week for one project used to crowd the other
# 18 signals off the page entirely. Three per project covers a churn signal plus an
# error plus a second churny file — the actual shape of a real grind — while the
# rest still collapse to a count so the list stays a page, not a wall.
if [ -n "$ALL" ]; then
  SHOWN=$(echo "$ALL" | cut -f2- | awk -F': ' '{c[$1]++; if (c[$1] <= 3) print}')
  N=$(wc -l <<<"$ALL")
  S=$(wc -l <<<"$SHOWN")
  printf '\n  stuck signals\n%s\n' "$SHOWN"
  [ "$N" -gt "$S" ] && printf '  ... and %d more, same projects, same story.\n' "$((N - S))"
fi

printf '\n  Ask: was the top line the thing that mattered?\n\n'
