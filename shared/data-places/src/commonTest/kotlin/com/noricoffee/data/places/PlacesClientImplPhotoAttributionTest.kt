package com.noricoffee.data.places

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * 写真の作者帰属（`authorAttributions`）の DTO デコード / マッピングを検証するテスト。
 *
 * Google Maps Platform のポリシー（App Store ガイドライン 5.2.2 対応）で、写真表示時は
 * 作者クレジットの掲示が必須。`authorAttributions` は `places.photos` を FieldMask に
 * 含めれば自動的に付随して返るため（Google 公式ドキュメント確認済み）、FieldMask 自体への
 * 追加は不要。ここでは DTO デコードと [PlaceSummary.photoAttributions] へのマッピングのみ検証する。
 *
 * 1. `authorAttributions[0].displayName` が [PlaceSummary.photoAttributions] にマッピングされる
 * 2. `photoNames` と `photoAttributions` は同じ順序・同じ長さ（作者情報が無い写真は空文字）
 * 3. `photos` が空の場合は両方とも空リスト
 */
class PlacesClientImplPhotoAttributionTest {

    private fun buildClient(responseJson: String): PlacesClientImpl {
        val engine = MockEngine { _ ->
            respond(
                content = responseJson,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        return PlacesClientImpl(httpClient = HttpClient(engine), apiKey = "test-key")
    }

    @Test
    fun searchText_decodesAuthorAttributions_intoPlaceSummary() = runTest {
        val client = buildClient(
            """
                {"places":[{
                    "id":"ChIJtest001",
                    "displayName":{"text":"Blue Bottle"},
                    "photos":[
                        {"name":"places/ChIJtest001/photos/ref1","authorAttributions":[{"displayName":"Jane Doe"}]},
                        {"name":"places/ChIJtest001/photos/ref2","authorAttributions":[]}
                    ]
                }]}
            """.trimIndent(),
        )

        val results = client.searchText("渋谷 カフェ")

        assertEquals(1, results.size)
        val summary = results.first()
        assertEquals(
            listOf("places/ChIJtest001/photos/ref1", "places/ChIJtest001/photos/ref2"),
            summary.photoNames,
        )
        assertEquals(listOf("Jane Doe", ""), summary.photoAttributions)
    }

    @Test
    fun searchText_noPhotos_mapsToEmptyAttributions() = runTest {
        val client = buildClient(
            """
                {"places":[{"id":"ChIJtest001","displayName":{"text":"Blue Bottle"}}]}
            """.trimIndent(),
        )

        val results = client.searchText("渋谷 カフェ")

        assertEquals(1, results.size)
        assertEquals(emptyList(), results.first().photoNames)
        assertEquals(emptyList(), results.first().photoAttributions)
    }

    @Test
    fun searchText_photoWithMultipleAttributions_usesFirstOnly() = runTest {
        val client = buildClient(
            """
                {"places":[{
                    "id":"ChIJtest001",
                    "displayName":{"text":"Blue Bottle"},
                    "photos":[
                        {"name":"places/ChIJtest001/photos/ref1","authorAttributions":[
                            {"displayName":"First Author"},
                            {"displayName":"Second Author"}
                        ]}
                    ]
                }]}
            """.trimIndent(),
        )

        val results = client.searchText("渋谷 カフェ")

        assertEquals(listOf("First Author"), results.first().photoAttributions)
    }
}
