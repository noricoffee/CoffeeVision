package com.noricoffee.repository

import com.noricoffee.domain.model.CuratedCafe
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [CuratedCafeFirestoreMapper] の decode 挙動を検証する。
 *
 * - 正常系: `prefectureCode` + `cafes` 配列から [CuratedCafe] リストへ正しく変換される
 * - 異常系: ドキュメント直下 `prefectureCode` 欠如は空リスト
 * - 異常系: `cafes` 配列の要素で必須フィールド（placeId / name / latitude / longitude）が
 *   欠如している要素は skip され、他の正常な要素は残る
 */
class CuratedCafeFirestoreMapperTest {

    @Test
    fun fromDocument_validDocument_decodesAllCafes() {
        val doc = mapOf<String, Any>(
            "prefectureCode" to "13",
            "prefectureName" to "東京都",
            "cafes" to listOf(
                mapOf(
                    "placeId" to "place-1",
                    "name" to "Test Cafe 1",
                    "latitude" to 35.658,
                    "longitude" to 139.701,
                ),
                mapOf(
                    "placeId" to "place-2",
                    "name" to "Test Cafe 2",
                    "latitude" to 35.660,
                    "longitude" to 139.700,
                ),
            ),
        )

        val cafes = CuratedCafeFirestoreMapper.fromDocument(doc)

        assertEquals(
            listOf(
                CuratedCafe(
                    placeId = "place-1",
                    name = "Test Cafe 1",
                    latitude = 35.658,
                    longitude = 139.701,
                    prefectureCode = "13",
                ),
                CuratedCafe(
                    placeId = "place-2",
                    name = "Test Cafe 2",
                    latitude = 35.660,
                    longitude = 139.700,
                    prefectureCode = "13",
                ),
            ),
            cafes,
        )
    }

    @Test
    fun fromDocument_missingPrefectureCode_returnsEmptyList() {
        val doc = mapOf<String, Any>(
            "cafes" to listOf(
                mapOf(
                    "placeId" to "place-1",
                    "name" to "Test Cafe 1",
                    "latitude" to 35.658,
                    "longitude" to 139.701,
                ),
            ),
        )

        val cafes = CuratedCafeFirestoreMapper.fromDocument(doc)

        assertTrue(cafes.isEmpty())
    }

    @Test
    fun fromDocument_missingCafesArray_returnsEmptyList() {
        val doc = mapOf<String, Any>("prefectureCode" to "13")

        val cafes = CuratedCafeFirestoreMapper.fromDocument(doc)

        assertTrue(cafes.isEmpty())
    }

    @Test
    fun fromDocument_cafeEntryMissingRequiredField_isSkippedButOthersSurvive() {
        val doc = mapOf<String, Any>(
            "prefectureCode" to "13",
            "cafes" to listOf(
                mapOf(
                    // placeId 欠如 → skip されるべき
                    "name" to "Missing PlaceId Cafe",
                    "latitude" to 35.658,
                    "longitude" to 139.701,
                ),
                mapOf(
                    "placeId" to "place-2",
                    "name" to "Test Cafe 2",
                    "latitude" to 35.660,
                    "longitude" to 139.700,
                ),
            ),
        )

        val cafes = CuratedCafeFirestoreMapper.fromDocument(doc)

        assertEquals(listOf("place-2"), cafes.map { it.placeId })
    }

    @Test
    fun fromDocument_cafeEntryIntegerCoordinates_decodesAsDouble() {
        val doc = mapOf<String, Any>(
            "prefectureCode" to "13",
            "cafes" to listOf(
                mapOf(
                    "placeId" to "place-1",
                    "name" to "Test Cafe 1",
                    "latitude" to 35L,
                    "longitude" to 139L,
                ),
            ),
        )

        val cafes = CuratedCafeFirestoreMapper.fromDocument(doc)

        assertEquals(35.0, cafes.first().latitude)
        assertEquals(139.0, cafes.first().longitude)
    }
}
