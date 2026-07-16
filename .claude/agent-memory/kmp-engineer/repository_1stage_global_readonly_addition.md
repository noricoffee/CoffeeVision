---
name: repository-1stage-global-readonly-addition
description: BeanProfile 型（グローバル read-only + one-shot get + メモリキャッシュ、SQLDelight なし）の新規 Repository を追加するときのファイル一覧・雛形・検証コマンド
metadata:
  type: project
---

`BeanProfileRepository` パターン（フェーズ 19 の `CuratedCafeRepository` で再適用）。
`repository_2stage_addition`（local+remote 合成、per-user 書き込みあり）とは別系統。
こちらは **サービス管理データ・書き込みなし・SQLDelight 不要** な場合に使う（`docs/data-model.md` に設計確定済み前提）。

## 触るファイル一覧（新エンティティ `Foo` の例、Android 実装のみ担当）

1. `shared/domain/src/commonMain/kotlin/com/noricoffee/domain/model/Foo.kt` — data class
2. `shared/domain/src/commonMain/kotlin/com/noricoffee/repository/FooRepository.kt` — `interface { @Throws suspend fun getAll(): List<Foo> }` のみ
3. `shared/data-firebase/src/androidMain/.../FooFirestoreMapper.kt` — `fromDocument(data: Map<String, Any>): List<Foo>`（1 ドキュメントが複数エンティティを埋め込む場合は `List<Foo>` を返す設計にする。1 ドキュメント = 1 エンティティなら `Foo?` を返す BeanProfile 型でよい）。必須フィールド欠落は mapNotNull で skip、Firestore の数値は `(value as? Number)?.toDouble()` で受ける（Long/Double どちらもありうる）
4. `shared/data-firebase/src/androidMain/.../FooRepositoryAndroidImpl.kt` — `suspendCancellableCoroutine` + `db.collection("foo").get()` + メモリキャッシュ（`private var cache: List<Foo>? = null`）。BeanProfileRepositoryAndroidImpl の丸ごとコピーで足りる
5. `shared/data-firebase/src/androidHostTest/.../FooFirestoreMapperTest.kt` — 正常系 / 必須フィールド欠落 skip / Long 座標の Double 変換
6. `AppContainer.kt`: primary constructor + **全セカンダリコンストラクタ**（本プロジェクトは 2 本ある: 7 引数版 iOS 用 / 6 引数版 Android 用）に `val fooRepository: FooRepository` を追加。KDoc 内の「Swift 側の呼び出しシグネチャ」コメント文字列も両方更新すること（`.h` で裏取りする前提の記述なので更新漏れは実害小さいが一貫性のため直す）
7. `AppContainerViewModelFactory.kt`: 該当 `make*ViewModel` に配線
8. `androidApp/.../CoffeeVisionApp.kt`: `AppContainer(...)` 呼び出しに `fooRepository = FooRepositoryAndroidImpl(FirebaseFirestore.getInstance())` を追加
9. 既存 ViewModel に追加する場合、commonTest の全 Fake 呼び出し箇所に新パラメータが要る。`python3` で `"savedCafeRepository = fakeSavedCafeRepo,\n            userId = ..."` → 同文字列 + `curatedCafeRepository = fakeCuratedCafeRepo,\n            userId = ...` の一括置換が速い。ただしテストファイルによっては fake が「クラスフィールド共有」（`PoiLookupTest`）と「テストごとにローカル変数」（`SavedCafeTest`）の 2 流儀が混在するので、置換後に `grep -n "fakeCuratedCafeRepo"` で未定義参照がないか必ず確認する（ローカル変数流儀のファイルでは inline `FakeCuratedCafeRepository()` に個別置換し直す必要がある）

## 検証コマンド

```
./gradlew :shared:domain:compileKotlinIosSimulatorArm64 \
  :shared:data-firebase:compileAndroidMain :shared:data-firebase:testAndroidHostTest
./gradlew :shared:core:compileKotlinIosSimulatorArm64 :shared:framework:compileKotlinIosSimulatorArm64 \
  :shared:feature:<xxx>:compileKotlinIosSimulatorArm64
./gradlew :shared:feature:<xxx>:compileTestKotlinIosSimulatorArm64 :shared:feature:<xxx>:testAndroidHostTest
./gradlew :androidApp:assembleDebug
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./gradlew :shared:framework:assembleSharedLogicXCFramework
```

`assembleSharedLogicXCFramework` は DEVELOPER_DIR 環境変数だけで sandbox でも最後まで通る（2026-07-17 確認、debug/release 両方、約 50 秒）。
生成物の `.../SharedLogic.framework/Headers/SharedLogic.h`（Obj-C ヘッダ）で `@interface SharedLogicAppContainer` /
`@interface SharedLogicFooRepository` / `@interface SharedLogicXxxViewModelUIState` を grep すれば、
Swift から見える `initWith...:` / property 名 / `NSArray<SharedLogicFoo *>` 型を正確に裏取りできる
（`.swiftinterface` は SKIE が生成した suspend 関数の拡張しか載らず、クラス本体は `.h` 側にしかない）。
