# ios-engineer memory

## Kotlin ブリッジの配置（2026-07-04 確認）

- `<Feature>ViewModelBridge.swift` は各 `iosApp/iosApp/Features/<Name>/` 配下に分散（feature ごとに 1 ファイル、計 8 つ。Settings / Onboarding にはなし）。
- Swift→Kotlin 方向の共通 Flow ブリッジ基盤（`CallbackFlow`、Obj-C `Kotlinx_coroutines_coreFlow` 準拠）は `iosApp/iosApp/FirebaseRepositories/FlowBridge.swift`。
