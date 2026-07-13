# ios-engineer memory

## 新規 Firebase SPM プロダクト追加の pbxproj 手順 + `FIRRemoteConfigValue.stringValue` 非 Optional 注意（[firebase_remote_config_spm.md](firebase_remote_config_spm.md)、2026-07-13）

## Kotlin data class（ネスト型含む）は `.onChange(of:)` にそのまま渡せる — Foundation の `NSObject: Equatable` 拡張が effectively 効く（2026-07-13、`MapViewModel.PoiLookupError` 導入で確認）

- Kotlin の `data class`（`Cafe` や `MapViewModel.PoiLookupError` 等のネスト data class 含む）は Obj-C ヘッダ上で `SharedLogicBase : NSObject` を継承し、`equals()`/`hashCode()` から生成された `isEqual:`/`hash` をオーバーライドしている。Foundation は `extension NSObject: Equatable { == は isEqual: を呼ぶ }` を提供しているため、**Swift 側で追加の `Equatable` 適合を書かなくても** `.onChange(of: bridge.someKotlinDataClassOptional)` がそのまま使える（`Optional` の条件付き `Equatable` 経由）。既存の `.onChange(of: bridge.poiLookupResult)`（`Cafe?`）と同型。新しい nested data class を State 監視に使うときも、まず素朴に `.onChange` を試してよい（Equatable 拡張を自前で書く必要は基本ない）。
- ただし `.swiftinterface` にはこの Equatable 適合は載らない（ObjC ブリッジ経由の暗黙効果のため）。裏取りは「Foundation が NSObject に Equatable を生やす」という一般知識で足り、都度 grep する必要はない。

## UserDefaults + JSON（Codable）ローカルキャッシュは `enum` static メソッド + private struct Entry で完結する（2026-07-13、`ApplePoiNegativeCache` 新設で確認）

- 既存 `PhotoFileStore`（ファイル I/O 版）と同じ「全 `static` メソッドの enum、インスタンス不要」パターンを UserDefaults 版でも踏襲できる。`private struct Entry: Codable` を型内に閉じ込め、`loadEntries()`/`saveEntries(_:)` の private ヘルパで JSON エンコード/デコードを行う最小構成で十分（件数上限が小さい—数百件程度—なら線形走査で過剰設計にならない）。
- Apple の POI（`MKMapItem`）は安定 ID を持たないため、名前完全一致 + 座標近接（`CLLocation.distance(from:)`）の複合キーで dedup / 一致判定するのが定番（`displayedAppleNearbyCafes` の既存 40m 近接排除と同じ手法、キャッシュ側は 30m を採用）。

## 横スクロール（LazyHStack）内の「さらに表示」段階読み込みは `@State var visibleCount` + Item enum への追加 case で完結する（2026-07-13、CafePhotoHeader 写真ヘッダーで確認）

- KMP 側データ（`cafe.photoReferences` 等）はそのまま `prefix(visibleCount)` で間引くだけでよく、Kotlin 側に変更は不要（純粋な表示制御は View 内 `@State` に閉じる、既存規約どおり）。
- `isEmpty`（呼び出し側がヘッダー全体を隠すかの判定）は**元データ基準**にし、`visibleCount` に依存させない。段階読み込みの表示上限（例: 全体で最大 10 件）とは別に判定すること。
- 「さらに表示」ボタンは既存セルと同じ `Identifiable` enum（`Item`）に `case loadMore` を追加し、`items` 配列の末尾（次セクションの手前）に条件付きで挿入するのが素直。ボタン自体は `.frame(width:height:)` を既存の写真セルと揃えれば ScrollView 内でレイアウトが崩れない。

## Kotlin の nullable Double プロパティ（`Double?`）を Swift で扱うときの型変換パターン（2026-07-13、`CoffeeRecord.rating` nullable 化で確認）

- SKIE の `.swiftinterface` は「呼び出し方向」の糖衣構文しか載らない。`data class` のプロパティ自体の nullable Double は Obj-C ヘッダで `SharedLogicDouble * _Nullable`（= Swift `KotlinDouble?`）と確認するのが確実（`shared/framework/build/bin/iosSimulatorArm64/debugFramework/SharedLogic.framework/Headers/SharedLogic.h` を `grep`）。
- 読み取り側: `record.rating?.doubleValue` で `Double?` に変換してから Swift ネイティブ API（`StarRatingView` 等）に渡す。
- 書き込み側（Firestore encode）: `if let rating = record.rating { doc["rating"] = rating.doubleValue }`（他の nullable フィールドと同じ「非 nil のときだけキーを立てる」パターンを踏襲）。
- Swift → Kotlin へ渡す側（ViewModel ブリッジの `onXxxChanged`）: `Double?` を引数に取る Swift 関数内で `rating.map { KotlinDouble(value: $0) }` に包んでから Kotlin 側 `KotlinDouble?` パラメータへ渡す。
- `data class` の positional initializer に `Double` リテラル（`4.5` 等）を直接渡している箇所（`PreviewSamples.swift` 等）は、フィールドが `Double` → `Double?`（Kotlin 側）に変わると **コンパイルエラーではなくキャストエラー**にもならず一見動きそうに見えて実際は `KotlinDouble` 型不一致でビルドエラーになる。`KotlinDouble(value:)` で明示ラップが必要（`CoffeeRecord.rating` / `CoffeeStats` 系の既存パターンと同型）。

