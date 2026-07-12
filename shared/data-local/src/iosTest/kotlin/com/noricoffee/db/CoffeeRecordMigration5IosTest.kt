package com.noricoffee.db

import app.cash.sqldelight.driver.native.NativeSqliteDriver
import co.touchlab.sqliter.DatabaseConfiguration
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * migration `5.sqm`（2026-07-12 B-4: `rating` の NOT NULL 撤廃 + テーブル再作成）を、
 * **本番と同じ `NativeSqliteDriver`（sqliter）** 上で検証する iOS ターゲット版。
 *
 * ## なぜ別途 iOS 版が必要か
 * `CoffeeRecordMigration5Test`（androidHostTest）は JVM の `JdbcSqliteDriver` を使うが、
 * SQLite の `PRAGMA foreign_keys` は「トランザクション内では無視される」という制約があり、
 * ドライバ（sqliter vs sqlite-jdbc）ごとに migration 実行時のトランザクションラップ挙動が
 * 異なる可能性がある。JVM 側が green でも sqliter 側で FK 制約が有効なまま
 * `DROP TABLE coffee_record`（親テーブル）が実行され孤児化する、という事態を本テストで検出する。
 *
 * ## v4 スキーマの構築方法
 * [createInMemoryTestSqlDriver] は `NativeSqliteDriver(schema = AppDatabase.Schema, ...)` の
 * 便利コンストラクタを使うため、DB 未作成時は常に `schema.create()`（= 現行 head スキーマ）が
 * 直接構築されてしまい、v4 相当（migration 5 適用前）の状態を再現できない。
 * そこで `NativeSqliteDriver(configuration: DatabaseConfiguration)` の低レベルコンストラクタを使い、
 * `create` を no-op にした生ドライバを取得し、`androidHostTest` 版と同じく生 DDL で
 * v4 スキーマを直接構築してから `AppDatabase.Schema.migrate(driver, 5L, 6L)` を呼ぶ。
 *
 * バージョン番号の意味（`oldVersion=5, newVersion=6`）は `androidHostTest` 版と同じ
 * （`sqldelight_migration_version_semantics.md` 参照。`.sqm` が 5 個 → `Schema.version = 6`、
 * `N.sqm` は `version N → N+1` の遷移。migration 5 だけを走らせるには oldVersion=5 が必要）。
 */
class CoffeeRecordMigration5IosTest {

    private val driver: NativeSqliteDriver = NativeSqliteDriver(
        DatabaseConfiguration(
            name = "coffee-record-migration5-test.db",
            version = 1,
            create = { /* no-op: 本テストでは v4 スキーマを生 DDL で自前構築する */ },
            inMemory = true,
            extendedConfig = DatabaseConfiguration.Extended(
                // 本番ドライバ（DatabaseDriverFactory.ios.kt）と同じく FK を有効化する
                foreignKeyConstraints = true,
            ),
        ),
    )

    @AfterTest
    fun tearDown() {
        driver.close()
    }

