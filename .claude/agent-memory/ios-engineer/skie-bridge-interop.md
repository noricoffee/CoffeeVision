---
name: skie-bridge-interop
description: SKIE 経由の Kotlin ⇄ Swift ブリッジ実地パターン（Equatable、nullable、sealed class、data class 破壊的変更、.swiftinterface vs ヘッダ裏取り）
metadata:
  type: project
---

## Kotlin ブリッジの配置（2026-07-04 確認）

- `<Feature>ViewModelBridge.swift` は各 `iosApp/iosApp/Features/<Name>/` 配下に分散（feature ごとに 1 ファイル、計 8 つ。Settings / Onboarding にはなし）。
- Swift→Kotlin 方向の共通 Flow ブリッジ基盤（`CallbackFlow`、Obj-C `Kotlinx_coroutines_coreFlow` 準拠）は `iosApp/iosApp/FirebaseRepositories/FlowBridge.swift`。

## KMP 側の変更を Swift から裏取りする最短手順（2026-07-06 確認）

`.swiftinterface` は SKIE が追加する **Swift 側拡張のみ**しか載らず、Kotlin の `data class` / `interface` 本体の宣言（プロパティ名・引数順・completion handler シグネチャ）は載らない。本体を確認するなら
`shared/framework/build/bin/iosSimulatorArm64/debugFramework/SharedLogic.framework/Headers/SharedLogic.h`（Obj-C ヘッダ）を読むこと。`@property` / `initWith...` / `swift_name(...)` 属性がそのまま Swift シグネチャの正。
kmp-engineer が commit 済みでも `shared/framework/build/**` は古いままなことが多いので、まず
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./gradlew :shared:framework:linkDebugFrameworkIosSimulatorArm64` で最新化してから読む（数秒で終わる。xcodebuild 本番実行より軽い下調べ用）。

## Kotlin data class（ネスト型含む）は `.onChange(of:)` にそのまま渡せる — Foundation の `NSObject: Equatable` 拡張が effectively 効く（2026-07-13、`MapViewModel.PoiLookupError` 導入で確認）

- Kotlin の `data class`（`Cafe` や `MapViewModel.PoiLookupError` 等のネスト data class 含む）は Obj-C ヘッダ上で `SharedLogicBase : NSObject` を継承し、`equals()`/`hashCode()` から生成された `isEqual:`/`hash` をオーバーライドしている。Foundation は `extension NSObject: Equatable { == は isEqual: を呼ぶ }` を提供しているため、**Swift 側で追加の `Equatable` 適合を書かなくても** `.onChange(of: bridge.someKotlinDataClassOptional)` がそのまま使える（`Optional` の条件付き `Equatable` 経由）。既存の `.onChange(of: bridge.poiLookupResult)`（`Cafe?`）と同型。新しい nested data class を State 監視に使うときも、まず素朴に `.onChange` を試してよい（Equatable 拡張を自前で書く必要は基本ない）。
- ただし `.swiftinterface` にはこの Equatable 適合は載らない（ObjC ブリッジ経由の暗黙効果のため）。裏取りは「Foundation が NSObject に Equatable を生やす」という一般知識で足り、都度 grep する必要はない。

## Kotlin の nullable Double プロパティ（`Double?`）を Swift で扱うときの型変換パターン（2026-07-13、`CoffeeRecord.rating` nullable 化で確認）

- SKIE の `.swiftinterface` は「呼び出し方向」の糖衣構文しか載らない。`data class` のプロパティ自体の nullable Double は Obj-C ヘッダで `SharedLogicDouble * _Nullable`（= Swift `KotlinDouble?`）と確認するのが確実（同ヘッダを `grep`）。
- 読み取り側: `record.rating?.doubleValue` で `Double?` に変換してから Swift ネイティブ API（`StarRatingView` 等）に渡す。
- 書き込み側（Firestore encode）: `if let rating = record.rating { doc["rating"] = rating.doubleValue }`（他の nullable フィールドと同じ「非 nil のときだけキーを立てる」パターンを踏襲）。
- Swift → Kotlin へ渡す側（ViewModel ブリッジの `onXxxChanged`）: `Double?` を引数に取る Swift 関数内で `rating.map { KotlinDouble(value: $0) }` に包んでから Kotlin 側 `KotlinDouble?` パラメータへ渡す。
- `data class` の positional initializer に `Double` リテラル（`4.5` 等）を直接渡している箇所（`PreviewSamples.swift` 等）は、フィールドが `Double` → `Double?`（Kotlin 側）に変わると **コンパイルエラーではなくキャストエラー**にもならず一見動きそうに見えて実際は `KotlinDouble` 型不一致でビルドエラーになる。`KotlinDouble(value:)` で明示ラップが必要。

## Kotlin `data class` へのフィールド追加は Swift 側の全 positional 呼び出しに波及する（2026-07-07/07-13、`CoffeeRecord.brewRecipe` / `.rating` で確認）

- KMP 側で `data class` に新規プロパティ（default 値なし）を追加すると、SKIE 生成 Swift init のシグネチャが変わるため、Swift 側で `CoffeeRecord(...)` を直接呼んでいる箇所（本体の `CoffeeFirestoreMapper.fromDocument` 以外に `PreviewSupport/PreviewSamples.swift` のサンプルデータ生成が複数箇所ある）は**すべて**コンパイルエラーになる。`grep -rn "CoffeeRecord(" iosApp --include="*.swift"` で呼び出し箇所を洗い出してから着手すると漏れがない。`CoffeeStats(...)` も同型の落とし穴（`grep -rn "CoffeeStats(" iosApp --include="*.swift"`）。

## `CoffeeStats` に加算的フィールド（`List<T>` の派生集計）を足す変更は Swift 側で Bridge・View とも無改修で通る（2026-07-07、15-E-3 探索提案で確認）

- KMP 側で `CoffeeStats` に `unexploredBeanSuggestions: List<UnexploredBeanSuggestion> = emptyList()` を追加したケースでは、`AnalysisViewModelBridge.apply(_:)` は `state.stats` を丸ごと代入するだけなので**無改修**。`AnalysisView` 側で `stats.unexploredBeanSuggestions` を新規セクションとして読むだけで済む（`preferredBeanTraits`/`readiness` の 12-C 追加と同型）。ただし positional init を直接呼んでいる箇所（上記参照）は要修正。
- SKIE Swift 名の裏取り結果: `UnexploredBeanSuggestion`（`profile: BeanProfile` + `matchedOriginLabel: String`）、`BeanProfile.init(beanId:name:origin:variety:processings:flavorNotes:description:)`。`ProcessingMethod` は Kotlin enum ながら Swift 側で `CaseIterable` な素の enum として見え、`.natural`/`.washed`/`.honey`/`.anaerobic`/`.other` の lowerCamel case でリテラル生成できる。

## SKIE のネストされた `data class`（例: `CoffeeListViewModel.MonthSection`）を Swift で `Identifiable` 拡張するときは `public var id` が必須（2026-07-06、15-C 検索+月別グルーピングで確認）

- `extension CoffeeListViewModel.MonthSection: @retroactive Identifiable { var id: ... }` は **ビルドエラー**になる（`property 'id' must be declared public because it matches a requirement in public protocol 'Identifiable'`）。フレームワーク側の型が public のため、conformance を後付けするなら witness も `public var id` にする（`extension CoffeeRecord: @retroactive Identifiable {}` が今まで無警告だったのは `id` が Kotlin 側で既にプロパティとして存在し追加の witness 宣言が要らなかっただけで、新規に witness を書くケースでは public 必須という違いに注意）。
- List の Section 分割は `ForEach(viewModel.sections) { section in Section { ForEach(section.records) { ... } } header: { Text(...).accessibilityAddTraits(.isHeader) } }` の形で素直に書ける（`sections`/`records` は SKIE 経由で `[T]` として既に届く）。

## `.searchable` を Kotlin StateFlow 駆動の一覧にバインドするときは Bridge 側に「即時反映 + Kotlin 転送」の get/set プロパティを置く（2026-07-06、CoffeeList 検索で確認）

- `CafeSearchView`（ローカル @State + onChange 転送）と違い、CoffeeList は Bridge 自体に `var searchQuery: String { get { _searchQuery } set { _searchQuery = newValue; kotlin.onSearchQueryChanged(query: newValue) } }` を生やし、View 側は `Binding(get: { viewModel.searchQuery }, set: { viewModel.searchQuery = $0 })` を `.searchable(text:)` に渡す形にした。set で `_searchQuery` を即時更新してから Kotlin へ転送するため、StateFlow の非同期ラウンドトリップを待たずにキーストロークが echo される。
- 空状態の 2 種出し分け（`sections.isEmpty && searchQuery.isEmpty` vs `sections.isEmpty && !searchQuery.isEmpty`）は `ContentUnavailableView.search(text:)` がそのまま使える（`CafeSearchView` の `emptyResultsView` と同じ部品）。

## SKIE sealed class の新規 case 追加は Obj-C ヘッダで型名・init シグネチャを裏取りするのが必須（2026-07-06、`Mode.Duplicate` 追加で確認）

- Kotlin の `sealed interface Mode { data class Duplicate(val sourceCoffeeId: String) : Mode }` は Swift 側で `SharedLogicCoffeeEditorViewModelModeDuplicate`（`swift_name` 属性で `CoffeeEditorViewModelModeDuplicate` に短縮）になり、`init(sourceCoffeeId:)` で構築する。命名パターンは類推できるが、念のためヘッダで `initWith...` 属性を確認してから使う。
- `Mode` の分岐を Swift 側で `if mode is XxxCreate { ... } else { ... }` のような 2 分岐（if/else, switch でない）で書いている箇所は、新規 case 追加時に「それ以外」に自動的に丸められるため見た目上は壊れない。ただし**意図が正しいか必ず要件を確認**する。

## Firestore Repository の 2 段構成 iOS 実装（SavedCafe で確認、2026-07-06）

- `Remote<X>DataSourceIosImpl.swift` は既存 `RemoteCoffeeDataSourceIosImpl.swift` をそのままテンプレートにする（`observeChanges` → `CallbackFlow` + `SkieSwiftFlow._unconditionallyBridgeFromObjectiveC`、`upload`/`remove` → `__upload`/`__remove` の completion handler。Swift concurrency interop が `__` prefix を要求する仕組みは `RemoteCoffeeDataSource` と同一）。
- Firestore マッパーの `Cafe` 8 フィールド直列化（`toCafeMap`/`cafeFromMap`）は `CoffeeFirestoreMapper` に `internal static` として残し、新エンティティのマッパーから再利用する（private のままだと新規マッパーから呼べず重複実装になる）。
- `AppContainer` のコンストラクタ引数が増える（破壊的変更）ときの呼び出し箇所は `iosApp/iosApp/AppState.swift` の 1 箇所のみ（2026-07-06 時点。`grep -rn "AppContainer(" iosApp` で確認）。
- KMP 側にトグル用の `UIState` フィールド/アクションが無い表示切替（例: フィルタチップの ON/OFF）は Swift 側 `@State` だけで完結させてよい（`MapTabView` の `showSavedCafes` 例）。ただし「複数種のピンの優先順位で 1 本だけ表示」のような**データの整合性に関わる dedup ロジック**は表示トグルの状態に関係なく常時適用する（トグルは見た目の間引きだけ、競合解決はトグル非依存）。
- 「BeanProfileRepository と同型」と親から指定された新規 Repository（`CuratedCafeRepository` 等、read-only + one-shot get + メモリキャッシュ）は、Obj-C ヘッダで裏取りしても実際に `getAllWithCompletionHandler:` → Swift 名 `getAll(completionHandler:)` で完全一致した（フェーズ 19、2026-07-17）。`BeanProfileRepositoryIosImpl.swift` をそのままコピーして型名を差し替えるだけで実装できる、信頼度の高いテンプレート。

## KMP 側で機能ごと `UIState` フィールド/メソッドを削除したときの iOS 追随は grep 4 点セットで漏れなく洗い出せる（2026-07-21、テイストフィルタ削除で確認）

`grep -rn "<削除対象の識別子>" iosApp/` を「削除された KMP プロパティ名」「削除された KMP メソッド名」「その機能専用の Swift View ファイル名」「その機能専用の `@State` 変数名」の 4 系統で回すと、Bridge のプロパティ宣言 / `apply(_:)` 内代入 / アクションメソッド / View 側の `@State` / `.sheet` / チップ UI / 派生ロジック（今回は pinOpacity の三項式に混ざっていた）まで一通り拾える。**派生ロジックへの混入**（他機能の減光条件と 1 つの三項演算子に同居していた）が見落としやすいので、対象識別子そのものだけでなく「その値を使っている条件式・三項演算子」まで目視で追うこと。File System Synchronized Group（Xcode 16+）採用プロジェクトでは専用 View ファイルの削除に `project.pbxproj` 編集は不要（`grep` で該当ファイル名がヒットしなければ確認不要、`rm` だけで完結）。

## `Cafe`（8 フィールド + デフォルト値付き 6 フィールド）は Swift 側で 14 引数の designated initializer 1 本しかない（2026-07-17、CuratedCafe → 最小 Cafe 構築で確認）

Kotlin `data class Cafe(placeId, name, address, latitude, longitude, photoReferences, websiteUrl, mapsUrl, openNow = null, weekdayDescriptions = emptyList(), phoneNumber = null, priceLevel = null, googleRating = null, userRatingCount = null)` は、末尾 6 フィールドが Kotlin 側でデフォルト値を持っていても **SKIE は defaultArgumentInterop 非対応（既存ルール参照）のため 8 引数の短縮 init は生成されない**。`Cafe(placeId:...:mapsUrl:)` のような呼び出しはビルドエラーになる。他のドメインモデル（`CuratedCafe` 等）から最小限のフィールドだけで `Cafe` を組み立てたい場合は、`openNow: nil, weekdayDescriptions: [], phoneNumber: nil, priceLevel: nil, googleRating: nil, userRatingCount: nil` を明示的にすべて渡す（`grep -n "instancetype)initWithPlaceId" SharedLogic.h` で該当クラスの init が 1 本だけか確認してから使う。似た名前の `CafeExportDto` は別クラスで 8 引数版しか持たないため取り違えに注意）。

## 既存メソッドと同型シグネチャの interface に新規メソッドを 1 本足すケースは、`.swiftinterface`（`async throws` 糖衣のみ）ではなく Obj-C ヘッダの `swift_name` 属性で裏取りすれば足りる（2026-08-06、`AuthRepository.deleteUserProfile()` 追加で確認）

- Kotlin 側で `@Throws(Exception::class) suspend fun deleteUserProfile()`（既存 `deleteAuthUser()` と完全に同型: 引数なし・戻り値なし）を追加したケースでは、`.swiftinterface` は両方とも `public func deleteXxx() async throws` としか出ず区別がつかない。Obj-C ヘッダ（`SharedLogic.h`）の `- (void)deleteUserProfileWithCompletionHandler:...  __attribute__((swift_name("deleteUserProfile(completionHandler:)")))` で協定名を確認するのが確実（`grep -n "deleteUserProfile" SharedLogic.h`）。
- protocol 実装側（`AuthRepositoryIosImpl` のような NSObject 準拠クラス）で書く実際のメソッド名は、この swift_name そのままではなく **`__` プレフィックスを付けた `__deleteUserProfile(completionHandler:)`**（同ファイルの既存 `__deleteAuthUser`/`__updateAnalyticsConsent` と同じ witness パターン）。「同じ interface 内の既存メソッドと引数の有無・型が完全一致するなら、その既存メソッドの実装をそのままコピーして名前だけ変える」のが最も確実で、`.swiftinterface` を読みに行く前に既存 witness を探すほうが早い。

## Kotlin `object` の `val List<String>` カタログ + `const val` 特殊値を Swift `Picker` の選択肢にする際、legacy 自由入力値のフォールバック表示は「動的に選択肢へ追加」で native Picker のまま解決できる（2026-07-22、産地ドロップダウン化で確認）

- `CoffeeOriginCatalog.shared.countries: [String]` / `.BLEND` / `.OTHER` は SKIE 経由でそのまま `[String]` / `String` として読める（`docs/kmp-bridge.md` の記載どおり、追加のブリッジコード不要）。
- 「Edit モードで catalog に無い legacy 値でも壊れない」要件は、**Menu で自前ラベルを出す**より、**Picker の選択肢配列に legacy 値を動的追加する**方が既存の Picker パターン（`brewMethod`/`processing` 等）と統一でき、アクセシビリティも native のまま乗る。`options = ["", ...countries, BLEND] + (legacy値があれば追加) + [OTHER]` を組み、`selection: Binding<String>` の `set` で `newValue == OTHER` のときだけ「その他モード」用の別 `@State` フラグを立てて自由入力 `TextField` を出す（Picker の `get` はフラグが立っている間 `OTHER` を固定で返す）。
- 「その他」選択時は literal を保存しない仕様のため、フラグを立てるのと同時に `onXxxChanged("")` で一旦空にしてから自由入力に委ねると、選択直後に前の値が誤って保存される事故を防げる。
- `CoffeeRecord` に `origin` + `region`（表示専用の別フィールド）が両方あるケースの表示結合は、`CoffeeRecord` に `extension` で computed property（`originDisplayText`）を生やして複数 View（詳細画面 / シェアカード）から共有するのが最小实装（`iosApp/iosApp/Utilities/` 配下に新規ファイルを置くパターン）。
