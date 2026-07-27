# ios-engineer memory

- [Swift Charts / カスタム Path チャート](swiftui-charts.md) — レーダーチャート自前描画、enum 固定順マージ + 色ランプ（分析タブ）
- [SKIE ブリッジ実地パターン](skie-bridge-interop.md) — Equatable、nullable Double、data class 破壊的変更、sealed class 新 case、Firestore Repo 2 段構成、object カタログ + legacy フォールバック Picker
- [UI コンポーネント / ローカルキャッシュパターン](ui-components-patterns.md) — TagChip、AccentColor 形式、buttonStyle 分岐バグ、StarRatingView nullable、UserDefaults キャッシュ、段階読み込み、ShareLink、単一レコード削除(isDeleted+pending写真)、下部ドラッグシート(Button+simultaneousGesture)、排他的複数シート+連動強調は enum item + .sheet(item:)
- [位置情報 / MapKit 実装パターン](location-mapkit.md) — LocationManager 無音取得、MKLocalPointsOfInterestRequest 常時ピン、MKMapItem.location、Places locationBias は範囲制限でないためクライアント側 MKCoordinateRegion 矩形フィルタが要る
- [xcodebuild 検証の落とし穴](xcodebuild-verification.md) — tail で Gradle ログが消える、destination 名確認、-list の Schemes 位置
- [Firebase SPM pbxproj 手動追加](firebase-spm-pbxproj.md) — 一般手順 + FirebaseAnalyticsWithoutAdIdSupport 廃止
- [FirebaseRemoteConfig SPM 追加手順](firebase_remote_config_spm.md) — pbxproj 連番規則 + stringValue 非 Optional 注意
- [AdMob アダプティブバナー実装パターン](admob-native-ads.md) — ネイティブ→バナー再編の経緯、SPM モジュール名の罠、BannerView/AdSize API、UMP をコードから呼ばない理由、`.task` 発火の罠と GeometryReader 幅計測
- [ImageRenderer 共有カード画像生成パターン](image-renderer-share-card.md) — 固定フレーム+clipped、scaleEffect+frame での固定高さコンポーネント圧縮、可変レイアウトの高さ配分計算、PreviewSamples 4 種の使い回し
- [SwiftUI View 分割の落とし穴](swiftui-view-splitting.md) — 別ファイル extension への private 移動でアクセス不能になる問題、複数消費者が要る算出値は親に残し子へ down-flow で渡す設計判断、fetch ロジックを `@Observable` サービスへ隔離（クラス全体 `@MainActor`・共有 static しきい値・dedup は引数渡し）、`@State` 保持クラスのコールバックが兄弟 `@State`/`@FocusState` を要る場合は `.task` で事後配線、`@Bindable` ローカル宣言でメンバー単位 Binding、行番号一括削除は範囲内の無関係ヘルパー混入を grep で事前チェック、呼び出し元が同一新ファイルに収まるかで private 温存/internal 化を仕分ける（AnalysisView 分割）

## 単発の確認事項（トピック化するほどでない小ネタ）

- `MapPins.swift`（`iosApp/iosApp/Features/Map/`）の 6 ピンは白フチ（`.overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))`、`.frame` 直後・`.shadow` 直前）で統一済み（MP-2、2026-07-27）。今後ピンを追加するときはこの位置に揃える

- `iosApp` の `IPHONEOS_DEPLOYMENT_TARGET` は 26.0（`API_AVAILABLE(ios(26.0))` は可用性チェック不要）。詳細は [location-mapkit.md](location-mapkit.md) の `MKMapItem.location` 項目参照
- `iosApp.xcodeproj` は `PBXFileSystemSynchronizedRootGroup` 採用済み。フォルダ配下に新規 `.swift` を作成するだけで自動的にターゲットに含まれる（pbxproj を手編集する必要なし）。大型ファイル分割リファクタ（MapTabView 等）で新ファイルを切り出すときもこれで足りる。**削除も同様**（`rm` するだけで pbxproj 側の参照除去は不要。`ContentView.swift`（KMP テンプレート残骸、未参照）削除で確認済み、2026-07-27）
- Edit ツールで全角括弧（（）等）を含む複数行ブロックを `old_string` に含めると、一見同じ文字に見えても "String to replace not found" で失敗することがある（2026-07-24 確認、原因未特定）。同じテキストでも全角括弧を含まない周辺行だけを対象にした小さい `old_string` に分割するか、`python3` で `open(path, encoding='utf-8')` して行番号ベースの `del lines[a:b]` / 置換を行うと確実（本タスクの MapTabView State 削除で多用）
