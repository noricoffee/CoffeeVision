#!/usr/bin/env bash
#
# doc の内訳を測る（curate-doc skill Phase 2 用）。
#   使い方: .claude/skills/curate-doc/measure-doc.sh docs/data-model.md
#
# 出力: 総行数 / コードブロック行数と比率 / 見出しごとの行数（降順 15 件）
#
# awk を SKILL.md に直書きすると skill 起動時の引数展開で `$0` が潰されるため、
# スクリプトとして同梱する（2026-07-25 に dogfooding で発覚）。
set -euo pipefail

doc="${1:?usage: measure-doc.sh <path-to-doc.md>}"
[ -f "$doc" ] || { echo "not found: $doc" >&2; exit 1; }

total=$(wc -l < "$doc" | tr -d ' ')
code=$(awk '/^```/{f=!f; next} f{c++} END{print c+0}' "$doc")
printf '総行数: %s / コードブロック: %s 行 (%d%%)\n\n' "$total" "$code" "$(( total ? code * 100 / total : 0 ))"

echo "見出しごとの行数（降順 15 件）:"
awk '
  /^#{1,3} /{ if (h != "") printf "%5d  %s\n", NR - s, h; h = $0; s = NR }
  END       { if (h != "") printf "%5d  %s\n", NR - s, h }
' "$doc" | sort -rn | head -15
