#!/bin/bash
# サブエージェントの Edit/Write 書き込みスコープ検証（PreToolUse フック）
#
# 使い方（エージェント frontmatter の hooks から）:
#   command: ".claude/hooks/validate-write-scope.sh <許可プレフィックス>..."
#
# 判定ルール:
#   - 対象パスをリポジトリルート相対に正規化し、引数の許可プレフィックスと前方一致で照合
#   - `.claude/agent-memory*/` は常に許可（agent memory の管理用）
#   - リポジトリ外の絶対パス（スクラッチパッド / /tmp 等の一時ファイル）は許可
#   - 違反は exit 2 でブロックし、理由を stderr でエージェントに返す

set -u

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  FILE_PATH=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))')
fi

# file_path を持たないツール入力は対象外
[ -z "$FILE_PATH" ] && exit 0

# リポジトリルート = このスクリプト（.claude/hooks/）の 2 つ上
REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)

case "$FILE_PATH" in
  "$REPO_ROOT"/*)
    REL="${FILE_PATH#"$REPO_ROOT"/}"
    ;;
  /*)
    # リポジトリ外（スクラッチパッド等）は許可
    exit 0
    ;;
  *)
    REL="$FILE_PATH"
    ;;
esac

# パストラバーサルは判定不能なのでブロック（絶対パスでの再試行を促す）
case "/$REL/" in
  */../*)
    echo "Blocked: パスに '..' が含まれるためスコープ判定できません。絶対パスで指定し直してください: $FILE_PATH" >&2
    exit 2
    ;;
esac

# agent memory は常に許可
case "$REL" in
  .claude/agent-memory/*|.claude/agent-memory-local/*)
    exit 0
    ;;
esac

for PREFIX in "$@"; do
  case "$REL" in
    "$PREFIX"*)
      exit 0
      ;;
  esac
done

echo "Blocked: '$REL' はこのエージェントの書き込みスコープ外です（許可: $* および .claude/agent-memory/）。スコープ外の変更が必要な場合は、編集せずレポートの「親への依頼」に明記してください。" >&2
exit 2
