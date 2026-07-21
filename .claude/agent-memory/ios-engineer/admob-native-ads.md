---
name: admob-native-ads
description: Google Mobile Ads SDK（AdMob）アダプティブバナー広告（旧ネイティブ広告） + UMP SDK を SPM 導入するときの実地 API 確認手順とハマりどころ
metadata:
  type: project
---

## 広告フォーマットはネイティブ→アダプティブバナーへ再編済み（2026-07-14 同日）

当初はネイティブ広告で実装したが、テスト広告の validator で **MediaView（最小 120×120pt）が必須アセット**と判明。
コンパクト枠（ドロップダウン行 / 下部固定枠）に 120pt のメディアを組み込むとバナー（50〜90pt）より
大きく悪目立ちし「UI に溶け込む」前提が崩れたため、**全面アダプティブバナーに再編**した
（requirements.md §11、implementation_note 2026-07-14）。以下はバナー実装の知見。ネイティブ広告の
UIKit レンダリング知見（`NativeAdView` の headlineView 等）は不要になったため本メモリから削除済み
（過去のネイティブ広告実装は git 履歴参照）。

## SPM パッケージと実際の Swift モジュール名（2026-07-14、v13.6.0 で確認）

- 公式 SPM パッケージは `https://github.com/googleads/swift-package-manager-google-mobile-ads`。
  products は `GoogleMobileAds` の 1 つだけ（Firebase と違い複数プロダクトはない）。この Package.swift の
  `GoogleMobileAdsTarget` が内部で別パッケージ `swift-package-manager-google-user-messaging-platform`
  （product 名 `GoogleUserMessagingPlatform`）に依存しており、**アプリの pbxproj には
  `GoogleMobileAds` 1 プロダクトだけ追加すれば UMP も自動的にリンクされる**（別途 UMP パッケージを
  明示追加する必要はない。ただし UMP は**コードから呼ばない**方針に変更済み。後述）。
- Swift の `import` 文はプロダクト名と一致しない: `import GoogleMobileAds` と `import UserMessagingPlatform`
  （`GoogleUserMessagingPlatform` ではない）。xcframework の module map 名で確定するので、
  実際に `xcodebuild -resolvePackageDependencies` してから
  `DerivedData/.../SourcePackages/artifacts/**/Modules/module.modulemap` の `framework module <name>`
  行を見て確認するのが確実。
- pbxproj 追加手順は [[firebase-remote-config-spm]] と同じ 4 箇所パターンで通る（新規プレフィックス
  `AD00000...` を割り当てた。`FB` と衝突しなければ任意の連番でよい）。

## バージョン指定は具体的な最新メジャーを明示すること（`upToNextMajorVersion` の罠）

- `minimumVersion` を控えめな値（例 11.0.0）にすると `upToNextMajorVersion` は**そのメジャー内の最新**
  （11.13.0）を解決し、実際の最新メジャー（13.6.0）を取り逃す。GoogleMobileAds は v11→v13 で
  Swift 向け `NS_SWIFT_NAME` リネームが大幅に入った（v11 系は ObjC ヘッダに `NS_SWIFT_NAME` が
  ほぼ皆無で `GAD` プレフィックスのまま Swift に見える。v13 系は主要クラスに `NS_SWIFT_NAME` が
  付き `MobileAds` / `BannerView` / `AdLoader` / `Request` / `Extras` / `RequestConfiguration` /
  `AdSize` 等プレフィックスなしで使える）。
  **API ドキュメントや公式サンプルがプレフィックスなしのクラス名を使っていたら、pbxproj の
  `minimumVersion` を現行最新メジャーに合わせて明示的に引き上げる**（GitHub の Releases/tags で
  実際の最新版を確認してから固定する。Package.swift の記載やコード生成 AI の記憶だけを信じない）。
- 一方 **UMP SDK（`swift-package-manager-google-user-messaging-platform`, v2.7.0 時点）は
  `NS_SWIFT_NAME` が一切無く、`UMPConsentInformation.sharedInstance` / `UMPConsentForm` /
  `UMPRequestParameters` / `UMPDebugSettings` のように `UMP` プレフィックスが Swift 側でもそのまま残る**。
  AI が生成する「Google 公式ドキュメント要約」は `ConsentInformation.shared` のような
  プレフィックスなし表記を提示してくることがあるが、これは実装が伴わない誤り（少なくとも
  2.7.0 時点）。**必ず実際にダウンロードしたヘッダの `NS_SWIFT_NAME` の有無で裏取りする**
  （`grep NS_SWIFT_NAME` がゼロ件ならプレフィックスは残る）。

## UMP はコードから呼ばない（コンソール構成に挙動が依存し二重表示するため）

