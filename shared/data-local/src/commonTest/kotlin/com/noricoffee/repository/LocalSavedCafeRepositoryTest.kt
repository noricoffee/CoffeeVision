package com.noricoffee.repository

import com.noricoffee.db.AppDatabase
import com.noricoffee.db.createInMemoryTestSqlDriver
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.model.SavedCafe
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlin.coroutines.coroutineContext
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class LocalSavedCafeRepositoryTest {

    private lateinit var repository: LocalSavedCafeRepository
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

    @Test
    fun saved_cafe_round_trips_via_observe_by_place_id() = runTest {
        repository = LocalSavedCafeRepository(db, coroutineContext)

        val savedCafe = sampleSavedCafe()
        repository.save(savedCafe)

        val loaded = repository.observeByPlaceId(USER_ID, savedCafe.cafe.placeId).first()
        assertEquals(savedCafe, loaded)
    }

    @Test
    fun observe_all_orders_by_saved_at_descending() = runTest {
        repository = LocalSavedCafeRepository(db, coroutineContext)

        val older = sampleSavedCafe(placeId = "place-old", savedAt = Instant.fromEpochMilliseconds(1_000))
        val newer = sampleSavedCafe(placeId = "place-new", savedAt = Instant.fromEpochMilliseconds(2_000))
        repository.save(older)
        repository.save(newer)

        val list = repository.observeAll(USER_ID).first()
        assertEquals(listOf("place-new", "place-old"), list.map { it.cafe.placeId })
    }

    @Test
    fun save_upserts_existing_place_id() = runTest {
        repository = LocalSavedCafeRepository(db, coroutineContext)

        val original = sampleSavedCafe()
        repository.save(original)

        val updated = original.copy(note = "更新後のメモ")
        repository.save(updated)

        val list = repository.observeAll(USER_ID).first()
        assertEquals(1, list.size, "同一 placeId は上書きされ件数は増えない")
        assertEquals("更新後のメモ", list.first().note)
    }

    @Test
    fun delete_removes_saved_cafe() = runTest {
        repository = LocalSavedCafeRepository(db, coroutineContext)

        val savedCafe = sampleSavedCafe()
        repository.save(savedCafe)
        repository.delete(USER_ID, savedCafe.cafe.placeId)

        assertNull(repository.observeByPlaceId(USER_ID, savedCafe.cafe.placeId).first())
        assertTrue(repository.observeAll(USER_ID).first().isEmpty())
    }

    @Test
    fun observe_by_place_id_returns_null_when_not_saved() = runTest {
        repository = LocalSavedCafeRepository(db, coroutineContext)

        assertNull(repository.observeByPlaceId(USER_ID, "unknown-place").first())
    }

    private companion object {
        const val USER_ID = "test-user"

        fun sampleSavedCafe(
            placeId: String = "place-1",
            savedAt: Instant = Instant.fromEpochMilliseconds(1_750_000_000_000),
        ): SavedCafe = SavedCafe(
            userId = USER_ID,
            cafe = Cafe(
                placeId = placeId,
                name = "Blue Bottle 三軒茶屋",
                address = "東京都世田谷区",
                latitude = 35.6448,
                longitude = 139.6694,
                photoReferences = listOf("ref-1", "ref-2"),
                websiteUrl = "https://bluebottlecoffee.jp/",
                mapsUrl = null,
            ),
            note = "",
            savedAt = savedAt,
        )
    }
}
