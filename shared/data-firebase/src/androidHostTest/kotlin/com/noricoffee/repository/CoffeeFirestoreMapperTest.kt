package com.noricoffee.repository

import com.google.firebase.Timestamp
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.CoffeeRecord
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull

/**
 * [CoffeeFirestoreMapper] の `rating` nullable 化（2026-07-12 B-4）の decode / encode 正規化を検証する。
 *
 * - encode: `rating == null` はキーごと省略
 * - decode: キー欠如 / null / `0.0`（nullable 化以前の legacy sentinel）はすべて null に正規化
 */
class CoffeeFirestoreMapperTest {

    private fun baseDocument(ratingValue: Any?, includeRatingKey: Boolean = true): Map<String, Any> {
        val doc = mutableMapOf<String, Any>(
            "id" to "record-1",
            "userId" to "user-1",
            "visitedOn" to "2026-06-01",
            "notes" to "",
            "name" to "テストコーヒー",
            "brewMethod" to BrewMethod.HandDrip.name,
            "createdAt" to Timestamp(0, 0),
            "updatedAt" to Timestamp(0, 0),
        )
        if (includeRatingKey && ratingValue != null) {
            doc["rating"] = ratingValue
        }
        return doc
    }

    @Test
    fun fromDocument_missingRatingKey_decodesToNull() {
        val doc = baseDocument(ratingValue = null, includeRatingKey = false)

        val record = CoffeeFirestoreMapper.fromDocument(doc)

        assertNull(record?.rating, "rating キーが欠如している場合は null にデコードされるべき")
    }

    @Test
    fun fromDocument_legacyZeroRating_decodesToNull() {
        val doc = baseDocument(ratingValue = 0.0)

        val record = CoffeeFirestoreMapper.fromDocument(doc)

        assertNull(record?.rating, "legacy sentinel rating=0.0 は null に正規化されるべき")
    }

    @Test
    fun fromDocument_nonZeroRating_decodesToSameValue() {
        val doc = baseDocument(ratingValue = 4.5)

        val record = CoffeeFirestoreMapper.fromDocument(doc)

        assertEquals(4.5, record?.rating)
    }

    @Test
    fun toDocument_nullRating_omitsRatingKey() {
        val record = sampleRecord(rating = null)

        val doc = CoffeeFirestoreMapper.toDocument(record)

        assertFalse(doc.containsKey("rating"), "rating = null のときは rating キーを省略するべき")
    }

    @Test
    fun toDocument_nonNullRating_includesRatingKey() {
        val record = sampleRecord(rating = 4.5)

        val doc = CoffeeFirestoreMapper.toDocument(record)

        assertEquals(4.5, doc["rating"])
    }

    @Test
    fun roundTrip_nullRating_survivesEncodeDecode() {
        val record = sampleRecord(rating = null)

        val doc = CoffeeFirestoreMapper.toDocument(record)
        @Suppress("UNCHECKED_CAST")
        val decoded = CoffeeFirestoreMapper.fromDocument(doc as Map<String, Any>)

        assertNull(decoded?.rating)
    }

    private fun sampleRecord(rating: Double?): CoffeeRecord = CoffeeRecord(
        id = "record-1",
        userId = "user-1",
        cafe = null,
        visitedOn = LocalDate(2026, 6, 1),
        rating = rating,
        notes = "",
        photos = emptyList(),
        name = "テストコーヒー",
        brewMethod = BrewMethod.HandDrip,
        origin = null,
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        brewRecipe = null,
        tasting = null,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )
}
