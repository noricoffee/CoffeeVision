---
name: vm-test-verification-gotchas
description: ViewModel の commonTest を追加/検証するときに踏みやすい 2 つの罠（未コンパイルの既存テスト・vm.clear() 忘れ）と切り分け方
metadata:
  type: project
---

## 罠1: 既存テストファイルが実は一度もコンパイルを通っていない

`compileCommonMainKotlinMetadata` や `compileKotlinIosSimulatorArm64`（main）が green でも、
同じモジュールの `commonTest` が別の理由でコンパイル不能なまま放置されていることがある
（例: 2026-07-06、`AnalysisViewModelQaTest.kt` の fake が `CoffeeInsightProvider.summarizeBeanTraits`
未実装のまま長期間コンパイルエラーだった）。自分の新規テストを同じ commonTest ソースセットに追加すると、
この既存エラーに巻き込まれて `compileTestKotlinIosSimulatorArm64` / `testAndroidHostTest` が落ちる。

**切り分け方**: `git stash -u` で自分の変更を退避し、同じコマンドを実行して同じエラーが出るか確認する
（`-u` を付けないと新規ファイルが残ってしまい誤診断になる）。既存の別バグと確認できたら、
自分のタスクを検証可能にするための最小修正として直してよい（スコープ内 commonTest ファイルの trivial fix）。

## 罠2: `UncompletedCoroutinesError`（vm.clear() 忘れ）

`viewModelScope = CoroutineScope(scope.coroutineContext + SupervisorJob(...))` パターンの VM は、
`SupervisorJob()` を手動生成しているため子コルーチンが全部完了しても Job 自体は自動完了しない
（`Job()`/`SupervisorJob()` の既知の仕様）。テストの最後に `vm.clear()`（内部で `viewModelScope.cancel()`）
を呼ばないと `runTest` が終了時チェックで `UncompletedCoroutinesError` を報告する。

罠1 を直した直後にこれが連鎖して出ることがある（コンパイルが通って初めて実行され、
初めて発覚する）。`coffee-list` / `coffee-editor` 等のテストファイルは既に
`try { ... } finally { vm.clear() }` テンプレートを徹底しているので、新規 VM テストファイルも
最初からこのテンプレートで書く。既存ファイルを触る場合は全テストへの一括追随が必要（部分適用だと
直した分だけ green になり中途半端な状態になる）。

## 関連

`docs/coding-conventions.md` / `.claude/rules/kotlin-kmp.md` に「各 ViewModel は注入 scope から子スコープ
（`SupervisorJob(parentJob)`）を所有し `clear()` で畳む」の規約はあるが、テスト側の
`vm.clear()` 徹底は docs 化されていない実装コンベンション（各テストファイルのコメントに散在）。
