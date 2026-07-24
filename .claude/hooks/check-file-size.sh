#!/usr/bin/env bash
#
# PostToolUse (Write|Edit) フック: コードファイル（Swift / Kotlin）の行数が
# 閾値を超えたら「責務ごとの分割を検討」する警告を出す。
#
# 巨大化したファイルは変更影響が読めず、ビルドも遅くなる（MapTabView 2008 行の
# 教訓、2026-07-24）。分割規約は docs/coding-conventions.md /
# .claude/rules/{swift-ios,kotlin-kmp}.md を参照。
#
# 非ブロッキング（警告のみ・exit 0）。閾値は THRESHOLD で調整可。
set -euo pipefail

THRESHOLD=800

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[ -z "$file" ] && exit 0

# 実装コードのみ対象（Swift / Kotlin）。docs・設定・生成物は対象外。
case "$file" in
  *.swift|*.kt) ;;
  *) exit 0 ;;
esac

[ -f "$file" ] || exit 0

lines=$(wc -l < "$file" | tr -d ' ')
if [ "$lines" -gt "$THRESHOLD" ]; then
  base=$(basename "$file")
  msg="⚠️ ${base} が ${lines} 行（閾値 ${THRESHOLD} 行超）です。責務ごとのファイル分割を検討してください（分割規約: docs/coding-conventions.md / .claude/rules/）。"
  jq -n --arg msg "$msg" '{systemMessage: $msg}'
fi

exit 0
