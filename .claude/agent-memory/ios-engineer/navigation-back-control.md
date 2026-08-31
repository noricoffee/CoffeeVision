---
name: navigation-back-control
description: NavigationStack の入れ子検出と、処理中の「戻る」を封じる実装パターン（戻るボタン + エッジスワイプ）
metadata:
  type: project
---

## push される画面は自身を `NavigationStack` で包まない（2026-08-21、AccountView SR-1 残務で確認）

- `NavigationLink { InnerView() }` で push される `InnerView` が自身の `body` で `NavigationStack { ... }` を作ると、outer/inner で 2 つの独立した `UINavigationController` が積み重なる。inner 側は自分のスタックの root なので back button を持たず、実際に画面遷移（back button・戻るジェスチャー）を握っているのは outer 側になる。
- この状態だと `.navigationBarBackButtonHidden` / `.toolbar` の back 制御を **inner 側**（＝ push された画面自身）に書いても outer の back button には効かない。「完了ボタンの無効化しかできなかった」という過去の残務コメントはこれが原因。
- 検出方法: `grep -rln "NavigationStack {" iosApp/iosApp --include="*.swift"` で全候補を洗い出し、各ファイルの呼び出し元を `grep "ViewName("` で追う。呼び出し元が `NavigationLink { ... }` の中（push）なら nested バグ候補、`.sheet { ... }` の中（モーダル）ならその画面が自分の `NavigationStack` を持つのが正しいパターン（sheet は独立したナビゲーション文脈が必要）。
- 修正: push される画面は `NavigationStack` を持たず `Form`/`List`/`ScrollView` に直接 `.navigationTitle` 等を付ける。コメントで「◯◯ の NavigationStack に push される前提のため自身では包まない」を明記しておく（`CoffeeDetailView` に既に同種のコメントがある実例）。
- **横断点検で他に 1 件見つかった**（`TastePreferenceConversionView`、`AnalysisView` から `NavigationLink` で push されるのに自身で `NavigationStack` を持つ）。ただし「戻るを封じる」要件は無く見た目の崩れ（二重ナビゲーションバー）に留まる可能性がある実害未確認の指摘のため、今回は対象タスク（AccountView）のみ修正し、この 1 件は親へ報告に留めた。

## 処理中は「戻る」の全経路（ボタン + エッジスワイプ）を封じる

- `.navigationBarBackButtonHidden(condition)` は back **ボタンの表示**のみを止める。**エッジスワイプでの pop は別経路**で、これだけでは止まらない。
- エッジスワイプを止めるには `UINavigationController.interactivePopGestureRecognizer.isEnabled` を直接操作する必要があり、SwiftUI 単体の modifier では届かない。`UIViewControllerRepresentable` で不可視の `UIViewController` を `.background()` に挿入し、その `navigationController` を辿って `isEnabled` を切り替えるブリッジが必要（プロジェクトでは `iosApp/iosApp/Utilities/InteractivePopGestureLock.swift` として汎用化済み。`.background(InteractivePopGestureLock(isLocked: viewModel.isProcessing))` で使う）。
- 実装上の注意: `makeUIViewController` の時点では `navigationController` が未確定（nil）のことがあるため `viewDidAppear` でも再適用する。`viewWillDisappear` で必ず `isEnabled = true` に戻す（同じ `UINavigationController` を共有する後続の push 画面までロックを引きずらないため）。
- 検証: サンドボックスに GUI シミュレータが無くタップ操作ができないため（[[sandbox-no-gui-simulator]]）、このパターンの実機能検証（本当にスワイプが止まるか）はビルド成功だけでは確認できない。親経由でユーザーに実機 / シミュレータでの確認を依頼する。
