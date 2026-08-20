package com.noricoffee.repository

import com.google.firebase.Timestamp
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

/**
 * [CoffeeFirestoreMapper] の `cafe.photoAttributions`（写真の作者帰属。
 * App Store ガイドライン 5.2.2 対応）の encode / decode を検証する。
 *
 * - encode: 非空リストは `photoAttributions` キーとして書き出す。空リストはキーごと省略
 * - decode: キー欠如は空リストにフォールバックする
 * - round trip: encode → decode で元の値が保持される
 */
class CoffeeFirestoreMapperPhotoAttributionTest {

    @Test
    fun toDocument_nonEmptyPhotoAttributions_includesKey() {
        val record = sampleRecord(photoAttributions = listOf("Jane Doe", ""))

        val doc = CoffeeFirestoreMapper.toDocument(record)

        @Suppress("UNCHECKED_CAST")
        val cafeMap = doc["cafe"] as Map<String, Any?>
        assertEquals(listOf("Jane Doe", ""), cafeMap["photoAttributions"])
    }

    @Test
    fun toDocument_emptyPhotoAttributions_omitsKey() {
        val record = sampleRecord(photoAttributions = emptyList())

        val doc = CoffeeFirestoreMapper.toDocument(record)

        @Suppress("UNCHECKED_CAST")
        val cafeMap = doc["cafe"] as Map<String, Any?>
        assertFalse(
            cafeMap.containsKey("photoAttributions"),
            "photoAttributions が空リストのときはキーを省略するべき",
        )
    }

    @Test
    fun fromDocument_missingPhotoAttributionsKey_decodesToEmptyList() {
        val record = sampleRecord(photoAttributions = emptyList())
        val doc = CoffeeFirestoreMapper.toDocument(record)

        @Suppress("UNCHECKED_CAST")
        val decoded = CoffeeFirestoreMapper.fromDocument(doc as Map<String, Any>)

        assertEquals(emptyList(), decoded?.cafe?.photoAttributions)
    }

    @Test
    fun roundTrip_photoAttributions_survivesEncodeDecode() {
        val record = sampleRecord(photoAttributions = listOf("Jane Doe", "", "John Smith"))

        val doc = CoffeeFirestoreMapper.toDocument(record)
        @Suppress("UNCHECKED_CAST")
        val decoded = CoffeeFirestoreMapper.fromDocument(doc as Map<String, Any>)

        assertEquals(listOf("Jane Doe", "", "John Smith"), decoded?.cafe?.photoAttributions)
    }

    private fun sampleRecord(photoAttributions: List<String>): CoffeeRecord = CoffeeRecord(
        id = "record-1",
        userId = "user-1",
        cafe = Cafe(
            placeId = "ChIJtest001",
            name = "Blue Bottle Coffee",
            address = "東京都渋谷区",
            latitude = 35.658,
            longitude = 139.701,
            photoReferences = listOf("places/ChIJtest001/photos/ref1"),
            photoAttributions = photoAttributions,
            websiteUrl = null,
            mapsUrl = null,
        ),
        visitedOn = LocalDate(2026, 6, 1),
        rating = 4.5,
        notes = "",
        photos = emptyList(),
        name = "テストコーヒー",
        brewMethod = BrewMethod.HandDrip,
        origin = null,
        region = null,
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
