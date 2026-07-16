---
name: image-renderer-share-card
description: ImageRenderer で固定サイズ SNS 共有カード画像を作るときの実装パターン（scaleEffect+frame での子ビュー圧縮、可変レイアウトの高さ配分、プレビューシート構成）
metadata:
  type: project
---

## `ImageRenderer` で固定ピクセルサイズのカード画像を作るときは、ルート View に `.frame(width:height:)` + `.clipped()` を明示する（2026-07-16、共有カード画像生成で確認）

- `ImageRenderer(content:)` はルートに渡した View の実測サイズをそのまま出力キャンバスサイズにする。`1080×1350px` のような確定出力サイズが必要なら、ルート View 自身に `.frame(width: 360, height: 450, alignment: .top)`（pt サイズ）を明示し、`renderer.scale = 3` を掛ける（360×3=1080）。`alignment: .top` にしておくと、内容が短い場合に下側へ空白が残るだけで崩れない。
- 内容がフレームより長くなる極端なケース（属性文字列が異常に長い等）に備え、ルートに `.clipped()` を付けておくと安全網になる（レイアウトが破綻しても画像サイズ自体は必ず確定値になる）。
- ライトテーマ固定（端末のダーク設定に依存させない）は `ImageRenderer` に渡す `content` に `.environment(\.colorScheme, .light)` を付けるだけで良い。カード View 自身はシステムカラー（`.primary`/`Color(.systemBackground)` 等）を使うだけで環境非依存に保てる。

## 固定 `.frame(height:)` を持つ既存コンポーネント（例: `TastingRadarChart` の内部 `.frame(height: 260)`）を、外側から小さい領域に収めるには `.scaleEffect(scale)` の**後に** `.frame(height: scale * 260)` を続ける

- `.scaleEffect` は描画だけを縮小し、レイアウト上の footprint（親に報告するサイズ）は変えない。続けて `.frame(height:)` を書くとその値が新しい footprint として親に報告され、視覚的にちょうどそのサイズに収まる（内部で 260pt 前提の座標計算をしているコンポーネントを改変せずに小さい領域へ押し込める）。`.frame(maxWidth: .infinity)` を追加すると水平方向は中央寄せで自然に収まる。
- コンポーネント本体は改変しない（分析タブ等の既存利用箇所と共用するため）。呼び出し側でこの縮小ラップだけ行う。

## 可変レイアウト（写真/評価/テイスティング等が「あれば載せる」）を固定フレーム内で組むときの高さ配分は、各行に `private static let` で固定 pt を割り当て、可変枠（レーダー等）だけ「残り高さ = 全体 - 固定行合計 - spacing 合計」を計算式で出す

- SwiftUI の `GeometryReader` 2 パス測定に頼らず、行の高さを最初からデザイン定数として固定してしまえば、可変枠の残り高さは単純な四則演算で求まる（`visibleCount` を数えて `spacing * (visibleCount - 1)` を引くのを忘れない）。計算結果に `max(_, 下限値)` を必ずかけて、要素が多い最悪パターンでもゼロ/負値にならないようにする。
- 逆に「その行がまったく無いときは残り空間を埋めて次要素を押し下げたい」だけのケース（例: テイスティング無しなら空白を作ってフッターを座りよく見せる）は、無理に計算式に含めず `Spacer(minLength:)` に任せる方が素直（親が確定高さの箱である限り、`Spacer` は正しく残り領域を埋めてくれる）。計算式が要るのは「同じ枠に固定サイズの既存コンポーネントを縮小して収める」ときだけ。

## Preview 用サンプルは既存 `PreviewSamples`（`iosApp/iosApp/PreviewSupport/PreviewSamples.swift`）の 4 種で「写真なし/テイスティングなし/未評価/セルフ抽出」の組み合わせがほぼ揃っている

- `sampleCoffeeRecord`（カフェ+写真+評価+テイスティング）/ `sampleCoffeeRecordWithoutPhotos`（カフェ+評価+テイスティング、写真なし）/ `sampleCoffeeRecordSelfBrew`（セルフ抽出+評価+テイスティング）/ `sampleCoffeeRecordUnrated`（未評価+テイスティングなし+属性なし）。新しい「あれば載せる」系 View の Preview 検証はこの 4 つをそのまま使い回せる。ただし `Photo_.fileName` は実ファイルが simulator 上に存在しないため、`PhotoFileStore.loadImage` は Preview では常に `nil` を返す（= 写真ありサンプルでも Preview 上は「写真なし」表示にフォールバックする）。実際の写真ありレイアウトはシミュレータ/実機での目視確認が必要。
