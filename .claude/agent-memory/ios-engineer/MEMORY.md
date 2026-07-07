# ios-engineer memory

## xcodebuild を `| tail -N` で絞ると Gradle Run Script フェーズの出力が見えなくなる（2026-07-06 確認）

`xcodebuild ... | tail -80` のように末尾だけ見ると、ビルド後半（Swift コンパイル〜リンク）しか映らず、序盤に実行される `./gradlew :shared:framework:embedAndSignAppleFrameworkForXcode`（`project.pbxproj` の Run Script フェーズ）のログが消えて「Gradle が本当に走ったか」を確認できない。**`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` を使わずに Gradle 実行を裏取りしたいときは、出力をファイルへリダイレクト（`> build.log 2>&1`）してから `grep` する**（`tail` で絞らない）。差分検証なら `clean build` にすると Run Script も含め全フェーズが必ず再実行されるので確実。

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

## 位置情報を「許可済みのときだけ無音取得」する実装パターン（2026-07-06、CoffeeEditor 現在地サジェストで確認）

- 既存 `iosApp/iosApp/Utilities/LocationManager.swift` の `requestLocation()` は `.notDetermined` のとき自動で許可ダイアログを出す仕様（`MapTabView` の「タップして現在地」導線向け）。**「未許可なら無音でスキップ」が要件の画面（例: エディタ起動時の自動サジェスト）では `requestLocation()` を直接呼ばず、呼ぶ側で `authorizationStatus` を switch して `.authorizedWhenInUse` / `.authorizedAlways` のときだけ呼ぶ**。`LocationManager` 自体は変更不要（既存の他画面の挙動を壊さないため）。
- 取得結果の反映は `.onChange(of: locationManager.lastLocation?.latitude)` で拾うのが確立パターン（`CLLocationCoordinate2D` が `Equatable` 非準拠なため `latitude` を見る。`MapTabView` と同型）。

## SKIE のネストされた `data class`（例: `CoffeeListViewModel.MonthSection`）を Swift で `Identifiable` 拡張するときは `public var id` が必須（2026-07-06、15-C 検索+月別グルーピングで確認）

- `extension CoffeeListViewModel.MonthSection: @retroactive Identifiable { var id: ... }` は **ビルドエラー**になる（`property 'id' must be declared public because it matches a requirement in public protocol 'Identifiable'`）。フレームワーク側の型が public のため、conformance を後付けするなら witness も `public var id` にする（`extension CoffeeRecord: @retroactive Identifiable {}` が今まで無警告だったのは `id` が Kotlin 側で既にプロパティとして存在し追加の witness 宣言が要らなかっただけで、新規に witness を書くケースでは public 必須という違いに注意）。
- List の Section 分割は `ForEach(viewModel.sections) { section in Section { ForEach(section.records) { ... } } header: { Text(...).accessibilityAddTraits(.isHeader) } }` の形で素直に書ける（`sections`/`records` は SKIE 経由で `[T]` として既に届く）。

## `.searchable` を Kotlin StateFlow 駆動の一覧にバインドするときは Bridge 側に「即時反映 + Kotlin 転送」の get/set プロパティを置く（2026-07-06、CoffeeList 検索で確認）

- `CafeSearchView`（ローカル @State + onChange 転送）と違い、CoffeeList は Bridge 自体に `var searchQuery: String { get { _searchQuery } set { _searchQuery = newValue; kotlin.onSearchQueryChanged(query: newValue) } }` を生やし、View 側は `Binding(get: { viewModel.searchQuery }, set: { viewModel.searchQuery = $0 })` を `.searchable(text:)` に渡す形にした。set で `_searchQuery` を即時更新してから Kotlin へ転送するため、StateFlow の非同期ラウンドトリップを待たずにキーストロークが echo される。Kotlin 側のフィルタはメモリ内同期処理なので `apply(_:)` からの書き戻しも実用上遅延なく収束する。
- 空状態の 2 種出し分け（`sections.isEmpty && searchQuery.isEmpty` vs `sections.isEmpty && !searchQuery.isEmpty`）は `ContentUnavailableView.search(text:)` がそのまま使える（`CafeSearchView` の `emptyResultsView` と同じ部品）。

## Kotlin `data class` に nullable フィールド 1 個を追加しただけでも Swift 側の全 positional 呼び出しに波及する（2026-07-07、`CoffeeRecord.brewRecipe` 追加で確認）

