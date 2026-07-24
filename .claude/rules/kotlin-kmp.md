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
