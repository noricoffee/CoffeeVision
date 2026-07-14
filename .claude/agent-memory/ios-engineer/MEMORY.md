# ios-engineer memory

- [Swift Charts / カスタム Path チャート](swiftui-charts.md) — レーダーチャート自前描画、enum 固定順マージ + 色ランプ（分析タブ）
- [SKIE ブリッジ実地パターン](skie-bridge-interop.md) — Equatable、nullable Double、data class 破壊的変更、sealed class 新 case、Firestore Repo 2 段構成
- [UI コンポーネント / ローカルキャッシュパターン](ui-components-patterns.md) — TagChip、AccentColor 形式、buttonStyle 分岐バグ、StarRatingView nullable、UserDefaults キャッシュ、段階読み込み、ShareLink
- [位置情報 / MapKit 実装パターン](location-mapkit.md) — LocationManager 無音取得、MKLocalPointsOfInterestRequest 常時ピン、MKMapItem.location
- [xcodebuild 検証の落とし穴](xcodebuild-verification.md) — tail で Gradle ログが消える、destination 名確認、-list の Schemes 位置
- [Firebase SPM pbxproj 手動追加](firebase-spm-pbxproj.md) — 一般手順 + FirebaseAnalyticsWithoutAdIdSupport 廃止
- [FirebaseRemoteConfig SPM 追加手順](firebase_remote_config_spm.md) — pbxproj 連番規則 + stringValue 非 Optional 注意
- [AdMob ネイティブ広告 + UMP 実装パターン](admob-native-ads.md) — SPM モジュール名の罠、バージョン指定と NS_SWIFT_NAME 有無、UIKit ネイティブ広告ビュー、NPA 指定、start() のタイミング

## 単発の確認事項（トピック化するほどでない小ネタ）

- `iosApp` の `IPHONEOS_DEPLOYMENT_TARGET` は 26.0（`API_AVAILABLE(ios(26.0))` は可用性チェック不要）。詳細は [location-mapkit.md](location-mapkit.md) の `MKMapItem.location` 項目参照