## 「未評価に戻せる」UI は accessibilityAdjustableAction の decrement 下限 + 明示クリアボタンの二重導線にする（2026-07-13、StarRatingView nullable rating 対応で確認）

- `rating: Double?` 化した `StarRatingView` は、read-only モードで `nil` のとき星を出さず `Text("未評価")`（`.foregroundStyle(.secondary)`）を表示する（星 0 個表示は「1つも星がない低評価」と誤読されるため避ける）。
- 編集モードのクリア手段は 2 経路用意すると VoiceOver / タップ操作の両方をカバーできる: ① `accessibilityAdjustableAction` の `.decrement` を rating 0.5 未満に到達したら `nil` を返すよう実装（スワイプ操作の自然な延長）、② 星の右側に `xmark.circle.fill` の明示クリアボタン（`rating != nil` のときだけ表示、`.frame(minWidth: 44, minHeight: 44)` で 44pt 確保）。星の HStack 全体は `accessibilityElement(children: .ignore)` でグループ化しつつ、クリアボタンは**その外側**の別要素にする（グループに巻き込むと VoiceOver から個別にフォーカスできなくなるため）。
- `some View` を返す computed var 内で `if/else` 分岐を書くには `@ViewBuilder` 属性が必須（`body` プロパティ自体は View プロトコル要件により暗黙で付与されるが、任意の computed var には付かない。既存コードでも `CafeDetailView.swift` 等に確立パターンあり）。

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

## `xcodebuild -project ... -list` の出力は末尾までスクロールしないと `Schemes:` セクションが見えないことがある（2026-07-07 確認）

`| head -30` 等で先頭だけ見ると `Targets:` / `Build Configurations:` までしか映らず「共有スキームが無い」と誤認しがち（実際は package 解決ログが長く `Schemes:` セクションはさらに下）。`xcshareddata/xcschemes/*.xcscheme` の有無を先に `find` で確認するか、`-list` は全文（`tail` 併用）で見ること。ビルドは `-target` ではなく `-scheme`（+ 必要なら `-derivedDataPath`）を使う（`-derivedDataPath` 指定時は `-scheme` が必須で `-target` だと `error: The flag -scheme... is required` になる）。

## `iosApp` の `IPHONEOS_DEPLOYMENT_TARGET` は 26.0（2026-07-07、フェーズ 17 確認）

最小デプロイターゲットが 26.0 のため、`API_AVAILABLE(ios(26.0))` の新 API を無条件で使ってよい（可用性チェック不要）。例: `MKMapItem.placemark` は ios 26.0 で deprecated（`API_DEPRECATED(..., ios(6.0, 26.0))`）になっており、代わりの `MKMapItem.location`（`CLLocation`, `API_AVAILABLE(ios(26.0))`）が確実に使える。`.placemark.coordinate` ではなく `.location.coordinate` を使うことでビルド警告 (`DeprecatedDeclaration`) を避けられる。同様のパターン（旧 API が ios 26.0 で deprecated、新 API が ios 26.0 available）は他の SDK API でも今後遭遇し得るので、warning が出たら新 API への置換をまず検討する。

## `MKLocalPointsOfInterestRequest` + `MKLocalSearch` で「常時見えるカフェピン」を実装するパターン（フェーズ 17、周辺カフェ自前ピン化で確認）

- `MKLocalPointsOfInterestRequest(center:radius:)` の Swift シグネチャは ObjC ヘッダの `initWithCenterCoordinate:radius:` から素直に導出できる（`.swiftinterface` 確認不要、Apple 公式 SDK ヘッダ `MapKit.framework/Headers/MKLocalPointsOfInterestRequest.h` を直接読めばよい。KMP ブリッジと違い純正 Apple API なので裏取り先が異なる）。
- `MKLocalSearch(request:)` → `try await .start()` は completion handler ベースの ObjC API に対する Apple 公式 Swift async overlay（ヘッダには載らない）。広く使われる確立パターンなので信頼してよい。
- `MKPointOfInterestFilter(including:)` は SwiftUI `MapStyle` の `PointOfInterestFilter.including(_:)`（`.mapStyle(.standard(pointsOfInterest:))` に渡す方）とは**別の型**（`MKPointOfInterestFilter`、MapKit の ObjC 型）。名前が同じ `including` で紛らわしいので取り違えに注意。
- デバウンス+キャンセルは `Task` を `@State` に保持し、新規スケジュール時に前回を `cancel()` → `Task.sleep` → `Task.isCancelled` チェック、が定番。ズームゲート（半径がしきい値超なら fetch せずクリア）は `scheduleAppleNearbyFetch` の入口でガードするだけで十分（View 側で「見えている」/「見えていない」の切替が要らない単純ケース）。
- 座標近接による重複排除は `CLLocation.distance(from:)`（メートル単位）で十分。既存ピンの座標一覧はトグル（`bridge.showVisited` 等）の状態に関わらず**全件**から作る（表示トグルは見た目の間引き、dedup はトグル非依存という既存パターンを踏襲）。

