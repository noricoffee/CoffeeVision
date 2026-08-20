---
name: swiftui-charts
description: 分析タブの Swift Charts / カスタム Path 描画チャート実装パターン（レーダーチャート、enum 固定順マージ、色ランプ）
metadata:
  type: project
---

## Swift Charts 非対応チャート（レーダー）は `GeometryReader` + `Path` の自前描画で汎用コンポーネント化する（2026-07-13、`TastingRadarChart` 新設で確認）

- `iosApp/iosApp/Features/Analysis/TastingRadarChart.swift`。軸配置は `angle(index) = -π/2 + index * (2π / count)`（12 時位置から時計回り）で統一し、グリッド同心多角形・スポーク・データポリゴン・頂点マーカーはすべて同じ `vertexPoint(index:ratio:radius:center:)` ヘルパを共有すると実装がぶれない（ratio=1 でグリッド/スポーク、ratio=value/maxValue でデータ点）。
- **`@ViewBuilder` 関数の閉じ括弧の直後にモディファイアを続けて書くと構文エラー**になる（`private func x() -> some View { ... }.accessibilityHidden(true)` は不可）。装飾レイヤー全体を隠したいときは関数本体を `Group { ... }.accessibilityHidden(true)` の形にして、`Group` に対してモディファイアを付ける（`@ViewBuilder` 属性自体は不要になる。単一 `Group` 式の暗黙 return で足りる）。
- 軸ラベルの「重ならない自動アンカー」は、GeometryReader 内で実測サイズを取る 2-pass レイアウトを組まなくても、各軸の `cos(angle)`/`sin(angle)` を閾値判定（例 `|cos|>0.35` → 左右オフセット、`|sin|>0.35` → 上下オフセット）してラベル中心をベクトル方向にずらすだけで実用上十分（5 軸の正五角形配置なら「上/右/右下/左下/左」の組み合わせに自然に収束する）。ラベルは固定 `.frame(width:)` + `.fixedSize(horizontal: false, vertical: true)` で自己サイズを確定させ、`.position(...)` で中心座標を直接指定する。
- チャート全体を 1 要素に潰さず「軸ごとに読み上げ」させるには、装飾（グリッド/スポーク/データ塗り/頂点マーカー）側をすべて `.accessibilityHidden(true)` にし、可視ラベル `Text` 側にだけ `.accessibilityLabel(...)` を付ける（Text は自動でひとつのアクセシビリティ要素になるため、追加のグルーピングを書かなくても軸数と同じ要素数になる）。
- 汎用コンポーネント（`RadarChartAxis` = `(id, label, value, accessibilityLabel: String?)` + `TastingRadarChart(axes:maxValue:)`）にドメイン固有の a11y 文言（「◯◯ 平均 X.X（N 件の記録）」等）を持ち込みたいときは、コンポーネント側に文言生成ロジックを書かず、呼び出し側で `accessibilityLabel` を明示的に組み立てて渡す設計にすると、コンポーネントがドメイン非依存のまま既存ヘルパ（`tastingAccessibilityLabel` 等）を再利用できる。

## Kotlin enum の「件数降順の集計配列」を Swift 側で「固定順・全件表示」にマージする定番パターン（2026-07-13、分析タブ焙煎度チャート横棒化で確認）

- KMP 側の契約（`CoffeeStats.byRoastLevel` は件数降順、LLM digest にも使われる）は変更せず、Swift 側だけで「焙煎順（enum 宣言順）に並べ替え + 欠けている段階を count 0 で補完」を行う。手順: ① enum の Kotlin 宣言順を Swift 側に `private static let xxxOrder: [String]` として固定コピー（`RoastLevel.kt` 等の `.kt` ファイルを直接 Read して裏取り）、② `Dictionary(uniqueKeysWithValues: stats.byX.map { ($0.label, $0) })` で label→CategoryStat の辞書を作り、③ `xxxOrder.enumerated().map { position, label in ... }` で 8 件固定の Identifiable struct 配列を組み立てる（`position` は色ランプ等の連続値に使う）。件数 0 の要素も配列に残し、chart 側で「バーはゼロ幅で描くが軸ラベルは出す」形にすると「記録が無い段階が見える」という要件を Chart 側の追加分岐なしで満たせる。
- 横棒 `BarMark`（x=値, y=カテゴリ）で表示順を enum 固定順にしたいときは、データ配列の並び順に加えて `.chartYScale(domain: xxxOrder.map { localized($0) })` を明示すると安全（Swift Charts の「カテゴリ軸はデータ初出順」という暗黙挙動に頼らない）。先頭要素が横棒チャートの最上段になる。
- 連続量に応じた「同一色相のシーケンシャルランプ」は `Color.accentColor.mix(with: .white, by:)` / `.mix(with: .black, by:)`（iOS 18+ API、本プロジェクトの `IPHONEOS_DEPLOYMENT_TARGET` は 26.0 のため可用性チェック不要）で明暗 2 端点を作り、`lightest.mix(with: darkest, by: t)`（`t = position / (count - 1)`）で線形補間するのが簡潔。`docs/ui-ux-guidelines.md` の「勝手に色を増やさない」方針とも整合する（新規カラーリテラルを増やさず `accentColor` 由来のみで構成）。
- Kotlin の nullable `Double` フィールドを含む集計要素（`CategoryStat.averageRating`）を Swift のローカル Identifiable struct に詰め替えるときは、既存パターン通り `stat?.averageRating?.doubleValue`（ネストした Optional は自動フラット化される）で `Double?` に変換してから代入する。
- **順序性のないカテゴリ（抽出方法など）を横棒化するときは、焙煎度パターンの「enum 固定順マージ」「色ランプ」「chartYScale(domain:)」は不要**。`Chart(stats.byX, id: \.label)` をそのまま使い、BarMark の x/y だけ入れ替えれば足りる（2026-07-16、`brewMethodSection` 横棒化で確認）。X 軸ラベルが被る根本原因は「縦棒 + カテゴリ名が長い」なので、横棒（x=件数, y=カテゴリラベル）に倒すだけで解消する。`.frame(height:)` は固定値をやめ `CGFloat(items.count) * 32` にして項目数に応じて可変にする。軸構成は焙煎度と対称: X 軸（数値側）に `AxisGridLine()+AxisValueLabel()`、Y 軸（カテゴリ側）は `AxisValueLabel()` のみ。