- KMP 側で `CoffeeRecord` に新規 nullable プロパティを追加すると、SKIE 生成 Swift init は default 値を持たないため（Kotlin データクラスにデフォルト値が無い限り）、Swift 側で `CoffeeRecord(...)` を直接呼んでいる箇所（本体は `CoffeeFirestoreMapper.fromDocument` の 1 箇所だが、`PreviewSupport/PreviewSamples.swift` のサンプルデータ生成が複数箇所ある）は**すべて**コンパイルエラーになる。`grep -rn "CoffeeRecord(" iosApp --include="*.swift"` で呼び出し箇所を洗い出してから着手すると漏れがない。

## `ShareLink` で「生成 → 共有」の 2 フェーズ導線を作るときは enum 状態（idle/exporting/ready(URL)）で Section 内容を丸ごと差し替える（2026-07-07、設定画面データエクスポートで確認）

- `ShareLink` はボタン自体をタップした瞬間にしか share sheet を出せない（値を先に非同期生成してから自動でシートを開く API はない）。「タップでエクスポート実行 → 完了したら共有」の要件は、`Button`（idle）→ `ProgressView`（exporting）→ `ShareLink(item:)`（ready）と同じ `Section` 内で `switch` して差し替える 2 段階 UI にするのが素直（`SettingsView.exportSection` 参照）。エラーは別途 `@State private var exportError: String?` + `.alert` で拾い、`ExportState` 自体は成功系（idle/exporting/ready）のみに絞ると分岐がシンプルになる。
- 一時ファイル書き出しは `FileManager.default.temporaryDirectory.appendingPathComponent(name)` + `String.write(to:atomically:encoding:)` で十分（既存 `PhotoFileStore` のような専用ストア不要。エクスポートは 1 回性の一時ファイルなので Documents 配下に永続化しない）。
- suspend な UseCase 呼び出し（`appContainer.xxxUseCase.invoke(userId:)` 系）を View 直下の `Task` から呼ぶ既存パターンは `AccountView` 同様 `Task { @MainActor in ... }` で統一されている（Swift 5 言語モード・strict concurrency 未設定のプロジェクトでも、この書き方に揃える）。

## `CoffeeStats` に加算的フィールド（`List<T>` の派生集計）を足す変更は Swift 側で Bridge・View とも無改修で通る（2026-07-07、15-E-3 探索提案で確認）

- KMP 側で `CoffeeStats` に `unexploredBeanSuggestions: List<UnexploredBeanSuggestion> = emptyList()` を追加したケースでは、`AnalysisViewModelBridge.apply(_:)` は `state.stats` を丸ごと代入するだけなので**無改修**。`AnalysisView` 側で `stats.unexploredBeanSuggestions` を新規セクションとして読むだけで済む（`preferredBeanTraits`/`readiness` の 12-C 追加と同型）。
- ただし `CoffeeStats(...)` を直接呼んでいる箇所（`PreviewSupport/PreviewSamples.swift` の `sampleCoffeeStats` のみ、2026-07-07 時点）は positional init のため新規フィールド追加のたびに**必ず**引数を足す必要がある（`grep -rn "CoffeeStats(" iosApp --include="*.swift"` で洗い出し。`CoffeeRecord` と同型の落とし穴）。
- SKIE Swift 名の裏取り結果: `UnexploredBeanSuggestion`（`profile: BeanProfile` + `matchedOriginLabel: String`）、`BeanProfile.init(beanId:name:origin:variety:processings:flavorNotes:description:)`。`ProcessingMethod` は Kotlin enum ながら Swift 側で `CaseIterable` な素の enum として見え、`.natural`/`.washed`/`.honey`/`.anaerobic`/`.other` の lowerCamel case でリテラル生成できる（`ProcessingMethod.allCases` / `.name` は既存コードで確立パターン）。

## `.buttonStyle(condition ? .borderedProminent : .bordered)` は型不一致でビルドエラー（2026-07-07、フェーズ 16 保存ボタン切替で確認）

