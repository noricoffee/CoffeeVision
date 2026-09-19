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

## 全画面下部固定バナー（2026-09-19、requirements.md §11-5 第 1 段）

- **`currentOrientationAnchoredAdaptiveBanner(width:)` は非推奨と分かっていても親から明示指定されることがある**。
  本メモリの上の項目（v13.6.0 実測）で「実装時は `largeAnchoredAdaptiveBanner(width:)` を使うこと」と
  結論していたにもかかわらず、dispatch 指示は当初非推奨の `currentOrientationAnchoredAdaptiveBanner`
  を名指ししていた。**着手前にメモリを見ていても、指示が古い知見と矛盾することがある**。実装は一旦指示に
  従いつつ、コード doc コメント + レポートの両方に矛盾を明記して親の判断を仰いだところ、
  親が実ヘッダで裏取りして `largeAnchoredAdaptiveBanner(width:)` への切り替え指示に修正した
  （2026-09-19、修正後の最終形）。**「指示 vs メモリの矛盾」を握ったまま黙って指示に従うだけでなく、
  レポートで明示すれば指示自体が正しい方向に修正される**（今回そうなった）。
- **`isAutoloadEnabled` は常設枠のリフレッシュ手段としては不採用が無難**。理由は実測ではなく公式ヘッダの
  記述の限界: `GADBannerView.h` は「有効にすると `load(_:)` を呼ばなくてよい」としか書いておらず、SDK が
  自動生成するリフレッシュリクエストに独自の `Request`（NPA extras 含む）が反映されるかは
  ドキュメント上確認できない。`developers.google.com/admob/ios/banner` の "Refresh an ad" も
  「広告ユニット側の設定を SDK が尊重する」としか言わず、リフレッシュ間隔がコード側で完結しない
  （AdMob コンソール設定に依存）。**ATT 拒否ユーザーへの NPA 徹底が絡む箇所をコンソール設定任せに
  するリスクを避けるなら、クライアント側タイマー（`load(adSize:forceReload:)` を追加して
  `scenePhase == .active` 限定で 60 秒間隔ループ）の方が全ロジックがコード内で完結し安全**。
- **`GADRequestConfiguration.publisherPrivacyPersonalizationState`** は
  `MobileAds.shared.requestConfiguration` 経由のグローバル設定で、ヘッダに「settings in this class
  will apply to all ad requests」とあるため per-request の `Extras`(NPA) より広く効く可能性がある候補だが、
  「autoload のリフレッシュ要求にも適用されるか」を明言した記述が見つからず今回は不採用。将来 autoload を
  再検討するならまずここを深掘りする価値がある。
- **`BannerAdLoader.load(adSize:forceReload:)`**: 既存の「同一サイズなら no-op」ガードに
  `forceReload: Bool = false` を追加するだけで、タイマー駆動の強制リフレッシュと既存 2 面の
  無限リロード防止を両立できた（呼び出し元を増やすたびに新しいローダーを作るのではなく、
  1 つのメソッドにオプション引数を足す方が影響範囲が小さい）。
- **`.safeAreaInset(edge: .bottom)` で常設バーの上にタブバーを「浮かせる」発想は iOS 26 の TabView と噛み合わない**
  （2026-09-19、ユーザー実機/シミュレータ確認で実際にタブバーが広告帯の裏に隠れて発覚。2 回連続で
  誤った対処を提案した末に判明した根本原因）。`.safeAreaInset(edge:)` は**ビューのフレームを縮めず、
  子に報告する safe area の値だけを増やす**。iOS 26 の浮動（floating pill）タブバーは `TabView` 自身の
  **フレーム基準**で画面下端に描画され、報告された safe area 値を見て位置を調整するタイプの
  コンポーネントではない。そのため `.safeAreaInset` で包んでも `TabView` のフレームは画面全体のまま
  変わらず、タブバーは相変わらず物理下端付近に描画され、そこに広告帯の不透明な背景が重なって
  タブバーを完全に隠してしまう。**フレーム自体を縮める必要がある場面では `VStack(spacing:)` で
  `content` と広告帯を縦に並べる**（`VStack(spacing: loader.isLoaded ? 8 : 0) { content; AdBar() }`）。
  これなら `content`（`RootTabView`）に実際に縮んだフレームが渡り、内部の浮動タブバーもその
  縮んだフレームの下端（= 広告帯の直上）に描画される。**「セーフエリアを操作すれば十分」という判断は
  対象がセーフエリアを見て自分の位置を決めるタイプのコンポーネントかどうかで成否が変わる**
  ——今回のような「フレーム基準で自分の位置を決める」コンポーネント（iOS 26 floating TabView）には効かない。