## Firebase SPM の SPM プロダクト名は pbxproj 手編集で追加できる。ただし `FirebaseAnalyticsWithoutAdIdSupport` は現行 SDK（12.14.0 時点）で廃止済み（2026-07-08、テレメトリ導入で確認）

- `iosApp.xcodeproj/project.pbxproj` は手書き/短縮 ID（`FB0000...`）で管理されており xcodegen 等の生成ツールは使っていない。新規 SPM プロダクト追加は `PBXBuildFile` + `PBXFrameworksBuildPhase.files` + `PBXNativeTarget.packageProductDependencies` + `XCSwiftPackageProductDependency` の 4 箇所に同じ ID 命名規則（`FB000001.../FB000002...`）で追記すれば通る（Xcode UI 不要）。新規 Run Script Build Phase も同様に手書き追加可能（`PBXShellScriptBuildPhase` セクション + native target `buildPhases` 配列への ID 追記）。
- **重要な仕様変更**: 旧来 IDFA 回避目的で使われていた SPM プロダクト `FirebaseAnalyticsWithoutAdIdSupport` は、firebase-ios-sdk 12.14.0 時点の `Package.swift` に存在しない（`grep AdIdSupport Package.swift` が 0 件）。**現行 SDK ではデフォルトの `FirebaseAnalytics` プロダクト自体が IDFA 非対応（旧 WithoutAdIdSupport 相当）**になっており、IDFA/AdId を使いたい場合だけ追加で `FirebaseAnalyticsIdentitySupport`（旧命名の逆転）を足す方式に変わった。`Carthage.md` に「AdId support を無効化するには `GoogleAppMeasurementIdentitySupport.xcframework` を含めない」という記述があり裏取りできる。**docs や実装ノートに `FirebaseAnalyticsWithoutAdIdSupport` という名前が残っていたら、`FirebaseAnalytics`（プレーン）に読み替える**。IDFA 非依存という要件自体は `FirebaseAnalyticsIdentitySupport` を追加しなければ変わらず満たされる。
- Crashlytics dSYM アップロード run-script 追加後、Debug 構成ビルドで `DEBUG_INFORMATION_FORMAT should be set to dwarf-with-dsym` warning が出るのは想定内（Debug は `dwarf`、Release のみ `dwarf-with-dsym` のプロジェクト設定のため。Release/TestFlight ビルドでのみ実際に dSYM がアップロードされれば良く、Debug 警告は無害）。
- 新しい `FirebaseAnalytics` SDK（12.x）は `.analyticsScreen(name:class:extraParameters:)` という公式 SwiftUI screen-tracking modifier を同梱している（`FirebaseAnalytics/README.md` に記載）。自前の `.trackScreen(_:)` extension を書く代わりに使える将来の選択肢として認識しておく（今回は独自命名の `.trackScreen` を採用。理由は screen 名を `AnalyticsParameterScreenName`/`ScreenClass` に同一値で渡す既存方針に寄せたかったため）。

## SKIE sealed class の新規 case 追加は Obj-C ヘッダで型名・init シグネチャを裏取りするのが必須（2026-07-06、`Mode.Duplicate` 追加で確認）

- Kotlin の `sealed interface Mode { data class Duplicate(val sourceCoffeeId: String) : Mode }` は Swift 側で `SharedLogicCoffeeEditorViewModelModeDuplicate`（`swift_name` 属性で `CoffeeEditorViewModelModeDuplicate` に短縮）になり、`init(sourceCoffeeId:)` で構築する。既存の `ModeEdit(coffeeId:)` と同じ命名パターンなので類推で書けるが、念のためヘッダで `initWith...` 属性を確認してから使う。
- `Mode` の分岐を Swift 側で `if mode is XxxCreate { ... } else { ... }` のような 2 分岐（if/else, switch でない）で書いている箇所は、新規 case 追加時に「それ以外」に自動的に丸められるため見た目上は壊れない。ただし**意図（Duplicate も Create 同様の挙動にする）が正しいか必ず要件を確認**する（このタスクでは意図通りだった）。
