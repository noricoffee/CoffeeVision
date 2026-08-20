---
name: edit-tool-fullwidth-char-gotcha
description: Edit ツールが日本語コメント内の全角括弧・全角スラッシュ等で "String to replace not found" を繰り返すときの対処
metadata:
  type: project
---

このコードベースの Kotlin ドキュメントコメントは全角括弧 `（）` や通常のスラッシュ `/` を混在させて
書かれていることが多く、`Read` ツールの表示から `old_string` をコピーしても、実際のファイルの
全角文字（`（` `）` `、` 等）と微妙に異なる文字（半角括弧・別のダッシュ等）を打ち込んでしまい、
`Edit` が "String to replace not found" を繰り返すことがある（2026-07-07、
`CoffeeEditorViewModel.kt` の複数箇所で発生）。

**対処**: 2 回続けて "not found" になったら、`grep -n "<部分文字列>"` で該当行を取得し、
`python3` で `open(path, encoding="utf-8")` → 文字列置換 → 書き戻すスクリプトに切り替える方が早い。
その際 `assert content.count(old) == 1` を必ず入れて意図しない多重ヒットを防ぐ（同一文言が
docstring に複数箇所ある場合はこの assert で早期に気づける。実際に 2 箇所ヒットした）。
