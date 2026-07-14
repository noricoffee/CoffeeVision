---
name: admob-native-ads
description: Google Mobile Ads SDK（AdMob）ネイティブ広告 + UMP SDK を SPM 導入するときの実地 API 確認手順とハマりどころ
metadata:
  type: project
---

## SPM パッケージと実際の Swift モジュール名（2026-07-14、v13.6.0 で確認）

- 公式 SPM パッケージは `https://github.com/googleads/swift-package-manager-google-mobile-ads`。
  products は `GoogleMobileAds` の 1 つだけ（Firebase と違い複数プロダクトはない）。この Package.swift の
  `GoogleMobileAdsTarget` が内部で別パッケージ `swift-package-manager-google-user-messaging-platform`
  （product 名 `GoogleUserMessagingPlatform`）に依存しており、**アプリの pbxproj には
  `GoogleMobileAds` 1 プロダクトだけ追加すれば UMP も自動的にリンクされる**（別途 UMP パッケージを
  明示追加する必要はない）。
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
  付き `MobileAds` / `NativeAd` / `AdLoader` / `Request` / `Extras` / `RequestConfiguration` /
  `NativeAdView` / `MediaView` / `AdChoicesView` 等プレフィックスなしで使える）。
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

## ネイティブ広告のレンダリングは UIKit 必須（SwiftUI 公式ビューは存在しない）

- `NativeAdView`（旧 `GADNativeAdView`）は `UIView` サブクラスで、`headlineView` / `bodyView` /
  `callToActionView` / `iconView` / `advertiserView` / `mediaView`（`MediaView` 型必須） /
  `adChoicesView`（`AdChoicesView` 型必須）の弱参照プロパティを持つ。これらに好きな `UIView` を
  差し込んで最後に `adView.nativeAd = nativeAd` を代入するとクリック登録まで自動で行われる
  （`registerAdView(_:clickableAssetViews:nonclickableAssetViews:)` という低レベル API は
  カスタムアセット向けで通常は不要）。
- `SwiftUI` からは `UIViewRepresentable` でラップする以外に方法がない。CTA ボタンは
  `isUserInteractionEnabled = false` にして SDK 側のジェスチャー認識に委ねる（公式サンプルの作法）。
- `headline` 以外は全部 optional アセットのため、`mediaView` を省略して
  アイコン+テキスト+CTA だけの「Small テンプレート」相当にしても AdMob ポリシー上問題ない
  （行の高さを既存 UI と揃えたいときに有効）。

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

## xcodebuild 検証中に DerivedData の `rm -rf` を中断すると SPM checkout が壊れる

- `rm -rf DerivedData/iosApp-*` の途中で `Directory not empty` エラーが出て中断されると、
  次の `-resolvePackageDependencies` が
  `invalid custom path 'FirebaseCore/Extension' for target 'FirebaseCoreExtension'` や
  `Package.swift ... doesn't exist in file system` のような不可解なエラーを出す
  （SourceKitService 等が同時にファイルを触っているため rm が完走しないことがある、
  [[xcodebuild-verification]] 参照）。**同じ `rm -rf` をもう一度実行するだけで直る**ことが多い
  （2 回目で完全に消える）。原因調査に時間をかけず、まず再実行する。
