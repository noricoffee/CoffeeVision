---
name: tag-catalog-suggestion-pattern
description: 「使用回数ランキング + 絞り込み」型のサジェスト機能（要件 2-13 タグサジェスト）を feature VM に足すときの実地パターン
metadata:
  type: project
---

## 実装した構成（CoffeeEditorViewModel、要件 2-13）

`MapViewModel.availableTags`（重複排除 + 昇順のみ）と違い、今回は「頻度ランキング + 絞り込み +
上限」の 3 段パイプラインが要る。実装は 2 層に分離すると見通しが良い：

1. **カタログ購読**（`onAppear` で cancel-and-relaunch する Job。`coffeeRepository.observeAll(userId)`
   を継続購読 — one-shot `.first()` にすると Firestore 同期前にサジェストが空のまま固定される）。
   emit のたびに `allTagsByFrequency`（private var、頻度降順→昇順）を更新するだけで `UIState` には
   直接書かない。
   ```kotlin
   records.flatMap { it.tags }
       .groupingBy { it }.eachCount()
       .entries.sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
       .map { it.key }
   ```
2. **`recomputeSuggestedTags()` private ヘルパ**が `allTagsByFrequency` から
   `UIState.suggestedTags` を再計算する。**絞り込み（`contains(ignoreCase=true)`）→ 上限（`take(10)`）
   の順序を絶対に変えない**（逆順にすると下位ランクのタグが検索でも二度と出せなくなる。これは
   `docs/requirements.md` の確定仕様であり実装都合で変えてはいけない）。

## 再計算の起点は 3 つでは足りないことがある

呼び出し元の設計指示に「起点は 3 つ（購読 emit / 入力変化 / タグ追加・削除）」とあっても、
**Edit / Duplicate のように非同期ロードで `draft` が後から差し替わるモードがあると、
ロード完了ブロックでも明示的に `recomputeSuggestedTags()` を呼ぶ必要がある**。理由: カタログ
購読 Job とロード Job はどちらも `onAppear` から同時に `launch` されるため、カタログ側の初回
emit がロード完了より先に走ると「付与済み除外」が draft 未反映の空タグ集合に対して計算され、
以後 DB に変化がない限り再計算されずサジェストに"すでに付いているタグ"が残り続けるレースが起こる。
テスト `onAppear_edit_excludesAlreadyAttachedTagsFromSuggestionsOnInitialLoad` で固定した。

## テストで頻度・順序を作るコツ

`sampleRecord(tags = listOf(...))` を複数レコードに分けて同じタグ文字列を重複させることで
頻度を作る（1 レコードの `tags` リストに同じ文字列を複数入れても `flatMap` 後の重複カウントには
効くが、可読性が落ちる）。11 件以上のタグでランク付けを固定したい場合は
`"tag" + it.toString().padStart(2, '0')` で `tag01..tag11` の辞書順を作ると、
全タグ頻度 1 件の状態でも upper-bound 検証（`take(10)` で `tag11` だけ落ちる）が安定する。
`String.format("%02d", ...)` は commonTest（iOS ターゲット含む）ではコンパイル不能
（JVM 専用 API）なので使わないこと。
