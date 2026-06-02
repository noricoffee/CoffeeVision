package com.noricoffee.repository

import com.noricoffee.db.AppDatabase
import com.noricoffee.db.createInMemoryTestSqlDriver
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeItem
import com.noricoffee.domain.FoodItem
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.Visit
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

class LocalVisitRepositoryTest {

    private lateinit var repository: LocalVisitRepository
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
    fun saved_visit_with_children_is_observable_by_id() = runTest {
        repository = LocalVisitRepository(db, coroutineContext)

        val visit = sampleVisit()
        repository.save(visit)

        val loaded = repository.observeById(visit.id).first()
        assertEquals(visit, loaded)
    }

    @Test
    fun observe_all_orders_by_visited_on_descending() = runTest {
        repository = LocalVisitRepository(db, coroutineContext)

        val older = sampleVisit(id = "v1", visitedOn = LocalDate(2026, 5, 30))
        val newer = sampleVisit(id = "v2", visitedOn = LocalDate(2026, 6, 1))
        repository.save(older)
        repository.save(newer)

        val list = repository.observeAll(USER_ID).first()
        assertEquals(listOf("v2", "v1"), list.map { it.id })
    }

    @Test
    fun observe_by_cafe_returns_visits_for_the_place() = runTest {
        repository = LocalVisitRepository(db, coroutineContext)

        val a = sampleVisit(id = "a", placeId = "place-a")
        val b = sampleVisit(id = "b", placeId = "place-b")
        repository.save(a)
        repository.save(b)

        val list = repository.observeByCafe(USER_ID, "place-a").first()
        assertEquals(listOf("a"), list.map { it.id })
    }

    @Test
    fun save_replaces_existing_visit_and_children() = runTest {
        repository = LocalVisitRepository(db, coroutineContext)

        val original = sampleVisit()
        repository.save(original)

        val updated = original.copy(
            rating = 5,
            notes = "updated notes",
            coffees = original.coffees + CoffeeItem(
                id = "c2",
                name = "Extra Espresso",
                brewMethod = BrewMethod.Espresso,
                origin = null,
                variety = null,
                processing = null,
                roastLevel = null,
                cup = null,
                rating = 3,
                notes = null,
            ),
        )
        repository.save(updated)

        val loaded = repository.observeById(original.id).first()
        assertEquals(updated, loaded)
    }

    @Test
    fun delete_removes_visit_and_cascades_children() = runTest {
        repository = LocalVisitRepository(db, coroutineContext)

        val visit = sampleVisit()
        repository.save(visit)
        repository.delete(visit.id)

        assertNull(repository.observeById(visit.id).first())
        assertTrue(db.coffeeItemQueries.selectByVisit(visit.id).executeAsList().isEmpty())
        assertTrue(db.foodItemQueries.selectByVisit(visit.id).executeAsList().isEmpty())
        assertTrue(db.photoQueries.selectByVisit(visit.id).executeAsList().isEmpty())
    }

    private companion object {
        const val USER_ID = "test-user"

        fun sampleVisit(
            id: String = "visit-1",
            placeId: String = "place-1",
            visitedOn: LocalDate = LocalDate(2026, 6, 2),
        ): Visit = Visit(
            id = id,
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
            visitedOn = visitedOn,
            ambiance = "落ち着いた木質の内装",
            rating = 4,
            notes = "店員さんが品種を教えてくれた",
            photos = listOf(
                Photo(
                    id = "p1",
                    localPath = "/tmp/p1.jpg",
                    remoteUrl = null,
                    width = 1920,
                    height = 1080,
                    createdAt = Instant.fromEpochMilliseconds(1_700_000_000_000),
                ),
            ),
            coffees = listOf(
                CoffeeItem(
                    id = "c1",
                    name = "ケニア カグモイニ",
                    brewMethod = BrewMethod.HandDrip,
                    origin = "ケニア",
                    variety = "SL28",
                    processing = ProcessingMethod.Washed,
                    roastLevel = RoastLevel.Medium,
                    cup = "ノリタケ",
                    rating = 5,
                    notes = "ベリー系の華やかな酸味",
                ),
            ),
            foods = listOf(
                FoodItem(
                    id = "f1",
                    name = "バナナブレッド",
                    rating = 4,
                    notes = null,
                ),
            ),
            createdAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
            updatedAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
    }
}
