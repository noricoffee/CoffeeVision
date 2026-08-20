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
#   - ストック型 docs（仕様の正本）500 行超 → 棚卸し（curate-doc skill）
#     陳腐化チェック → 縮約 → 分離の 3 段。data-model.md 1246 行の教訓（2026-07-25。
#     陳腐化 6 件 + 欠落 2 件 + データ欠損バグ 1 件を検出）
#
#   - フロー型 docs（作業ログ = implementation_note / tasks）1200 行超 → 月次アーカイブ
#     ストック型と閾値を分ける理由: 作業ログは append-only 気味に伸びるのが正常で、
#     縮約で 500 行に収めようとすると経緯そのものを削る（歴史の破棄）。加えて dispatch
#     ごとに触る doc なので 500 だとほぼ毎回鳴り、他 doc の警告まで読み飛ばす habit が
#     つく（アラーム疲れで仕組みが無効化される）。2026-07-25 に 2 段化。
#
#   - 対象外: docs/tasks/lessons.md（「昇格しても発生源として残す」設計）/
#     docs/talks/（登壇資料でプロダクト仕様ではない）/ 凍結アーカイブ
#     （*-archive.md。移送の受け皿なので閾値は意味を持たず、通読されず日付・ID で
#     grep されるだけ。鳴らすとアラーム疲れで他 doc の警告まで読み飛ばす）
#
# 非ブロッキング（警告のみ・exit 0）。閾値は下記 3 定数で調整可。
set -euo pipefail

CODE_THRESHOLD=800
DOCS_THRESHOLD=500
FLOW_DOCS_THRESHOLD=1200

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
  # 棚卸し対象外の docs（先に弾く）— 凍結アーカイブは移送の受け皿なので閾値を持たない
  docs/tasks/lessons.md|docs/talks/*|docs/*-archive.md) exit 0 ;;
  # フロー型 docs（作業ログ）— 縮約より月次アーカイブが効く
  docs/implementation_note.md|docs/tasks.md)
    threshold=$FLOW_DOCS_THRESHOLD
    action="追記が止まった月をアーカイブへ切り出す時期です（curate-doc skill Phase 3 / 各 doc 前文の運用ルール）。"
    ;;
  # ストック型 docs（仕様の正本）。root README.md も対象（リポジトリの玄関で、
  # モジュール構成の記述が陳腐化しやすい。2026-07-25 に旧ドメイン名の残存を検出）
  docs/*.md|docs/*/*.md|README.md)
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
