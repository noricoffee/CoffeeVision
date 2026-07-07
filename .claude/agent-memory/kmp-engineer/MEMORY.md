# kmp-engineer memory

（作業ノウハウをここに蓄積する。仕様・トレードオフ・汎用教訓は書かない — それらはレポートで親に返す）

- [Repository 2 段構成の追加手順](repository_2stage_addition.md) — CoffeeRepository と同型の新 Repository（例: SavedCafe）を足すときのファイル一覧とコマンド
- [SQLDelight migration 検証タスク](sqldelight_migration_check.md) — `verifySqlDelightMigration` で migration ↔ 最終スキーマの整合を機械確認できる
- [CoffeeEditor 複数 Mode パターン](coffee_editor_multimode_pattern.md) — Mode 追加時の見落とし箇所 3 つ + nested private class から外側 private fun 呼べない罠
- [VM テスト検証の罠2つ](vm_test_verification_gotchas.md) — 既存 commonTest が未コンパイルのまま放置 / `vm.clear()` 忘れによる `UncompletedCoroutinesError` の切り分け方
- [CoffeeRecord へのカラム追加手順](coffee_record_column_addition.md) — cup と同型の nullable TEXT 属性を追加するときのファイル一覧。`LocalCoffeeRepository.save()` の `upsert()` 呼び出し漏れに注意
- [Edit ツールの全角文字ミスマッチ](edit_tool_fullwidth_char_gotcha.md) — 日本語コメントの全角括弧等で Edit が繰り返し失敗するときは python3 スクリプト置換に切り替える
- [kotlinx-serialization export DTO の罠](kotlinx_serialization_export_gotchas.md) — `encodeDefaults` 既定 false でデフォルト値フィールドが消える / `JsonNull` は非 null / SKIE は `invoke` を `callAsFunction` 化しない / DEVELOPER_DIR での XCFramework 検証再確認
- [CoffeeStats 派生 UseCase 追加パターン](coffeestats_derived_usecase_addition.md) — BeanProfile 突合系の新集計は `BuildCoffeeStatsUseCase.invoke()` 内で計算し `CoffeeStats` に直生やしする（VM 配線不要）。`BeanProfileMatchUseCase` の再利用ポイント
- [Cafe 揮発フィールド追加パターン](cafe_volatile_places_field_addition.md) — FieldMask/DTO/PlaceSummary/Mapper の 5 箇所 + `CafeDetailViewModel` の条件付き Details リフレッシュ設計（`googleRating` を鮮度センチネルに使う）
