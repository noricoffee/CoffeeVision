# ios-engineer memory

- [Swift Charts / カスタム Path チャート](swiftui-charts.md) — レーダーチャート自前描画、enum 固定順マージ + 色ランプ（分析タブ）
- [SKIE ブリッジ実地パターン](skie-bridge-interop.md) — Equatable、nullable Double、data class 破壊的変更、sealed class 新 case、Firestore Repo 2 段構成、object カタログ + legacy フォールバック Picker
- [UI コンポーネント / ローカルキャッシュパターン](ui-components-patterns.md) — TagChip、AccentColor 形式、buttonStyle 分岐バグ、StarRatingView nullable、UserDefaults キャッシュ、段階読み込み、ShareLink、単一レコード削除(isDeleted+pending写真)、下部ドラッグシート(Button+simultaneousGesture)、排他的複数シート+連動強調は enum item + .sheet(item:)
- [位置情報 / MapKit 実装パターン](location-mapkit.md) — LocationManager 無音取得、MKLocalPointsOfInterestRequest 常時ピン、MKMapItem.location
- [xcodebuild 検証の落とし穴](xcodebuild-verification.md) — tail で Gradle ログが消える、destination 名確認、-list の Schemes 位置
- [Firebase SPM pbxproj 手動追加](firebase-spm-pbxproj.md) — 一般手順 + FirebaseAnalyticsWithoutAdIdSupport 廃止
- [FirebaseRemoteConfig SPM 追加手順](firebase_remote_config_spm.md) — pbxproj 連番規則 + stringValue 非 Optional 注意
- [AdMob アダプティブバナー実装パターン](admob-native-ads.md) — ネイティブ→バナー再編の経緯、SPM モジュール名の罠、BannerView/AdSize API、UMP をコードから呼ばない理由、`.task` 発火の罠と GeometryReader 幅計測
- [ImageRenderer 共有カード画像生成パターン](image-renderer-share-card.md) — 固定フレーム+clipped、scaleEffect+frame での固定高さコンポーネント圧縮、可変レイアウトの高さ配分計算、PreviewSamples 4 種の使い回し

## 単発の確認事項（トピック化するほどでない小ネタ）

- `iosApp` の `IPHONEOS_DEPLOYMENT_TARGET` は 26.0（`API_AVAILABLE(ios(26.0))` は可用性チェック不要）。詳細は [location-mapkit.md](location-mapkit.md) の `MKMapItem.location` 項目参照