- `UMPConsentInformation.sharedInstance.requestConsentInfoUpdate` →
  `UMPConsentForm.loadAndPresentIfRequired` を呼ぶと、AdMob コンソールに ATT メッセージ（IDFA 説明）が
  構成されている場合、**GDPR 圏外でも ATT が `.notDetermined` なら UMP が `consentStatus` を
  `.required` 扱いにする**ため、自前のプレプロンプト + ATT ダイアログの直後にさらに UMP 側の
  英語ダイアログが二重表示される（2026-07-14 実機で 2 回再現）。`.required` ガードを付けても
  コンソール構成（フォールバックのテスト App ID には ATT メッセージが構成済み）次第で素通りする。
  **「条件を狭めて呼ぶ」対応では解決しない。UMP の呼び出し自体を撤去するのが正解**（`canRequestAds`
  も常に `false` になるため広告ロードのゲートに使ってはいけない）。SDK 自体のリンクは
  Google Mobile Ads SDK の内部依存として残るが、コードからは一切参照しない。日本のみ配信なら
  実害なし。EU 配信を始めるときだけ GDPR フォーム実装として再導入する。

## アダプティブバナーの Swift API（v13.6.0 実測）

- 型: `BannerView`（`UIView` サブクラス、`GADBannerView` の Swift 名）。生成は
  `BannerView(adSize:)`、`adUnitID` / `rootViewController` / `delegate`（`BannerViewDelegate`）を
  設定し `isAutoloadEnabled = false` にした上で `bannerView.load(Request())` を呼ぶ
  （`loadRequest:` は Clang importer の型名重複除去で Swift からは `load(_:)` になる）。
- サイズ計算はすべて **グローバル関数**（型のstatic memberではない）。`AdSize`（`GADAdSize`）を返す:
  - `largeAnchoredAdaptiveBanner(width:)` — アンカー（下部固定）用、現在の画面向きに対応した
    「Large」版。**`currentOrientationAnchoredAdaptiveBanner(width:)` は非推奨**（ヘッダに
    `GAD_DEPRECATED_MSG_REPLACEMENT_ATTRIBUTE` で `GADLargeAnchoredAdaptiveBannerAdSizeWithWidth`
    への置き換えが明記されている）。ドキュメント上の古いサンプルがこの非推奨名を使っていても、
    実装時は `largeAnchoredAdaptiveBanner(width:)` を使うこと。
  - `inlineAdaptiveBanner(width:maxHeight:)` — インライン（リスト行等）用、非推奨ではない。
    Google 公式サンプル（`googleads/googleads-mobile-ios-examples` リポジトリ）の
    `Swift/admob/BannerExample` で `bannerView.adSize = largeAnchoredAdaptiveBanner(width: 375)` の
    ような裸の（型に紐付かない）呼び出しが確認できる。GitHub の生ファイルは
    `curl -sL https://raw.githubusercontent.com/googleads/googleads-mobile-ios-examples/main/...`
    で読める（`gh`/WebFetch が 404 でも curl で通ることがある）。
- delegate: `BannerViewDelegate.bannerViewDidReceiveAd(_:)` / `bannerView(_:didFailToReceiveAdWithError:)`。
- レイアウトは `BannerView` 自身の `intrinsicContentSize`（ロード後の実サイズ）に委ね、
  `UIViewRepresentable` ラッパーに明示的な `.frame()` を付けない方が正しく収まる。

## NPA（非パーソナライズ広告）の指定方法

- `Extras().additionalParameters = ["npa": "1"]` を作り `request.register(extras)`
  （メソッド名は `registerAdNetworkExtras:` だが Clang importer の型名重複除去で Swift からは
  `register(_:)` になる）。ATT 拒否時にリクエストへ都度付与する方式で、グローバル設定
  `RequestConfiguration.publisherPrivacyPersonalizationState` より簡潔・実績があるので優先採用。

## `MobileAds.shared.start()` は同意フローと切り離してアプリ起動時に呼んでよい

- SDK 起動（mediation 初期化含む）自体は ATT/UMP の結果を待つ必要がない
  （公式ドキュメントも「できるだけ早く呼ぶ」と明記）。パーソナライズ可否は
  **広告リクエストを組み立てる瞬間**に `ATTrackingManager.trackingAuthorizationStatus` を
  見て NPA extras を付けるかどうかで制御すれば十分。同意フロー完了を待ってから start() すると
  セッション最初の広告のレイテンシが悪化するだけで得るものがない。

## SwiftUI で非同期ロードをトリガーする `.task` は「常に実体化されるビュー」に付けること

- `Group { if let x { View() } }.task { ... }` は、条件が偽（実質 `EmptyView`）の初回描画時に
  `.task` の付け先が実体化されず発火しないことがある（2026-07-14 実機診断で確認。ネイティブ広告→
  バナー広告どちらの実装でも該当）。`ZStack { if let ... }.task { ... }` や
  `.background(GeometryReader { ... }.task { ... })`（`Color.clear` は常に実体化される）のように、
  **条件分岐の外側にある、常に存在するコンテナに `.task` を付ける**。
- `List` の `Section` は中身が空でも行の余白・区切り線を描画しうるため、「未ロード時は畳む」対応を
  コンポーネント内部（`Group`/`ZStack` で高さ 0）だけに頼ると空の Section が見た目に残ることがある。
  ロード状態を親（画面側）に持ち上げ、**未ロード時は Section 自体を List の body に含めない**
  ようにする（`CafeDetailView.adSection` 参照）。ただしこの場合、ロードトリガー（`.task`）は
  その Section とは別の、常に List の body に含まれる場所（List 自体への `.background(GeometryReader)`
  等）に置く必要がある（Section 表示条件と読み込みトリガーを同じ条件にすると鶏卵問題になる）。

