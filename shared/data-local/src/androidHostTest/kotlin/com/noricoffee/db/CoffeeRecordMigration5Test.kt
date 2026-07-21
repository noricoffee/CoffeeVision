package com.noricoffee.db

import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * migration `5.sqm`（2026-07-12 B-4: `rating` の NOT NULL 撤廃 + テーブル再作成）の
 * データ変換と FK 保持を検証する。
 *
 * `JdbcSqliteDriver` は JVM 専用のため、[TestSqlDriver.android.kt] と同じく androidHostTest に置く
 * （`AppDatabase.Schema.migrate` を任意のバージョン間で明示的に呼べる低レベル API が必要なため、
 * 常に最新スキーマを直接作成する [createInMemoryTestSqlDriver] は使わない）。
 *
 * ## v4 スキーマの構築方法
 * `AppDatabase.Schema.migrate(driver, 0, 4)` は使えない — `.sqm` は「直前バージョンからの差分」
 * （例: `1.sqm` は `ALTER TABLE photo ADD COLUMN ...`）のみを記述しており、
 * バージョン 0 の時点で `coffee_record` / `photo` テーブルが既に存在すること前提のため、
 * 空の DB に対して `migrate(0, 4)` を呼ぶと `no such table` で失敗する。
 * そのため、migration 5 直前（= migration 4 適用後）のテーブル定義を生 DDL で直接構築する。
 */
class CoffeeRecordMigration5Test {

    private val driver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)

    @AfterTest
    fun tearDown() {
        driver.close()
    }

    @Test
    fun migration5_converts_legacy_zero_rating_to_null_and_preserves_photo_fk() {
        // 本番ドライバと同じく FK を有効化した状態で migration 5 を通す（PRAGMA OFF/ON の実効性を検証）
        driver.execute(null, "PRAGMA foreign_keys = ON", 0, null)

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
            region = null,
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
            region = null,
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

        // migration 5（rating nullable 化 + テーブル再作成）+ migration 6（region 列追加）を適用する。
        // SQLDelight の Schema.version は「.sqm ファイル数 + 1」（baseline=1、migration N.sqm は
        // version N→N+1 の遷移）。5.sqm だけを走らせるなら oldVersion=5 → newVersion=6 で足りるが、
        // 生成される `coffeeRecordQueries` は常に**現行 head スキーマ**（region 列を含む）基準のため、
        // 6.sqm まで通して region 列を復元しないと直後の型付き selectById が列不足で失敗する。
        // よって newVersion は現行 head バージョン（7）まで進める
        // （migrateInternal の各ブロックは `oldVersion <= N && newVersion > N` で判定するため）。
        AppDatabase.Schema.migrate(driver, 5L, 7L)

        val zeroRow = db.coffeeRecordQueries.selectById("r-zero").executeAsOne()
        assertNull(zeroRow.rating, "旧 sentinel rating=0.0 は migration 5 で NULL に変換されるべき")

        val ratedRow = db.coffeeRecordQueries.selectById("r-rated").executeAsOne()
        assertEquals(4.5, ratedRow.rating, "0.0 以外の rating は migration 5 で変化しないべき")

        // photo の FK（record_id）がテーブル再作成後も孤児化せず残っていること
        val photos = db.photoQueries.selectByRecord("r-zero").executeAsList()
        assertEquals(1, photos.size, "migration 5 のテーブル再作成後も photo の FK 参照は保たれるべき")
        assertEquals("p-zero", photos.first().id)

        // FK が実効のままであることの確認（record 削除で ON DELETE CASCADE が機能する）
        db.coffeeRecordQueries.deleteById("r-zero")
        assertTrue(
            db.photoQueries.selectByRecord("r-zero").executeAsList().isEmpty(),
            "migration 後も ON DELETE CASCADE が機能するべき",
        )
    }

    /**
     * migration 4 適用後（= migration 5 適用前）の `coffee_record` / `photo` テーブルを
     * 生 DDL で構築する。`coffee_record.rating` が `NOT NULL` である点が現行 `.sq` との差分。
     *
     * 本来 `region` 列は migration 6（v6 以降）で追加されるため v4 時点には存在しないが、
     * 生成される `coffeeRecordQueries`（型付き API）は常に現行 head スキーマ基準の SQL を発行するため、
     * ここでの型付き `upsert` 呼び出しを成立させる目的で `region TEXT` を含めている
     * （migration 5 のテーブル再作成は明示的な列挙 SELECT のため、この余剰列は 5.sqm 実行時に
     * 一旦失われ、直後に 6.sqm の `ALTER TABLE ADD COLUMN region` で作り直される。値は常に null のため実害なし）。
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
                region TEXT,
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
