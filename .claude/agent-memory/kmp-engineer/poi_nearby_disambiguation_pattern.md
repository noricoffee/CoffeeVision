---
name: poi-nearby-disambiguation-pattern
description: 座標近傍検索の結果から単一候補を選ぶとき「最近傍のみ」だと別店を拾う。名前による曖昧性解消の実装パターン（MapViewModel.onPoiTapped、フェーズ17-C）
metadata:
  type: project
---

`searchNearby(lat, lng, radius)` の結果（DISTANCE ランク済）から単一の Cafe を自動選択する処理
（例: `MapViewModel.onPoiTapped`）は、`.first()`（最近傍）だけだと座標ズレや近接複数店で
別店を誤って選んでしまう。

対処パターン: 呼び出し側が持っている参照名（POI タップ名等）で候補を絞り込む
`results.firstOrNull { namesMatch(it.name, tappedName) } ?: results.first()` の形にする。
`namesMatch` は commonMain 完結で `lowercase() + 空白除去 → 双方向 contains`。
ただし正規化後の参照名が短すぎる（2 文字未満）と generic な名前
（iOS 側が POI 名 nil のとき渡す "カフェ" 等）で誤マッチするため、閾値未満は名前一致を
スキップして最近傍にフォールバックするガードが要る。

file: `shared/feature/map/src/commonMain/kotlin/com/noricoffee/feature/map/MapViewModel.kt`
（`namesMatch` は private top-level 関数としてファイル末尾に配置）

横断点検メモ: `CoffeeEditorViewModel`（`take(3)` でユーザーに複数候補提示）や
`CafeSearchViewModel`（一覧提示、ユーザーが選択）は単一自動選択をしていないため
同型の問題なし。単一自動選択をしている箇所が今後増えたら同じ罠がないか確認する。