## インラインアダプティブバナーの幅計測: List 行では `.background(GeometryReader)` が安全

- `GeometryReader` をプライマリコンテンツとして使うと親のレイアウトを乱すことがあるが、
  `.background(GeometryReader { ... })` は「先に自分のサイズを確定してから、その背景として
  受動的に計測する」ため安全（widely-used SwiftUI サイズ計測パターン）。`.frame(maxWidth: .infinity)`
  を先に付けて幅方向に greedy にしてから計測すると、List/LazyVStack の行幅を正確に取れる。
- タブバー直上の `.safeAreaInset(edge: .bottom)` に載せるアンカーバナーも同じパターンで統一できる
  （safeAreaInset 自身が定義済みの幅を content closure に渡すため、GeometryReader が
  unbounded になる心配はない）。

## 広告面の撤去（2026-07-16、コーヒー記録タブ / 分析タブの 2 面を撤去し 4 面→2 面に）

- ユーザビリティレビューでバナー 4 面中 2 面（コーヒー記録タブ先頭インライン / 分析タブ下部固定）を
  撤去。カフェ詳細・マップ検索ドロップダウンの 2 面と ATT/プレプロンプトフローは維持。
- `iosApp.xcodeproj` は `PBXFileSystemSynchronizedRootGroup`（Xcode 16 同期グループ）なので、
  ファイル削除は `rm` だけで足り、`project.pbxproj` の手動編集は不要（ビルドログに
  `note: Removed stale file '.../AnchoredBannerAdView.o'` が出て自動追随を確認できる）。
- 削除順序: View 側の宣言・組み込み箇所を先に消してから専用コンポーネントファイルを `rm`。
  共有コンポーネント（`BannerAdLoader.swift` 等）は残存面が使うため触らず、doc コメント中の
  「4 面」「AnchoredBannerAdView」への言及だけ更新（コードには影響しない）。
- `AdUnitIDs.swift` の定数削除と `Info.plist` の対応キー削除、`Base.xcconfig` のフォールバック
  宣言削除はセットで行う（3 箇所は必ず揃える。1 つでも残すとダングリング参照になる）。

## `LazyVStack` の N 番目要素に埋め込んだ `InlineBannerAdView` は、シートが既定 detent（peek/fold）で開くと初回ロードされない（2026-07-22、マップ検索結果下部シート回帰で確認）

- `InlineBannerAdView` 自身の `.task` トリガーは「常に実体化されるビュー」に付ける設計だが、それは
  **自分自身が実体化されて初めて発火する**。`LazyVStack` の N 番目行として埋め込むと、fold 下
  （スクロール到達前）では行自体が生成されず `.task` が一度も走らない。`CafeDetailView` の広告面は
  `List`（`.insetGrouped`）の Section 内だが、**List 自身に別途 `.background(GeometryReader).task`
  を付けて先読みロードしている**ため気づきにくい落とし穴になっていた。
- 修正パターン: 広告行を囲む**常に実体化されるコンテナ**（シートのルート `VStack` 等）の
  `.background(GeometryReader { proxy in Color.clear.task(id: ...) { loader.load(...) } })` から
  先読みロードをトリガーし、`LazyVStack` 内の `InlineBannerAdView` 自体はそのまま残す
  （`BannerAdLoader` が `isLoaded` 済みなら行が実体化された瞬間に即描画される。二重 `load()` は
  `pendingAdSize` 機構が吸収するので無害）。`.task(id:)` の合成キーは「幅（Int 丸め）+ 表示条件
  （例: 結果件数 >= 3）」の文字列結合にすると、条件が false→true に変わったときや幅変化時に
  再発火する。
- **`.background(GeometryReader{...})` 経由で `inlineAdaptiveBanner` / `BannerAdLoader` を直接
  呼ぶファイルには `import GoogleMobileAds` が必要**（`InlineBannerAdView.swift` 側で完結していた
  ときは不要だったが、呼び出し元の View ファイルに処理を持ち上げると新規 import 漏れでビルドエラー
  `cannot find 'inlineAdaptiveBanner' in scope` になる）。

## xcodebuild 検証中に DerivedData の `rm -rf` を中断すると SPM checkout が壊れる

- `rm -rf DerivedData/iosApp-*` の途中で `Directory not empty` エラーが出て中断されると、
  次の `-resolvePackageDependencies` が
  `invalid custom path 'FirebaseCore/Extension' for target 'FirebaseCoreExtension'` や
  `Package.swift ... doesn't exist in file system` のような不可解なエラーを出す
  （SourceKitService 等が同時にファイルを触っているため rm が完走しないことがある、
  [[xcodebuild-verification]] 参照）。**同じ `rm -rf` をもう一度実行するだけで直る**ことが多い
  （2 回目で完全に消える）。原因調査に時間をかけず、まず再実行する。
