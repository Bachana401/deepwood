#!/usr/bin/env bash
# Regenerates CODEMAP.md — a navigation index of every game script (purpose) plus
# section+function outlines with line numbers for the big files. Run from repo root:
#   bash gen_codemap.sh
# Line numbers drift as code changes; regenerate after significant edits.
# (No `set -e`/pipefail on purpose: greps here legitimately find nothing on files
#  with no header comment, and that must not abort the run.)
cd "$(dirname "$0")"

BIG="game_state.gd boss.gd player.gd dungeon_interior.gd building.gd enemy.gd inventory.gd main.gd underdark.gd npc.gd special_mob.gd wizard.gd adventurer.gd assign_ui.gd day_night_cycle.gd"

{
echo "# Deepwood — Codemap"
echo ""
echo "_Navigation index for fast lookup. Regenerate with \`bash gen_codemap.sh\`. Line numbers drift as code changes — treat as approximate anchors, confirm with a read._"
echo ""
echo "\`$(ls -1 *.gd | grep -vE '^test_|^tool_' | wc -l | tr -d ' ')\` game scripts, ~$(cat $(ls -1 *.gd | grep -vE '^test_|^tool_') | wc -l | tr -d ' ') LOC. Generated $(date +%Y-%m-%d)."
echo ""
echo "## File directory"
echo ""
echo "| script | lines | purpose (first header comment) |"
echo "|--------|------:|--------------------------------|"
for f in $(ls -1 *.gd | grep -vE "^test_|^tool_" | sort); do
  ln=$(wc -l < "$f" | tr -d ' ')
  purpose=$(sed -n '1,12p' "$f" | grep -E "^#" | grep -vE "^# ?[-=#]{3,}" | head -1 | sed 's/^#\+ \?//' | cut -c1-90)
  [ -z "$purpose" ] && purpose="(no header comment)"
  printf "| %s | %s | %s |\n" "$f" "$ln" "$purpose"
done

echo ""
echo "## Big-file outlines (sections + functions, with line numbers)"
echo ""
echo "Jump anchors for the files too large to grep comfortably. \`#\` = section header, \`»\` = function."
for f in $BIG; do
  [ -f "$f" ] || continue
  echo ""
  echo "### $f ($(wc -l < "$f" | tr -d ' ') lines)"
  echo '```'
  grep -nE "^# ?={3,}|^# ?-{3,}|^func [a-zA-Z_]" "$f" | sed -E \
    -e 's/^([0-9]+):# ?[-=]+ ?/\1  # /' \
    -e 's/ ?[-=]+ ?$//' \
    -e 's/^([0-9]+):func ([a-zA-Z_0-9]+).*/\1  » \2/' | awk '{printf "%-6s %s\n", $1, substr($0, index($0,$2))}'
  echo '```'
done
} > CODEMAP.md
echo "CODEMAP.md regenerated: $(wc -l < CODEMAP.md) lines"
