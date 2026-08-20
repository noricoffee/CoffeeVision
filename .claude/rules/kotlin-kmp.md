---
paths:
  - "shared/**"
  - "sharedUI/**"
  - "androidApp/**"
  - "build-logic/**"
  - "**/*.kt"
  - "**/*.gradle.kts"
---

# Kotlin / KMP 実装規約（要点）

正本は [`docs/coding-conventions.md`](../../docs/coding-conventions.md) / [`docs/architecture.md`](../../docs/architecture.md) / [`docs/kmp-bridge.md`](../../docs/kmp-bridge.md)。ここは常時確認する要点のみ。

- 公式 [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html) に従う。ViewModel は `<機能名>ViewModel` と命名し、UI イベントは `on○○Tapped` 等のメソッドで受ける
- **1 ファイル / 1 型が肥大化したら責務分割**（目安: **800 行超**で分割検討。PostToolUse フック `check-file-size.sh` が警告）。UseCase / Repository / `expect`-`actual` ラッパ等へ切り出す。詳細は [`coding-conventions.md`](../../docs/coding-conventions.md) §3.4
  - 分割・リネームで **`public` メンバ（特に companion メンバ・nested 型）の定義位置や可視性を変えると Swift Bridge を壊す**（`companion.foo()` 参照が解決不能に / `internal` 化で ObjC ヘッダから消える）。元が `public` のシンボルは定義位置を保持する。KMP モジュールの Kotlin テストは Swift コンパイルを検証しないため、`commonMain` の public API に触れる分割は**親が実 Swift ビルドまで検証**する（lessons 2026-07-25）
- `when` は全ケースを網羅する（`else` は極力使わない）
- コルーチン内で `runCatching` を使わない。`try/catch` + `CancellationException` の先行 catch & 再スロー
- 各 ViewModel は注入 scope から子スコープ（`SupervisorJob(parentJob)`）を所有し `clear()` で畳む
- Swift から呼ぶ `suspend` 関数には `@Throws`。デフォルト引数に頼らずオーバーロードで表現（SKIE はデフォルト引数を Swift に出さない）

## コード生成時のチェックリスト

- [ ] ドメインモデルは `data class`、UI 状態は `data class` または `sealed interface`
- [ ] ViewModel は `StateFlow<UIState>` を 1 本だけ公開しているか
- [ ] 副作用は `suspend` 関数または `Flow` として定義されているか
- [ ] `commonMain` で書ける処理を `iosMain` / `androidMain` に漏らしていないか
- [ ] `when` で全ケースを網羅しているか
- [ ] 配置先モジュールが正しいか（モデル / UseCase は `domain`、ViewModel は `feature/*`、DB は `data-local`、Places は `data-places`、Firestore は `data-firebase`）
- [ ] **`CoffeeRecord` 等のドメインモデルにフィールドを足したら、写る先 6 経路すべてを追随したか**（①domain model ②SQLDelight = `.sq` の列 + `upsert` の列/VALUES + `Mapper.toDomain`/`toRow` + `LocalCoffeeRepository.save` の named 引数 + migration ③Firestore mapper の **Kotlin / Swift 両方** の encode / decode ④**export DTO + `CoffeeRecordExportMapper`** ⑤`feature/coffee-editor` の Draft 往復（`toDraft` / **`toDuplicateDraft`**）⑥**`scripts/seed/seed-coffees.mjs` の `toDocument`**（開発用インポート）／ 仕様の正本は [`data-model.md`](../../docs/data-model.md) §1.1・§2.1・§3.2・§8）。**④⑥ は手写しの allowlist でコンパイラも芋づる grep も検出しない**ため、`grep -rl "CoffeeRecordExportDto\|CoffeeRecordExportMapper" shared --include="*.kt" | grep -v /build/` と `grep -n "record\." scripts/seed/seed-coffees.mjs` を明示的に回す（⑥ は `scripts/**` = 親の管轄なので、サブエージェントは漏れを見つけたら親へ依頼で返す）。lessons 2026-07-08 / 2026-07-25
- [ ] **ユーザーに紐づく永続ストアを新設したら、削除経路にも同じ差分で追随したか**（Firestore コレクション / SQLDelight テーブル / 端末のファイル領域）。上のチェックは**フィールド**を足したときの話で、**ストアそのもの**を増やしたときは別軸。**消し漏れはコードのどこにも現れず、型検査もテストも検出しない**（書かなかったことによるバグなので grep する対象すら無い）。削除範囲の正本は [`data-model.md`](../../docs/data-model.md) §3.1「アカウント削除で消す範囲」で、そこと `DeleteAccountUseCase` を同時に更新する。削除は**サブコレクション → 親ドキュメント → 認証ユーザー**の順（Firestore はカスケードしない / Auth 削除後は Rules で配下に到達不能）。`ON DELETE CASCADE` に頼るテーブルは **FK が両ターゲットで有効か**まで確認する。lessons 2026-08-06
- [ ] **機能を撤去したら、残骸を 4 層すべてで数えたか**（①domain の interface メソッド ②`AppContainer` のプロパティ ③**ブリッジ = `shared/framework` の `AppContainer` 拡張・`@Throws` 付き public 関数** ④プラットフォーム実装 = `androidMain` の override / `iosApp` の Swift 実装）。**③ は iOS からしか呼ばれない前提なので Kotlin 側 grep では生死にかかわらず「宣言 1・参照 0」に見える** — 生死は `iosApp` / `androidApp` を含めた呼び出し元の有無で判定する。削除順は **KMP → iOS**（逆順だと Swift のプロトコル要件が未実装になり壊れる）。「呼び出し元ゼロ」を KDoc の注記に落として残さない。lessons 2026-07-31