    @Test
    fun migration5_converts_legacy_zero_rating_to_null_and_preserves_photo_fk_on_native_driver() {
        // migration 4 まで適用した状態（rating REAL NOT NULL、brew_recipe まで含む）を生 DDL で構築
        createV4Schema()

        val db = AppDatabase(driver)

        // v4 スキーマの coffee_record に rating=0.0（旧 sentinel）の行を直接挿入する
        db.coffeeRecordQueries.upsert(
            id = "r-zero",
            user_id = "user-1",
            cafe_place_id = null,
            cafe_name = null,
            cafe_address = null,
            cafe_latitude = null,
            cafe_longitude = null,
            cafe_photo_references = null,
            cafe_website_url = null,
            cafe_maps_url = null,
            visited_on = "2026-06-01",
            rating = 0.0,
            notes = "",
            name = "raw",
            brew_method = "HandDrip",
            origin = null,
            variety = null,
            processing = null,
            roast_level = null,
            cup = null,
            brew_recipe = null,
            sweetness = null,
            body = null,
            acidity = null,
            flavor = null,
            aftertaste = null,
            tags = "[]",
            created_at = 1_750_000_000_000,
            updated_at = 1_750_000_000_000,
        )
        // 比較用: 通常評価済みの行（0.0 以外）は変化しないことも確認する
        db.coffeeRecordQueries.upsert(
            id = "r-rated",
            user_id = "user-1",
            cafe_place_id = null,
            cafe_name = null,
            cafe_address = null,
            cafe_latitude = null,
            cafe_longitude = null,
            cafe_photo_references = null,
            cafe_website_url = null,
            cafe_maps_url = null,
            visited_on = "2026-06-02",
            rating = 4.5,
            notes = "",
            name = "raw-rated",
            brew_method = "HandDrip",
            origin = null,
            variety = null,
            processing = null,
            roast_level = null,
            cup = null,
            brew_recipe = null,
            sweetness = null,
            body = null,
            acidity = null,
            flavor = null,
            aftertaste = null,
            tags = "[]",
            created_at = 1_750_000_000_000,
            updated_at = 1_750_000_000_000,
        )

        // FK 検証対象の photo 子行（r-zero にぶら下げる）
        db.photoQueries.upsert(
            id = "p-zero",
            record_id = "r-zero",
            file_name = "p.jpg",
            local_path = "photos/p.jpg",
            remote_url = null,
            width = null,
            height = null,
            created_at = 1_750_000_000_000,
            sort_order = 0,
        )

        // migration 5 を適用（rating nullable 化 + テーブル再作成）。
        // sqliter は FK 有効なままこの一連の DDL/DML を実行することになるため、
        // ここで FOREIGN KEY constraint 違反例外が飛ぶかどうかが本テストの核心の懸念点。
        AppDatabase.Schema.migrate(driver, 5L, 6L)

        val zeroRow = db.coffeeRecordQueries.selectById("r-zero").executeAsOne()
        assertNull(zeroRow.rating, "旧 sentinel rating=0.0 は migration 5 で NULL に変換されるべき（sqliter）")

        val ratedRow = db.coffeeRecordQueries.selectById("r-rated").executeAsOne()
        assertEquals(4.5, ratedRow.rating, "0.0 以外の rating は migration 5 で変化しないべき（sqliter）")

        // photo の FK（record_id）がテーブル再作成後も孤児化せず残っていること
        val photos = db.photoQueries.selectByRecord("r-zero").executeAsList()
        assertEquals(1, photos.size, "migration 5 のテーブル再作成後も photo の FK 参照は保たれるべき（sqliter）")
        assertEquals("p-zero", photos.first().id)

        // FK が実効のままであることの確認（record 削除で ON DELETE CASCADE が機能する）
        db.coffeeRecordQueries.deleteById("r-zero")
        assertTrue(
            db.photoQueries.selectByRecord("r-zero").executeAsList().isEmpty(),
            "migration 後も ON DELETE CASCADE が機能するべき（sqliter）",
        )
    }

    /**
     * migration 4 適用後（= migration 5 適用前）の `coffee_record` / `photo` テーブルを
     * 生 DDL で構築する。`coffee_record.rating` が `NOT NULL` である点が現行 `.sq` との唯一の差分。
     * `CoffeeRecordMigration5Test.kt`（androidHostTest）の `createV4Schema()` と同一内容。
     */
    private fun createV4Schema() {
        driver.execute(
            null,
            """
            CREATE TABLE coffee_record (
                id TEXT NOT NULL PRIMARY KEY,
                user_id TEXT NOT NULL,
                cafe_place_id TEXT,
                cafe_name TEXT,
                cafe_address TEXT,
                cafe_latitude REAL,
                cafe_longitude REAL,
                cafe_photo_references TEXT,
                cafe_website_url TEXT,
                cafe_maps_url TEXT,
                visited_on TEXT NOT NULL,
                rating REAL NOT NULL,
                notes TEXT NOT NULL,
                name TEXT NOT NULL,
                brew_method TEXT NOT NULL,
                origin TEXT,
                variety TEXT,
                processing TEXT,
                roast_level TEXT,
                cup TEXT,
                brew_recipe TEXT,
                sweetness INTEGER,
                body INTEGER,
                acidity INTEGER,
                flavor INTEGER,
                aftertaste INTEGER,
                tags TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent(),
            0,
            null,
        )
        driver.execute(null, "CREATE INDEX coffee_record_by_user_visited ON coffee_record (user_id, visited_on DESC)", 0, null)
        driver.execute(null, "CREATE INDEX coffee_record_by_cafe ON coffee_record (cafe_place_id)", 0, null)

        driver.execute(
            null,
            """
            CREATE TABLE photo (
                id TEXT NOT NULL PRIMARY KEY,
                record_id TEXT NOT NULL,
                file_name TEXT,
                local_path TEXT,
                remote_url TEXT,
                width INTEGER,
                height INTEGER,
                created_at INTEGER NOT NULL,
                sort_order INTEGER NOT NULL,
                FOREIGN KEY (record_id) REFERENCES coffee_record(id) ON DELETE CASCADE
            )
            """.trimIndent(),
            0,
            null,
        )
        driver.execute(null, "CREATE INDEX photo_by_record ON photo (record_id, sort_order)", 0, null)
    }
}
