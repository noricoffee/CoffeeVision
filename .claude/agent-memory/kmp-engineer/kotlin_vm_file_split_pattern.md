---
name: kotlin-vm-file-split-pattern
description: 800 行超の Kotlin ViewModel を複数ファイルへ機械的に分割するときの手順（CoffeeEditorViewModel 実例）。Swift の extension 分割と異なり Kotlin クラス本体は分割不可な点への対処。
metadata:
  type: project
---

## 背景

Swift 側は `extension ClassName { ... }` で 1 クラスを複数ファイルに割れるが、Kotlin にはこれがない
（`class Foo` 本体は 1 ファイルに閉じる）。KMP の ViewModel が 800 行を超えたら、
**クラスに閉じている必要のない純粋ロジックを top-level `internal` 関数として同一パッケージの
兄弟ファイルへ抽出**するのが唯一の実質的な分割手段（`coding-conventions.md` §3.4 の Kotlin 版）。

## 実例（CoffeeEditorViewModel.kt 896→662 行、2026-07-25）

3 ファイルへ分割:
- `CoffeeEditorViewModel.kt`（クラス本体・型定義・state・ライフサイクル・保存オーケストレーション）
- `CoffeeRecordBuilder.kt`（`validate` / `buildRecord` / `buildCafe` を top-level `internal fun` 化。
  クラス内 private だった頃は `_state.value.mode` / `currentInitialRecord` / `selectedCafe` を暗黙参照
  していたが、これらを引数として明示的に渡す形に変換。呼び出し側（`onSaveTapped` 等）は
  `buildRecord(draft, userId, _state.value.mode, currentInitialRecord, selectedCafe)` のように
  内部プロパティをその場で渡すだけで済んだ）
- `CoffeeEditorMapping.kt`（record ⇄ draft の純粋拡張関数 `toDraft()` / `toDuplicateDraft()`、
  クランプ処理、`defaultDraft()`。これらは元から暗黙の外部状態参照がなく、そのまま `internal` 化して移動するだけ）

## 手順・チェックポイント

1. **nested 型（`sealed interface Mode` / `data class UIState` / `data class CoffeeDraft`）は絶対に
   top-level 化しない** — Swift 公開名が `CoffeeEditorViewModel.UIState` から変わってしまい iOS 追随が要る。
   クラス本体に残す。
2. 移動対象の private メソッドが `_state.value.xxx` や `private var` プロパティを暗黙参照している場合、
   関数シグネチャに明示引数として追加する（例: `buildRecord(draft, userId, mode, initialRecord, selectedCafe)`）。
   呼び出し元の書き換えは通常 1 箇所で済む。
3. 定数（`companion object` の `const val`）は無理に移動しない。**元の場所に残し、
   分割先ファイルからは `CoffeeEditorViewModel.CONST_NAME` で参照する**方が、公開 API 位置を変えず
   シンプル（re-export のための重複定数を作ると設計が汚くなる）。
4. 分割後、元ファイルで **未使用になった import**（`Clock` / `TimeZone` / `todayIn` など、
   移動した関数だけが使っていたもの）と、**もう使われなくなったクラスレベル `@OptIn` アノテーション**
   （例: `kotlin.uuid.ExperimentalUuidApi` — Uuid 生成コードが builder ファイルへ移った場合）を消し忘れない。
5. 検証は `compileCommonMainKotlinMetadata` → `compileKotlinIosSimulatorArm64` →
   `compileTestKotlinIosSimulatorArm64` → `testAndroidHostTest`（`--rerun-tasks` 推奨。
   UP-TO-DATE キャッシュだと「本当に今回のテストが走ったか」の確証が弱い）の順。
   `:shared:framework:assembleSharedLogicXCFramework` まで通すと `compileKotlinIosSimulatorArm64`
   の framework 側も検証できる（sandbox では link 段階で `xcrun xcodebuild` 不在エラーになるのは
   正常。compile が通っていれば十分）。
