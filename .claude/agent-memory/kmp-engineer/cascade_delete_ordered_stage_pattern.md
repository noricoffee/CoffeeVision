---
name: cascade-delete-ordered-stage-pattern
description: 複数 Repository をまたぐ順序保証つき削除 UseCase（例 DeleteAccountUseCase）を拡張するときのテスト設計と検証コマンド
metadata:
  type: project
---

`DeleteAccountUseCase`（`shared/domain/.../usecase/DeleteAccountUseCase.kt`）のように「サブコレクション群 → ルートドキュメント → Auth 本体」の順で複数 Repository を消す UseCase に新しい削除ステージを挟むときの実地パターン（2026-08-06、`SavedCafeRepository` の全削除 + `AuthRepository.deleteUserProfile()` 追加で確認）。

## 実装の型
- 各ステージは `repository.observeAll(userId).first()` でスナップショットを取り、`for` ループで個別 `delete()`。bulk delete API は意図的に用意しない（アカウント削除は稀頻度、N+1 許容と UseCase の KDoc に明記されている）
- 新ステージは既存ステージの**前**に挿す方が安全になりやすい（サブコレクション削除は Auth 本体削除より必ず前でなければならない制約があるため、末尾に近いほど「後で処理」の制約が強い）
- Repository interface に足す新メソッド（例 `deleteUserProfile()`）は既存の同系メソッド（`updateAnalyticsConsent` 等）の隣に置き、KDoc に「どのメソッドの直前/直後に呼ぶか」を明記する。呼び出し順が仕様そのものなので、UseCase 側 KDoc とインターフェース側 KDoc の両方に理由（Firestore はルートdocでサブコレクションをカスケードしない/Auth削除後はRulesでアクセス不可になる）を書く

## テスト設計（順序保証 + 早期中断の両方を見る）
- 全 Fake に**共通の `callOrder: MutableList<String>`** を渡し、各 `delete`/呼び出しごとに `"savedCafe:$id"` のようなタグを push する。`indexOfFirst`/`indexOfLast` で「ステージ A の全呼び出し < ステージ B の最初の呼び出し」を検証すると、件数が変わっても壊れにくい
- 各ステージについて「そのステージが例外を投げたら後続ステージが一切呼ばれない」ケースを 1 つずつ用意する（於 N ステージなら N-1 個の失敗テスト + 1 個の成功テスト + 1 個の空リストテストが最小セット）
- 0 件でも後続が実行されることの確認を忘れない（`observeAll` が空リストを返すケース）

## Fake 更新の見落としやすい場所
`AuthRepository` のような複数箇所で Fake 実装されるグローバル interface にメソッドを足すと、以下 3 種の Fake が同時に壊れる（コンパイラが検出するので漏れる心配は薄いが、探索コマンドとして）:
```
grep -rn "class Fake.*AuthRepository\|: AuthRepository" shared --include="*.kt" | grep -v /build/
```
新メソッドを呼ばない Fake は `override suspend fun deleteUserProfile() = Unit` のような 1 行スタブで十分（UseCase 側のテストでのみ挙動を作り込む）。

## 検証コマンド（実績: 2026-08-06）
```
./gradlew :shared:domain:compileCommonMainKotlinMetadata :shared:data-firebase:testAndroidHostTest \
  :shared:framework:compileCommonMainKotlinMetadata :shared:feature:account:compileCommonMainKotlinMetadata
./gradlew :shared:feature:account:testAndroidHostTest :shared:domain:testAndroidHostTest
./gradlew :shared:domain:compileKotlinIosSimulatorArm64 :shared:feature:account:compileKotlinIosSimulatorArm64 \
  :shared:framework:compileKotlinIosSimulatorArm64
./gradlew :shared:feature:account:compileTestKotlinIosSimulatorArm64 :shared:domain:compileTestKotlinIosSimulatorArm64
./gradlew :shared:framework:assembleSharedLogicXCFramework
```
`shared/data-firebase` に Android 専用の compile タスク名（`compileDebugKotlinAndroid` 等）は存在しない。`testAndroidHostTest`（main + test 両方コンパイルしてから実行）で代用する。`assembleSharedLogicXCFramework` は sandbox では `compileKotlinIosSimulatorArm64`（および `skieUnpackSwiftSources*`）まで成功し、`linkReleaseFrameworkIosSimulatorArm64` / `linkDebugFrameworkIosSimulatorArm64` だけが `xcrun xcodebuild -version` 不在で FAILED になるのが正常（[[commontest_first_setup_in_feature_module]] の既存知見と一致）。

## Swift 側シグネチャの裏取り
「Swift が Kotlin interface を実装する」方向（`AuthRepository` はこちら）の無引数 `suspend fun` は、`iosApp/iosApp/FirebaseRepositories/AuthRepositoryIosImpl.swift` の既存メソッド（`__deleteAuthUser` / `__updateAnalyticsConsent`）から実地パターンが確認できる:
```swift
func __deleteUserProfile(
    completionHandler: @escaping @Sendable ((any Error)?) -> Void
) { ... }
```
`__` プレフィックス + `completionHandler` 引数（`Error?` 一つ）が無引数 `@Throws suspend fun` の定型。iosApp は自分のスコープ外だが、読み取りだけなら既存実装を grep して裏取りできる。
