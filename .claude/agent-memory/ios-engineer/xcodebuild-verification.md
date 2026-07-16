---
name: xcodebuild-verification
description: xcodebuild によるビルド検証時のハマりどころ（Gradle 出力の見え方、destination 名、-list、シミュレータ選定）
metadata:
  type: project
---

## xcodebuild を `| tail -N` で絞ると Gradle Run Script フェーズの出力が見えなくなる（2026-07-06 確認）

`xcodebuild ... | tail -80` のように末尾だけ見ると、ビルド後半（Swift コンパイル〜リンク）しか映らず、序盤に実行される `./gradlew :shared:framework:embedAndSignAppleFrameworkForXcode`（`project.pbxproj` の Run Script フェーズ）のログが消えて「Gradle が本当に走ったか」を確認できない。**`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` を使わずに Gradle 実行を裏取りしたいときは、出力をファイルへリダイレクト（`> build.log 2>&1`）してから `grep` する**（`tail` で絞らない）。差分検証なら `clean build` にすると Run Script も含め全フェーズが必ず再実行されるので確実。

## xcodebuild のシミュレータ destination 名は `xcrun simctl list devices available` で確認する（2026-07-07 確認）

環境によって「iPhone 16」等の型番が存在しないことがある（この環境では iPhone 17 系のみインストール済み）。`-destination 'platform=iOS Simulator,name=iPhone 16'` は `Unable to find a device matching...` で即失敗するので、事前に `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl list devices available | grep iPhone` で存在する名前を確認してから `-destination` を組み立てる。

## `xcodebuild -project ... -list` の出力は末尾までスクロールしないと `Schemes:` セクションが見えないことがある（2026-07-07 確認）

`| head -30` 等で先頭だけ見ると `Targets:` / `Build Configurations:` までしか映らず「共有スキームが無い」と誤認しがち（実際は package 解決ログが長く `Schemes:` セクションはさらに下）。`xcshareddata/xcschemes/*.xcscheme` の有無を先に `find` で確認するか、`-list` は全文（`tail` 併用）で見ること。ビルドは `-target` ではなく `-scheme`（+ 必要なら `-derivedDataPath`）を使う（`-derivedDataPath` 指定時は `-scheme` が必須で `-target` だと `error: The flag -scheme... is required` になる）。

## 深くネストした `Map`/`ForEach`/`Annotation` の ViewBuilder クロージャ内で `let x: Double` を複数行 `if/else` 代入にすると、無関係な外側の `ForEach(..., id: \.prop.subprop)` KeyPath が `KotlinBase` にしか解決できず「has no member」エラーになることがある（2026-07-16、MapTabView 好み一致チップ対応で確認）

`MapTabView` の `Map { ForEach(bridge.visitedCafes, id: \.cafe.placeId) { visitedCafe in Annotation(...) { let pinOpacity: Double; if a { ... } else if b { ... } else { ... }; Group { ... }.opacity(pinOpacity) } } }` のように、深いネストの中で 3 分岐の `if/else` 文（式ではなく文として `let` に代入）を追加すると、型チェッカが外側の `ForEach` の KeyPath 型推論を `VisitedCafe` ではなく基底の `KotlinBase` に解決してしまい、`visitedCafe.cafe` が「`KotlinBase` に `cafe` メンバがない」という一見無関係なエラーになる（エラー位置が実際の原因箇所と一致しない）。**同じ複雑度の代入は 1 文の（入れ子）三項演算子式に書き換えると解消する**（`let x: Double = condA ? valA : (condB ? valB : valC)`）。SKIE 型 + 深いネスト ViewBuilder + 複数行 `if/else` の組み合わせで再現しやすいので、同様のエラーに遭遇したら「関係なさそうな外側の KeyPath / ForEach」を疑う前に、まず直近で追加した多分岐 `let` 代入を三項演算子化して切り分けるとよい。
