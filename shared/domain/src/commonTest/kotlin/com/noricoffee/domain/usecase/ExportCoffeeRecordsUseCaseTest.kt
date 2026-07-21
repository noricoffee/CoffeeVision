package com.noricoffee.domain.usecase

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.TastingScores
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [ExportCoffeeRecordsUseCase] を検証する（要件 §7-4 / tasks.md フェーズ 15-E-2）。
 *
 * 検証観点:
 * 1. 出力が有効な JSON であること
 * 2. cafe あり/セルフ抽出、tasting あり/なし、tags、brewRecipe など主要フィールドが含まれること
 * 3. 0 件時は `records: []` になること
 */
class ExportCoffeeRecordsUseCaseTest {

    // --- テスト用 Fake ---

    private class FakeCoffeeRepository(
        private val records: List<CoffeeRecord> = emptyList(),
    ) : CoffeeRepository {

        private val flow = MutableStateFlow(records)

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flow

        override fun observeById(id: String): Flow<CoffeeRecord?> =
            MutableStateFlow(records.firstOrNull { it.id == id })

        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> =
            MutableStateFlow(records.filter { it.cafe?.placeId == placeId })

        override suspend fun save(record: CoffeeRecord) = Unit

        override suspend fun delete(userId: String, id: String) = Unit
    }

    // --- テスト用ヘルパ ---

    private fun cafe(placeId: String = "place-1") = Cafe(
        placeId = placeId,
        name = "Blue Bottle 三軒茶屋",
        address = "東京都世田谷区",
        latitude = 35.6448,
        longitude = 139.6694,
        photoReferences = listOf("photo-ref-1"),
        websiteUrl = "https://bluebottlecoffee.jp/",
        mapsUrl = "https://maps.google.com/?cid=1",
    )

    private fun tasting() = TastingScores(
        sweetness = 7,
        body = 5,
        acidity = 9,
        flavor = 7,
        aftertaste = 6,
    )

    private fun record(
        id: String,
        cafe: Cafe? = null,
        tasting: TastingScores? = null,
        tags: List<String> = emptyList(),
        brewRecipe: String? = null,
    ) = CoffeeRecord(
        id = id,
        userId = "user-1",
        cafe = cafe,
        visitedOn = LocalDate(2026, 6, 2),
        rating = 4.5,
        notes = "ベリー系の華やかな酸味",
        photos = emptyList(),
        name = "本日のコーヒー",
        brewMethod = BrewMethod.HandDrip,
        origin = "ケニア",
        region = null,
        variety = "SL28",
        processing = null,
        roastLevel = null,
        cup = null,
        brewRecipe = brewRecipe,
        tasting = tasting,
        tags = tags,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    // --- テスト ---

    @Test
    fun emptyRecords_producesValidJsonWithEmptyRecordsArray() = runTest {
        val useCase = ExportCoffeeRecordsUseCase(FakeCoffeeRepository(emptyList()))

        val json = useCase("user-1")

        val root = Json.parseToJsonElement(json).jsonObject
        assertEquals(1, root["version"]!!.jsonPrimitive.int)
        assertTrue(root.containsKey("exportedAt"))
        assertTrue(root["records"]!!.jsonArray.isEmpty())
    }

    @Test
    fun recordWithCafeAndTastingAndTagsAndBrewRecipe_includesAllFields() = runTest {
        val r = record(
            id = "r1",
            cafe = cafe(),
            tasting = tasting(),
            tags = listOf("ラテアート", "浅煎り"),
            brewRecipe = "豆 15g / 湯 240ml / 92℃ / 2:30",
        )
        val useCase = ExportCoffeeRecordsUseCase(FakeCoffeeRepository(listOf(r)))

        val json = useCase("user-1")

        val records = Json.parseToJsonElement(json).jsonObject["records"]!!.jsonArray
        assertEquals(1, records.size)
        val obj = records.first().jsonObject

        assertEquals("r1", obj["id"]!!.jsonPrimitive.content)
        assertEquals("2026-06-02", obj["visitedOn"]!!.jsonPrimitive.content)
        assertEquals("HandDrip", obj["brewMethod"]!!.jsonPrimitive.content)
        assertEquals("豆 15g / 湯 240ml / 92℃ / 2:30", obj["brewRecipe"]!!.jsonPrimitive.content)

        val cafeObj = obj["cafe"]!!.jsonObject
        assertEquals("place-1", cafeObj["placeId"]!!.jsonPrimitive.content)
        assertEquals("Blue Bottle 三軒茶屋", cafeObj["name"]!!.jsonPrimitive.content)

        val tastingObj = obj["tasting"]!!.jsonObject
        assertEquals(7, tastingObj["sweetness"]!!.jsonPrimitive.int)
        assertEquals(9, tastingObj["acidity"]!!.jsonPrimitive.int)

        val tagsArray = obj["tags"]!!.jsonArray
        assertEquals(2, tagsArray.size)
        assertEquals("ラテアート", tagsArray[0].jsonPrimitive.content)
    }

    @Test
    fun selfExtractedRecordWithoutTasting_cafeAndTastingAreNull() = runTest {
        val r = record(id = "r2", cafe = null, tasting = null)
        val useCase = ExportCoffeeRecordsUseCase(FakeCoffeeRepository(listOf(r)))

        val json = useCase("user-1")

        val obj = Json.parseToJsonElement(json).jsonObject["records"]!!.jsonArray.first().jsonObject
        assertEquals(JsonNull, obj["cafe"])
        assertEquals(JsonNull, obj["tasting"])
    }

    @Test
    fun multipleRecords_allIncludedInOutput() = runTest {
        val records = listOf(
            record(id = "r1", cafe = cafe("place-1")),
            record(id = "r2", cafe = null),
            record(id = "r3", tasting = tasting()),
        )
        val useCase = ExportCoffeeRecordsUseCase(FakeCoffeeRepository(records))

        val json = useCase("user-1")

        val ids = Json.parseToJsonElement(json).jsonObject["records"]!!.jsonArray
            .map { it.jsonObject["id"]!!.jsonPrimitive.content }
        assertEquals(listOf("r1", "r2", "r3"), ids)
    }
}
