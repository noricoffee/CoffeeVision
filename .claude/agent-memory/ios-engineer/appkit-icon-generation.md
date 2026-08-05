---
name: appkit-icon-generation
description: iosApp/scripts/generate_app_icon.swift（AppKit + NSBezierPath でアプリアイコン/LaunchLogo PNG を生成するオフライン script）の実装パターン
metadata:
  type: project
---

## SF Symbols はアプリアイコン / ロゴに使えない（ライセンス条項）

`iosApp/scripts/generate_app_icon.swift` は当初 `NSImage(systemSymbolName:)` でレンダリングしていたが、SF Symbols のライセンスがアイコン/ロゴ用途を禁じているため、全図形を `NSBezierPath` の自前描画に置き換えた（2026-08-06）。以後このスクリプトに `systemSymbolName` を戻さないこと。意匠は「アーモンド型のアイライン + 中に置いたカップ&ソーサー」（`eyeOutline` + `drawCup` 関数）。幾何定数（`0.375 * size` 等の比率）は SF の実測ベースで確定済みなので、デザイン変更でない限り数値を触らない。

## 透過 PNG で「穴を開ける」描画は `bg()` クロージャの再実行 + `.copy` 合成を使う

- `drawCup` はカップの取っ手の穴・持ち手の内側・ソーサーの隙間・カップの飲み口を「背景を再度クリップ内に描き直す」ことで表現する（`ink.setFill()` で塗った後、穴の形で `addClip()` してから `bg()` を呼ぶ）。アイコン（不透明グラデーション背景）なら `bg` はグラデーション再描画で自然に穴が背景色に戻る。
- **透過キャンバス（LaunchLogo）で同じ手法を使う場合、`bg` は「クリアに戻す」処理でなければならず、`NSColor.clear.setFill()` だけでは不十分**（デフォルトの `.sourceOver` 合成はアルファ 0 の色を重ねても下のピクセルのアルファを変えない＝透明にならない）。`rect.fill(using: .copy)` で明示的に `.copy` 合成にすると、アルファも含めてピクセルを完全上書きでき、期待通り透明になる。生成後は `NSBitmapImageRep.colorAt(x:y:).alphaComponent` でコーナーが `0.0` であることを実際に確認するとよい（本ファイル末尾の検証コマンド参照）。

## `eyeOutline(_ c: CGFloat, w:, h:)` は中心点の x/y に同じ値 `c` を要求する（正方形キャンバス前提）

- 関数シグネチャが `cx`/`cy` を分離せず単一の `c` を取るため、意匠のマークを正方形キャンバスの中心（`c = size/2`）に置く前提でしか直接使えない。LaunchLogo のように「マークを上寄せ、下にワードマークを置きたい」ケースでは、キャンバス全体に直接描くのではなく、**マーク専用の正方形 `NSImage`（`markSize × markSize`）を別途 `lockFocus()`/`unlockFocus()` で用意し、その内部で `c = markSize/2` として `eyeOutline`/`drawCup` を描画してから、完成した `NSImage` を本キャンバスの好きな位置に `draw(at:)` で合成する**とシグネチャを変更せずに済む。マーク用オフスクリーンの背景クリア（`markBg` クロージャ）も上記の `.copy` 合成を使う。

## 透過キャンバス上のロックアップ（マーク+ワードマーク）を中央寄せするには「オフスクリーンに描く→bbox 実測→シフト量を逆算して再合成」

`UILaunchScreen` は画像の**フレーム**を画面中央に置くため、画像内のコンテンツ bbox がキャンバス中心からズレていると起動画面上でもズレて見える（2026-08-06、LaunchLogo で発生: 上余白 64px / 下余白 140px の非対称）。ハードコードでオフセットを足すと将来マークサイズやワードマークを変えたときに再びズレるので、実測してから中央化する手順に直す。

1. ロックアップをキャンバスと同サイズの中間 `NSBitmapImageRep`（+ そのための `NSGraphicsContext`）に、これまでどおりの「自然な」位置で描画する。
2. その `NSBitmapImageRep` を `colorAt(x:y:)` で全走査し、`alpha > 0.01` のピクセルから `minX/maxX/minY/maxY` を求める（512×512 程度なら全走査で十分高速）。
3. **`NSBitmapImageRep.colorAt` の行方向は top-down（row 0 = 描画時の上端）で、`NSRect`/`NSPoint` で描画するときの座標系（origin 左下、y 上向き）とは逆向き**（`NSGraphicsContext(bitmapImageRep:)` で得るコンテキストは非フリップの標準 Cocoa 座標系のため）。実測で確認済み: `NSRect(x:0,y:0,width:10,height:10).fill()`（描画空間の下端）→ `colorAt` 走査で `y` の最大側（`size-1` 付近）にヒットする。ピクセル完全対称にするシフト量は「合計 = width-1（または height-1）」を解く形で出す。`shiftX = ((width-1) - (minX+maxX)) / 2`、`shiftY = ((minY+maxY) - (height-1)) / 2`（Y は上記の軸反転を織り込み済みの式）。`width/2 - 平均` のような単純な式は 0.5px 分のずれ方向を誤り、四捨五入で 2px 級の非対称が残ることがある（実装時に一度この誤差を踏んだ）。
4. 求めたシフト量を `.rounded()` で整数化し、最終キャンバスをクリアしてから `lockupRep.draw(in: NSRect(x: shiftX, y: shiftY, width: width, height: height))` で合成する（元と同サイズの矩形に描画すれば等倍でシフトだけがかかる）。
5. 検証は `colorAt` で bbox を再計算し、`minX == width-1-maxX` かつ `minY == height-1-maxY`（両側の余白が一致）であることを数値で確認する。四隅の alpha が 0.0 であることも合わせて確認する。

## 検証コマンド（このスクリプトを改修したときの再検証セット）

```bash
# 1. 生成
swift iosApp/scripts/generate_app_icon.swift

# 2. SF Symbol 残存チェック（0 件であること）
grep -rn "systemSymbolName" iosApp/scripts/

# 3. 透過確認（コーナーの alpha が 0.0 であること）— PIL が無い環境では NSBitmapImageRep.colorAt を使う小さい swift script を書いて確認する
swift - <<'EOF'
import AppKit
let rep = (NSImage(contentsOfFile: "iosApp/iosApp/Assets.xcassets/LaunchLogo.imageset/launch-logo.png")!
    .representations.first as! NSBitmapImageRep)
print(rep.colorAt(x: 0, y: 0)!.alphaComponent)  // expect 0.0
EOF

# 4. サイズ検証はスクリプト自身が最後に print する（1024x1024 x3 / 512x512 x1）
```

## ビルド検証は Debug + シミュレータで十分（アセット差し替えのみなら Kotlin framework は UP-TO-DATE でよい）

アイコン/画像アセットだけの変更では `shared:framework` 系タスクは `UP-TO-DATE` のままで問題ない（Kotlin 公開 API 変更が絡まないため）。`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -destination 'platform=iOS Simulator,name=iPhone 17' build`（`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` 無し）で `** BUILD SUCCEEDED **` を確認すれば足りる。
