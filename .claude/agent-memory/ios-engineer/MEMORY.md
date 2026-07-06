# ios-engineer memory

## Kotlin ブリッジの配置（2026-07-04 確認）

- `<Feature>ViewModelBridge.swift` は各 `iosApp/iosApp/Features/<Name>/` 配下に分散（feature ごとに 1 ファイル、計 8 つ。Settings / Onboarding にはなし）。
- Swift→Kotlin 方向の共通 Flow ブリッジ基盤（`CallbackFlow`、Obj-C `Kotlinx_coroutines_coreFlow` 準拠）は `iosApp/iosApp/FirebaseRepositories/FlowBridge.swift`。

## KMP 側の変更を Swift から裏取りする最短手順（2026-07-06 確認）

`.swiftinterface` は SKIE が追加する **Swift 側拡張のみ**しか載らず、Kotlin の `data class` / `interface` 本体の宣言（プロパティ名・引数順・completion handler シグネチャ）は載らない。本体を確認するなら
`shared/framework/build/bin/iosSimulatorArm64/debugFramework/SharedLogic.framework/Headers/SharedLogic.h`（Obj-C ヘッダ）を読むこと。`@property` / `initWith...` / `swift_name(...)` 属性がそのまま Swift シグネチャの正。
kmp-engineer が commit 済みでも `shared/framework/build/**` は古いままなことが多いので、まず
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./gradlew :shared:framework:linkDebugFrameworkIosSimulatorArm64` で最新化してから読む（数秒で終わる。xcodebuild 本番実行より軽い下調べ用）。

## Firestore Repository の 2 段構成 iOS 実装（SavedCafe で確認、2026-07-06）

- `Remote<X>DataSourceIosImpl.swift` は既存 `RemoteCoffeeDataSourceIosImpl.swift` をそのままテンプレートにする（`observeChanges` → `CallbackFlow` + `SkieSwiftFlow._unconditionallyBridgeFromObjectiveC`、`upload`/`remove` → `__upload`/`__remove` の completion handler。Swift concurrency interop が `__` prefix を要求する仕組みは `RemoteCoffeeDataSource` と同一）。
- Firestore マッパーの `Cafe` 8 フィールド直列化（`toCafeMap`/`cafeFromMap`）は `CoffeeFirestoreMapper` に `internal static` として残し、新エンティティのマッパーから再利用する（private のままだと新規マッパーから呼べず重複実装になる）。
- `AppContainer` のコンストラクタ引数が増える（破壊的変更）ときの呼び出し箇所は `iosApp/iosApp/AppState.swift` の 1 箇所のみ（2026-07-06 時点。`grep -rn "AppContainer(" iosApp` で確認）。
- KMP 側にトグル用の `UIState` フィールド/アクションが無い表示切替（例: フィルタチップの ON/OFF）は Swift 側 `@State` だけで完結させてよい（`MapTabView` の `showSavedCafes` 例）。ただし「複数種のピンの優先順位で 1 本だけ表示」のような**データの整合性に関わる dedup ロジック**は表示トグルの状態に関係なく常時適用する（トグルは見た目の間引きだけ、競合解決はトグル非依存）。
