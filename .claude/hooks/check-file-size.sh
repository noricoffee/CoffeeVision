#!/usr/bin/env bash
#
# PostToolUse (Write|Edit) フック: ファイルの行数が閾値を超えたら警告を出す。
# 対象は 2 系統で、閾値と推奨アクションが違う:
#
#   - 実装コード（Swift / Kotlin）800 行超 → 責務ごとのファイル分割を検討
#     巨大化したファイルは変更影響が読めず、ビルドも遅くなる（MapTabView 2008 行の
#     教訓、2026-07-24）。分割規約は docs/coding-conventions.md /
#     .claude/rules/{swift-ios,kotlin-kmp}.md
#
#   - docs/**.md 500 行超 → 棚卸し（curate-doc skill）
#     陳腐化チェック → 縮約 → 分離の 3 段。data-model.md 1246 行の教訓（2026-07-25。
#     陳腐化 6 件 + 欠落 2 件 + データ欠損バグ 1 件を検出）。
#     docs/tasks/lessons.md は「昇格しても発生源として残す」設計のため対象外。
#     docs/talks/ は登壇資料でプロダクト仕様ではないため対象外。
#
# 非ブロッキング（警告のみ・exit 0）。閾値は CODE_THRESHOLD / DOCS_THRESHOLD で調整可。
set -euo pipefail

CODE_THRESHOLD=800
DOCS_THRESHOLD=500

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

# リポジトリルート相対パスに正規化してから対象を判定する（docs/ 配下の判定に使う）。
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
rel="${file#"$root"/}"

case "$rel" in
  # 実装コード
  *.swift|*.kt)
    threshold=$CODE_THRESHOLD
    action="責務ごとのファイル分割を検討してください（分割規約: docs/coding-conventions.md / .claude/rules/）。"
    ;;
  # 棚卸し対象外の docs（先に弾く）
  docs/tasks/lessons.md|docs/talks/*) exit 0 ;;
  # 設計・仕様 docs
  docs/*.md|docs/*/*.md)
    threshold=$DOCS_THRESHOLD
    action="棚卸しを検討してください（curate-doc skill: 陳腐化チェック → 縮約 → 分離）。"
    ;;
  *) exit 0 ;;
esac

lines=$(wc -l < "$file" | tr -d ' ')
if [ "$lines" -gt "$threshold" ]; then
  base=$(basename "$file")
  msg="⚠️ ${base} が ${lines} 行（閾値 ${threshold} 行超）です。${action}"
  jq -n --arg msg "$msg" '{systemMessage: $msg}'
fi

exit 0
