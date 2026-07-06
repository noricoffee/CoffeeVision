# kmp-engineer memory

（作業ノウハウをここに蓄積する。仕様・トレードオフ・汎用教訓は書かない — それらはレポートで親に返す）

- [Repository 2 段構成の追加手順](repository_2stage_addition.md) — CoffeeRepository と同型の新 Repository（例: SavedCafe）を足すときのファイル一覧とコマンド
- [SQLDelight migration 検証タスク](sqldelight_migration_check.md) — `verifySqlDelightMigration` で migration ↔ 最終スキーマの整合を機械確認できる
- [CoffeeEditor 複数 Mode パターン](coffee_editor_multimode_pattern.md) — Mode 追加時の見落とし箇所 3 つ + nested private class から外側 private fun 呼べない罠
