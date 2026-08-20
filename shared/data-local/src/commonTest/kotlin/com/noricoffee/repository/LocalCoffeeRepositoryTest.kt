package com.noricoffee.repository

import com.noricoffee.db.AppDatabase
import com.noricoffee.db.createInMemoryTestSqlDriver
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.coroutines.coroutineContext
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class LocalCoffeeRepositoryTest {

    private lateinit var repository: LocalCoffeeRepository
    private lateinit var db: AppDatabase
    private val driver = createInMemoryTestSqlDriver()

    @BeforeTest
    fun setUp() {
        db = AppDatabase(driver)
    }

    @AfterTest
    fun tearDown() {
        driver.close()
    }

    // --- 基本的な CRUD ---

    @Test
    fun saved_record_with_cafe_is_observable_by_id() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord()
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertEquals(record, loaded)
    }

    @Test
    fun saved_record_without_cafe_null_is_observable_by_id() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord(cafe = null)
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertEquals(record, loaded)
        assertNull(loaded?.cafe, "セルフ抽出レコードの cafe は null であるべき")
    }

    @Test
    fun observe_all_orders_by_visited_on_descending() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val older = sampleRecord(id = "r1", visitedOn = LocalDate(2026, 5, 30))
        val newer = sampleRecord(id = "r2", visitedOn = LocalDate(2026, 6, 1))
        repository.save(older)
        repository.save(newer)

        val list = repository.observeAll(USER_ID).first()
        assertEquals(listOf("r2", "r1"), list.map { it.id })
    }

    @Test
    fun observe_by_cafe_returns_records_for_the_place() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val a = sampleRecord(id = "a", placeId = "place-a")
        val b = sampleRecord(id = "b", placeId = "place-b")
        repository.save(a)
        repository.save(b)

        val list = repository.observeByCafe(USER_ID, "place-a").first()
        assertEquals(listOf("a"), list.map { it.id })
    }

    @Test
    fun observe_by_cafe_excludes_null_cafe_records() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val withCafe = sampleRecord(id = "with-cafe", placeId = "place-1")
        val selfExtract = sampleRecord(id = "self", cafe = null)
        repository.save(withCafe)
        repository.save(selfExtract)

        // セルフ抽出レコードは selectByCafe クエリで自然に除外される
        val list = repository.observeByCafe(USER_ID, "place-1").first()
        assertEquals(listOf("with-cafe"), list.map { it.id })
    }

    @Test
    fun save_replaces_existing_record_and_photos() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val original = sampleRecord()
        repository.save(original)

        val updated = original.copy(
            rating = 5.0,
            notes = "updated notes",
            name = "Updated Coffee",
        )
        repository.save(updated)

        val loaded = repository.observeById(original.id).first()
        assertEquals(updated, loaded)
    }

    @Test
    fun delete_removes_record_and_cascades_photos() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord()
        repository.save(record)
        repository.delete(USER_ID, record.id)

        assertNull(repository.observeById(record.id).first())
        // CASCADE で photo も削除される
        assertTrue(db.photoQueries.selectByRecord(record.id).executeAsList().isEmpty())
    }

    // --- cafe が null のレコードの往復テスト ---

    @Test
    fun self_extract_record_round_trips_correctly() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord(cafe = null)
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertNull(loaded?.cafe)
        assertEquals(record.name, loaded?.name)
        assertEquals(record.brewMethod, loaded?.brewMethod)
        assertEquals(record.origin, loaded?.origin)
    }

    @Test
    fun half_step_rating_round_trips_correctly() = runTest {
        // 0.5 刻みの rating が SQLDelight REAL カラムで正確に往復することを確認する
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord().copy(rating = 4.5)
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertEquals(4.5, loaded?.rating)
    }

    @Test
    fun null_rating_round_trips_correctly() = runTest {
        // rating = null（未評価）が SQLDelight の nullable REAL カラムで正確に往復することを確認する
        // （2026-07-12 B-4: rating の NOT NULL 撤廃）
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord().copy(rating = null)
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertNull(loaded?.rating, "rating = null のレコードは null として往復するべき")
    }

    @Test
    fun record_with_cafe_round_trips_correctly() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord()
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertEquals(record.cafe, loaded?.cafe)
        assertEquals("place-1", loaded?.cafe?.placeId)
    }

    // --- observe_all に両種（cafe あり / null）が混在するケース ---

    @Test
    fun observe_all_includes_both_cafe_and_self_extract_records() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val withCafe = sampleRecord(id = "with-cafe")
        val selfExtract = sampleRecord(id = "self", cafe = null)
        repository.save(withCafe)
        repository.save(selfExtract)

        val list = repository.observeAll(USER_ID).first()
        val ids = list.map { it.id }
        assertTrue(ids.contains("with-cafe"))
        assertTrue(ids.contains("self"))
    }

    // --- tasting 往復テスト ---

    @Test
    fun tasting_with_all_five_values_round_trips_correctly() = runTest {
        // 5 要素すべて設定（all-or-nothing: TastingScores は 5 要素非 null のみ）
        repository = LocalCoffeeRepository(db, coroutineContext)

        val scores = TastingScores(sweetness = 6, body = 7, acidity = 8, flavor = 5, aftertaste = 9)
        val record = sampleRecord().copy(tasting = scores)
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertEquals(scores, loaded?.tasting)
        assertEquals(6, loaded?.tasting?.sweetness)
        assertEquals(7, loaded?.tasting?.body)
        assertEquals(8, loaded?.tasting?.acidity)
        assertEquals(5, loaded?.tasting?.flavor)
        assertEquals(9, loaded?.tasting?.aftertaste)
    }

    @Test
    fun tasting_null_round_trips_correctly() = runTest {
        // tasting = null（未入力）
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord().copy(tasting = null)
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertNull(loaded?.tasting, "tasting = null のレコードは null として往復するべき")
    }

    // --- tags 往復テスト ---

    @Test
    fun tags_empty_list_round_trips_correctly() = runTest {
        // tags = emptyList()（タグなし）が保存・読み取りで正確に往復することを確認する
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord().copy(tags = emptyList())
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertEquals(emptyList<String>(), loaded?.tags, "tags = emptyList() は空リストとして往復するべき")
    }

    @Test
    fun tags_non_empty_round_trips_correctly() = runTest {
        // tags に複数タグを設定した場合の往復確認（日本語・英数字・クォートを含む値）
        repository = LocalCoffeeRepository(db, coroutineContext)

        val tags = listOf("ラテアート", "浅煎り", "single-origin")
        val record = sampleRecord().copy(tags = tags)
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertEquals(tags, loaded?.tags, "非空 tags はそのまま往復するべき")
    }

    // --- 未知 enum 文字列からの安全な復元テスト ---

    @Test
    fun observe_by_id_falls_back_to_other_for_unknown_brew_method_string() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        // ドメインモデルを経由せず、既存 enum に存在しない文字列を直接書き込む
        // （enum リネーム/削除後の旧データや、より新しいクライアントが書いた値を模す）
        insertRawRecord(id = "unknown-brew", brewMethod = "SomeFutureMethod")

        val loaded = repository.observeById("unknown-brew").first()
        assertEquals(BrewMethod.Other, loaded?.brewMethod, "未知の brew_method 文字列は Other にフォールバックするべき")
    }

    @Test
    fun observe_by_id_falls_back_to_null_for_unknown_processing_and_roast_level_strings() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        insertRawRecord(id = "unknown-processing-roast", processing = "SomeFutureProcessing", roastLevel = "SomeFutureRoast")

        val loaded = repository.observeById("unknown-processing-roast").first()
        assertNull(loaded?.processing, "未知の processing 文字列は null にフォールバックするべき")
        assertNull(loaded?.roastLevel, "未知の roast_level 文字列は null にフォールバックするべき")
    }

    @Test
    fun observe_all_does_not_throw_when_a_row_has_unknown_enum_strings() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        repository.save(sampleRecord(id = "normal"))
        insertRawRecord(id = "unknown-brew-in-list", brewMethod = "SomeFutureMethod")

        // observeAll は 1 行でも未知 enum 文字列を含むと従来は例外で落ちていた（valueOf 由来）
        val list = repository.observeAll(USER_ID).first()
        assertEquals(2, list.size)
    }

    /**
     * [CoffeeRecord] を経由せず、SQLDelight の `coffee_record` テーブルに直接
     * 未知 enum 文字列を含む行を挿入するテストヘルパー。
     */
    private fun insertRawRecord(
        id: String,
        brewMethod: String = BrewMethod.HandDrip.name,
        processing: String? = ProcessingMethod.Washed.name,
        roastLevel: String? = RoastLevel.Medium.name,
    ) {
        db.coffeeRecordQueries.upsert(
            id = id,
            user_id = USER_ID,
            cafe_place_id = null,
            cafe_name = null,
            cafe_address = null,
            cafe_latitude = null,
            cafe_longitude = null,
            cafe_photo_references = null,
            cafe_photo_attributions = null,
            cafe_website_url = null,
            cafe_maps_url = null,
            visited_on = LocalDate(2026, 6, 2).toString(),
            rating = 4.0,
            notes = "",
            name = "raw",
            brew_method = brewMethod,
            origin = null,
            region = null,
            variety = null,
            processing = processing,
            roast_level = roastLevel,
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
    }

    // --- brewRecipe 往復テスト（フェーズ 15-E-1）---

    @Test
    fun brew_recipe_with_value_round_trips_correctly() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord(brewRecipe = "豆 15g / 湯 240ml / 92℃ / 2:30")
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertEquals("豆 15g / 湯 240ml / 92℃ / 2:30", loaded?.brewRecipe)
    }

    @Test
    fun brew_recipe_null_round_trips_correctly() = runTest {
        repository = LocalCoffeeRepository(db, coroutineContext)

        val record = sampleRecord(brewRecipe = null)
        repository.save(record)

        val loaded = repository.observeById(record.id).first()
        assertNull(loaded?.brewRecipe, "brewRecipe = null のレコードは null として往復するべき")
    }

    private companion object {
        const val USER_ID = "test-user"

        fun sampleRecord(
            id: String = "record-1",
            placeId: String = "place-1",
            visitedOn: LocalDate = LocalDate(2026, 6, 2),
            brewRecipe: String? = null,
            cafe: Cafe? = Cafe(
                placeId = placeId,
                name = "Blue Bottle 三軒茶屋",
                address = "東京都世田谷区",
                latitude = 35.6448,
                longitude = 139.6694,
                photoReferences = listOf("ref-1", "ref-2"),
                photoAttributions = listOf("Jane Doe", ""),
                websiteUrl = "https://bluebottlecoffee.jp/",
                mapsUrl = null,
            ),
        ): CoffeeRecord = CoffeeRecord(
            id = id,
            userId = USER_ID,
            cafe = cafe,
            visitedOn = visitedOn,
            rating = 4.0,
            notes = "ベリー系の華やかな酸味",
            photos = listOf(
                Photo(
                    id = "p1",
                    fileName = "p1.jpg",
                    localPath = "photos/p1.jpg",
                    remoteUrl = null,
                    width = 1920,
                    height = 1080,
                    createdAt = Instant.fromEpochMilliseconds(1_700_000_000_000),
                ),
            ),
            name = "ケニア カグモイニ",
            brewMethod = BrewMethod.HandDrip,
            origin = "ケニア",
            region = null,
            variety = "SL28",
            processing = ProcessingMethod.Washed,
            roastLevel = RoastLevel.Medium,
            cup = "ノリタケ",
            brewRecipe = brewRecipe,
            tasting = TastingScores(sweetness = 7, body = 5, acidity = 9, flavor = 7, aftertaste = 6), // all-or-nothing: 5 要素すべてセット
            createdAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
            updatedAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
    }
}