- **`VStack` に切り替えると、広告ビュー本体の safe area 内配置は自動で満たされ、手動の `GeometryReader`
  実測 + `padding` は不要になる**（前回このメモリに書いた「2 段構え」の 1 段目は VStack 化で丸ごと
  不要になった）。`VStack` は `content` に渡すフレームを実際に縮めるため、その下に続く広告バーは
  もとから safe area 内に収まる位置に配置される。**残るのは「背景だけホームインジケータの裏まで
  伸ばす」の 1 点だけ**: 広告バーに `.background(Color(.systemBackground).ignoresSafeArea(.container, edges: .bottom))`
  を付ける（`.ignoresSafeArea` は背景の `Color` 自体に付ける。広告ビュー本体を包む外側の View に
  付けると本体まで一緒に下端へ落ちる）。`AnchoredBannerAdBar` / `BottomAdBannerModifier`
  （`iosApp/iosApp/Ads/AnchoredBannerAdView.swift`）に実装例がある。
- **「未ロード時は高さ 0 に畳み、ロード完了時に実サイズへ広げる」は常設帯には適用できない**
  （2026-09-19、ユーザー実機確認で発覚。上の項目で書いた「`spacing` を `0`/`8` に出し分ける」も
  同じ誤りの一部で、結局撤回した）。`AnchoredBannerAdBar` が `VStack` の一員である以上、
  その高さが変わることは `content`（`RootTabView`）の高さも同時に変える——つまり**タブバーの
  位置が動く**。`.claude/rules/swift-ios.md`「幅・高さを持つ要素を `if` で条件生成しない」は
  兄弟がシフトする典型例として`if`分岐を挙げているが、**`.frame(height:)` の値を状態で出し分ける
  のも同じ症状を起こす**（`if` かどうかは本質ではなく、高さが変わるかどうかが本質）。
  **常設帯は高さを固定値（`maxAdHeight`）に固定し、受信した広告はその枠内に中央寄せで収める。
  未ロード時は無地の帯（背景色のみ）を同じ高さで表示する**——「畳む」はインライン枠（コンテンツの
  流れの中の 1 枠、周囲の行がずれるだけで済む）の作法であり、常設帯には適用しない。
  `VStack(spacing:)` の `spacing` も同じ理由で固定値（8pt）に統一する。
- **`largeAnchoredAdaptiveBanner(width:)` は「アンカード用の名前」だが高さの天井（20%/150pt）が
  常設帯としては大きすぎた**（2026-09-19、ユーザー実機確認で画面の約 15% を占め大きすぎると判断）。
  **サイズ選択（アンカード用 API を使うか）と高さの見た目（どれだけ大きいか）は別の軸**で、
  高さの天井が欲しいだけなら非推奨でもない `inlineAdaptiveBanner(width:maxHeight:)`
  （既存インライン 2 面と同じ関数）に固定の `maxHeight` を渡す方が単純。
  **「アンカード配置（下部固定）だからアンカード用のサイズ計算を使うべき」という直感に反する組み合わせ**
  になるため、なぜインライン用の関数を使っているかをコード doc に明記しておかないと、次に触る人が
  「戻し忘れ」と誤解して `largeAnchoredAdaptiveBanner` 等に戻してしまう。
- **`maxHeight` の値は 60pt → 50pt へさらに調整された（2026-09-19 同日）。50 が Google 推奨の実質下限
  なので、これ以上は下げない**。`GADAdSize.h` の `GADInlineAdaptiveBannerAdSizeWithWidthAndMaxHeight`
  doc コメント: 「`maxHeight` は 32px 以上必須、50px 以上を推奨」。32-49px は機械的には指定可能だが
  Google 非推奨領域。**「もっと小さく」という要望が今後来ても 50 未満へは下げず、それ以上小さくしたいなら
  別の手段（帯自体を細くする以外の UI 上の工夫）を検討すべき、という判断の根拠を `maxAdHeight` の
  doc コメントに明記した**（次に触る人が根拠を知らずに 32 まで下げてしまうのを防ぐため）。
- **1 つの `.task(id:)` に「幅・scenePhase・追加条件（同意フロー完了等）」をまとめた `Equatable` struct
  を渡す**と、初回ロードと自動リフレッシュループを 1 本のタスクで管理でき、条件変化時に前タスクを
  確実にキャンセルしてやり直せる（`ScenePhase` も `Equatable` なので複合キーに含められる）。