- `BorderedProminentButtonStyle` と `BorderedButtonStyle` は別の具象型のため、三項演算子で `some ButtonStyle` に代入しようとすると `type 'ButtonStyle' has no member 'borderedProminent'/'bordered'` になる（`.buttonStyle(_:)` は generic over concrete `S: ButtonStyle` であり、分岐で型推論できない）。見た目だけ変える（tint 切替）なら 1 つの style + `.tint(condition ? .indigo : nil)` で済ませるのが簡単。**style 自体を切り替える必要がある場合**（例: 未保存=`.bordered` / 保存済み=`.borderedProminent` の要件）は `@ViewBuilder` 関数にして `if condition { Button(...).buttonStyle(.borderedProminent) } else { Button(...).buttonStyle(.bordered) }` と分岐ごと丸ごと書き分ける（`CafeDetailView.saveButton` 参照。ラベル View は `let label = Label(...)` で 1 箇所に共通化できる）。

## Xcode AccentColor（カスタムカラー）の Contents.json は hex バイト文字列（`"0x8B"`）形式（2026-07-07、フェーズ 16 で確認）

- `Assets.xcassets/*.colorset/Contents.json` の `components` は 10 進小数（`"1.000"`）ではなく `red`/`green`/`blue` それぞれ `"0xRR"` 形式の 8bit hex 文字列で書く（`alpha` のみ `"1.000"` 形式）。ダーク対応は `colors` 配列に `"appearances": [{"appearance": "luminosity", "value": "dark"}]` を付けた 2 つ目のエントリを追加する（`idiom: universal` のまま）。手書きで問題なくビルドに反映される（Xcode Asset Catalog Compiler がこの形式を読む）。

## 共通 `TagChip` コンポーネント（フェーズ 16 で新設、`Components/TagChip.swift`）

- マップ / 一覧で使う「選択トグル可能なチップ」は `TagChip`（`label:systemImage:isOn:count:action:`、選択時 accentColor 塗り、`count` 指定で右上に件数バッジ）と、非インタラクティブな凡例表示用 `TagLegendChip`（`label:systemImage:tint:`）の 2 種に共通化済み。新しいフィルタ/凡例 UI が必要になったらここに追加する（画面ごとに private struct を再実装しない）。
- **`.offset(x:y:)` でバッジ等をはみ出させる実装は、`ScrollView` 内では上/右端がクリップされる**（`offset` は描画位置だけ動かし、親へ伝わるレイアウトサイズには寄与しないため）。対策は「はみ出す量ぶんの padding をコンポーネント自身に対称に確保する」パターン: 上下は `isOn` 状態に関わらず同じ padding（0 or 対称値）にして、はみ出す辺（上・右）は非対称に、対辺（下・左）はゼロのままにする。これにより `HStack` の `.center` 揃えでカプセル本体の垂直中心が他要素と揃ったまま保たれる（左右は中心揃えの対象ではないので trailing だけ広げても隣接要素との間隔が単に広がるだけで済む）。実例: `TagChip` の `badgeReservedInsets`（`count` があるときだけ `top:6, trailing:6, bottom:6` を確保）。

## xcodebuild のシミュレータ destination 名は `xcrun simctl list devices available` で確認する（2026-07-07 確認）

環境によって「iPhone 16」等の型番が存在しないことがある（この環境では iPhone 17 系のみインストール済み）。`-destination 'platform=iOS Simulator,name=iPhone 16'` は `Unable to find a device matching...` で即失敗するので、事前に `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl list devices available | grep iPhone` で存在する名前を確認してから `-destination` を組み立てる。

## SKIE sealed class の新規 case 追加は Obj-C ヘッダで型名・init シグネチャを裏取りするのが必須（2026-07-06、`Mode.Duplicate` 追加で確認）

- Kotlin の `sealed interface Mode { data class Duplicate(val sourceCoffeeId: String) : Mode }` は Swift 側で `SharedLogicCoffeeEditorViewModelModeDuplicate`（`swift_name` 属性で `CoffeeEditorViewModelModeDuplicate` に短縮）になり、`init(sourceCoffeeId:)` で構築する。既存の `ModeEdit(coffeeId:)` と同じ命名パターンなので類推で書けるが、念のためヘッダで `initWith...` 属性を確認してから使う。
- `Mode` の分岐を Swift 側で `if mode is XxxCreate { ... } else { ... }` のような 2 分岐（if/else, switch でない）で書いている箇所は、新規 case 追加時に「それ以外」に自動的に丸められるため見た目上は壊れない。ただし**意図（Duplicate も Create 同様の挙動にする）が正しいか必ず要件を確認**する（このタスクでは意図通りだった）。
