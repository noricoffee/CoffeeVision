package com.noricoffee.data.places

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * [CafeRepositoryImpl.searchText] のオーバーロード委譲テスト。
 *
 * Fake な [PlacesClient] を使い、以下を検証する:
 * 1. `searchText(query)` は `placesClient.searchText(query)` を呼ぶ（locationBias = null）
 * 2. `searchText(query, locationBias)` は `placesClient.searchText(query, locationBias)` を呼ぶ
 * 3. `PlaceSummary` → `Cafe` の変換が正しい（id / displayName / address / lat / lng）
 */
class CafeRepositoryImplSearchTextTest {

    // --- Fake PlacesClient ---

    /**
     * 呼び出し引数を記録するフェイク。
     * 戻り値は [stubbedResults] に設定した [PlaceSummary] リストを返す。
     */
    private class FakePlacesClient : PlacesClient {

        var lastSearchTextQuery: String? = null
        var lastSearchTextLocationBias: LocationBias? = null
        var searchTextCallCount: Int = 0
        var stubbedResults: List<PlaceSummary> = emptyList()

        override suspend fun searchText(query: String): List<PlaceSummary> {
            searchTextCallCount++
            lastSearchTextQuery = query
            lastSearchTextLocationBias = null
            return stubbedResults
        }

        override suspend fun searchText(
            query: String,
            locationBias: LocationBias,
        ): List<PlaceSummary> {
            searchTextCallCount++
            lastSearchTextQuery = query
            lastSearchTextLocationBias = locationBias
            return stubbedResults
        }

        override suspend fun searchNearby(
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
        ): List<PlaceSummary> = emptyList()

        override suspend fun getDetails(placeId: String): PlaceSummary =
            PlaceSummary(
                id = placeId,
                displayName = "",
                formattedAddress = null,
                latitude = null,
                longitude = null,
                websiteUri = null,
                googleMapsUri = null,
                photoNames = emptyList(),
                openNow = null,
                weekdayDescriptions = emptyList(),
                phoneNumber = null,
                priceLevel = null,
                googleRating = null,
                userRatingCount = null,
            )

        override suspend fun photoMediaUrl(
            photoName: String,
            maxWidthPx: Int?,
            maxHeightPx: Int?,
        ): String = ""
    }

    private val fakePlacesClient = FakePlacesClient()
    private val repository = CafeRepositoryImpl(fakePlacesClient)

    // --- searchText(query) ---

    @Test
    fun searchText_withoutBias_callsClientWithoutBias() = runBlockingTest {
        fakePlacesClient.stubbedResults = emptyList()

        repository.searchText("渋谷 コーヒー")

        assertEquals(1, fakePlacesClient.searchTextCallCount)
        assertEquals("渋谷 コーヒー", fakePlacesClient.lastSearchTextQuery)
        assertNull(fakePlacesClient.lastSearchTextLocationBias)
    }

    // --- searchText(query, locationBias) ---

    @Test
    fun searchText_withBias_callsClientWithBias() = runBlockingTest {
        val bias = LocationBias(latitude = 35.658, longitude = 139.701, radiusMeters = 500.0)
        fakePlacesClient.stubbedResults = emptyList()

        repository.searchText("Blue Bottle", bias)

        assertEquals(1, fakePlacesClient.searchTextCallCount)
        assertEquals("Blue Bottle", fakePlacesClient.lastSearchTextQuery)
        assertEquals(bias, fakePlacesClient.lastSearchTextLocationBias)
    }

    @Test
    fun searchText_withBias_returnsConvertedCafe() = runBlockingTest {
        val bias = LocationBias(latitude = 35.658, longitude = 139.701, radiusMeters = 500.0)
        fakePlacesClient.stubbedResults = listOf(
            PlaceSummary(
                id = "ChIJtest001",
                displayName = "Blue Bottle Coffee",
                formattedAddress = "東京都渋谷区",
                latitude = 35.658,
                longitude = 139.701,
                websiteUri = "https://bluebottlecoffee.com",
                googleMapsUri = "https://maps.google.com/?cid=001",
                photoNames = listOf("places/ChIJtest001/photos/ref1"),
                openNow = null,
                weekdayDescriptions = emptyList(),
                phoneNumber = null,
                priceLevel = null,
                googleRating = null,
                userRatingCount = 128,
            )
        )

        val results = repository.searchText("Blue Bottle", bias)

        assertEquals(1, results.size)
        val cafe = results.first()
        assertEquals("ChIJtest001", cafe.placeId)
        assertEquals("Blue Bottle Coffee", cafe.name)
        assertEquals("東京都渋谷区", cafe.address)
        assertEquals(35.658, cafe.latitude)
        assertEquals(139.701, cafe.longitude)
        assertEquals(listOf("places/ChIJtest001/photos/ref1"), cafe.photoReferences)
        assertEquals(128, cafe.userRatingCount)
    }

    @Test
    fun searchText_withBias_emptyResultsPassthrough() = runBlockingTest {
        val bias = LocationBias(latitude = 0.0, longitude = 0.0, radiusMeters = 500.0)
        fakePlacesClient.stubbedResults = emptyList()

        val results = repository.searchText("存在しないカフェ", bias)

        assertEquals(emptyList<Cafe>(), results)
    }
}

/**
 * `suspend` テスト用の `runTest` 互換ヘルパ。
 *
 * KMP の `commonTest` では `kotlinx.coroutines.test.runTest` を使うが、
 * 簡易な同期フェイクであれば `runBlocking` 相当の `runTest` が使える。
 */
private fun runBlockingTest(block: suspend () -> Unit) {
    kotlinx.coroutines.test.runTest { block() }
}
