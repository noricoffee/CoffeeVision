# CoffeeVision UI/UX ガイドライン（iOS / SwiftUI）

## 概要

本ドキュメントは CoffeeVision の **iOS（SwiftUI）** における UI/UX 設計方針を定めます。
Apple の **Human Interface Guidelines（HIG）** をベースとし、iOS ネイティブの体験に沿った一貫性のある UI を提供することを目的とします。

> Android（Compose Multiplatform）の UI ガイドラインは将来 `sharedUI/` を実装する段階で別途追加します。

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

| 役割 | 色（仮） | 備考 |
|------|---------|------|
| アクセント | `Color("AccentBrown")`（例: `#8B5A2B`） | `Assets.xcassets` の AccentColor として設定 |
| 評価の星 | `.yellow`（システム） | アクセシビリティ対応のため標準色を使用 |

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
    VisitListView(viewModel: ...)
        .navigationTitle("訪問記録")
        .navigationBarTitleDisplayMode(.large)
}
```

### モーダル

- Visit 作成のような一連の入力フローは `.sheet` で表示する
- 写真の全画面表示は `.fullScreenCover` を使う

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

- 一覧では `AsyncImage` または独自のキャッシュ画像 View でサムネイル表示
- 詳細では `ScrollView(.horizontal)` + `LazyHStack` で複数枚を横スワイプ
- 全画面表示は `.fullScreenCover` + `MagnificationGesture` でピンチズーム
- ローカルにキャッシュがあれば優先表示し、Storage URL からの再取得は非同期で行う

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

- 致命的でないエラー（同期失敗など）は **画面上にバナー or トーストで控えめに表示**
- 致命的なエラー（保存失敗など）は `.alert` で確認を求める
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
