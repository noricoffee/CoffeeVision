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
- [VM の Repository メソッド差し替えパターン](vm_repository_method_swap_pattern.md) — searchText→searchNearby 等の呼び出し先変更時の KDoc 更新箇所 3 つ + Fake テストのリネーム手順 + 他 feature への影響 grep
- [POI 近傍曖昧性解消パターン](poi_nearby_disambiguation_pattern.md) — searchNearby 結果から単一候補を`.first()`だけで選ぶと別店を拾う。名前一致優先+フォールバックの実装場所
- [Mapper enum フォールバック + raw row テスト手法](mapper_enum_fallback_and_raw_row_test.md) — `valueOf`→`entries.firstOrNull` 置換の記録。ドメインモデルを経由せず SQLDelight クエリへ直接不正値を書き込むテストヘルパーの作り方
- [OriginNormalizer シノニム辞書導入](origin_normalizer_synonym_dict.md) — origin 正規化 5 箇所の置換リスト + 辞書完全一致方式が複合語 contains テストを壊す既知トレードオフ
- [SQLDelight migration のバージョン番号の実際の意味](sqldelight_migration_version_semantics.md) — `oldVersion<=N` の罠（N.sqm だけ実行するには oldVersion=N+1）/ `migrate(0,N)` が空DBで失敗する理由 / テーブル再作成 migration の PRAGMA foreign_keys は ON/OFF でなく 0/1 / iOS 版 migration テスト（NativeSqliteDriver 低レベル構築 + `klib dump-abi` での API 裏取り）/ sandbox でも `iosSimulatorArm64Test` が通った実績
- [commonTest 新設時の手順](commontest_first_setup_in_feature_module.md) — build.gradle.kts の commonTest 依存追加漏れ（kotlinx.datetime 等）/ sandbox で assembleXCFramework は compile までは成功し link だけ xcodebuild 不在で失敗するのが正常
- [タブ常駐 VM の onAppear 冪等化パターン](tab_resident_vm_onappear_idempotency.md) — 無引数 onAppear + タブ常駐 VM の再購読ガード / 同値 emit スキップ / Job 未実行キャンセルによるテストの罠
