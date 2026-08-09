# CoffeeVision UI/UX ガイドライン（iOS / SwiftUI）

## 概要

本ドキュメントは CoffeeVision の **iOS（SwiftUI）** における UI/UX 設計方針を定めます。
Apple の **Human Interface Guidelines（HIG）** をベースとし、iOS ネイティブの体験に沿った一貫性のある UI を提供することを目的とします。

> Android（Compose Multiplatform）は `sharedUI/` に検証用 1 画面（`CoffeeListScreen`）が実装済みですが、リリース対象外のため UI ガイドラインは定めていません。Android を製品として作り込む段階で別途追加します。

参考: [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

---

## 設計の基本原則

Apple HIG が掲げる 3 つの原則をプロジェクト全体で遵守します。

| 原則 | 説明 |
|------|------|
| **Clarity（明確さ）** | テキスト・アイコン・カラーを使って情報を正確に伝える。装飾より機能を優先する |
| **Deference（従順さ）** | コンテンツ（写真・カフェ情報・評価）を主役にする。UI はコンテンツを引き立てる背景として機能する |
| **Depth（奥行き）** | 視覚的な階層・アニメーション・トランジションで空間的な理解を助ける |

---

## ブランドカラー

CoffeeVision のアクセントカラーは **コーヒー由来のブラウン系** とします。
ただし、テキスト・背景・ボーダーなどシステム標準で十分な箇所には独自カラーを当てません。

| 役割 | 色 | 備考 |
|------|---------|------|
| アクセント | AccentColor **#8B5A2B**（dark: **#C08552**） | `Assets.xcassets` の AccentColor に設定済み（フェーズ 16） |
| 評価の星 | `.yellow`（システム） | アクセシビリティ対応のため標準色を使用 |

### マップ概念の色セマンティクス（フェーズ 16 確定）

マップのピン・チップ・バッジは以下の 5 概念の色割り当てを正とする。新しい UI を足すときもこの表に従う（勝手に色を増やさない）。

| 概念 | 色 | 使用箇所 |
|------|----|---------|
| ブランド / 訪問済み | `Color.accentColor`（#8B5A2B） | visitedCafePin、`TagChip` 選択フィル（既定 `tint`）、tint 全般 |
| 保存済み（行きたい） | `Color.indigo` | savedCafePin（カップ + `bookmark.fill` バッジ）、保存ボタン / バッジ。**保存ボタンは未保存・保存済みの両状態とも indigo**（tint 未指定で `accentColor` を継承させない）。状態は色ではなく**塗りの有無**で表す — 保存済み = `.borderedProminent`（塗り）/ 未保存 = `.bordered`（淡色）。アイコンの `bookmark` / `bookmark.fill` と同じ「塗り = ON」の対応に揃える（2026-08-07、UX-4） |
| 好み一致 | `Color.pink` | recommendedCafePin（カップ + `heart.fill` バッジ）、「好み一致」チップ（`TagChip` の `tint: .pink`）、`RecommendedCafeListSheet`（**`accentColor` を「好み」の意味で使わない**） |
| 検索結果 | `Color.blue` | searchResultPin、検索 UI |
| おすすめ（キュレーション、フェーズ 19） | `Color.orange`（システムカラー） | curatedCafePin（カップ + `star.fill` バッジ。2026-08-07 改訂。下記「おすすめピンを色で区別しない理由」）。表示は Apple 周辺ピンと同じズームゲート（可視半径 3000m 以内）でズームイン時のみ。**さらにその内側で可視範囲（`mapSearchCenter` 中心から半径 × 1.3）に絞る**（2026-08-09 / MU-1。従来はズームゲートを通ると全 421 件が Annotation に載り、画面外のピンまで View 構築されていた = 実測 210 個/回 → 4 個/回）。当初の burnt orange（黒 25% mix）は訪問済みの茶と誤認されたため素の orange に改訂（implementation_note 2026-07-18） |

#### ピンの意匠ルール（2026-07-27 確定 / 2026-08-07 にバッジ規則を拡張）

ピンの視覚的な強弱は **サイズと色（彩度）だけで表す**。輪郭・影は全ピン共通の「地図から切り離すための処理」であり、強調の手段に使わない。**バッジはこの規則の対象外** — 強弱ではなく*意味*を載せる枠。

| 要素 | 規則 |
|------|------|
| 白フチ | **全ピン共通で `Circle().stroke(Color(.systemBackground), lineWidth: 1.5)`**。`.frame` の直後・`.shadow` の直前に置く |
| 影 | `radius: 4, x: 0, y: 2` + 自色 `opacity(0.4)`。例外は 2 つ: 周辺ピンは低強調のため `.black.opacity(0.25)` / `radius: 3` / `y: 1`、検索結果ピンは**選択中のみ** `opacity(0.6)` / `radius: 6`（選択の一時的な強調で、種別間の序列ではない）|
| サイズ | 好み一致 38 > 訪問済み 36 > 保存済み 34（強調中 38）> おすすめ 32 = 検索結果 32（選択中は `scaleEffect(1.3)`）> 周辺 28 |
| バッジ | 直径 18pt の**白地の円 + 自色のシンボル / 文字**、`.offset(x: 4, y: -4)` で右上に重ねる。訪問済み = 訪問回数（2 回以上のみ。10 以上は `9+`）、保存済み = `bookmark.fill`、好み一致 = `heart.fill`、おすすめ = `star.fill` |

##### 「カテゴリアイコン + 意味バッジ」を全概念ピンの構成とする（2026-08-07 確定）

**マップ概念ピン 4 種（訪問済み / 保存済み / 好み一致 / おすすめ）は、本体を `cup.and.saucer.fill`（= コーヒーの店というカテゴリ）で統一し、右上バッジで概念を表す**。おすすめピンで先行導入した構成（下記「おすすめピンを色で区別しない理由」）を、ユーザー判断で全概念ピンへ拡張した。

- **本体アイコンは「何の店か」だけを担う**。以前は本体アイコン自体が概念を兼ねており（`bookmark.fill` = 保存済み / `heart.fill` = 好み一致）、おすすめだけがカップ + バッジという不揃いな状態になっていた。カップに統一することで「マップ上の丸 = カフェ」が一目で読め、概念の識別は色 + バッジという一貫した 2 つの手がかりに集約される
- **バッジのシンボルは各概念が他所で使っているアイコンをそのまま流用する**（保存ボタンの `bookmark.fill`、好み一致チップの `heart.fill`）。ピン専用の記号を発明しない
- **バッジのシンボル色 = 概念色**（白地の円 + 自色）。既存のバッジ規則そのままで、新しい色は増やさない
- **サイズは据え置き**。おすすめを 34 → 32 に下げたのは「当時バッジを持つのがおすすめだけで、バッジ無しの訪問済み 36 に対して実効占有面積が勝ってしまう」ための相殺だった。4 種すべてがバッジを持つ今は相殺の必要がなく、むしろ一律 -2 すると 好み一致 = 訪問済み（36）、保存済み = おすすめ（32）とサイズ序列が潰れる
- **検索結果（`mappin.and.ellipse`）と周辺（カップ・バッジ無し）はこの規則の対象外**。前者は「まだカフェか確定していない検索ヒット」、後者は「概念を持たない低強調の背景情報」で、どちらもマップ概念ピンではない

##### ピンのタップは全種カフェ詳細へ直行する（2026-08-07 確定）

**マップ上の丸いピンは、種別に関わらずタップでカフェ詳細へ push する**（`NavigationLink`）。ピンに付随する情報（好み一致の理由など）を見せるためにシートやカードを経由地として挟まない。

- 2026-08-07 まで好み一致ピンだけが例外で、タップすると推薦理由のモーダルシートを挟んでいた。**同じ見た目のピンで行き先が違うと、詳細へ行きたいユーザーは「辿り着けない」と受け取る**（ユーザー報告）。理由シート下部に詳細への導線は実在したが、フッター状の帯で主アクションに見えず機能しなかった
- **ピンに紐づく付加情報は、遷移先（カフェ詳細）の中に置く**。好み一致の理由はカフェ詳細の「好み一致」セクションへ移設した。経由地に置くと**その経路から来たときしか見られない**という副作用がある（旧構成ではコーヒー記録一覧から同じ店を開いても理由が出なかった）
- **例外は検索結果ピン**。下部の `cafeSelectionCard`（`.safeAreaInset` の通常オーバーレイでモーダルではない）で選択を示し、カード内の導線で詳細へ push する。まだ記録の無い店を「選ぶ」段階が必要なため、概念ピンとは別扱い

##### おすすめピンを色で区別しない理由（2026-08-07 確定）

**訪問済みとおすすめは色相がほぼ同じで、色だけでは分離できない**。HSV 実測値:

| ピン | 色 | 色相 | 彩度 | 明度 |
|------|----|------|------|------|
| 訪問済み（light） | `#8B5A2B` | 29° | 69% | 55% |
| おすすめ（light） | `#FF9500` | 35° | 100% | 100% |
| 訪問済み（dark） | `#C08552` | 28° | 57% | 75% |
| おすすめ（dark） | `#FF9F0A` | 36° | 96% | 100% |

色相差は 6〜8° しかなく、両者を分けているのは明度と彩度だけ。ダークモードでは訪問済みの明度が 55% → 75% に上がるため差はさらに詰まる。2026-07-18 に「burnt orange（黒 25% mix）が茶と誤認された」のも同じ構造で、**オレンジの明度を動かす方向は原理的に袋小路**（暗くすれば茶に寄り、明るくすれば白フチに負ける）。

対処として色相を離す案（`.teal` / `.mint` = 茶から 160° 以上）も検討したが、**ティール = おすすめ が意味的に自明でない**ため不採用。カテゴリアイコン（カップ = コーヒーの店）は 3 種で共有したまま、★バッジで「推されている」という*状態*だけを足す方式を採る（Google Maps が人気スポットをカテゴリアイコンのまま強調するのと同じ発想）。**凡例は置かない** — マップの慣習で読める範囲に収めるのが前提で、凡例が要る意匠は意匠側の失敗とみなす（2026-08-07 ユーザー判断）。サイズは、バッジが乗って実効的な占有面積が増えるぶん 34 → 32 に下げて相殺する。

**白フチの有無を混ぜない**。白フチは地図の情報密度から図形を切り離す効果が大きく、有無が混ざると数 pt のサイズ差を打ち消して意図しない序列が生まれる（訪問済みだけ白フチが無く、34pt のおすすめピンに負けて見えていた。2026-07-27 にユーザー指摘で全ピン統一。教訓は [`tasks/lessons.md`](./tasks/lessons.md) 2026-07-27）。

共通チップ部品は `Components/TagChip.swift`（インタラクティブ `TagChip` + 凡例用 `TagLegendChip`）。画面ローカルにチップを再実装しない。`TagLegendChip` は 2026-07-16 の「好み一致」チップのタップ対応で production 上の使用箇所がゼロになった（凡例が必要になったら再利用する。次に触るタイミングで用途が生まれていなければ削除してよい）。

### マップ検索結果の提示（下部ドラッグシート、2026-07-22 確定）

マップの検索結果は「マップ主体 + 下部ドラッグシート一覧」で提示する（Apple/Google マップ風）。旧・検索バー直下の上部ドロップダウンは廃止（マップ = 位置を隠すため）。

- **一覧は下部の自前ドラッグシート**（`searchResultsBottomSheet`）。native `.sheet` は使わない — 検索モード中に併存する ✨ `TasteSearchSheet` と「同一 View に 2 枚目の `.sheet`」で競合するため。2 detent（peek / expanded）を `DragGesture` + スナップで実装。背後のマップは常時パン/ズーム可能。
- **カメラ自動フィット**: テキスト検索の完了時のみ、全結果ピンの bounding box に収まるようカメラを寄せる（結果が画面外に落ちて「位置が見えない」問題の解消）。**「このエリアを検索」は自動フィットしない**（表示範囲内検索で結果は構造的に画面内のため、動かすと不自然）。
- **結果シートと選択カードは下部で排他**: カフェ未選択 → 結果シート表示。行 or ピンをタップ → `selectedSearchCafe` を立て、シートを退避して既存 `cafeSelectionCard` を表示。カードの × で選択解除 → 一覧シートが戻る（= 「一覧に戻る」導線）。
- **選択ピンの強調**: 選択中の検索結果ピンは一回り拡大（scale 1.3）+ 影で強調。色は `Color.blue`（上表の検索結果セマンティクスを維持、色は増やさない）。
- **広告（§11-2）**: インライン広告 1 枠は一覧内の 3 件目の後に置く（結果 3 件未満は非表示）。提示先が上部ドロップダウン → 下部シートへ移っただけで、配置ルールは不変。

### マップの初期カメラ（2026-08-09 確定）

初期カメラは**アプリ側が明示的に決める**。MapKit の自動追従（`MapCameraPosition.automatic`）は使わない。

決定順序:

1. **`cameraPosition` の初期値** = 東京駅周辺（緯度 35.6812 / 経度 139.7671、5000m 四方）。表示されるのは初期カメラ確定までの一瞬のみ
2. **位置情報が許可済み** → 現在地に 1000m 四方で寄せる（`setupLocation` のワンショット取得後）
3. **未許可 / 拒否** → 訪問済みカフェの bounding box に合わせる。訪問済みが 0 件なら 1 の東京駅デフォルトのまま（`setInitialCameraFromVisitedCafes`）

**`.automatic` を使わない理由**（実装上の制約であり、見た目の好みではない）: `.automatic` は `Map` のコンテンツが変わるたびにカメラを再計算する。おすすめピン（curated）の表示はズームゲート（可視半径 3000m 以内）に依存するため、**カメラ → ピン表示数 → カメラ** の循環になり、実測で 10fps でズームイン / ズームアウトを往復し続けた。フォアグラウンドでは「重い」だけだが、位置情報の許諾ダイアログで Background に入った瞬間にウォッチドッグでアプリが強制終了する（TestFlight ビルド 28 / 29 の実障害。詳細は lessons 2026-08-09、規約は `coding-conventions.md` §2.3）。

---

## カラー

### システムカラーを優先する

独自カラーより `Color` のシステムカラーを優先します。ダークモード・アクセシビリティ対応が自動的に得られます。

```swift
// Good
Text("カフェ名").foregroundStyle(.primary)
Rectangle().fill(Color(.systemBackground))
Button("保存") { }.tint(.accentColor)

// Bad
Text("カフェ名").foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
```

### カラーの役割定義

| 役割 | 使用するカラー |
|------|--------------|
| プライマリテキスト | `.primary` |
| セカンダリテキスト | `.secondary` |
| 背景 | `Color(.systemBackground)` / `Color(.secondarySystemBackground)` |
| グループ背景 | `Color(.systemGroupedBackground)` |
| アクセント | `.accentColor`（`Assets.xcassets` で定義） |
| 危険操作 | `.red` |
| 成功・完了 | `.green` |

### ダークモード対応

- ハードコードを避け、Color Set でライト / ダークを両方定義する
- 画像は **テンプレート画像** または SF Symbols を使い、自動で前景色が反映されるようにする

---

## タイポグラフィ

### Dynamic Type を必ず使用する

固定サイズの `font(.system(size: 14))` ではなく、Dynamic Type スタイルを使用します。

```swift
// Good
Text("カフェ名").font(.headline)
Text("メモ").font(.body)
Text("2026/06/02").font(.caption)

// Bad
Text("カフェ名").font(.system(size: 17, weight: .semibold))
```

### テキストスタイルの使い分け

| スタイル | 用途 |
|---------|------|
| `.largeTitle` | 画面タイトル（NavigationStack の大見出し） |
| `.title` / `.title2` / `.title3` | セクションタイトル |
| `.headline` | カードのメインラベル（カフェ名・コーヒー名） |
| `.body` | 通常の本文テキスト（メモなど） |
| `.subheadline` / `.callout` | 補足情報（産地・抽出方法） |
| `.footnote` / `.caption` | 日付・更新時刻などのメタ情報 |

---

## スペーシング・レイアウト

### 余白は 8pt グリッドを基準にする

| サイズ | 用途 |
|-------|------|
| `4pt` | 最小マージン（アイコンとラベルの間など） |
| `8pt` | コンポーネント内の標準スペース |
| `16pt` | コンテンツの水平パディング（画面端からの余白） |
| `24pt` | セクション間のスペース |
| `32pt` | 大きなセクション区切り |

```swift
// Good
VStack(spacing: 8) { ... }
    .padding(.horizontal, 16)

// Bad
VStack(spacing: 11) { ... }
    .padding(.horizontal, 13)
```

### Safe Area を尊重する

コンテンツが Safe Area に重ならないようにします。カスタム背景や全画面写真ビューワなど意図的にはみ出す場合のみ `.ignoresSafeArea()` を使用します。

---

## コンポーネント

### ネイティブコンポーネントを優先する

| 用途 | 使用するコンポーネント |
|------|----------------------|
| 一覧表示 | `List` または `ScrollView` + `LazyVStack` |
| グリッド表示 | `LazyVGrid` |
| 画面遷移 | `NavigationStack` / `NavigationLink` |
| タブ切り替え | `TabView` |
| モーダル | `.sheet` / `.fullScreenCover` |
| アラート・確認 | `.alert` / `.confirmationDialog` |
| アクション選択 | `.contextMenu` / `Menu` |
| 入力 | `TextField` / `Toggle` / `Picker` |
| 評価入力 | カスタム `StarRatingView`（SF Symbol `star.fill` を 5 つ並べる） |
| 写真ピッカー | `PhotosPicker`（PhotosUI） |

### ボタン

- 主要アクションは `.buttonStyle(.borderedProminent)`
- 危険な操作（削除など）には `.tint(.red)` を付与
- アイコンボタンには `Label` を使い、アクセシビリティラベルを持たせる

#### 追加アクションの配置（2026-08-07 確定）

**「新規作成」は必ず `ToolbarItem(placement: .topBarTrailing)` の `plus` に置く。FAB（`overlay(alignment: .bottomTrailing)` の円形ボタン）は使わない。** 同じ「コーヒーを記録」がコーヒー記録一覧では右下 FAB、カフェ詳細では右上 `+` と 2 通りに分かれていたのを統一したもの（2026-08-07、UX-3）。FAB は iOS 標準の語彙ではなく、加えてリスト最下行に重なって内容を隠していた。

画面内に空状態の CTA を別途置くのは構わない（`ContentUnavailableView` の `description` など）。ただし**その文言が追加ボタンの位置を指す場合、ボタンを動かしたら必ず一緒に直す** — 「右下の + ボタンから」のような位置参照は、配置変更のたびに腐る。位置を書かずに済むなら書かない方が安全。

なお**マップの現在地 FAB（`currentLocationFAB`）はこの規則の対象外**。「新規作成」ではなく地図の視点操作で、Apple/Google マップとも同じ位置に置く慣習がある。

```swift
// 主要アクション
Button("保存") { viewModel.onSaveTapped() }
    .buttonStyle(.borderedProminent)

// 危険アクション
Button(role: .destructive) {
    viewModel.onDeleteTapped()
} label: {
    Label("削除", systemImage: "trash")
}

// アイコンボタン
Button { viewModel.onAddTapped() } label: {
    Label("追加", systemImage: "plus")
        .labelStyle(.iconOnly)
}
```

### アイコン

- アイコンは **SF Symbols** を使用する
- 一貫性のため、画面共通の意味には共通のシンボルを使う
- ⚠️ **これはアプリ内 UI に限った話**。SF Symbols のライセンス条項はシンボルを**アプリアイコン / ロゴ / 商標**に使うことを禁じているため、`AppIcon` と `LaunchLogo` には使えない。両者は `iosApp/scripts/generate_app_icon.swift` の自前パス描画で生成する（2026-08-06 に SF Symbol 焼き込みから移行。implementation_note 2026-08-06）

| 意味 | SF Symbol |
|------|----------|
| カフェ / 場所 | `cup.and.saucer.fill` / `mappin.and.ellipse` |
| 評価 | `star.fill` / `star` |
| 写真 | `photo` / `photo.stack` |
| メモ | `text.alignleft` |
| 編集 | `pencil` |
| 削除 | `trash` |
| 追加 | `plus` |
| 検索 | `magnifyingglass` |
| お気に入り | `heart.fill` / `heart` |

---

## ナビゲーション

### NavigationStack を使用する

- `NavigationStack` + `NavigationLink` で画面遷移を管理する
- 深い階層に潜るときは `NavigationStack(path:)` で `path` を ViewModel に持たせ、`pop` 操作を制御可能にする

### 画面タイトル

- 各画面に `.navigationTitle()` を必ず設定する
- 一覧画面: `.navigationBarTitleDisplayMode(.large)`
- 詳細・編集画面: `.navigationBarTitleDisplayMode(.inline)`

```swift
NavigationStack {
    CoffeeListView(...)
        .navigationTitle(String(localized: "コーヒー記録"))
        .navigationBarTitleDisplayMode(.large)
}
```

### モーダル

- コーヒー記録の作成・編集のような一連の入力フローは `.sheet` で表示する
- 写真の全画面表示を作るときは `.fullScreenCover` を使う（**2026-08-08 時点で未実装**。下記「写真表示」参照）

---

## フィードバック

ユーザー操作に対して適切なフィードバックを返します。

| 状況 | フィードバック手段 |
|------|-----------------|
| ロード中 | `ProgressView()` |
| 保存成功 | `.sensoryFeedback(.success, trigger:)` + 軽いトースト or 自動 dismiss |
| エラー | `.alert` でメッセージ表示 + `.sensoryFeedback(.error, trigger:)` |
| 削除・完了 | `.sensoryFeedback(.impact, trigger:)` |
| 同期中 | ナビゲーションバーに控えめなインジケータ |

```swift
List { ... }
    .sensoryFeedback(.success, trigger: viewModel.state.savedAt)
```

---

## 写真表示

- 一覧・検索結果行では 1 枚をサムネイル表示（読み込み方法は下表）
- 詳細では `ScrollView(.horizontal)` + `LazyHStack` で複数枚を横スワイプ
- **全画面表示（`.fullScreenCover` + ピンチズーム）は未実装**（2026-08-08 に SW6-A の調査で判明。`fullScreenCover` / `MagnificationGesture` とも実装が存在しない）。実装する場合の方針としてこの行を残すが、**現状の写真表示は一覧・詳細・カフェ詳細の 3 サイズのサムネイルのみ**。なお [`requirements.md`](./requirements.md) §未決事項の保存解像度 2048px は「全画面表示（6.7 インチ @3x = 1290px）にも余裕がある」ことを根拠の 1 つにしているため、**未実装でも解像度の前提としては生きている**

**記録写真と Places 写真は読み込み方針が違う**。同じ横スクロール帯（`CafePhotoHeader`）に並べても、UI の作り方を揃えてはいけない。

| | 記録写真（ユーザーが撮った写真） | Places 写真（カフェの写真） |
|---|---|---|
| 取得元 | 端末ローカル（`<Documents>/photos/`、`PhotoFileStore`）。**保存時に長辺を縮小してから書き出す**（`ImageDownsampler`。解像度・品質の値は [`requirements.md`](./requirements.md) が正） | Places Photo Media API の時限署名 URL を都度取得（`PlacePhotoLoader` → `PlacePhotoThumbnail` の `AsyncImage`） |
| キャッシュ | 端末に永続保存（クラウド同期対象外。[`requirements.md`](./requirements.md) §7-2） | **独自の永続キャッシュは Places 規約で禁止**。`URLSession` / `AsyncImage` の標準 HTTP キャッシュのみ許容 |
| 表示枚数 | **添付されている全件を表示する**（View 側で絞らない）。ただし添付そのものに 1 記録あたりの上限があり、エディタのピッカー側で制限する（枚数は [`requirements.md`](./requirements.md) が正） | **View 側で絞る**。画面再表示のたびに再リクエスト＝課金されるため（枚数と上限は [`paid-services.md`](./paid-services.md) が正） |
| 失敗時 | `photo.badge.exclamationmark`（ファイル欠損を示す） | `photo`（ロード中は `ProgressView`） |
| アクセシビリティ | 記録の一部なのでラベルを付ける | 装飾扱いで `.accessibilityHidden(true)`（`PlacePhotoThumbnail` 側で付与済み） |

Places 写真に「一度読んだら保持する」独自キャッシュ層を挟む設計は規約違反になるため採らない。多く見せたい場合はキャッシュではなく段階読み込み（「さらに表示」でユーザー操作を挟む）で対応する。

---

## アクセシビリティ

HIG はアクセシビリティを必須要件として位置づけています。

### ラベルの付与

すべてのインタラクティブ要素にはアクセシビリティラベルを設定します。

```swift
Button { viewModel.onAddTapped() } label: {
    Image(systemName: "plus")
}
.accessibilityLabel("訪問記録を追加")
```

### コントラスト比

- テキストとその背景のコントラスト比は **4.5:1 以上**（WCAG AA 準拠）を確保する
- システムカラーを使用していれば自動的に満たされる

### タップ領域

タップ可能な要素の最小サイズは **44×44pt** を確保します。

```swift
Button { ... } label: {
    Image(systemName: "ellipsis")
}
.frame(minWidth: 44, minHeight: 44)
```

### 評価入力（星）

- 各星にアクセシビリティラベル（「1 星」「2 星」…）を付ける
- VoiceOver 利用時は `Stepper` 相当の挙動を提供する

### VoiceOver 対応

- 装飾的な画像には `.accessibilityHidden(true)` を付与する
- 複数要素をグループ化する場合は `.accessibilityElement(children: .combine)` を使用する

---

## アニメーション

- アニメーションは `.animation(.default, value:)` を使用し、変化のトリガーを明示する
- 過度なアニメーションはユーザーの集中を妨げるため避ける
- **Reduce Motion** 設定を尊重する

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var fadeAnimation: Animation? {
    reduceMotion ? nil : .easeInOut(duration: 0.2)
}

List { ... }
    .animation(fadeAnimation, value: viewModel.state.visits)
```

---

## エラー表示

- 致命的でないエラー（同期失敗・検索失敗など）は **画面上にバナー or トーストで控えめに表示**
  - 共通コンポーネント `View.errorToast(message:onDismiss:)`（`iosApp/iosApp/Components/ErrorToast.swift`）を使う。上部スライドイン / 約 4 秒で自動消去 + タップ・上スワイプで手動消去
  - 複数のエラー源がある画面（現状は `MapTabView` の `bridge.error` + `bridge.poiLookupError` + エリア検索 0 件の案内）は `activeToast` で優先順位付き単一値に集約し、`.errorToast` は 1 つだけ付ける（`.overlay(alignment: .top)` の衝突回避）。エラー源が 1 つの画面はそのまま `.errorToast(message: bridge.error)` でよい
  - 表示時に `AccessibilityNotification.Announcement` を投稿（VoiceOver 対応済）。`accessibilityReduceMotion` true 時は opacity のみで遷移
- 致命的なエラー（保存失敗など）、およびアクションを伴うエラー（位置情報許可拒否 → 設定アプリ誘導など）は `.alert` で確認を求める
- ネットワーク不通は「オフライン」表示にとどめ、Firestore の自動同期に任せる

---

## ローカライズ

- MVP は **日本語のみ**
- 文字列は `String(localized:)` を使い、将来の i18n に備える

```swift
Text(String(localized: "訪問記録"))
```

---

## 参考リンク

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [Dynamic Type](https://developer.apple.com/documentation/uikit/uifont/scaling_fonts_automatically)
- [アーキテクチャ方針](./architecture.md)
- [コーディング規約](./coding-conventions.md)