- **iOS 26 の floating TabView の実機/シミュレータ確認は文字列 grep では代替できない**。今回、
  `.safeAreaInset` 版もビルドは 3 回連続で成功し警告も出なかったが、実際の見た目（タブバー消失）は
  ビルド成功と無関係な実行時レイアウトの話だった。**レイアウト系の変更は「ビルドが通った」を検証の
  終着点にせず、シミュレータ目視確認の項目を必ずレポートに列挙する**（このタスクでは自分で
  シミュレータのタップ操作ができないため、目視確認そのものは親/ユーザーに委ねるほかない）。

## インライン広告 2 面の撤去（2026-09-20、requirements.md §11-5 第 2 段。カフェ詳細 + マップ検索結果一覧の 2 面を撤去し 1 面に集約）

- **`ForEach` 内で「N 番目の要素の後に広告 + 区切り線」を挟む実装は、各行自身が持つ「次行との区切り線」
  （`row(cafe:isLast:)` が `!isLast` のとき自前で描く `Divider()`）とは別に、広告ブロック側にも
  専用の `Divider()` を持たせて挟み込む形になっていた**（`row → Divider（行由来）→ 広告 → Divider（広告由来）→
  次の row` という並び）。撤去するときは**広告ブロックの `if index == N { ... }` を丸ごと消すだけで、
  行由来の `Divider()` がそのまま隣接行間の区切りを引き継ぐ**（`MapSearchResultsSheet.swift`）。
  区切り線を個別に足し引きする必要はない — 広告が無くなった後の「普通の行送り」は元々 `row()` 自身が
  担保していたため。
- **`List` の `Section` ベースの広告枠（`CafeDetailView.adSection`）は撤去しても周辺レイアウトへの
  波及がない**。`Section` は独立した境界を持つため、間に挟まっていた `Section` を 1 つ消しても
  前後の `Section` 同士の区切りは `List` が自動で処理する（`MapSearchResultsSheet` の自前 `VStack` +
  手書き `Divider()` とは対照的 — `List`/`Section` を使っている画面は削除が単純、素の `VStack` で
  行を手組みしている画面は「区切り線を誰が描いているか」を先に特定してから削除する）。
- **削除順序**: 呼び出し元（View 側の宣言・組み込み箇所・`@State` ローダー・パラメータ受け渡し）を
  先に消してから、共有コンポーネントファイル（`InlineBannerAdView.swift`）を `rm`。`AdUnitIDs.swift` の
  定数削除・`Info.plist` の対応キー削除・`Base.xcconfig` のフォールバック宣言削除は 3 点セット
  （1 つでも残すとダングリング参照になる。2026-07-16 の 2 面撤去時と同じ手順）。
- **doc コメント中の「撤去済みの型」への言及は、型名を裸の識別子（バッククォート付き）で残すと
  `grep -rn "<型名>"` の残骸チェックに引っかかり続ける**。「撤去済みの旧インライン広告」のように
  型名を使わない説明に置き換える（親から明示的に「残骸ゼロを grep で確認しレポートに貼ること」を
  求められた場合、識別子の**文字列としての存在**まで気にする必要がある — コード上は完全に無害な
  コメントでも、検証コマンドの結果には出てしまう）。
- **`grep` によるパターン一致は部分文字列にもヒットする**ため、`cafeDetail` のような短い検索語は
  無関係な既存識別子（`cafeDetailList` / `CafeDetailView` 等）にもマッチする。レポートでは「これは
  既存の無関係な識別子で、削除対象の残骸ではない」と明示しないと、grep 結果だけを見た人に
  誤解を与える。
- **`Configuration/Secrets.xcconfig` はユーザーローカルのコミット対象外ファイル**。撤去したキーの
  コメントアウト済み残骸がこのファイルに残っていても触らない（gitignore 済みで実害なし、かつ
  親から明示的に「触らないこと」と指示されている）。

## xcodebuild 検証中に DerivedData の `rm -rf` を中断すると SPM checkout が壊れる

- `rm -rf DerivedData/iosApp-*` の途中で `Directory not empty` エラーが出て中断されると、
  次の `-resolvePackageDependencies` が
  `invalid custom path 'FirebaseCore/Extension' for target 'FirebaseCoreExtension'` や
  `Package.swift ... doesn't exist in file system` のような不可解なエラーを出す
  （SourceKitService 等が同時にファイルを触っているため rm が完走しないことがある、
  [[xcodebuild-verification]] 参照）。**同じ `rm -rf` をもう一度実行するだけで直る**ことが多い
  （2 回目で完全に消える）。原因調査に時間をかけず、まず再実行する。
